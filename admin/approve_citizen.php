<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/admin_guard.php';
require_once __DIR__ . '/includes/layout.php';

$admin = require_admin();

$loadError = null;
$actionMessage = null;
$actionError = null;

// Hardcoded Supabase configuration
$SUPABASE_URL = 'https://kfvhnpkkwxipschhlouk.supabase.co';
$SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtmdmhucGtrd3hpcHNjaGhsb3VrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MzEzNjg3OSwiZXhwIjoyMDk4NzEyODc5fQ.qdl_L_3h2f8xzBmijRNMMUa1FklYog5fvZqgkJrojeQ';

// Pagination parameters
$page = max(1, (int)($_GET['page'] ?? 1));
$perPage = 10;
$offset = ($page - 1) * $perPage;
$statusFilter = $_GET['status'] ?? 'all';

// Filter Parameters
$dateFrom = $_GET['date_from'] ?? '';
$dateTo = $_GET['date_to'] ?? '';
$searchQuery = trim($_GET['search'] ?? '');

/*
|--------------------------------------------------------------------------
| Call Supabase REST API directly
|--------------------------------------------------------------------------
*/
function supabaseRequest($method, $endpoint, $body = null, $query = []) {
    global $SUPABASE_URL, $SUPABASE_KEY;
    
    $url = rtrim($SUPABASE_URL, '/') . $endpoint;
    if (!empty($query)) {
        $url .= '?' . http_build_query($query);
    }
    
    $ch = curl_init($url);
    $headers = [
        'apikey: ' . $SUPABASE_KEY,
        'Authorization: Bearer ' . $SUPABASE_KEY,
        'Content-Type: application/json',
        'Prefer: return=representation'
    ];
    
    $options = [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_TIMEOUT => 30,
        CURLOPT_SSL_VERIFYPEER => false
    ];
    
    if ($body !== null) {
        $options[CURLOPT_POSTFIELDS] = json_encode($body);
    }
    
    curl_setopt_array($ch, $options);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);
    
    if ($error) {
        throw new Exception('CURL Error: ' . $error);
    }
    
    if ($httpCode < 200 || $httpCode >= 300) {
        throw new Exception('HTTP ' . $httpCode . ': ' . substr($response, 0, 500));
    }
    
    $data = json_decode($response, true);
    return is_array($data) ? $data : [];
}

/*
|--------------------------------------------------------------------------
| Helper: Get full Storage URL
|--------------------------------------------------------------------------
*/
function getFullStorageUrl($path) {
    global $SUPABASE_URL;
    if (empty($path)) return null;
    if (filter_var($path, FILTER_VALIDATE_URL)) return $path;
    
    return rtrim($SUPABASE_URL, '/') . '/storage/v1/object/public/registration-documents/' . ltrim($path, '/');
}

/*
|--------------------------------------------------------------------------
| Handle Approve / Reject for Citizen
|--------------------------------------------------------------------------
*/
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $profileId = trim((string)($_POST['profile_id'] ?? ''));
    $decision = trim((string)($_POST['decision'] ?? ''));

    if ($profileId === '') {
        $actionError = 'Invalid ID.';
    } elseif (!in_array($decision, ['approve', 'reject'], true)) {
        $actionError = 'Invalid decision.';
    } else {
        try {
            $newStatus = $decision === 'approve' ? 'approved' : 'rejected';
            
            supabaseRequest(
                'PATCH',
                '/rest/v1/citizens?profile_id=eq.' . rawurlencode($profileId),
                [
                    'verification_status' => $newStatus,
                    'verified_at' => gmdate('c'),
                    'verified_by' => $admin['id'] ?? null
                ]
            );

            $actionMessage = $decision === 'approve'
                ? 'Citizen has been approved successfully.'
                : 'Citizen has been rejected successfully.';

            header('Location: ' . $_SERVER['PHP_SELF'] . '?status=' . $statusFilter . '&date_from=' . $dateFrom . '&date_to=' . $dateTo . '&search=' . urlencode($searchQuery) . '&page=' . $page);
            exit;
        } catch (Throwable $e) {
            $actionError = 'Unable to update. Please try again later.';
            error_log('Approve error: ' . $e->getMessage());
        }
    }
}

/*
|--------------------------------------------------------------------------
| Load Citizens with Stats & Filters
|--------------------------------------------------------------------------
*/
$items = [];
$totalItems = 0;
$pendingCount = 0;
$approvedCount = 0;
$rejectedCount = 0;

try {
    // Get Citizens only
    $citizens = supabaseRequest('GET', '/rest/v1/citizens?select=*&order=verified_at.desc.nullslast');
    $allItems = [];
    
    if (is_array($citizens)) {
        foreach ($citizens as $c) {
            $c['_type'] = 'citizen';
            $c['_display_name'] = 'Citizen';
            $c['_icon'] = '';
            $c['_photo_front'] = getFullStorageUrl($c['ic_front_url'] ?? null);
            $c['_photo_back'] = getFullStorageUrl($c['ic_back_url'] ?? null);
            $allItems[] = $c;
        }
    }
    
    // Date Range Filter
    if ($dateFrom !== '') {
        $allItems = array_filter($allItems, function($item) use ($dateFrom) {
            $createdAt = $item['created_at'] ?? '';
            if ($createdAt === '') return true;
            return strtotime($createdAt) >= strtotime($dateFrom . ' 00:00:00');
        });
    }
    if ($dateTo !== '') {
        $allItems = array_filter($allItems, function($item) use ($dateTo) {
            $createdAt = $item['created_at'] ?? '';
            if ($createdAt === '') return true;
            return strtotime($createdAt) <= strtotime($dateTo . ' 23:59:59');
        });
    }
    
    // Keyword Search
    if ($searchQuery !== '') {
        $searchLower = strtolower($searchQuery);
        $allItems = array_filter($allItems, function($item) use ($searchLower) {
            $profileId = strtolower($item['profile_id'] ?? '');
            $ic = strtolower($item['ic_number'] ?? '');
            
            return strpos($profileId, $searchLower) !== false ||
                   strpos($ic, $searchLower) !== false;
        });
    }
    
    // Filter by status
    if ($statusFilter !== 'all') {
        $allItems = array_filter($allItems, function($item) use ($statusFilter) {
            $status = strtolower($item['verification_status'] ?? '');
            return $status === $statusFilter;
        });
    }
    
    // Sort by created_at desc
    usort($allItems, function($a, $b) {
        $timeA = strtotime($a['created_at'] ?? $a['verified_at'] ?? 'now');
        $timeB = strtotime($b['created_at'] ?? $b['verified_at'] ?? 'now');
        return $timeB - $timeA;
    });
    
    // Count stats
    $totalItems = count($allItems);
    foreach ($allItems as $item) {
        $status = strtolower($item['verification_status'] ?? '');
        if ($status === 'pending') $pendingCount++;
        elseif ($status === 'approved') $approvedCount++;
        elseif ($status === 'rejected') $rejectedCount++;
    }
    
    // Paginate
    $items = array_slice($allItems, $offset, $perPage);
    
} catch (Throwable $e) {
    $loadError = 'Unable to load data. Error: ' . $e->getMessage();
    error_log('Load error: ' . $e->getMessage());
}

$totalPages = ceil($totalItems / $perPage);

render_admin_start('Approve Citizens', $admin, 'dashboard');

?>

<style>
/* =========================================================
   PAGE LAYOUT
========================================================= */
.citizen-page {
    display: flex;
    flex-direction: column;
    gap: 24px;
}

.citizen-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 20px;
    flex-wrap: wrap;
}

.citizen-header h1 {
    margin: 0;
    font-size: 24px;
    font-weight: 700;
    color: #1a1a2e;
}

.citizen-header h1 i {
    color: #8b5cf6;
}

.citizen-header .subtitle {
    display: flex;
    align-items: center;
    gap: 12px;
    margin: 4px 0 0;
    flex-wrap: wrap;
}

.citizen-header .subtitle p {
    margin: 0;
    opacity: .7;
    font-size: 14px;
}

.citizen-header .badge-citizens {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 2px 12px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 600;
    background: #ede9fe;
    color: #5b21b6;
}

.btn-back {
    padding: 8px 20px;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    text-decoration: none;
    color: #4b5563;
    font-size: 13px;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    transition: all 0.2s;
    font-weight: 500;
}

.btn-back:hover {
    background: #f3f4f6;
}

/* =========================================================
   STATS CARDS
========================================================= */
.stats-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 14px;
}

.stat-card {
    padding: 18px 16px;
    border-radius: 14px;
    background: white;
    box-shadow: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04);
    text-align: center;
    transition: transform 0.2s, box-shadow 0.2s;
    border: 1px solid #f1f3f5;
}

.stat-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 25px rgba(0,0,0,0.08);
}

.stat-card .stat-number {
    font-size: 26px;
    font-weight: 700;
    display: block;
    line-height: 1.2;
}

.stat-card .stat-label {
    font-size: 12px;
    opacity: .7;
    margin-top: 4px;
    display: block;
}

.stat-card .stat-icon {
    font-size: 20px;
    display: block;
    margin-bottom: 4px;
}

.stat-total .stat-number { color: #1a1a2e; }
.stat-pending .stat-number { color: #f59e0b; }
.stat-approved .stat-number { color: #10b981; }
.stat-rejected .stat-number { color: #dc3545; }

/* =========================================================
   FILTER BAR
========================================================= */
.filter-bar {
    display: flex;
    flex-direction: column;
    gap: 12px;
    padding: 16px 18px;
    background: white;
    border-radius: 14px;
    border: 1px solid #f1f3f5;
    box-shadow: 0 1px 3px rgba(0,0,0,0.04);
}

.filter-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
}

.filter-group {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
    align-items: center;
}

.filter-btn {
    padding: 4px 16px;
    border: 1px solid #e5e7eb;
    border-radius: 20px;
    background: white;
    cursor: pointer;
    font-size: 12px;
    color: #4b5563;
    text-decoration: none;
    transition: all 0.2s;
    font-weight: 500;
}

.filter-btn:hover {
    background: #f3f4f6;
    border-color: #d1d5db;
}

.filter-btn.active {
    background: #1a1a2e;
    color: white;
    border-color: #1a1a2e;
}

.filter-btn.active-pending {
    background: #f59e0b;
    color: white;
    border-color: #f59e0b;
}

.filter-btn.active-approved {
    background: #10b981;
    color: white;
    border-color: #10b981;
}

.filter-btn.active-rejected {
    background: #dc3545;
    color: white;
    border-color: #dc3545;
}

.filter-divider {
    color: #e5e7eb;
    font-size: 20px;
    padding: 0 4px;
}

.filter-label {
    font-size: 11px;
    font-weight: 600;
    color: #6b7280;
    text-transform: uppercase;
    letter-spacing: 0.05em;
}

.filter-input {
    padding: 6px 12px;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    font-size: 12px;
    background: white;
    transition: border-color 0.2s;
    color: #1a1a2e;
}

.filter-input:focus {
    outline: none;
    border-color: #1a1a2e;
    box-shadow: 0 0 0 3px rgba(26,26,46,0.08);
}

.filter-input-sm {
    padding: 4px 10px;
    font-size: 12px;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    background: white;
    min-width: 100px;
}

.filter-actions {
    display: flex;
    gap: 6px;
    align-items: center;
    flex-wrap: wrap;
}

.btn-filter {
    padding: 6px 16px;
    font-size: 12px;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    font-weight: 500;
    transition: all 0.2s;
    display: inline-flex;
    align-items: center;
    gap: 4px;
}

.btn-filter-primary {
    background: #1a1a2e;
    color: white;
}

.btn-filter-primary:hover {
    background: #2d2d4e;
}

.btn-filter-outline {
    background: white;
    color: #4b5563;
    border: 1px solid #e5e7eb;
}

.btn-filter-outline:hover {
    background: #f3f4f6;
}

.btn-filter-reset {
    background: #f3f4f6;
    color: #4b5563;
    border: 1px solid #e5e7eb;
}

.btn-filter-reset:hover {
    background: #e5e7eb;
}

/* Active Filters Display */
.active-filters {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
    padding: 4px 0;
}

.filter-badge {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 2px 10px;
    border-radius: 12px;
    font-size: 10px;
    font-weight: 600;
    background: #f1f5f9;
    color: #4b5563;
}

.filter-badge .remove {
    cursor: pointer;
    font-weight: 700;
    margin-left: 2px;
}

.filter-badge .remove:hover {
    color: #dc3545;
}

.filter-badge-date {
    background: #dbeafe;
    color: #1e40af;
}

.filter-badge-search {
    background: #fef3c7;
    color: #92400e;
}

/* =========================================================
   TABLE
========================================================= */
.table-container {
    background: white;
    border-radius: 16px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04);
    border: 1px solid #f1f3f5;
    overflow: hidden;
}

.citizen-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 14px;
}

.citizen-table thead {
    background: #f8fafc;
    border-bottom: 2px solid #e5e7eb;
}

.citizen-table th {
    padding: 14px 16px;
    text-align: left;
    font-weight: 600;
    color: #4b5563;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
}

.citizen-table td {
    padding: 14px 16px;
    border-bottom: 1px solid #f1f3f5;
    vertical-align: middle;
}

.citizen-table tbody tr:hover {
    background: #f8fafc;
}

.citizen-table tbody tr:last-child td {
    border-bottom: none;
}

.citizen-id {
    font-weight: 600;
    color: #1a1a2e;
    font-family: monospace;
}

.type-badge {
    display: inline-block;
    padding: 2px 10px;
    border-radius: 12px;
    font-size: 11px;
    font-weight: 600;
}

.type-citizen {
    background: #ede9fe;
    color: #5b21b6;
}

.photo-thumb {
    width: 40px;
    height: 40px;
    border-radius: 8px;
    object-fit: cover;
    border: 1px solid #e5e7eb;
    cursor: pointer;
    transition: transform 0.2s;
}

.photo-thumb:hover {
    transform: scale(1.1);
}

.photo-thumb-placeholder {
    width: 40px;
    height: 40px;
    border-radius: 8px;
    background: #f3f4f6;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
    color: #9ca3af;
    border: 1px solid #e5e7eb;
}

.status-badge {
    display: inline-block;
    padding: 4px 12px;
    border-radius: 12px;
    font-size: 11px;
    font-weight: 600;
}

.status-pending {
    background: #fef3c7;
    color: #92400e;
}

.status-approved {
    background: #d1fae5;
    color: #065f46;
}

.status-rejected {
    background: #fee2e2;
    color: #991b1b;
}

/* =========================================================
   ACTION BUTTONS
========================================================= */
.btn-view {
    padding: 6px 18px;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    background: white;
    font-size: 12px;
    cursor: pointer;
    text-decoration: none;
    color: #4b5563;
    transition: all 0.2s;
    font-weight: 500;
}

.btn-view:hover {
    background: #f3f4f6;
    border-color: #d1d5db;
}

/* =========================================================
   PAGINATION
========================================================= */
.pagination {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px 20px;
    border-top: 1px solid #f1f3f5;
    flex-wrap: wrap;
    gap: 12px;
}

.pagination-info {
    font-size: 14px;
    color: #6b7280;
}

.pagination-links {
    display: flex;
    gap: 4px;
}

.pagination-links a,
.pagination-links span {
    padding: 6px 12px;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    text-decoration: none;
    color: #4b5563;
    font-size: 13px;
    min-width: 32px;
    text-align: center;
    transition: all 0.2s;
}

.pagination-links a:hover {
    background: #f3f4f6;
}

.pagination-links .active {
    background: #1a1a2e;
    color: white;
    border-color: #1a1a2e;
}

.pagination-links .disabled {
    opacity: 0.5;
    cursor: not-allowed;
}

/* =========================================================
   ALERTS
========================================================= */
.citizen-alert {
    padding: 14px 18px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    gap: 10px;
}

.citizen-alert i {
    font-size: 20px;
}

.citizen-success {
    background: #d1fae5;
    color: #065f46;
}

.citizen-error {
    background: #fee2e2;
    color: #991b1b;
}

/* =========================================================
   EMPTY STATE
========================================================= */
.empty-state {
    padding: 60px 20px;
    text-align: center;
}

.empty-state i {
    font-size: 44px;
    opacity: .4;
    display: block;
    margin-bottom: 12px;
}

.empty-state h3 {
    font-size: 18px;
    color: #1a1a2e;
    margin: 0 0 4px 0;
}

.empty-state p {
    color: #6b7280;
    font-size: 14px;
    margin: 0;
}

/* =========================================================
   DRAWER / SLIDE-OUT PANEL
========================================================= */
.drawer-overlay {
    display: none;
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.4);
    z-index: 999;
}

.drawer-overlay.active {
    display: block;
}

.drawer-panel {
    position: fixed;
    top: 0;
    right: -650px;
    width: 650px;
    max-width: 95vw;
    height: 100vh;
    background: white;
    z-index: 1000;
    transition: right 0.3s ease;
    box-shadow: -4px 0 20px rgba(0,0,0,0.15);
    overflow-y: auto;
    display: flex;
    flex-direction: column;
}

.drawer-panel.active {
    right: 0;
}

.drawer-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 20px 24px;
    border-bottom: 1px solid #f1f3f5;
    background: white;
    position: sticky;
    top: 0;
    z-index: 10;
}

.drawer-header h2 {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
}

.drawer-close {
    background: none;
    border: none;
    font-size: 28px;
    cursor: pointer;
    color: #6b7280;
    padding: 0 8px;
    line-height: 1;
    transition: color 0.2s;
}

.drawer-close:hover {
    color: #1a1a2e;
}

.drawer-body {
    padding: 24px;
    flex: 1;
    overflow-y: auto;
}

.drawer-body .detail-section {
    margin-bottom: 20px;
}

.drawer-body .detail-label {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: #6b7280;
    margin-bottom: 4px;
    display: block;
}

.drawer-body .detail-value {
    font-size: 15px;
    color: #1a1a2e;
}

.drawer-body .detail-divider {
    border: none;
    border-top: 1px solid #f1f3f5;
    margin: 16px 0;
}

.drawer-body .photo-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
}

.drawer-body .photo-grid img {
    width: 100%;
    height: 200px;
    object-fit: cover;
    border-radius: 8px;
    border: 1px solid #e5e7eb;
}

.drawer-body .photo-grid .no-photo {
    width: 100%;
    height: 200px;
    border-radius: 8px;
    background: #f3f4f6;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #9ca3af;
    font-size: 14px;
    border: 1px solid #e5e7eb;
}

.drawer-footer {
    padding: 16px 24px;
    border-top: 1px solid #f1f3f5;
    background: white;
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
    position: sticky;
    bottom: 0;
}

.drawer-footer .btn-approve-lg {
    padding: 10px 24px;
    border: none;
    border-radius: 8px;
    background: #10b981;
    color: white;
    font-size: 14px;
    cursor: pointer;
    flex: 1;
    min-width: 120px;
    font-weight: 500;
    transition: background 0.2s;
}

.drawer-footer .btn-approve-lg:hover {
    background: #059669;
}

.drawer-footer .btn-reject-lg {
    padding: 10px 24px;
    border: none;
    border-radius: 8px;
    background: #ef4444;
    color: white;
    font-size: 14px;
    cursor: pointer;
    flex: 1;
    min-width: 120px;
    font-weight: 500;
    transition: background 0.2s;
}

.drawer-footer .btn-reject-lg:hover {
    background: #dc2626;
}

.drawer-footer .btn-processed-lg {
    padding: 10px 24px;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    background: #f3f4f6;
    color: #6b7280;
    font-size: 14px;
    flex: 1;
    min-width: 120px;
    text-align: center;
    font-weight: 500;
}

@keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
}

/* =========================================================
   IMAGE VIEWER (Lightbox)
========================================================= */
.image-viewer-overlay {
    display: none;
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.92);
    z-index: 2000;
    align-items: center;
    justify-content: center;
    cursor: pointer;
}

.image-viewer-overlay.active {
    display: flex;
}

.image-viewer-overlay .close-btn {
    position: absolute;
    top: 20px;
    right: 30px;
    background: none;
    border: none;
    color: white;
    font-size: 40px;
    cursor: pointer;
    z-index: 2001;
    transition: transform 0.2s;
}

.image-viewer-overlay .close-btn:hover {
    transform: scale(1.2);
}

.image-viewer-overlay .viewer-image {
    max-width: 90%;
    max-height: 90%;
    object-fit: contain;
    border-radius: 8px;
    box-shadow: 0 10px 40px rgba(0,0,0,0.5);
}

.image-viewer-overlay .viewer-info {
    position: absolute;
    bottom: 30px;
    left: 50%;
    transform: translateX(-50%);
    color: rgba(255,255,255,0.6);
    font-size: 14px;
}

/* =========================================================
   RESPONSIVE
========================================================= */
@media (max-width: 1024px) {
    .stats-grid {
        grid-template-columns: repeat(2, 1fr);
    }
}

@media (max-width: 768px) {
    .stats-grid {
        grid-template-columns: repeat(2, 1fr);
    }
    
    .citizen-table {
        font-size: 12px;
    }
    
    .citizen-table th,
    .citizen-table td {
        padding: 10px 12px;
    }
    
    .filter-row {
        flex-direction: column;
        align-items: stretch;
    }
    
    .filter-group {
        justify-content: center;
    }

    .drawer-panel {
        width: 100vw;
        max-width: 100vw;
        right: -100vw;
    }

    .drawer-footer {
        flex-direction: column;
    }

    .drawer-footer .btn-approve-lg,
    .drawer-footer .btn-reject-lg,
    .drawer-footer .btn-processed-lg {
        width: 100%;
    }
    
    .drawer-body .photo-grid {
        grid-template-columns: 1fr;
    }
}

@media (max-width: 480px) {
    .stats-grid {
        grid-template-columns: 1fr 1fr;
    }
    
    .stat-card .stat-number {
        font-size: 20px;
    }
    
    .stat-card {
        padding: 12px 10px;
    }
    
    .pagination {
        flex-direction: column;
        text-align: center;
    }

    .citizen-table th,
    .citizen-table td {
        padding: 8px 10px;
        font-size: 11px;
    }
    
    .filter-input-sm {
        min-width: 80px;
        width: 100%;
    }
}
</style>

<div class="citizen-page">

    <!-- HEADER -->
    <section class="citizen-header">
        <div>
            <div class="subtitle">
                <p>Review citizen registrations, then approve or reject them.</p>
                <span class="badge-citizens">🪪 Citizens</span>
            </div>
        </div>
        <a href="admin_dashboard.php" class="btn-back">
            <i class='bx bx-arrow-back'></i> Dashboard
        </a>
    </section>

    <!-- ALERTS -->
    <?php if ($actionMessage !== null): ?>
        <div class="citizen-alert citizen-success" role="alert">
            <i class='bx bx-check-circle'></i>
            <?= htmlspecialchars($actionMessage, ENT_QUOTES, 'UTF-8') ?>
        </div>
    <?php endif; ?>

    <?php if ($actionError !== null): ?>
        <div class="citizen-alert citizen-error" role="alert">
            <i class='bx bx-error-circle'></i>
            <?= htmlspecialchars($actionError, ENT_QUOTES, 'UTF-8') ?>
        </div>
    <?php endif; ?>

    <?php if ($loadError !== null): ?>
        <div class="citizen-alert citizen-error" role="alert">
            <i class='bx bx-error-circle'></i>
            <?= htmlspecialchars($loadError, ENT_QUOTES, 'UTF-8') ?>
        </div>
    <?php endif; ?>

    <!-- STATS CARDS -->
    <section class="stats-grid">
        <div class="stat-card stat-total">
            <span class="stat-number"><?= $totalItems ?></span>
            <span class="stat-label">Total Citizens</span>
        </div>
        <div class="stat-card stat-pending">
            <span class="stat-number"><?= $pendingCount ?></span>
            <span class="stat-label">Pending Review</span>
        </div>
        <div class="stat-card stat-approved">
            <span class="stat-number"><?= $approvedCount ?></span>
            <span class="stat-label">Approved</span>
        </div>
        <div class="stat-card stat-rejected">
            <span class="stat-number"><?= $rejectedCount ?></span>
            <span class="stat-label">Rejected</span>
        </div>
    </section>

    <!-- FILTER BAR -->
    <div class="filter-bar">
        <!-- Row 1: Status Filters -->
        <div class="filter-row">
            <div class="filter-group">
                <span class="filter-label">Status:</span>
                <a href="?status=all&date_from=<?= $dateFrom ?>&date_to=<?= $dateTo ?>&search=<?= urlencode($searchQuery) ?>&page=1" class="filter-btn <?= $statusFilter === 'all' ? 'active' : '' ?>">All</a>
                <a href="?status=pending&date_from=<?= $dateFrom ?>&date_to=<?= $dateTo ?>&search=<?= urlencode($searchQuery) ?>&page=1" class="filter-btn <?= $statusFilter === 'pending' ? 'active-pending' : '' ?>">Pending</a>
                <a href="?status=approved&date_from=<?= $dateFrom ?>&date_to=<?= $dateTo ?>&search=<?= urlencode($searchQuery) ?>&page=1" class="filter-btn <?= $statusFilter === 'approved' ? 'active-approved' : '' ?>">Approved</a>
                <a href="?status=rejected&date_from=<?= $dateFrom ?>&date_to=<?= $dateTo ?>&search=<?= urlencode($searchQuery) ?>&page=1" class="filter-btn <?= $statusFilter === 'rejected' ? 'active-rejected' : '' ?>">Rejected</a>
            </div>
        </div>

        <!-- Row 2: Advanced Filters -->
        <div class="filter-row">
            <form method="get" style="display:flex;gap:8px;flex-wrap:wrap;align-items:center;width:100%;" id="filterForm">
                <input type="hidden" name="status" value="<?= $statusFilter ?>">

                <div class="filter-group">
                    <span class="filter-label">Date:</span>
                    <input type="date" name="date_from" class="filter-input filter-input-sm" value="<?= htmlspecialchars($dateFrom) ?>" placeholder="From">
                    <span style="font-size:12px;color:#6b7280;">→</span>
                    <input type="date" name="date_to" class="filter-input filter-input-sm" value="<?= htmlspecialchars($dateTo) ?>" placeholder="To">
                </div>

                <div class="filter-group">
                    <span class="filter-label">Search:</span>
                    <input type="text" name="search" class="filter-input filter-input-sm" placeholder="Profile ID, IC..." value="<?= htmlspecialchars($searchQuery) ?>" style="min-width:160px;">
                </div>

                <div class="filter-actions">
                    <button type="submit" class="btn-filter btn-filter-primary">
                        <i class='bx bx-filter'></i> Apply
                    </button>
                    <a href="approve_citizen.php" class="btn-filter btn-filter-reset">
                        <i class='bx bx-reset'></i> Reset
                    </a>
                </div>
            </form>
        </div>

        <!-- Active Filters Display -->
        <?php if ($statusFilter !== 'all' || $dateFrom !== '' || $dateTo !== '' || $searchQuery !== ''): ?>
            <div class="active-filters">
                <span style="font-size:11px;color:#6b7280;font-weight:500;">Active Filters:</span>
                <?php if ($statusFilter !== 'all'): ?>
                    <span class="filter-badge">
                        Status: <?= ucfirst($statusFilter) ?>
                        <span class="remove" onclick="removeFilter('status')">&times;</span>
                    </span>
                <?php endif; ?>
                <?php if ($dateFrom !== ''): ?>
                    <span class="filter-badge filter-badge-date">
                        From: <?= htmlspecialchars($dateFrom) ?>
                        <span class="remove" onclick="removeFilter('date_from')">&times;</span>
                    </span>
                <?php endif; ?>
                <?php if ($dateTo !== ''): ?>
                    <span class="filter-badge filter-badge-date">
                        To: <?= htmlspecialchars($dateTo) ?>
                        <span class="remove" onclick="removeFilter('date_to')">&times;</span>
                    </span>
                <?php endif; ?>
                <?php if ($searchQuery !== ''): ?>
                    <span class="filter-badge filter-badge-search">
                        Search: "<?= htmlspecialchars($searchQuery) ?>"
                        <span class="remove" onclick="removeFilter('search')">&times;</span>
                    </span>
                <?php endif; ?>
                <a href="approve_citizen.php" style="font-size:11px;color:#dc3545;text-decoration:none;font-weight:500;">
                    <i class='bx bx-x'></i> Clear All
                </a>
            </div>
        <?php endif; ?>
    </div>

    <!-- TABLE -->
    <div class="table-container">
        <table class="citizen-table">
            <thead>
                <tr>
                    <th>Type</th>
                    <th>Profile ID</th>
                    <th>IC Number</th>
                    <th>Photo</th>
                    <th>Status</th>
                    <th>Action</th>
                </tr>
            </thead>
            <tbody>
                <?php if (!empty($items)): ?>
                    <?php foreach ($items as $item): ?>
                        <?php
                        $profileId = (string)($item['profile_id'] ?? '');
                        $type = 'citizen';
                        $displayName = 'Citizen';
                        
                        $icNumber = $item['ic_number'] ?? 'N/A';
                        
                        $status = (string)($item['verification_status'] ?? 'pending');
                        $statusLower = strtolower($status);
                        
                        $photoFront = $item['_photo_front'] ?? null;
                        $photoBack = $item['_photo_back'] ?? null;

                        $statusClass = match($statusLower) {
                            'pending' => 'status-pending',
                            'approved' => 'status-approved',
                            'rejected' => 'status-rejected',
                            default => 'status-pending'
                        };

                        $statusDisplay = match($statusLower) {
                            'pending' => 'Pending Review',
                            'approved' => 'Approved',
                            'rejected' => 'Rejected',
                            default => $status
                        };
                        ?>
                        <tr>
                            <td>
                                <span class="type-badge type-citizen">
                                    Citizen
                                </span>
                            </td>
                            <td class="citizen-id"><?= htmlspecialchars(substr($profileId, 0, 8) . '...', ENT_QUOTES, 'UTF-8') ?></td>
                            <td><?= htmlspecialchars($icNumber, ENT_QUOTES, 'UTF-8') ?></td>
                            <td>
                                <?php if ($photoFront): ?>
                                    <img class="photo-thumb" src="<?= htmlspecialchars($photoFront, ENT_QUOTES, 'UTF-8') ?>" 
                                         alt="Photo" onclick="openImagePreview('<?= htmlspecialchars($photoFront, ENT_QUOTES, 'UTF-8') ?>')">
                                <?php else: ?>
                                    <div class="photo-thumb-placeholder">📷</div>
                                <?php endif; ?>
                            </td>
                            <td>
                                <span class="status-badge <?= $statusClass ?>">
                                    <?= htmlspecialchars($statusDisplay, ENT_QUOTES, 'UTF-8') ?>
                                </span>
                            </td>
                            <td>
                                <button class="btn-view" onclick="openDrawer('<?= htmlspecialchars($profileId, ENT_QUOTES, 'UTF-8') ?>')">
                                    <i class='bx bx-show'></i> View
                                </button>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                <?php else: ?>
                    <tr>
                        <td colspan="6" style="text-align: center; padding: 40px;">
                            <div class="empty-state">
                                <i class='bx bx-user'></i>
                                <h3>No Citizens Found</h3>
                                <p>No citizens found matching your criteria. Try adjusting your filters.</p>
                            </div>
                        </td>
                    </tr>
                <?php endif; ?>
            </tbody>
        </table>

        <!-- PAGINATION -->
        <?php if ($totalPages > 1): ?>
            <div class="pagination">
                <div class="pagination-info">
                    Showing <?= $offset + 1 ?>-<?= min($offset + $perPage, $totalItems) ?> of <?= $totalItems ?>
                </div>
                <div class="pagination-links">
                    <?php if ($page > 1): ?>
                        <a href="?page=<?= $page - 1 ?>&status=<?= $statusFilter ?>&date_from=<?= $dateFrom ?>&date_to=<?= $dateTo ?>&search=<?= urlencode($searchQuery) ?>">&larr;</a>
                    <?php else: ?>
                        <span class="disabled">&larr;</span>
                    <?php endif; ?>

                    <?php for ($i = 1; $i <= $totalPages; $i++): ?>
                        <?php if ($i === $page): ?>
                            <span class="active"><?= $i ?></span>
                        <?php elseif ($i === 1 || $i === $totalPages || abs($i - $page) <= 1): ?>
                            <a href="?page=<?= $i ?>&status=<?= $statusFilter ?>&date_from=<?= $dateFrom ?>&date_to=<?= $dateTo ?>&search=<?= urlencode($searchQuery) ?>"><?= $i ?></a>
                        <?php elseif ($i === $page - 2 || $i === $page + 2): ?>
                            <span>...</span>
                        <?php endif; ?>
                    <?php endfor; ?>

                    <?php if ($page < $totalPages): ?>
                        <a href="?page=<?= $page + 1 ?>&status=<?= $statusFilter ?>&date_from=<?= $dateFrom ?>&date_to=<?= $dateTo ?>&search=<?= urlencode($searchQuery) ?>">&rarr;</a>
                    <?php else: ?>
                        <span class="disabled">&rarr;</span>
                    <?php endif; ?>
                </div>
            </div>
        <?php endif; ?>
    </div>

</div>

<!-- IMAGE VIEWER (Lightbox) -->
<div class="image-viewer-overlay" id="imageViewer" onclick="closeImageViewer()">
    <button class="close-btn" onclick="closeImageViewer()">&times;</button>
    <img class="viewer-image" id="viewerImage" src="" alt="Evidence">
    <div class="viewer-info">Click anywhere or press ESC to close</div>
</div>

<!-- DETAILS DRAWER -->
<div class="drawer-overlay" id="drawerOverlay" onclick="closeDrawer()"></div>

<div class="drawer-panel" id="drawerPanel">
    <div class="drawer-header">
        <h2><i class='bx bx-detail'></i> Citizen Details</h2>
        <button class="drawer-close" onclick="closeDrawer()">&times;</button>
    </div>
    <div class="drawer-body" id="drawerBody">
        <div style="text-align: center; padding: 40px; color: #6b7280;">
            <i class='bx bx-loader-alt' style="font-size: 32px; animation: spin 1s linear infinite;"></i>
            <p>Loading...</p>
        </div>
    </div>
    <div class="drawer-footer" id="drawerFooter"></div>
</div>

<script>
// Items data for drawer
const itemsData = <?= json_encode($items) ?>;

function removeFilter(filterName) {
    const url = new URL(window.location.href);
    url.searchParams.delete(filterName);
    url.searchParams.set('page', '1');
    window.location.href = url.toString();
}

function openImagePreview(url) {
    const viewer = document.getElementById('imageViewer');
    const viewerImage = document.getElementById('viewerImage');
    viewerImage.src = url;
    viewer.classList.add('active');
    document.body.style.overflow = 'hidden';
}

function closeImageViewer() {
    const viewer = document.getElementById('imageViewer');
    viewer.classList.remove('active');
    document.body.style.overflow = '';
    document.getElementById('viewerImage').src = '';
}

function openDrawer(profileId) {
    const item = itemsData.find(r => r.profile_id === profileId);
    if (!item) {
        alert('Record not found');
        return;
    }

    const overlay = document.getElementById('drawerOverlay');
    const panel = document.getElementById('drawerPanel');
    const body = document.getElementById('drawerBody');
    const footer = document.getElementById('drawerFooter');

    const statusLower = (item.verification_status || '').toLowerCase();
    const isPending = statusLower === 'pending';
    const isApproved = statusLower === 'approved';
    const isRejected = statusLower === 'rejected';

    const statusClassMap = {
        'pending': 'status-pending',
        'approved': 'status-approved',
        'rejected': 'status-rejected'
    };
    const statusClass = statusClassMap[statusLower] || 'status-pending';

    const statusDisplayMap = {
        'pending': 'Pending Review',
        'approved': 'Approved',
        'rejected': 'Rejected'
    };
    const statusDisplay = statusDisplayMap[statusLower] || item.verification_status || 'Pending Review';

    const photoFront = item._photo_front || null;
    const photoBack = item._photo_back || null;

    let photoHtml = '';
    if (photoFront || photoBack) {
        photoHtml = '<div class="photo-grid">';
        if (photoFront) {
            photoHtml += `<img src="${photoFront}" alt="IC Front" onclick="openImagePreview('${photoFront}')" style="cursor:pointer;">`;
        } else {
            photoHtml += `<div class="no-photo">No Front Photo</div>`;
        }
        if (photoBack) {
            photoHtml += `<img src="${photoBack}" alt="IC Back" onclick="openImagePreview('${photoBack}')" style="cursor:pointer;">`;
        } else {
            photoHtml += `<div class="no-photo">No Back Photo</div>`;
        }
        photoHtml += '</div>';
    } else {
        photoHtml = '<div class="no-photo" style="padding:40px;text-align:center;border:1px solid #e5e7eb;border-radius:8px;">No photos uploaded</div>';
    }

    body.innerHTML = `
        <div class="detail-section">
            <span class="detail-label">Type</span>
            <div class="detail-value">
                <span class="type-badge type-citizen">Citizen</span>
            </div>
        </div>

        <div class="detail-section">
            <span class="detail-label">Profile ID</span>
            <div class="detail-value" style="font-weight: 600; font-family: monospace;">${item.profile_id || 'N/A'}</div>
        </div>

        <div class="detail-section">
            <span class="detail-label">IC Number (MyKad)</span>
            <div class="detail-value" style="font-weight: 600;">${item.ic_number || 'N/A'}</div>
        </div>

        <hr class="detail-divider">

        <div class="detail-section">
            <span class="detail-label">Verification Status</span>
            <div><span class="status-badge ${statusClass}">${statusDisplay}</span></div>
        </div>

        ${item.rejection_reason ? `
            <div class="detail-section">
                <span class="detail-label">Rejection Reason</span>
                <div class="detail-value" style="background: #fee2e2; padding: 12px; border-radius: 8px; color: #991b1b;">${item.rejection_reason}</div>
            </div>
        ` : ''}

        <div class="detail-section">
            <span class="detail-label">Verified At</span>
            <div class="detail-value">${item.verified_at ? new Date(item.verified_at).toLocaleString() : 'Not verified yet'}</div>
        </div>

        <hr class="detail-divider">

        <div class="detail-section">
            <span class="detail-label">📸 IC Photos</span>
            <div style="margin-top: 8px;">${photoHtml}</div>
        </div>
    `;

    if (isPending) {
        footer.innerHTML = `
            <form method="post" style="flex: 1; min-width: 120px;" 
                  onsubmit="return confirm('Approve this citizen?')">
                <input type="hidden" name="profile_id" value="${item.profile_id}">
                <input type="hidden" name="decision" value="approve">
                <button type="submit" class="btn-approve-lg">
                    <i class='bx bx-check'></i> Approve
                </button>
            </form>
            <form method="post" style="flex: 1; min-width: 120px;" 
                  onsubmit="return confirm('Reject this citizen?')">
                <input type="hidden" name="profile_id" value="${item.profile_id}">
                <input type="hidden" name="decision" value="reject">
                <button type="submit" class="btn-reject-lg">
                    <i class='bx bx-x'></i> Reject
                </button>
            </form>
        `;
    } else {
        footer.innerHTML = `
            <div class="btn-processed-lg">
                <i class='bx bx-check-circle'></i> 
                ${isApproved ? '✅ Approved' : '❌ Rejected'}
                (${statusDisplay})
            </div>
        `;
    }

    overlay.classList.add('active');
    panel.classList.add('active');
    document.body.style.overflow = 'hidden';
}

function closeDrawer() {
    document.getElementById('drawerOverlay').classList.remove('active');
    document.getElementById('drawerPanel').classList.remove('active');
    document.body.style.overflow = '';
}

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        closeDrawer();
        closeImageViewer();
    }
});
</script>

<?php
render_admin_end();
?>
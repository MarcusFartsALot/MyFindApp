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
| Handle Approve / Reject
|--------------------------------------------------------------------------
*/
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $profileId = trim((string)($_POST['profile_id'] ?? ''));
    $decision = trim((string)($_POST['decision'] ?? ''));

    if ($profileId === '') {
        $actionError = 'Invalid tourist ID.';
    } elseif (!in_array($decision, ['approve', 'reject'], true)) {
        $actionError = 'Invalid decision.';
    } else {
        try {
            $newStatus = $decision === 'approve' ? 'approved' : 'rejected';

            supabaseRequest(
                'PATCH',
                '/rest/v1/tourists?profile_id=eq.' . rawurlencode($profileId),
                [
                    'verification_status' => $newStatus,
                    'verified_at' => gmdate('c'),
                    'verified_by' => $admin['id'] ?? null
                ]
            );

            $actionMessage = $decision === 'approve'
                ? 'Tourist has been approved successfully.'
                : 'Tourist has been rejected successfully.';

            header('Location: ' . $_SERVER['PHP_SELF'] . '?status=' . $statusFilter . '&page=' . $page);
            exit;
        } catch (Throwable $e) {
            $actionError = 'Unable to update the tourist. Please try again later.';
            error_log('Approve tourist error: ' . $e->getMessage());
        }
    }
}

/*
|--------------------------------------------------------------------------
| Load Tourists with Stats
|--------------------------------------------------------------------------
*/
$tourists = [];
$totalTourists = 0;
$pendingCount = 0;
$approvedCount = 0;
$rejectedCount = 0;

try {
    // FIX: Sort by verified_at instead of created_at
    $allTourists = supabaseRequest('GET', '/rest/v1/tourists?select=*&order=verified_at.desc.nullslast');
    
    if (is_array($allTourists)) {
        $totalTourists = count($allTourists);
        foreach ($allTourists as $tourist) {
            $status = strtolower($tourist['verification_status'] ?? '');
            if ($status === 'pending') $pendingCount++;
            elseif ($status === 'approved') $approvedCount++;
            elseif ($status === 'rejected') $rejectedCount++;
        }
    }

    // FIX: Pagination query - sort by verified_at
    $queryParams = [
        'order' => 'verified_at.desc.nullslast',
        'limit' => $perPage,
        'offset' => $offset
    ];
    if ($statusFilter !== 'all') {
        $queryParams['verification_status'] = 'eq.' . $statusFilter;
    }
    $tourists = supabaseRequest('GET', '/rest/v1/tourists?select=*', null, $queryParams);
    
    if (!is_array($tourists)) $tourists = [];
    
} catch (Throwable $e) {
    $loadError = 'Unable to load tourists. Error: ' . $e->getMessage();
    error_log('Load tourists error: ' . $e->getMessage());
}

$totalPages = ceil($totalTourists / $perPage);

render_admin_start('Approve Tourist Registrations', $admin, 'dashboard');

?>

<style>
/* =========================================================
   PAGE LAYOUT
========================================================= */
.tourist-page {
    display: flex;
    flex-direction: column;
    gap: 24px;
}

.tourist-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 20px;
    flex-wrap: wrap;
}

.tourist-header h1 {
    margin: 0;
    font-size: 24px;
    font-weight: 700;
    color: #1a1a2e;
}

.tourist-header h1 i {
    color: #3b82f6;
}

.tourist-header .subtitle {
    display: flex;
    align-items: center;
    gap: 12px;
    margin: 4px 0 0;
    flex-wrap: wrap;
}

.tourist-header .subtitle p {
    margin: 0;
    opacity: .7;
    font-size: 14px;
}

.tourist-header .badge-tourists {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 2px 12px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 600;
    background: #dbeafe;
    color: #1e40af;
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
   FILTER & EXPORT
========================================================= */
.filter-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
    padding: 14px 18px;
    background: white;
    border-radius: 14px;
    border: 1px solid #f1f3f5;
    box-shadow: 0 1px 3px rgba(0,0,0,0.04);
}

.filter-group {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
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

.export-btn {
    padding: 6px 16px;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    background: white;
    cursor: pointer;
    font-size: 12px;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    text-decoration: none;
    color: #4b5563;
    transition: all 0.2s;
    font-weight: 500;
}

.export-btn:hover {
    background: #f3f4f6;
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

.tourist-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 14px;
}

.tourist-table thead {
    background: #f8fafc;
    border-bottom: 2px solid #e5e7eb;
}

.tourist-table th {
    padding: 14px 16px;
    text-align: left;
    font-weight: 600;
    color: #4b5563;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
}

.tourist-table td {
    padding: 14px 16px;
    border-bottom: 1px solid #f1f3f5;
    vertical-align: middle;
}

.tourist-table tbody tr:hover {
    background: #f8fafc;
}

.tourist-table tbody tr:last-child td {
    border-bottom: none;
}

.tourist-id {
    font-weight: 600;
    color: #1a1a2e;
    font-family: monospace;
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
.tourist-alert {
    padding: 14px 18px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    gap: 10px;
}

.tourist-alert i {
    font-size: 20px;
}

.tourist-success {
    background: #d1fae5;
    color: #065f46;
}

.tourist-error {
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

.drawer-body .description-text {
    background: #f8fafc;
    padding: 16px;
    border-radius: 8px;
    line-height: 1.6;
    margin: 0;
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
   RESPONSIVE
========================================================= */
@media (max-width: 768px) {
    .stats-grid {
        grid-template-columns: repeat(2, 1fr);
    }
    
    .tourist-table {
        font-size: 12px;
    }
    
    .tourist-table th,
    .tourist-table td {
        padding: 10px 12px;
    }
    
    .filter-bar {
        flex-direction: column;
        align-items: stretch;
        gap: 10px;
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

    .tourist-table th,
    .tourist-table td {
        padding: 8px 10px;
        font-size: 11px;
    }
}
</style>

<div class="tourist-page">

    <!-- HEADER -->
    <section class="tourist-header">
        <div>
            <h1><i class='bx bx-user-check'></i> Approve Tourist Registrations</h1>
            <div class="subtitle">
                <p>Review tourist registrations and approve or reject them.</p>
                <span class="badge-tourists">🛂 Tourist Registrations</span>
            </div>
        </div>
        <a href="admin_dashboard.php" class="btn-back">
            <i class='bx bx-arrow-back'></i> Dashboard
        </a>
    </section>

    <!-- ALERTS -->
    <?php if ($actionMessage !== null): ?>
        <div class="tourist-alert tourist-success" role="alert">
            <i class='bx bx-check-circle'></i>
            <?= htmlspecialchars($actionMessage, ENT_QUOTES, 'UTF-8') ?>
        </div>
    <?php endif; ?>

    <?php if ($actionError !== null): ?>
        <div class="tourist-alert tourist-error" role="alert">
            <i class='bx bx-error-circle'></i>
            <?= htmlspecialchars($actionError, ENT_QUOTES, 'UTF-8') ?>
        </div>
    <?php endif; ?>

    <?php if ($loadError !== null): ?>
        <div class="tourist-alert tourist-error" role="alert">
            <i class='bx bx-error-circle'></i>
            <?= htmlspecialchars($loadError, ENT_QUOTES, 'UTF-8') ?>
        </div>
    <?php endif; ?>

    <!-- STATS CARDS -->
    <section class="stats-grid">
        <div class="stat-card stat-total">
            <span class="stat-icon">📊</span>
            <span class="stat-number"><?= $totalTourists ?></span>
            <span class="stat-label">Total Registrations</span>
        </div>
        <div class="stat-card stat-pending">
            <span class="stat-icon">⏳</span>
            <span class="stat-number"><?= $pendingCount ?></span>
            <span class="stat-label">Pending Review</span>
        </div>
        <div class="stat-card stat-approved">
            <span class="stat-icon">✅</span>
            <span class="stat-number"><?= $approvedCount ?></span>
            <span class="stat-label">Approved</span>
        </div>
        <div class="stat-card stat-rejected">
            <span class="stat-icon">❌</span>
            <span class="stat-number"><?= $rejectedCount ?></span>
            <span class="stat-label">Rejected</span>
        </div>
    </section>

    <!-- FILTER & EXPORT -->
    <div class="filter-bar">
        <div class="filter-group">
            <a href="?status=all&page=1" class="filter-btn <?= $statusFilter === 'all' ? 'active' : '' ?>">All</a>
            <a href="?status=pending&page=1" class="filter-btn <?= $statusFilter === 'pending' ? 'active-pending' : '' ?>">⏳ Pending</a>
            <a href="?status=approved&page=1" class="filter-btn <?= $statusFilter === 'approved' ? 'active-approved' : '' ?>">✅ Approved</a>
            <a href="?status=rejected&page=1" class="filter-btn <?= $statusFilter === 'rejected' ? 'active-rejected' : '' ?>">❌ Rejected</a>
        </div>
        <a href="#" class="export-btn" onclick="exportTable(); return false;">
            <i class='bx bx-export'></i> Export Report
        </a>
    </div>

    <!-- TABLE -->
    <div class="table-container">
        <table class="tourist-table">
            <thead>
                <tr>
                    <th>Profile ID</th>
                    <th>Passport Number</th>
                    <th>Passport Country</th>
                    <th>Status</th>
                    <th>Action</th>
                </tr>
            </thead>
            <tbody>
                <?php if (!empty($tourists)): ?>
                    <?php foreach ($tourists as $tourist): ?>
                        <?php
                        $profileId = (string)($tourist['profile_id'] ?? '');
                        $passportNumber = (string)($tourist['passport_number'] ?? 'N/A');
                        $passportCountry = (string)($tourist['passport_issuing_country'] ?? 'N/A');
                        $status = (string)($tourist['verification_status'] ?? 'pending');
                        
                        $statusLower = strtolower($status);

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
                            <td class="tourist-id"><?= htmlspecialchars(substr($profileId, 0, 8) . '...', ENT_QUOTES, 'UTF-8') ?></td>
                            <td><?= htmlspecialchars($passportNumber, ENT_QUOTES, 'UTF-8') ?></td>
                            <td><?= htmlspecialchars($passportCountry, ENT_QUOTES, 'UTF-8') ?></td>
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
                        <td colspan="5" style="text-align: center; padding: 40px;">
                            <div class="empty-state">
                                <i class='bx bx-check-circle'></i>
                                <h3>No Tourist Registrations Found</h3>
                                <p>No registrations found matching your criteria.</p>
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
                    Showing <?= $offset + 1 ?>-<?= min($offset + $perPage, $totalTourists) ?> of <?= $totalTourists ?>
                </div>
                <div class="pagination-links">
                    <?php if ($page > 1): ?>
                        <a href="?page=<?= $page - 1 ?>&status=<?= $statusFilter ?>">&larr;</a>
                    <?php else: ?>
                        <span class="disabled">&larr;</span>
                    <?php endif; ?>

                    <?php for ($i = 1; $i <= $totalPages; $i++): ?>
                        <?php if ($i === $page): ?>
                            <span class="active"><?= $i ?></span>
                        <?php elseif ($i === 1 || $i === $totalPages || abs($i - $page) <= 1): ?>
                            <a href="?page=<?= $i ?>&status=<?= $statusFilter ?>"><?= $i ?></a>
                        <?php elseif ($i === $page - 2 || $i === $page + 2): ?>
                            <span>...</span>
                        <?php endif; ?>
                    <?php endfor; ?>

                    <?php if ($page < $totalPages): ?>
                        <a href="?page=<?= $page + 1 ?>&status=<?= $statusFilter ?>">&rarr;</a>
                    <?php else: ?>
                        <span class="disabled">&rarr;</span>
                    <?php endif; ?>
                </div>
            </div>
        <?php endif; ?>
    </div>

</div>

<!-- =========================================================
     DETAILS DRAWER / SLIDE-OUT PANEL
========================================================= -->

<!-- Overlay -->
<div class="drawer-overlay" id="drawerOverlay" onclick="closeDrawer()"></div>

<!-- Drawer Panel -->
<div class="drawer-panel" id="drawerPanel">
    <div class="drawer-header">
        <h2><i class='bx bx-detail'></i> Tourist Details</h2>
        <button class="drawer-close" onclick="closeDrawer()">&times;</button>
    </div>
    <div class="drawer-body" id="drawerBody">
        <div style="text-align: center; padding: 40px; color: #6b7280;">
            <i class='bx bx-loader-alt' style="font-size: 32px; animation: spin 1s linear infinite;"></i>
            <p>Loading...</p>
        </div>
    </div>
    <div class="drawer-footer" id="drawerFooter">
        <!-- Dynamic footer -->
    </div>
</div>

<script>
// Tourists data for drawer
const touristsData = <?= json_encode($tourists) ?>;

function openDrawer(profileId) {
    const tourist = touristsData.find(r => r.profile_id === profileId);
    if (!tourist) {
        alert('Tourist not found');
        return;
    }

    const overlay = document.getElementById('drawerOverlay');
    const panel = document.getElementById('drawerPanel');
    const body = document.getElementById('drawerBody');
    const footer = document.getElementById('drawerFooter');

    // Determine status
    const statusLower = (tourist.verification_status || '').toLowerCase();
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
    const statusDisplay = statusDisplayMap[statusLower] || tourist.verification_status || 'Pending Review';

    // Build detail content
    body.innerHTML = `
        <div class="detail-section">
            <span class="detail-label">Profile ID</span>
            <div class="detail-value" style="font-weight: 600; font-family: monospace;">${tourist.profile_id || 'N/A'}</div>
        </div>

        <div class="detail-section">
            <span class="detail-label">Passport Number</span>
            <div class="detail-value" style="font-weight: 600;">${tourist.passport_number || 'N/A'}</div>
        </div>

        <div class="detail-section">
            <span class="detail-label">Passport Issuing Country</span>
            <div class="detail-value">${tourist.passport_issuing_country || 'N/A'}</div>
        </div>

        <div class="detail-section">
            <span class="detail-label">Passport Issue Date</span>
            <div class="detail-value">${tourist.passport_issue_date || 'N/A'}</div>
        </div>

        <div class="detail-section">
            <span class="detail-label">Passport Expiry Date</span>
            <div class="detail-value" style="color: ${tourist.passport_expiry_date ? new Date(tourist.passport_expiry_date) < new Date() ? '#dc3545' : '#10b981' : '#6b7280'};">${tourist.passport_expiry_date || 'N/A'}</div>
        </div>

        <div class="detail-section">
            <span class="detail-label">Country of Residence</span>
            <div class="detail-value">${tourist.country_of_residence || 'N/A'}</div>
        </div>

        <hr class="detail-divider">

        <div class="detail-section">
            <span class="detail-label">Verification Status</span>
            <div><span class="status-badge ${statusClass}">${statusDisplay}</span></div>
        </div>

        ${tourist.rejection_reason ? `
            <div class="detail-section">
                <span class="detail-label">Rejection Reason</span>
                <div class="detail-value" style="background: #fee2e2; padding: 12px; border-radius: 8px; color: #991b1b;">${tourist.rejection_reason}</div>
            </div>
        ` : ''}

        <div class="detail-section">
            <span class="detail-label">Verified At</span>
            <div class="detail-value">${tourist.verified_at ? new Date(tourist.verified_at).toLocaleString() : 'Not verified yet'}</div>
        </div>
    `;

    // Build footer actions
    if (isPending) {
        footer.innerHTML = `
            <form method="post" style="flex: 1; min-width: 120px;" 
                  onsubmit="return confirm('Approve this tourist?')">
                <input type="hidden" name="profile_id" value="${tourist.profile_id}">
                <input type="hidden" name="decision" value="approve">
                <button type="submit" class="btn-approve-lg">
                    <i class='bx bx-check'></i> Approve
                </button>
            </form>
            <form method="post" style="flex: 1; min-width: 120px;" 
                  onsubmit="return confirm('Reject this tourist?')">
                <input type="hidden" name="profile_id" value="${tourist.profile_id}">
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

    // Show drawer
    overlay.classList.add('active');
    panel.classList.add('active');
    document.body.style.overflow = 'hidden';
}

function closeDrawer() {
    document.getElementById('drawerOverlay').classList.remove('active');
    document.getElementById('drawerPanel').classList.remove('active');
    document.body.style.overflow = '';
}

// Close on ESC key
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        closeDrawer();
    }
});

function exportTable() {
    alert('Export functionality will be implemented here.');
}
</script>

<?php

render_admin_end();

?>
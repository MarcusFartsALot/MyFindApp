<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/admin_guard.php';
require_once __DIR__ . '/includes/layout.php';
require_once __DIR__ . '/services/application_service.php';

$admin = require_admin();

$loadError = null;
$actionMessage = null;
$actionError = null;

// Create SupabaseClient instance directly
$client = new SupabaseClient();

// Pagination parameters
$page = max(1, (int)($_GET['page'] ?? 1));
$perPage = 10;
$offset = ($page - 1) * $perPage;

// Status filter
$statusFilter = $_GET['status'] ?? 'all';

/*
|--------------------------------------------------------------------------
| Handle Approve / Reject
|--------------------------------------------------------------------------
*/

if ($_SERVER['REQUEST_METHOD'] === 'POST') {

    $reportId = trim((string)($_POST['report_id'] ?? ''));
    $decision = trim((string)($_POST['decision'] ?? ''));

    if ($reportId === '') {
        $actionError = 'Invalid citizen report ID.';
    } elseif (!in_array($decision, ['approve', 'reject'], true)) {
        $actionError = 'Invalid report decision.';
    } else {
        try {
            $newStatus = $decision === 'approve' ? 'Validated' : 'Rejected';

            // Load the owner and ticket before updating so the matching
            // citizen can receive a status notification.
            $matchingReports = $client->asService(
                'GET',
                '/rest/v1/incident_reports?select=creator_profile_id,ticket_id,status&id=eq.'
                    . rawurlencode($reportId)
                    . '&limit=1'
            );

            $report = is_array($matchingReports) && isset($matchingReports[0])
                ? $matchingReports[0]
                : null;

            if (!is_array($report)) {
                throw new RuntimeException('Citizen report was not found.');
            }

            $ownerProfileId = trim((string)($report['creator_profile_id'] ?? ''));
            $ticketId = trim((string)($report['ticket_id'] ?? ''));

            if ($ownerProfileId === '' || $ticketId === '') {
                throw new RuntimeException('Citizen report owner information is incomplete.');
            }

            $updated = $client->asService(
                'PATCH',
                '/rest/v1/incident_reports?id=eq.' . rawurlencode($reportId),
                [
                    'status' => $newStatus,
                    'updated_at' => gmdate('c')
                ]
            );

            // Notification logging is intentionally separate from the status
            // update. A temporary notification failure must not undo a valid
            // admin decision.
            try {
                $notificationTitle = $newStatus === 'Validated'
                    ? 'Incident Report Validated'
                    : 'Incident Report Rejected';
                $notificationMessage = $newStatus === 'Validated'
                    ? 'Ticket ' . $ticketId . ' was validated by an administrator.'
                    : 'Ticket ' . $ticketId . ' was rejected as a false alarm.';

                $client->asService(
                    'POST',
                    '/rest/v1/notifications',
                    [
                        'user_id' => $ownerProfileId,
                        'title' => $notificationTitle,
                        'message' => $notificationMessage,
                        'type' => 'Alert',
                        'is_read' => false,
                        'created_at' => gmdate('c')
                    ]
                );
            } catch (Throwable $notificationError) {
                error_log(
                    'Citizen report status notification error: '
                    . $notificationError->getMessage()
                );
            }

            if ($decision === 'approve') {
                $actionMessage = 'Citizen report has been validated successfully.';
            } else {
                $actionMessage = 'Citizen report has been rejected successfully.';
            }

            header('Location: ' . $_SERVER['PHP_SELF'] . '?status=' . $statusFilter . '&page=' . $page);
            exit;

        } catch (Throwable $e) {
            $actionError = 'Unable to update the citizen report. Please try again later.';
            error_log('Approve citizen report error: ' . $e->getMessage());
        }
    }
}

/*
|--------------------------------------------------------------------------
| Helper: Get full Storage URL
|--------------------------------------------------------------------------
*/
function getFullStorageUrl($path) {
    $supabaseUrl = 'https://kfvhnpkkwxipschhlouk.supabase.co';
    if (empty($path)) return null;
    if (filter_var($path, FILTER_VALIDATE_URL)) return $path;
    
    // 如果路径已经包含 bucket 名称
    if (strpos($path, 'incident-evidence/') === 0) {
        return rtrim($supabaseUrl, '/') . '/storage/v1/object/public/' . $path;
    }
    
    return rtrim($supabaseUrl, '/') . '/storage/v1/object/public/incident-evidence/' . ltrim($path, '/');
}

/*
|--------------------------------------------------------------------------
| Load Citizen Reports with Stats
|--------------------------------------------------------------------------
*/

$reports = [];
$totalReports = 0;
$pendingCount = 0;
$rejectedCount = 0;
$resolvedCount = 0;

$supabaseUrl = 'https://kfvhnpkkwxipschhlouk.supabase.co';

try {
    $allReports = $client->asService(
        'GET',
        '/rest/v1/incident_reports?select=*&order=created_at.desc'
    );
    
    if (is_array($allReports)) {
        $totalReports = count($allReports);
        
        foreach ($allReports as $report) {
            $status = $report['status'] ?? '';
            $statusLower = strtolower($status);
            if ($statusLower === 'pending review' || $statusLower === 'pending') {
                $pendingCount++;
            } elseif ($statusLower === 'rejected') {
                $rejectedCount++;
            } elseif ($statusLower === 'validated' || $statusLower === 'resolved') {
                $resolvedCount++;
            }
        }
    }

    $query = '/rest/v1/incident_reports?select=*&order=created_at.desc';
    
    if ($statusFilter !== 'all') {
        $statusMap = [
            'pending' => 'Pending Review',
            'rejected' => 'Rejected',
            'resolved' => 'Validated'
        ];
        if (isset($statusMap[$statusFilter])) {
            $query .= '&status=eq.' . rawurlencode($statusMap[$statusFilter]);
        }
    }
    
    $query .= '&limit=' . $perPage . '&offset=' . $offset;
    
    $reports = $client->asService('GET', $query);
    
    if (!is_array($reports)) {
        $reports = [];
    }

    // 按 urgency_level 排序
    usort($reports, function($a, $b) {
        $urgencyOrder = [
            'Emergency' => 0,
            'High' => 1,
            'Normal' => 2
        ];
        
        $urgencyA = $a['urgency_level'] ?? 'Normal';
        $urgencyB = $b['urgency_level'] ?? 'Normal';
        
        $orderA = $urgencyOrder[$urgencyA] ?? 2;
        $orderB = $urgencyOrder[$urgencyB] ?? 2;
        
        return $orderA - $orderB;
    });
    
    // Process media_paths to generate accessible URLs
    foreach ($reports as &$report) {
        if (isset($report['media_paths']) && is_array($report['media_paths'])) {
            $report['media_urls'] = array_map(function($path) use ($supabaseUrl) {
                // 获取文件扩展名
                $extension = strtolower(pathinfo($path, PATHINFO_EXTENSION));
                $isVideo = in_array($extension, ['mp4', 'mov', 'avi', 'mkv', 'webm', 'wmv', 'flv', '3gp']);
                $isImage = in_array($extension, ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg']);
                
                // 使用 getFullStorageUrl 生成完整 URL
                $url = getFullStorageUrl($path);
                
                return [
                    'url' => $url,
                    'type' => $isVideo ? 'video' : ($isImage ? 'image' : 'unknown'),
                    'extension' => $extension,
                    'filename' => basename($path)
                ];
            }, $report['media_paths']);
        }
    }
    unset($report);
    
} catch (Throwable $e) {
    $loadError = 'Unable to load citizen reports. Please refresh the page or try again later.';
    error_log('Load citizen reports error: ' . $e->getMessage());
}

$totalPages = ceil($totalReports / $perPage);

render_admin_start('Approve Citizen Reports', $admin, 'dashboard');

?>

<style>
/* =========================================================
   PAGE LAYOUT
========================================================= */
.report-page {
    display: flex;
    flex-direction: column;
    gap: 24px;
}

/* =========================================================
   HEADER
========================================================= */
.report-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 20px;
    flex-wrap: wrap;
}

.report-header h1 {
    margin: 0;
    font-size: 24px;
    font-weight: 700;
    color: #1a1a2e;
}

.report-header h1 i {
    color: #3b82f6;
}

.report-header .subtitle {
    display: flex;
    align-items: center;
    gap: 12px;
    margin: 4px 0 0;
    flex-wrap: wrap;
}

.report-header .subtitle p {
    margin: 0;
    opacity: .7;
    font-size: 14px;
}

.report-header .badge-reports {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 2px 12px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 600;
    background: #fef3c7;
    color: #92400e;
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
.stat-rejected .stat-number { color: #ef4444; }
.stat-resolved .stat-number { color: #10b981; }

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

.filter-btn.active-rejected {
    background: #ef4444;
    color: white;
    border-color: #ef4444;
}

.filter-btn.active-resolved {
    background: #10b981;
    color: white;
    border-color: #10b981;
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

.report-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 14px;
}

.report-table thead {
    background: #f8fafc;
    border-bottom: 2px solid #e5e7eb;
}

.report-table th {
    padding: 14px 16px;
    text-align: left;
    font-weight: 600;
    color: #4b5563;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
}

.report-table td {
    padding: 14px 16px;
    border-bottom: 1px solid #f1f3f5;
    vertical-align: middle;
}

.report-table tbody tr:hover {
    background: #f8fafc;
}

.report-table tbody tr:last-child td {
    border-bottom: none;
}

.ticket-id {
    font-weight: 600;
    color: #1a1a2e;
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

.status-rejected {
    background: #fee2e2;
    color: #991b1b;
}

.status-validated {
    background: #d1fae5;
    color: #065f46;
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
.report-alert {
    padding: 14px 18px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    gap: 10px;
}

.report-alert i {
    font-size: 20px;
}

.report-success {
    background: #d1fae5;
    color: #065f46;
}

.report-error {
    background: #fee2e2;
    color: #991b1b;
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

.drawer-body .map-container {
    border-radius: 8px;
    overflow: hidden;
    margin-top: 4px;
    border: 1px solid #e5e7eb;
}

.drawer-body .map-container iframe {
    width: 100%;
    height: 280px;
    border: none;
    display: block;
}

.drawer-body .map-link {
    color: #3b82f6;
    text-decoration: none;
    font-size: 13px;
    display: inline-block;
    margin-top: 8px;
}

.drawer-body .map-link:hover {
    text-decoration: underline;
}

/* =========================================================
   EVIDENCE GRID - Image & Video
========================================================= */
.evidence-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 12px;
    margin-top: 8px;
}

.evidence-item {
    position: relative;
    border-radius: 10px;
    overflow: hidden;
    border: 1px solid #e5e7eb;
    cursor: pointer;
    background: #f8fafc;
    aspect-ratio: 16/12;
    transition: transform 0.2s, box-shadow 0.2s;
}

.evidence-item:hover {
    transform: scale(1.02);
    box-shadow: 0 4px 16px rgba(0,0,0,0.15);
    z-index: 5;
}

.evidence-item img,
.evidence-item video {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
}

.evidence-item .play-overlay {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 48px;
    height: 48px;
    background: rgba(0,0,0,0.6);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    color: white;
    font-size: 28px;
    pointer-events: none;
    transition: transform 0.2s;
}

.evidence-item:hover .play-overlay {
    transform: translate(-50%, -50%) scale(1.1);
}

.evidence-item .file-badge {
    position: absolute;
    bottom: 6px;
    right: 6px;
    background: rgba(0,0,0,0.7);
    color: white;
    font-size: 10px;
    padding: 2px 10px;
    border-radius: 12px;
    font-weight: 500;
}

.evidence-item .file-badge.video {
    background: rgba(220, 38, 38, 0.8);
}

.evidence-item .file-badge.image {
    background: rgba(16, 185, 129, 0.8);
}

.evidence-item .file-badge.unknown {
    background: rgba(107, 114, 128, 0.8);
}

.evidence-placeholder {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    font-size: 12px;
    color: #6b7280;
    text-align: center;
    padding: 10px;
    height: 100%;
}

.evidence-placeholder i {
    font-size: 32px;
    display: block;
    margin-bottom: 4px;
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
   VIDEO VIEWER (Modal)
========================================================= */
.video-viewer-overlay {
    display: none;
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.92);
    z-index: 2000;
    align-items: center;
    justify-content: center;
    cursor: pointer;
}

.video-viewer-overlay.active {
    display: flex;
}

.video-viewer-overlay .close-btn {
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

.video-viewer-overlay .close-btn:hover {
    transform: scale(1.2);
}

.video-viewer-overlay .viewer-video {
    max-width: 90%;
    max-height: 90%;
    border-radius: 8px;
    box-shadow: 0 10px 40px rgba(0,0,0,0.5);
    background: #000;
}

.video-viewer-overlay .viewer-info {
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
@media (max-width: 768px) {
    .stats-grid {
        grid-template-columns: repeat(2, 1fr);
    }
    
    .report-table {
        font-size: 12px;
    }
    
    .report-table th,
    .report-table td {
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

    .drawer-body .map-container iframe {
        height: 200px;
    }

    .evidence-grid {
        grid-template-columns: repeat(auto-fill, minmax(130px, 1fr));
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

    .drawer-body .map-container iframe {
        height: 180px;
    }

    .evidence-grid {
        grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
    }

    .report-table th,
    .report-table td {
        padding: 8px 10px;
        font-size: 11px;
    }
}
</style>

<div class="report-page">

    <!-- HEADER -->
    <section class="report-header">
        <div>
            <div class="subtitle">
                <p>Review submitted citizen reports and validate or reject them.</p>
                <span class="badge-reports">📋 Citizen Reports</span>
            </div>
        </div>
        <a href="admin_dashboard.php" class="btn-filter btn-filter-outline" style="padding:8px 20px;border:1px solid #e5e7eb;border-radius:8px;text-decoration:none;color:#4b5563;font-size:13px;display:inline-flex;align-items:center;gap:6px;transition:all 0.2s;font-weight:500;" onmouseover="this.style.background='#f3f4f6'" onmouseout="this.style.background='transparent'">
            <i class='bx bx-arrow-back'></i> Dashboard
        </a>
    </section>

    <!-- ALERTS -->
    <?php if ($actionMessage !== null): ?>
        <div class="report-alert report-success" role="alert">
            <i class='bx bx-check-circle'></i>
            <?= htmlspecialchars($actionMessage, ENT_QUOTES, 'UTF-8') ?>
        </div>
    <?php endif; ?>

    <?php if ($actionError !== null): ?>
        <div class="report-alert report-error" role="alert">
            <i class='bx bx-error-circle'></i>
            <?= htmlspecialchars($actionError, ENT_QUOTES, 'UTF-8') ?>
        </div>
    <?php endif; ?>

    <?php if ($loadError !== null): ?>
        <div class="report-alert report-error" role="alert">
            <i class='bx bx-error-circle'></i>
            <?= htmlspecialchars($loadError, ENT_QUOTES, 'UTF-8') ?>
        </div>
    <?php endif; ?>

    <!-- STATS CARDS -->
    <section class="stats-grid">
        <div class="stat-card stat-total">
            <span class="stat-icon">📊</span>
            <span class="stat-number"><?= $totalReports ?></span>
            <span class="stat-label">Total Reports</span>
        </div>
        <div class="stat-card stat-pending">
            <span class="stat-icon">⏳</span>
            <span class="stat-number"><?= $pendingCount ?></span>
            <span class="stat-label">Pending Review</span>
        </div>
        <div class="stat-card stat-rejected">
            <span class="stat-icon">❌</span>
            <span class="stat-number"><?= $rejectedCount ?></span>
            <span class="stat-label">Rejected</span>
        </div>
        <div class="stat-card stat-resolved">
            <span class="stat-icon">✅</span>
            <span class="stat-number"><?= $resolvedCount ?></span>
            <span class="stat-label">Resolved</span>
        </div>
    </section>

    <!-- FILTER & EXPORT -->
    <div class="filter-bar">
        <div class="filter-group">
            <a href="?status=all&page=1" class="filter-btn <?= $statusFilter === 'all' ? 'active' : '' ?>">All</a>
            <a href="?status=pending&page=1" class="filter-btn <?= $statusFilter === 'pending' ? 'active-pending' : '' ?>">⏳ Pending</a>
            <a href="?status=rejected&page=1" class="filter-btn <?= $statusFilter === 'rejected' ? 'active-rejected' : '' ?>">❌ Rejected</a>
            <a href="?status=resolved&page=1" class="filter-btn <?= $statusFilter === 'resolved' ? 'active-resolved' : '' ?>">✅ Resolved</a>
        </div>
    </div>

    <!-- TABLE -->
    <div class="table-container">
        <table class="report-table">
            <thead>
                <tr>
                    <th>Ticket ID</th>
                    <th>Category</th>
                    <th>District</th>
                    <th>Submitted</th>
                    <th>Status</th>
                    <th>Action</th>
                </tr>
            </thead>
            <tbody>
                <?php if (!empty($reports)): ?>
                    <?php foreach ($reports as $report): ?>
                        <?php
                        $reportId = (string)($report['id'] ?? '');
                        $ticketId = (string)($report['ticket_id'] ?? 'N/A');
                        $category = (string)($report['category'] ?? 'N/A');
                        $location = (string)($report['location'] ?? 'N/A');
                        $status = (string)($report['status'] ?? 'Pending Review');
                        $createdAt = (string)($report['created_at'] ?? '');
                        
                        $statusLower = strtolower($status);

                        $statusClass = match($statusLower) {
                            'pending review', 'pending' => 'status-pending',
                            'rejected' => 'status-rejected',
                            'validated' => 'status-validated',
                            default => 'status-pending'
                        };

                        $statusDisplay = match($statusLower) {
                            'validated' => 'Validated',
                            'rejected' => 'Rejected',
                            default => $status
                        };

                        $formattedDate = 'N/A';
                        if ($createdAt !== '') {
                            try {
                                $formattedDate = date('d M Y H:i', strtotime($createdAt));
                            } catch (Throwable $e) {
                                $formattedDate = $createdAt;
                            }
                        }
                        ?>
                        <tr>
                            <td class="ticket-id"><?= htmlspecialchars($ticketId, ENT_QUOTES, 'UTF-8') ?></td>
                            <td><?= htmlspecialchars($category, ENT_QUOTES, 'UTF-8') ?></td>
                            <td><?= htmlspecialchars($location, ENT_QUOTES, 'UTF-8') ?></td>
                            <td><?= htmlspecialchars($formattedDate, ENT_QUOTES, 'UTF-8') ?></td>
                            <td>
                                <span class="status-badge <?= $statusClass ?>">
                                    <?= htmlspecialchars($statusDisplay, ENT_QUOTES, 'UTF-8') ?>
                                </span>
                            </td>
                            <td>
                                <button class="btn-view" onclick="openDrawer('<?= htmlspecialchars($reportId, ENT_QUOTES, 'UTF-8') ?>')">
                                    <i class='bx bx-show'></i> View
                                </button>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                <?php else: ?>
                    <tr>
                        <td colspan="6" style="text-align: center; padding: 40px;">
                            <div class="empty-state">
                                <i class='bx bx-check-circle'></i>
                                <h3>No Citizen Reports Found</h3>
                                <p>No reports found matching your criteria.</p>
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
                    Showing <?= $offset + 1 ?>-<?= min($offset + $perPage, $totalReports) ?> of <?= $totalReports ?>
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
     RIGHT DRAWER / SLIDE-OUT PANEL
========================================================= -->

<!-- Overlay -->
<div class="drawer-overlay" id="drawerOverlay" onclick="closeDrawer()"></div>

<!-- Drawer Panel -->
<div class="drawer-panel" id="drawerPanel">
    <div class="drawer-header">
        <h2><i class='bx bx-detail'></i> Report Details</h2>
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

<!-- =========================================================
     IMAGE VIEWER (Lightbox)
========================================================= -->
<div class="image-viewer-overlay" id="imageViewer" onclick="closeImageViewer()">
    <button class="close-btn" onclick="closeImageViewer()">&times;</button>
    <img class="viewer-image" id="viewerImage" src="" alt="Evidence">
    <div class="viewer-info">Click anywhere or press ESC to close</div>
</div>

<!-- =========================================================
     VIDEO VIEWER (Modal)
========================================================= -->
<div class="video-viewer-overlay" id="videoViewer" onclick="closeVideoViewer()">
    <button class="close-btn" onclick="closeVideoViewer()">&times;</button>
    <video class="viewer-video" id="viewerVideo" controls autoplay>
        <source id="videoSource" src="" type="video/mp4">
        Your browser does not support the video tag.
    </video>
    <div class="viewer-info">Click anywhere or press ESC to close</div>
</div>

<script>
// Report data for drawer
const reportsData = <?= json_encode($reports) ?>;
const supabaseUrl = '<?= $supabaseUrl ?>';

function openDrawer(reportId) {
    const report = reportsData.find(r => r.id === reportId);
    if (!report) {
        alert('Report not found');
        return;
    }

    const overlay = document.getElementById('drawerOverlay');
    const panel = document.getElementById('drawerPanel');
    const body = document.getElementById('drawerBody');
    const footer = document.getElementById('drawerFooter');

    // Determine status
    const statusLower = (report.status || '').toLowerCase();
    const isPending = statusLower === 'pending review' || statusLower === 'pending';

    const statusClassMap = {
        'pending review': 'status-pending',
        'pending': 'status-pending',
        'rejected': 'status-rejected',
        'validated': 'status-validated'
    };
    const statusClass = statusClassMap[statusLower] || 'status-pending';

    const statusDisplayMap = {
        'pending review': 'Pending Review',
        'pending': 'Pending Review',
        'rejected': 'Rejected',
        'validated': 'Validated'
    };
    const statusDisplay = statusDisplayMap[statusLower] || report.status || 'Pending Review';

    // Check if location data exists
    const lat = parseFloat(report.latitude);
    const lng = parseFloat(report.longitude);
    const hasLocation = !isNaN(lat) && !isNaN(lng) && lat !== 0 && lng !== 0;

    // Generate map HTML
    let mapHtml = '';
    if (hasLocation) {
        const latMin = (lat - 0.015).toFixed(6);
        const latMax = (lat + 0.015).toFixed(6);
        const lngMin = (lng - 0.015).toFixed(6);
        const lngMax = (lng + 0.015).toFixed(6);
        const latFixed = lat.toFixed(6);
        const lngFixed = lng.toFixed(6);
        
        mapHtml = `
            <hr class="detail-divider">
            <div class="detail-section">
                <span class="detail-label">📍 Location</span>
                <div class="detail-value" style="font-family: monospace; margin-bottom: 8px;">
                    ${latFixed}° N, ${lngFixed}° E
                </div>
                <div class="map-container">
                    <iframe 
                        src="https://www.openstreetmap.org/export/embed.html?bbox=${lngMin}%2C${latMin}%2C${lngMax}%2C${latMax}&layer=mapnik&marker=${latFixed}%2C${lngFixed}"
                        width="100%" 
                        height="280" 
                        style="border:0;"
                        loading="lazy"
                        title="Report location on OpenStreetMap"
                    ></iframe>
                </div>
                <a href="https://www.google.com/maps?q=${lat},${lng}" 
                   target="_blank" class="map-link">
                    <i class='bx bx-map'></i> Open in Google Maps
                </a>
            </div>
        `;
    }

    // ✅ 生成 Evidence HTML - 支持图片和视频
    let evidenceHtml = '';
    if (report.media_urls && report.media_urls.length > 0) {
        let imageCount = 0;
        let videoCount = 0;
        
        const itemsHtml = report.media_urls.map((media, index) => {
            const isVideo = media.type === 'video';
            const isImage = media.type === 'image';
            const url = media.url;
            const filename = media.filename || 'file';
            
            if (isVideo) videoCount++;
            else if (isImage) imageCount++;
            
            if (isVideo) {
                return `
                    <div class="evidence-item" onclick="openVideoViewer('${url}')" title="${filename}">
                        <video src="${url}" muted preload="metadata" onloadedmetadata="this.poster = this.currentTime"></video>
                        <div class="play-overlay">▶</div>
                        <span class="file-badge video">🎬 Video</span>
                    </div>
                `;
            } else if (isImage) {
                return `
                    <div class="evidence-item" onclick="openImageViewer('${url}')" title="${filename}">
                        <img src="${url}" alt="Evidence ${index + 1}" loading="lazy"
                             onerror="this.style.display='none'; this.parentElement.innerHTML='<div class=\\'evidence-placeholder\\'><i class=\\'bx bx-image\\'></i>${filename}</div>'">
                        <span class="file-badge image">📷 Image</span>
                    </div>
                `;
            } else {
                return `
                    <div class="evidence-item" style="cursor:default;">
                        <div class="evidence-placeholder">
                            <i class='bx bx-file'></i>
                            ${filename}
                        </div>
                        <span class="file-badge unknown">📄 Unknown</span>
                    </div>
                `;
            }
        }).join('');
        
        let summaryText = '';
        if (imageCount > 0 && videoCount > 0) {
            summaryText = `${imageCount} image${imageCount > 1 ? 's' : ''} & ${videoCount} video${videoCount > 1 ? 's' : ''}`;
        } else if (imageCount > 0) {
            summaryText = `${imageCount} image${imageCount > 1 ? 's' : ''}`;
        } else if (videoCount > 0) {
            summaryText = `${videoCount} video${videoCount > 1 ? 's' : ''}`;
        } else {
            summaryText = `${report.media_urls.length} file${report.media_urls.length > 1 ? 's' : ''}`;
        }
        
        evidenceHtml = `
            <hr class="detail-divider">
            <div class="detail-section">
                <span class="detail-label">📎 Evidence (${summaryText})</span>
                <div class="evidence-grid">
                    ${itemsHtml}
                </div>
                <div style="margin-top: 8px; font-size: 12px; color: #6b7280;">
                    <i class='bx bx-info-circle'></i> Click on images to view full size, click on videos to play
                </div>
            </div>
        `;
    }

    // Build detail content
    body.innerHTML = `
        <div class="detail-section">
            <span class="detail-label">Ticket ID</span>
            <div class="detail-value" style="font-weight: 600;">${report.ticket_id || 'N/A'}</div>
        </div>

        <div class="detail-section">
            <span class="detail-label">Category</span>
            <div class="detail-value">${report.category || 'N/A'}</div>
        </div>

        <div class="detail-section">
            <span class="detail-label">District</span>
            <div class="detail-value">${report.location || 'N/A'}</div>
        </div>

        <div class="detail-section">
            <span class="detail-label">Submitted</span>
            <div class="detail-value">${report.created_at ? new Date(report.created_at).toLocaleString() : 'N/A'}</div>
        </div>

        <div class="detail-section">
            <span class="detail-label">Status</span>
            <div><span class="status-badge ${statusClass}">${statusDisplay}</span></div>
        </div>

        <hr class="detail-divider">

        <div class="detail-section">
            <span class="detail-label">Full Name</span>
            <div class="detail-value">${report.full_name || 'N/A'}</div>
        </div>

        <div class="detail-section">
            <span class="detail-label">Phone Number</span>
            <div class="detail-value">${report.phone_number || 'N/A'}</div>
        </div>

        <div class="detail-section">
            <span class="detail-label">Email</span>
            <div class="detail-value">${report.email || 'N/A'}</div>
        </div>

        <div class="detail-section">
            <span class="detail-label">Address</span>
            <div class="detail-value">${report.address || 'N/A'}</div>
        </div>

        <div class="detail-section">
            <span class="detail-label">Incident Date & Time</span>
            <div class="detail-value">
                ${report.incident_date ? new Date(report.incident_date).toLocaleDateString() : 'N/A'}
                ${report.incident_time ? ' at ' + report.incident_time : ''}
            </div>
        </div>

        <div class="detail-section">
            <span class="detail-label">Urgency Level</span>
            <div class="detail-value">
                ${report.urgency_level === 'High' ? '🔴 High' : 
                  report.urgency_level === 'Medium' ? '🟡 Medium' : 
                  '🟢 Normal'}
            </div>
        </div>

        <hr class="detail-divider">

        <div class="detail-section">
            <span class="detail-label">Description</span>
            <p class="description-text">${report.description || 'No description provided.'}</p>
        </div>

        ${mapHtml}

        ${evidenceHtml}

        ${report.admin_notes ? `
            <hr class="detail-divider">
            <div class="detail-section">
                <span class="detail-label">Admin Notes</span>
                <p style="background: #fef3c7; padding: 12px; border-radius: 8px; margin: 0;">
                    ${report.admin_notes}
                </p>
            </div>
        ` : ''}
    `;

    // Build footer actions
    if (isPending) {
        footer.innerHTML = `
            <form method="post" style="flex: 1; min-width: 120px;" 
                  onsubmit="return confirm('Approve this citizen report?')">
                <input type="hidden" name="report_id" value="${report.id}">
                <input type="hidden" name="decision" value="approve">
                <button type="submit" class="btn-approve-lg">
                    <i class='bx bx-check'></i> Approve & Release
                </button>
            </form>
            <form method="post" style="flex: 1; min-width: 120px;" 
                  onsubmit="return confirm('Reject this citizen report as false alarm?')">
                <input type="hidden" name="report_id" value="${report.id}">
                <input type="hidden" name="decision" value="reject">
                <button type="submit" class="btn-reject-lg">
                    <i class='bx bx-x'></i> Reject as False Alarm
                </button>
            </form>
        `;
    } else {
        footer.innerHTML = `
            <div class="btn-processed-lg">
                <i class='bx bx-check-circle'></i> 
                ${report.status === 'Validated' ? '✅ Approved' : '❌ Rejected'} 
                (${report.status})
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

// Image Viewer functions
function openImageViewer(imageUrl) {
    const viewer = document.getElementById('imageViewer');
    const viewerImage = document.getElementById('viewerImage');
    viewerImage.src = imageUrl;
    viewer.classList.add('active');
    document.body.style.overflow = 'hidden';
}

function closeImageViewer() {
    const viewer = document.getElementById('imageViewer');
    viewer.classList.remove('active');
    document.body.style.overflow = '';
    document.getElementById('viewerImage').src = '';
}

// Video Viewer functions
function openVideoViewer(videoUrl) {
    const viewer = document.getElementById('videoViewer');
    const video = document.getElementById('viewerVideo');
    const source = document.getElementById('videoSource');
    
    // 暂停当前播放
    video.pause();
    
    // 设置新源
    source.src = videoUrl;
    video.load();
    
    viewer.classList.add('active');
    document.body.style.overflow = 'hidden';
    
    // 自动播放
    video.play().catch(function(e) {
        console.log('Auto-play prevented:', e);
    });
}

function closeVideoViewer() {
    const viewer = document.getElementById('videoViewer');
    const video = document.getElementById('viewerVideo');
    video.pause();
    viewer.classList.remove('active');
    document.body.style.overflow = '';
}

// Close on ESC
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        closeImageViewer();
        closeVideoViewer();
        if (document.getElementById('drawerPanel').classList.contains('active')) {
            closeDrawer();
        }
    }
});

function exportTable() {
    alert('Export functionality will be implemented here.');
}
</script>

<?php

render_admin_end();

?>

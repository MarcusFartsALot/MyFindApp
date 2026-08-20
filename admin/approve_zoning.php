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

// =========================================================
// Export to PDF
// =========================================================
if (isset($_GET['export']) && $_GET['export'] === 'pdf') {
    // 先获取所有数据用于导出
    try {
        $allPredictions = $client->asService(
            'GET',
            '/rest/v1/risk_predictions?select=*&order=generated_at.desc'
        );
        
        $exportData = is_array($allPredictions) ? $allPredictions : [];
        
        // 应用过滤器
        if ($statusFilter !== 'all') {
            $statusMap = [
                'pending' => 'Manual Review',
                'approved' => 'Approve',
                'rejected' => 'Reject'
            ];
            if (isset($statusMap[$statusFilter])) {
                $exportData = array_filter($exportData, function($item) use ($statusMap, $statusFilter) {
                    $rec = $item['recommendation'] ?? '';
                    if ($statusFilter === 'pending') {
                        return $rec === '' || $rec === 'Manual Review' || $rec === null;
                    }
                    return $rec === $statusMap[$statusFilter];
                });
            }
        }
        
        // 统计
        $total = count($exportData);
        $pending = 0;
        $approved = 0;
        $rejected = 0;
        foreach ($exportData as $p) {
            $rec = $p['recommendation'] ?? '';
            if ($rec === '' || $rec === 'Manual Review' || $rec === null) $pending++;
            elseif ($rec === 'Approve') $approved++;
            elseif ($rec === 'Reject') $rejected++;
        }
        
        // 输出 HTML 用于打印 PDF
        header('Content-Type: text/html; charset=utf-8');
        echo '<!DOCTYPE html>
        <html>
        <head>
            <title>Predictive Zoning Report</title>
            <style>
                body { font-family: Arial, sans-serif; padding: 20px; background: #fff; }
                h1 { text-align: center; color: #1a1a2e; font-size: 24px; margin-bottom: 4px; }
                .subtitle { text-align: center; color: #666; font-size: 14px; margin-bottom: 20px; }
                .stats { display: flex; gap: 12px; justify-content: center; margin: 20px 0; flex-wrap: wrap; }
                .stat-item { padding: 10px 20px; border: 1px solid #ddd; border-radius: 8px; text-align: center; min-width: 80px; background: #f8fafc; }
                .stat-number { font-size: 22px; font-weight: bold; display: block; }
                .stat-label { font-size: 11px; color: #666; }
                table { width: 100%; border-collapse: collapse; margin-top: 20px; font-size: 12px; }
                th { background: #f0f0f0; padding: 10px 8px; border: 1px solid #ddd; text-align: left; font-weight: 600; }
                td { padding: 8px; border: 1px solid #ddd; }
                .footer { text-align: center; margin-top: 30px; font-size: 11px; color: #999; border-top: 1px solid #eee; padding-top: 15px; }
                .status-pending { color: #92400e; }
                .status-approved { color: #065f46; }
                .status-rejected { color: #991b1b; }
                .risk-low { color: #065f46; }
                .risk-medium { color: #b95f00; }
                .risk-high { color: #b42332; }
                @media print {
                    body { padding: 10px; }
                    .no-print { display: none; }
                    th { background: #f0f0f0 !important; }
                }
            </style>
        </head>
        <body>
            <h1>📊 Predictive Zoning Report</h1>
            <p class="subtitle">Generated: ' . date('d M Y H:i:s') . ' | Filter: ' . ucfirst($statusFilter) . '</p>
            
            <div class="stats">
                <div class="stat-item"><span class="stat-number">' . $total . '</span><span class="stat-label">Total</span></div>
                <div class="stat-item"><span class="stat-number">' . $pending . '</span><span class="stat-label">Pending</span></div>
                <div class="stat-item"><span class="stat-number">' . $approved . '</span><span class="stat-label">Approved</span></div>
                <div class="stat-item"><span class="stat-number">' . $rejected . '</span><span class="stat-label">Rejected</span></div>
            </div>

            <table>
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Risk Level</th>
                        <th>Risk Score</th>
                        <th>Confidence</th>
                        <th>Status</th>
                        <th>Generated</th>
                    </tr>
                </thead>
                <tbody>';
        
        if (empty($exportData)) {
            echo '<tr><td colspan="6" style="text-align:center;padding:30px;color:#999;">No data found</td></tr>';
        } else {
            foreach ($exportData as $p) {
                $rec = $p['recommendation'] ?? '';
                if ($rec === '' || $rec === 'Manual Review' || $rec === null) {
                    $status = 'Pending Review';
                    $statusClass = 'status-pending';
                } elseif ($rec === 'Approve') {
                    $status = 'Approved';
                    $statusClass = 'status-approved';
                } else {
                    $status = 'Rejected';
                    $statusClass = 'status-rejected';
                }
                
                $risk = $p['risk_level'] ?? 'N/A';
                $riskClass = match($risk) {
                    'Low' => 'risk-low',
                    'Medium' => 'risk-medium',
                    'High' => 'risk-high',
                    default => ''
                };
                
                echo '<tr>
                    <td>' . substr($p['id'] ?? '', 0, 8) . '...</td>
                    <td class="' . $riskClass . '">' . $risk . '</td>
                    <td>' . number_format($p['risk_score'] ?? 0, 2) . '</td>
                    <td>' . number_format($p['confidence_score'] ?? 0, 1) . '%</td>
                    <td class="' . $statusClass . '">' . $status . '</td>
                    <td>' . date('d M Y H:i', strtotime($p['generated_at'] ?? 'now')) . '</td>
                </tr>';
            }
        }
        
        echo '    </tbody>
            </table>
            <div class="footer">MyFind System - Predictive Zoning Report | Generated by Admin Panel</div>
            <script>
                // 自动打印
                window.onload = function() {
                    window.print();
                };
                // 打印后关闭
                window.onafterprint = function() {
                    window.close();
                };
            </script>
        </body>
        </html>';
        exit;
    } catch (Throwable $e) {
        // 如果导出出错，显示错误信息
        echo '<h1>Export Error</h1><p>' . htmlspecialchars($e->getMessage()) . '</p>';
        exit;
    }
}

/*
|--------------------------------------------------------------------------
| Handle Approve / Reject
|--------------------------------------------------------------------------
*/

if ($_SERVER['REQUEST_METHOD'] === 'POST') {

    $predictionId = trim((string)($_POST['prediction_id'] ?? ''));
    $decision = trim((string)($_POST['decision'] ?? ''));

    if ($predictionId === '') {
        $actionError = 'Invalid prediction ID.';
    } elseif (!in_array($decision, ['approve', 'reject'], true)) {
        $actionError = 'Invalid decision.';
    } else {
        try {
            $newRecommendation = $decision === 'approve' ? 'Approve' : 'Reject';

            $updated = $client->asService(
                'PATCH',
                '/rest/v1/risk_predictions?id=eq.' . rawurlencode($predictionId),
                [
                    'recommendation' => $newRecommendation
                ]
            );

            if ($decision === 'approve') {
                $actionMessage = 'Predictive zoning has been approved successfully.';
            } else {
                $actionMessage = 'Predictive zoning has been rejected successfully.';
            }

            header('Location: ' . $_SERVER['PHP_SELF'] . '?status=' . $statusFilter . '&page=' . $page);
            exit;

        } catch (Throwable $e) {
            $actionError = 'Unable to update the predictive zoning. Please try again later.';
            error_log('Approve zoning error: ' . $e->getMessage());
        }
    }
}

/*
|--------------------------------------------------------------------------
| Load Risk Predictions with Stats
|--------------------------------------------------------------------------
*/

$predictions = [];
$totalPredictions = 0;
$pendingCount = 0;
$approvedCount = 0;
$rejectedCount = 0;
$lowRisk = 0;
$mediumRisk = 0;
$highRisk = 0;

// Get Supabase URL
$supabaseUrl = rtrim(getenv('SUPABASE_URL') ?: '', '/');

try {
    $allPredictions = $client->asService(
        'GET',
        '/rest/v1/risk_predictions?select=*&order=generated_at.desc'
    );
    
    if (is_array($allPredictions)) {
        $totalPredictions = count($allPredictions);
        
        foreach ($allPredictions as $prediction) {
            // Count statuses
            $recommendation = $prediction['recommendation'] ?? '';
            if ($recommendation === '' || $recommendation === 'Manual Review' || $recommendation === null) {
                $pendingCount++;
            } elseif ($recommendation === 'Approve') {
                $approvedCount++;
            } elseif ($recommendation === 'Reject') {
                $rejectedCount++;
            }
            
            // Count risk levels
            $riskLevel = $prediction['risk_level'] ?? '';
            if ($riskLevel === 'Low') $lowRisk++;
            elseif ($riskLevel === 'Medium') $mediumRisk++;
            elseif ($riskLevel === 'High') $highRisk++;
        }
    }

    // Build query - filter by status
    $query = '/rest/v1/risk_predictions?select=*&order=generated_at.desc';
    
    if ($statusFilter !== 'all') {
        $statusMap = [
            'pending' => 'Manual Review',
            'approved' => 'Approve',
            'rejected' => 'Reject'
        ];
        if (isset($statusMap[$statusFilter])) {
            $query .= '&recommendation=eq.' . rawurlencode($statusMap[$statusFilter]);
        }
    }
    
    $query .= '&limit=' . $perPage . '&offset=' . $offset;
    
    $predictions = $client->asService('GET', $query);
    
    if (!is_array($predictions)) {
        $predictions = [];
    }
    
} catch (Throwable $e) {
    $loadError = 'Unable to load predictive zoning data. Please refresh the page or try again later.';
    error_log('Load risk predictions error: ' . $e->getMessage());
}

$totalPages = ceil($totalPredictions / $perPage);

render_admin_start('Approve Predictive Zoning', $admin, 'dashboard');

?>

<style>
/* =========================================================
   PAGE LAYOUT
========================================================= */
.zoning-page {
    display: flex;
    flex-direction: column;
    gap: 24px;
}

/* =========================================================
   HEADER
========================================================= */
.zoning-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 20px;
    flex-wrap: wrap;
}

.zoning-header h1 {
    margin: 0;
    font-size: 24px;
    font-weight: 700;
    color: #1a1a2e;
}

.zoning-header h1 i {
    color: #3b82f6;
}

.zoning-header .subtitle {
    display: flex;
    align-items: center;
    gap: 12px;
    margin: 4px 0 0;
    flex-wrap: wrap;
}

.zoning-header .subtitle p {
    margin: 0;
    opacity: .7;
    font-size: 14px;
}

.zoning-header .badge-predictive {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 2px 12px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 600;
    background: #e8eefc;
    color: #3159a5;
}

/* =========================================================
   STATS CARDS
========================================================= */
.stats-grid {
    display: grid;
    grid-template-columns: repeat(7, 1fr);
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
.stat-high .stat-number { color: #dc3545; }
.stat-low .stat-number { color: #28a745; }
.stat-medium .stat-number { color: #fd7e14; }

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

.prediction-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 14px;
}

.prediction-table thead {
    background: #f8fafc;
    border-bottom: 2px solid #e5e7eb;
}

.prediction-table th {
    padding: 14px 16px;
    text-align: left;
    font-weight: 600;
    color: #4b5563;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
}

.prediction-table td {
    padding: 14px 16px;
    border-bottom: 1px solid #f1f3f5;
    vertical-align: middle;
}

.prediction-table tbody tr {
    transition: background 0.15s;
}

.prediction-table tbody tr:hover {
    background: #f8fafc;
}

.prediction-table tbody tr:last-child td {
    border-bottom: none;
}

.prediction-id {
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

.risk-badge {
    display: inline-block;
    padding: 4px 12px;
    border-radius: 12px;
    font-size: 11px;
    font-weight: 600;
}

.risk-low {
    background: #d1fae5;
    color: #065f46;
}

.risk-medium {
    background: #fff0df;
    color: #b95f00;
}

.risk-high {
    background: #fde2e5;
    color: #b42332;
}

/* =========================================================
   ACTION BUTTONS - View only
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
.zoning-alert {
    padding: 14px 18px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    gap: 10px;
}

.zoning-alert i {
    font-size: 20px;
}

.zoning-success {
    background: #d1fae5;
    color: #065f46;
}

.zoning-error {
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
   RESPONSIVE
========================================================= */
@media (max-width: 1200px) {
    .stats-grid {
        grid-template-columns: repeat(4, 1fr);
    }
}

@media (max-width: 768px) {
    .stats-grid {
        grid-template-columns: repeat(3, 1fr);
    }
    
    .prediction-table {
        font-size: 12px;
    }
    
    .prediction-table th,
    .prediction-table td {
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
        grid-template-columns: repeat(2, 1fr);
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

    .prediction-table th,
    .prediction-table td {
        padding: 8px 10px;
        font-size: 11px;
    }
}
</style>

<div class="zoning-page">

    <!-- HEADER -->
    <section class="zoning-header">
        <div>
            <div class="subtitle">
                <p>Review predictive zoning predictions and approve or reject them.</p>
                <span class="badge-predictive">🤖 AI Predictions</span>
            </div>
        </div>
        <a href="admin_dashboard.php" class="btn-filter btn-filter-outline" style="padding:8px 20px;border:1px solid #e5e7eb;border-radius:8px;text-decoration:none;color:#4b5563;font-size:13px;display:inline-flex;align-items:center;gap:6px;transition:all 0.2s;font-weight:500;" onmouseover="this.style.background='#f3f4f6'" onmouseout="this.style.background='transparent'">
            <i class='bx bx-arrow-back'></i> Dashboard
        </a>
    </section>

    <!-- ALERTS -->
    <?php if ($actionMessage !== null): ?>
        <div class="zoning-alert zoning-success" role="alert">
            <i class='bx bx-check-circle'></i>
            <?= htmlspecialchars($actionMessage, ENT_QUOTES, 'UTF-8') ?>
        </div>
    <?php endif; ?>

    <?php if ($actionError !== null): ?>
        <div class="zoning-alert zoning-error" role="alert">
            <i class='bx bx-error-circle'></i>
            <?= htmlspecialchars($actionError, ENT_QUOTES, 'UTF-8') ?>
        </div>
    <?php endif; ?>

    <?php if ($loadError !== null): ?>
        <div class="zoning-alert zoning-error" role="alert">
            <i class='bx bx-error-circle'></i>
            <?= htmlspecialchars($loadError, ENT_QUOTES, 'UTF-8') ?>
        </div>
    <?php endif; ?>

    <!-- STATS CARDS -->
    <section class="stats-grid">
        <div class="stat-card stat-total">
            <span class="stat-icon">📊</span>
            <span class="stat-number"><?= $totalPredictions ?></span>
            <span class="stat-label">Total Predictions</span>
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
        <div class="stat-card stat-high">
            <span class="stat-icon">🔴</span>
            <span class="stat-number"><?= $highRisk ?></span>
            <span class="stat-label">High Risk</span>
        </div>
        <div class="stat-card stat-medium">
            <span class="stat-icon">🟠</span>
            <span class="stat-number"><?= $mediumRisk ?></span>
            <span class="stat-label">Medium Risk</span>
        </div>
        <div class="stat-card stat-low">
            <span class="stat-icon">🟢</span>
            <span class="stat-number"><?= $lowRisk ?></span>
            <span class="stat-label">Low Risk</span>
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
        <a href="?status=<?= $statusFilter ?>&export=pdf" class="export-btn" target="_blank">
            <i class='bx bx-export'></i> Export PDF
        </a>
    </div>

    <!-- TABLE -->
    <div class="table-container">
        <table class="prediction-table">
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Risk Level</th>
                    <th>Risk Score</th>
                    <th>Confidence</th>
                    <th>Status</th>
                    <th>Generated</th>
                    <th>Action</th>
                </tr>
            </thead>
            <tbody>
                <?php if (!empty($predictions)): ?>
                    <?php foreach ($predictions as $prediction): ?>
                        <?php
                        $predictionId = (string)($prediction['id'] ?? '');
                        $riskLevel = (string)($prediction['risk_level'] ?? 'Unknown');
                        $riskScore = (float)($prediction['risk_score'] ?? 0);
                        $confidenceScore = (float)($prediction['confidence_score'] ?? 0);
                        $recommendation = (string)($prediction['recommendation'] ?? '');
                        $generatedAt = (string)($prediction['generated_at'] ?? '');
                        $predictionReason = (string)($prediction['prediction_reason'] ?? '');

                        // Determine status
                        $isPending = $recommendation === '' || $recommendation === 'Manual Review' || $recommendation === null;
                        $isApproved = $recommendation === 'Approve';
                        $isRejected = $recommendation === 'Reject';

                        $statusText = $isPending ? 'Pending Review' : ($isApproved ? 'Approved' : 'Rejected');
                        $statusClass = $isPending ? 'status-pending' : ($isApproved ? 'status-approved' : 'status-rejected');

                        $riskClass = match($riskLevel) {
                            'Low' => 'risk-low',
                            'Medium' => 'risk-medium',
                            'High' => 'risk-high',
                            default => ''
                        };

                        // Format date
                        $formattedDate = 'N/A';
                        if ($generatedAt !== '') {
                            try {
                                $formattedDate = date('d M Y H:i', strtotime($generatedAt));
                            } catch (Throwable $e) {
                                $formattedDate = $generatedAt;
                            }
                        }

                        // Risk level icon
                        $riskIcon = match($riskLevel) {
                            'Low' => '🟢',
                            'Medium' => '🟠',
                            'High' => '🔴',
                            default => '⚪'
                        };
                        ?>
                        <tr>
                            <td class="prediction-id"><?= htmlspecialchars(substr($predictionId, 0, 8) . '...', ENT_QUOTES, 'UTF-8') ?></td>
                            <td>
                                <span class="risk-badge <?= $riskClass ?>">
                                    <?= $riskIcon ?> <?= htmlspecialchars($riskLevel, ENT_QUOTES, 'UTF-8') ?>
                                </span>
                            </td>
                            <td><?= number_format($riskScore, 2) ?></td>
                            <td><?= number_format($confidenceScore, 1) ?>%</td>
                            <td>
                                <span class="status-badge <?= $statusClass ?>">
                                    <?= htmlspecialchars($statusText, ENT_QUOTES, 'UTF-8') ?>
                                </span>
                            </td>
                            <td><?= htmlspecialchars($formattedDate, ENT_QUOTES, 'UTF-8') ?></td>
                            <td>
                                <!-- View button only -->
                                <button class="btn-view" onclick="showDetails('<?= htmlspecialchars($predictionId, ENT_QUOTES, 'UTF-8') ?>')">
                                    <i class='bx bx-show'></i> View
                                </button>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                <?php else: ?>
                    <tr>
                        <td colspan="7" style="text-align: center; padding: 40px;">
                            <div class="empty-state">
                                <i class='bx bx-check-circle'></i>
                                <h3>No Predictive Zoning Data</h3>
                                <p>No predictions found matching your criteria.</p>
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
                    Showing <?= $offset + 1 ?>-<?= min($offset + $perPage, $totalPredictions) ?> of <?= $totalPredictions ?>
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
        <h2>Prediction Details</h2>
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
// Predictions data for drawer
const predictionsData = <?= json_encode($predictions) ?>;

function showDetails(predictionId) {
    const prediction = predictionsData.find(r => r.id === predictionId);
    if (!prediction) {
        alert('Prediction not found');
        return;
    }

    const overlay = document.getElementById('drawerOverlay');
    const panel = document.getElementById('drawerPanel');
    const body = document.getElementById('drawerBody');
    const footer = document.getElementById('drawerFooter');

    // Determine status
    const recommendation = prediction.recommendation || '';
    const isPending = recommendation === '' || recommendation === 'Manual Review' || recommendation === null;
    const isApproved = recommendation === 'Approve';
    const isRejected = recommendation === 'Reject';

    const statusText = isPending ? '⏳ Pending Review' : (isApproved ? '✅ Approved' : '❌ Rejected');
    const statusClass = isPending ? 'status-pending' : (isApproved ? 'status-approved' : 'status-rejected');

    const riskLevel = prediction.risk_level || 'Unknown';
    const riskIcon = riskLevel === 'Low' ? '🟢' : (riskLevel === 'Medium' ? '🟠' : '🔴');
    const riskClass = riskLevel === 'Low' ? 'risk-low' : (riskLevel === 'Medium' ? 'risk-medium' : 'risk-high');

    // Build detail content
    body.innerHTML = `
        <div class="detail-section">
            <span class="detail-label">Prediction ID</span>
            <div class="detail-value" style="font-weight: 600; font-family: monospace;">${prediction.id || 'N/A'}</div>
        </div>

        <div class="detail-section">
            <span class="detail-label">Application ID</span>
            <div class="detail-value" style="font-family: monospace;">${prediction.application_id || 'N/A'}</div>
        </div>

        <div class="detail-section">
            <span class="detail-label">Risk Level</span>
            <div class="detail-value">
                <span class="risk-badge ${riskClass}">
                    ${riskIcon} ${riskLevel}
                </span>
            </div>
        </div>

        <hr class="detail-divider">

        <div class="detail-section" style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
            <div>
                <span class="detail-label">Risk Score</span>
                <div class="detail-value" style="font-size: 24px; font-weight: 700; color: #1a1a2e;">${parseFloat(prediction.risk_score || 0).toFixed(2)}</div>
            </div>
            <div>
                <span class="detail-label">Confidence Score</span>
                <div class="detail-value" style="font-size: 24px; font-weight: 700; color: #3b82f6;">${parseFloat(prediction.confidence_score || 0).toFixed(1)}%</div>
            </div>
        </div>

        <hr class="detail-divider">

        <div class="detail-section">
            <span class="detail-label">Status</span>
            <div><span class="status-badge ${statusClass}">${statusText}</span></div>
        </div>

        <div class="detail-section">
            <span class="detail-label">Recommendation</span>
            <div class="detail-value">${prediction.recommendation || 'Manual Review Required'}</div>
        </div>

        <hr class="detail-divider">

        <div class="detail-section">
            <span class="detail-label">Prediction Reason</span>
            <p class="description-text">${prediction.prediction_reason || 'No reason provided.'}</p>
        </div>

        <div class="detail-section">
            <span class="detail-label">Model Version</span>
            <div class="detail-value">v${prediction.model_version || '1.0'}</div>
        </div>

        <div class="detail-section">
            <span class="detail-label">Generated At</span>
            <div class="detail-value">${prediction.generated_at ? new Date(prediction.generated_at).toLocaleString() : 'N/A'}</div>
        </div>
    `;

    // Build footer actions
    if (isPending) {
        footer.innerHTML = `
            <form method="post" style="flex: 1; min-width: 120px;" 
                  onsubmit="return confirm('Approve this predictive zoning?')">
                <input type="hidden" name="prediction_id" value="${prediction.id}">
                <input type="hidden" name="decision" value="approve">
                <button type="submit" class="btn-approve-lg">
                    <i class='bx bx-check'></i> Approve
                </button>
            </form>
            <form method="post" style="flex: 1; min-width: 120px;" 
                  onsubmit="return confirm('Reject this predictive zoning?')">
                <input type="hidden" name="prediction_id" value="${prediction.id}">
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
                (${prediction.recommendation})
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
</script>

<?php

render_admin_end();

?>
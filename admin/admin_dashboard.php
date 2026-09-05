<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/admin_guard.php';
require_once __DIR__ . '/includes/layout.php';
require_once __DIR__ . '/services/application_service.php';

$admin = require_admin();

$loadError = null;
$pendingCount = 0;
$citizenReportsCount = 0;

// Registration statistics
$touristApproved = 0;
$touristRejected = 0;
$touristPending = 0;
$citizenApproved = 0;
$citizenRejected = 0;
$citizenPending = 0;

// Combined
$registrationApproved = 0;
$registrationRejected = 0;
$registrationPending = 0;

// Citizen Reports statistics
$citizenValidated = 0;
$citizenRejectedReports = 0;

// ============================================================
// Top 5 Risk Areas & Emergency Alerts Data
// ============================================================
$top5RiskAreas = [];
$emergencyReports = [];
$emergencyCount = 0;

try {
    // Get SupabaseClient
    $client = new SupabaseClient();
    
    // =========================================================
    // 1. Tourist Registrations
    // =========================================================
    $touristApprovedData = $client->asService(
        'GET',
        '/rest/v1/tourists?select=profile_id&verification_status=eq.approved'
    );
    $touristApproved = is_array($touristApprovedData) ? count($touristApprovedData) : 0;
    
    $touristRejectedData = $client->asService(
        'GET',
        '/rest/v1/tourists?select=profile_id&verification_status=eq.rejected'
    );
    $touristRejected = is_array($touristRejectedData) ? count($touristRejectedData) : 0;
    
    $touristPendingData = $client->asService(
        'GET',
        '/rest/v1/tourists?select=profile_id&verification_status=eq.pending'
    );
    $touristPending = is_array($touristPendingData) ? count($touristPendingData) : 0;
    
    // =========================================================
    // 2. Citizen Registrations
    // =========================================================
    $citizenApprovedData = $client->asService(
        'GET',
        '/rest/v1/citizens?select=profile_id&verification_status=eq.approved'
    );
    $citizenApproved = is_array($citizenApprovedData) ? count($citizenApprovedData) : 0;
    
    $citizenRejectedData = $client->asService(
        'GET',
        '/rest/v1/citizens?select=profile_id&verification_status=eq.rejected'
    );
    $citizenRejected = is_array($citizenRejectedData) ? count($citizenRejectedData) : 0;
    
    $citizenPendingData = $client->asService(
        'GET',
        '/rest/v1/citizens?select=profile_id&verification_status=eq.pending'
    );
    $citizenPending = is_array($citizenPendingData) ? count($citizenPendingData) : 0;
    
    // =========================================================
    // 3. Combined Registration Statistics
    // =========================================================
    $registrationApproved = $touristApproved + $citizenApproved;
    $registrationRejected = $touristRejected + $citizenRejected;
    $registrationPending = $touristPending + $citizenPending;
    
    // =========================================================
    // 4. Citizen Reports & Risk Zones
    // =========================================================
    $citizenValidatedData = $client->asService(
        'GET',
        '/rest/v1/incident_reports?select=id&status=eq.Validated'
    );
    $citizenValidated = is_array($citizenValidatedData) ? count($citizenValidatedData) : 0;
    
    $citizenReportRejectedData = $client->asService(
        'GET',
        '/rest/v1/incident_reports?select=id&status=eq.Rejected'
    );
    $citizenRejectedReports = is_array($citizenReportRejectedData) ? count($citizenReportRejectedData) : 0;
    
    $citizenPendingData = $client->asService(
        'GET',
        '/rest/v1/incident_reports?select=id&status=in.(Pending%20Review,Under%20Investigation)'
    );
    $citizenReportsCount = is_array($citizenPendingData) ? count($citizenPendingData) : 0;
    
    // Total pending count for badge
    $pendingCount = $registrationPending + $citizenReportsCount;
    
    // =========================================================
    // 5. Get all reports for Top 5 Risk Areas & Emergency Alerts
    // =========================================================
    $allReports = $client->asService(
        'GET',
        '/rest/v1/incident_reports?select=*,latitude,longitude,location,category,urgency_level,status,created_at,ticket_id&order=created_at.desc'
    );
    
    if (is_array($allReports)) {
        // =========================================================
        // Emergency Alerts (Pending Emergency Reports)
        // =========================================================
        $emergencyReports = array_filter($allReports, function($report) {
            $status = strtolower($report['status'] ?? '');
            $urgency = $report['urgency_level'] ?? 'Normal';
            return $urgency === 'Emergency' && 
                   ($status === 'pending review' || $status === 'pending');
        });
        $emergencyCount = count($emergencyReports);
        
        // Sort emergency reports by created_at (newest first)
        usort($emergencyReports, function($a, $b) {
            return strtotime($b['created_at'] ?? '') - strtotime($a['created_at'] ?? '');
        });
        
        // Take only first 5 emergency reports
        $emergencyReports = array_slice($emergencyReports, 0, 5);
        
        // =========================================================
        // Top 5 Risk Areas (by report count)
        // =========================================================
        $locationGroups = [];
        foreach ($allReports as $report) {
            // Only include validated reports
            $status = strtolower($report['status'] ?? '');
            if ($status !== 'validated' && $status !== 'resolved') continue;
            
            $lat = (float)($report['latitude'] ?? 0);
            $lng = (float)($report['longitude'] ?? 0);
            if ($lat === 0.0 && $lng === 0.0) continue;
            
            $key = $lat . ',' . $lng;
            if (!isset($locationGroups[$key])) {
                $locationGroups[$key] = [
                    'name' => $report['location'] ?? 'Unknown Location',
                    'lat' => $lat,
                    'lng' => $lng,
                    'count' => 0,
                    'category' => $report['category'] ?? 'N/A',
                    'reports' => []
                ];
            }
            $locationGroups[$key]['count']++;
            $locationGroups[$key]['reports'][] = $report;
        }
        
        // Sort by count (descending) and take top 5
        usort($locationGroups, function($a, $b) {
            return $b['count'] - $a['count'];
        });
        $top5RiskAreas = array_slice($locationGroups, 0, 5);
        
        // Assign risk levels to top 5 areas
        foreach ($top5RiskAreas as &$area) {
            $count = $area['count'];
            if ($count >= 10) {
                $area['risk'] = 'Red';
            } elseif ($count >= 5) {
                $area['risk'] = 'Orange';
            } else {
                $area['risk'] = 'Green';
            }
        }
        unset($area);
    }
    
} catch (Throwable $e) {
    $pendingCount = 0;
    $loadError = 'Pending count is temporarily unavailable.';
    error_log('Dashboard stats error: ' . $e->getMessage());
}

render_admin_start(
    'Admin Dashboard',
    $admin,
    'dashboard'
);
?>

<style>
/* Dashboard-only presentation; values and report calculations remain unchanged. */
.dashboard-page { display: flex; flex-direction: column; gap: 28px; padding: 4px 0 24px; color: #12223b; }
.dashboard-page .dashboard-header { display: flex; align-items: flex-end; justify-content: space-between; gap: 24px; flex-wrap: wrap; padding: 0 0 24px; border-bottom: 1px solid #dfe7ef; background: transparent; }
.dashboard-page .dashboard-eyebrow { margin: 0 0 10px; color: #58708e; font-size: 10px; font-weight: 700; letter-spacing: 1.8px; }
.dashboard-page .dashboard-header h1 { margin: 0; color: #12223b; font-size: clamp(28px, 3vw, 38px); line-height: 1.2; letter-spacing: -1.3px; font-weight: 700; }
.dashboard-page .dashboard-header p:not(.dashboard-eyebrow) { margin: 12px 0 0; color: #637185; font-size: 13px; line-height: 1.7; }
.dashboard-page .header-badge { display: flex; align-items: center; gap: 8px; color: #58708e; font-size: 12px; white-space: nowrap; padding: 8px 0; }
.dashboard-page .dashboard-metrics { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); border: 1px solid #dfe7ef; border-radius: 10px; background: #fff; overflow: hidden; }
.dashboard-page .dashboard-metric { padding: 24px; border-right: 1px solid #dfe7ef; }
.dashboard-page .dashboard-metric:last-child { border-right: 0; }
.dashboard-page .dashboard-metric-label { display: block; font-size: 11px; color: #637185; font-weight: 500; line-height: 1.5; }
.dashboard-page .dashboard-metric-value { display: block; color: #12223b; font-size: 32px; font-weight: 700; line-height: 1.25; letter-spacing: -1px; margin: 10px 0 7px; }
.dashboard-page .dashboard-metric-note { display: block; color: #637185; font-size: 10px; line-height: 1.5; }
.dashboard-page .dashboard-metric-attention { background: #edf4fc; }
.dashboard-page .chart-section { min-width: 0; }
.dashboard-page .chart-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 20px; margin-bottom: 18px; flex-wrap: wrap; }
.dashboard-page .chart-header h2 { margin: 0; font-size: 20px; letter-spacing: -.6px; color: #12223b; font-weight: 700; }
.dashboard-page .chart-header p { margin: 7px 0 0; color: #637185; font-size: 12px; line-height: 1.7; }
.dashboard-page .chart-badge { padding: 7px 11px; border-radius: 5px; background: #e8eff6; color: #405773; font-size: 11px; white-space: nowrap; }
.dashboard-page .chart-grid-3 { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 18px; }
.dashboard-page .chart-box { min-width: 0; padding: 22px 20px 18px; background: #fff; border: 1px solid #dfe7ef; border-radius: 10px; }
.dashboard-page .chart-box-header { margin-bottom: 23px; }
.dashboard-page .chart-box-title { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 8px; color: #12223b; font-size: 13px; font-weight: 600; }
.dashboard-page .badge-total { font-size: 10px; color: #637185; font-weight: 400; }
.dashboard-page .chart-split { display: flex; align-items: center; gap: 15px; }
.dashboard-page .chart-split-left { flex: 0 0 90px; }
.dashboard-page .chart-split-right { flex: 1; min-width: 0; }
.dashboard-page .donut-wrapper { position: relative; width: 90px; height: 90px; margin: 0 auto; }
.dashboard-page .donut-wrapper canvas { width: 100% !important; height: 100% !important; }
.dashboard-page .donut-center-text { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); text-align: center; pointer-events: none; }
.dashboard-page .total-number { display: block; color: #12223b; font-size: 20px; font-weight: 700; line-height: 1.2; }
.dashboard-page .total-label { color: #637185; font-size: 9px; }
.dashboard-page .bar-chart-vertical { display: flex; align-items: flex-end; justify-content: center; gap: 12px; height: 110px; padding: 0 4px 4px; }
.dashboard-page .bar-item { display: flex; flex-direction: column; align-items: center; flex: 1; max-width: 44px; min-width: 0; }
.dashboard-page .bar { width: 100%; max-width: 23px; border-radius: 3px 3px 0 0; min-height: 4px; }
.dashboard-page .bar-approved, .dashboard-page .dot-approved { background: #32816b; }
.dashboard-page .bar-rejected, .dashboard-page .dot-rejected { background: #c55b64; }
.dashboard-page .bar-pending, .dashboard-page .dot-pending { background: #c18d40; }
.dashboard-page .bar-value { font-size: 11px; font-weight: 600; color: #12223b; margin-bottom: 4px; }
.dashboard-page .bar-label { font-size: 8px; color: #637185; margin-top: 6px; white-space: nowrap; }
.dashboard-page .chart-stats-simple { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 8px 10px; margin-top: 21px; padding-top: 15px; border-top: 1px solid #e8edf3; }
.dashboard-page .stat-item { display: inline-flex; align-items: center; gap: 4px; }
.dashboard-page .dot { width: 6px; height: 6px; flex-shrink: 0; border-radius: 50%; }
.dashboard-page .stat-number { color: #12223b; font-size: 11px; font-weight: 600; }
.dashboard-page .stat-label { color: #637185; font-size: 9px; }
.dashboard-page .two-col-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 18px; }
.dashboard-page .top-areas-card, .dashboard-page .emergency-card { min-width: 0; background: white; border-radius: 10px; border: 1px solid #dfe7ef; overflow: hidden; }
.dashboard-page .top-areas-header, .dashboard-page .emergency-header { padding: 22px 24px; border-bottom: 1px solid #e8edf3; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px; }
.dashboard-page .top-areas-header h3, .dashboard-page .emergency-header h3 { margin: 0; font-size: 16px; font-weight: 600; letter-spacing: -.4px; color: #12223b; }
.dashboard-page .top-areas-header .badge { background: #edf4fc; color: #405773; border-radius: 5px; padding: 5px 9px; font-size: 10px; }
.dashboard-page .emergency-badge { font-size: 10px; color: #993e47; background: #faedf0; border-radius: 5px; padding: 5px 9px; }
.dashboard-page .top-areas-body, .dashboard-page .emergency-body { padding: 4px 24px; }
.dashboard-page .area-item, .dashboard-page .emergency-item { display: flex; align-items: center; gap: 13px; padding: 17px 0; border-bottom: 1px solid #e8edf3; }
.dashboard-page .area-item:last-child, .dashboard-page .emergency-item:last-child { border-bottom: 0; }
.dashboard-page .rank { display: inline-grid; place-items: center; min-width: 29px; height: 29px; border: 1px solid #dfe7ef; border-radius: 5px; font-size: 11px; color: #58708e; }
.dashboard-page .area-info, .dashboard-page .emergency-item .info { flex: 1; min-width: 0; }
.dashboard-page .area-info .name, .dashboard-page .ticket { color: #12223b; font-size: 12px; font-weight: 600; overflow-wrap: anywhere; }
.dashboard-page .meta, .dashboard-page .details { display: flex; align-items: center; flex-wrap: wrap; gap: 6px 10px; font-size: 10px; color: #637185; margin-top: 6px; line-height: 1.6; overflow-wrap: anywhere; }
.dashboard-page .risk-badge-sm { padding: 2px 7px; border-radius: 4px; font-size: 9px; font-weight: 500; }
.dashboard-page .risk-badge-sm-red { background: #faedf0; color: #993e47; }
.dashboard-page .risk-badge-sm-orange { background: #fcf4e7; color: #94671f; }
.dashboard-page .risk-badge-sm-green { background: #eaf5ef; color: #27684f; }
.dashboard-page .count-badge { color: #12223b; font-size: 13px; font-weight: 600; padding-left: 8px; }
.dashboard-page .area-empty, .dashboard-page .emergency-empty { padding: 47px 15px; text-align: center; color: #637185; font-size: 12px; }
.dashboard-page .area-empty i, .dashboard-page .emergency-empty i { display: block; color: #58708e; font-size: 26px; margin-bottom: 12px; }
.dashboard-page .emergency-item { color: inherit; text-decoration: none; transition: background .18s ease; }
.dashboard-page .emergency-item:hover { background: #f4f7fa; }
.dashboard-page .emergency-item .icon { display: inline-grid; place-items: center; width: 29px; height: 29px; flex-shrink: 0; background: #faedf0; border-radius: 5px; color: #993e47; font-size: 17px; }
.dashboard-page .emergency-item .time { color: #637185; font-size: 10px; flex-shrink: 0; }
.dashboard-page .emergency-view-all { display: block; padding: 15px 24px; border-top: 1px solid #e8edf3; font-size: 11px; font-weight: 600; text-decoration: none; color: #294f86; }
.dashboard-page .emergency-view-all:hover { background: #edf4fc; }
@media (max-width: 1200px) {
    .dashboard-page .chart-grid-3 { grid-template-columns: 1fr; }
    .dashboard-page .chart-split { max-width: 380px; margin: 0 auto; gap: 35px; }
    .dashboard-page .chart-stats-simple { justify-content: center; gap: 22px; }
    .dashboard-page .chart-box-header { margin-bottom: 12px; }
}
@media (max-width: 900px) {
    .dashboard-page .dashboard-metrics { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    .dashboard-page .dashboard-metric:nth-child(2) { border-right: 0; }
    .dashboard-page .dashboard-metric:nth-child(-n+2) { border-bottom: 1px solid #dfe7ef; }
    .dashboard-page .two-col-grid { grid-template-columns: 1fr; }
}
@media (max-width: 480px) {
    .dashboard-page { gap: 22px; }
    .dashboard-page .dashboard-metric { padding: 18px 14px; }
    .dashboard-page .dashboard-metric-value { font-size: 27px; }
    .dashboard-page .chart-box { padding: 20px 15px 16px; }
    .dashboard-page .chart-split { gap: 15px; }
    .dashboard-page .top-areas-header, .dashboard-page .emergency-header { padding: 19px; }
    .dashboard-page .top-areas-body, .dashboard-page .emergency-body { padding: 4px 19px; }
    .dashboard-page .area-item, .dashboard-page .emergency-item { flex-wrap: wrap; gap: 10px; }
    .dashboard-page .emergency-item .time { margin-left: 39px; }
}
@media (prefers-reduced-motion: reduce) {
    .dashboard-page .emergency-item { transition: none; }
}
</style>

<div class="dashboard-page">

    <!-- HEADER -->
    <section class="dashboard-header">
        <div>
            <p class="dashboard-eyebrow">YOUR ADMIN WORKSPACE</p>
            <h1>Dashboard overview</h1>
            <p>A clear view of registrations, community reports, and areas that need your attention.</p>
        </div>
        <div class="header-badge">
            <i class='bx bx-calendar'></i> <?= date('d M Y') ?>
        </div>
    </section>

    <!-- ALERTS -->
    <?php if ($loadError !== null): ?>
        <div class="alert alert-error" role="alert">
            <i class='bx bx-error-circle'></i>
            <?= escape($loadError) ?>
        </div>
    <?php endif; ?>

    <!-- Summary values use the existing dashboard statistics. -->
    <section class="dashboard-metrics" aria-label="Key statistics">
        <div class="dashboard-metric">
            <span class="dashboard-metric-label">Total registrations</span>
            <strong class="dashboard-metric-value"><?= $registrationApproved + $registrationRejected + $registrationPending ?></strong>
            <span class="dashboard-metric-note">Tourist and citizen accounts</span>
        </div>
        <div class="dashboard-metric">
            <span class="dashboard-metric-label">Approved registrations</span>
            <strong class="dashboard-metric-value"><?= $registrationApproved ?></strong>
            <span class="dashboard-metric-note">Across both account types</span>
        </div>
        <div class="dashboard-metric dashboard-metric-attention">
            <span class="dashboard-metric-label">Awaiting review</span>
            <strong class="dashboard-metric-value"><?= $pendingCount ?></strong>
            <span class="dashboard-metric-note">Registrations and citizen reports</span>
        </div>
        <div class="dashboard-metric">
            <span class="dashboard-metric-label">Validated reports</span>
            <strong class="dashboard-metric-value"><?= $citizenValidated ?></strong>
            <span class="dashboard-metric-note">Reviewed community submissions</span>
        </div>
    </section>

    <!-- CHART SECTION - 3 Charts -->
    <section class="chart-section">
        <div class="chart-header">
            <div>
                <h2>Module status distribution</h2>
                <p>Review the progress of account registrations and community reports.</p>
            </div>
            <span class="chart-badge"><?= $pendingCount ?> awaiting review</span>
        </div>
        <div class="chart-grid-3">

            <!-- Chart 1: Approve Tourist -->
            <div class="chart-box">
                <div class="chart-box-header">
                    <div class="chart-box-title">
                        Tourist registrations
                        <span class="badge-total">Total: <?= $touristApproved + $touristRejected + $touristPending ?></span>
                    </div>
                </div>
                <div class="chart-split">
                    <div class="chart-split-left">
                        <div class="donut-wrapper">
                            <canvas id="touristDonut"></canvas>
                            <div class="donut-center-text">
                                <span class="total-number"><?= $touristApproved + $touristRejected + $touristPending ?></span>
                                <span class="total-label">Total</span>
                            </div>
                        </div>
                    </div>
                    <div class="chart-split-right">
                        <div class="bar-chart-vertical">
                            <div class="bar-item">
                                <div class="bar-value"><?= $touristApproved ?></div>
                                <div class="bar bar-approved" style="height: <?= max(10, ($touristApproved + $touristRejected + $touristPending) > 0 ? ($touristApproved / max(1, $touristApproved + $touristRejected + $touristPending)) * 70 : 10) ?>px;"></div>
                                <div class="bar-label">Approved</div>
                            </div>
                            <div class="bar-item">
                                <div class="bar-value"><?= $touristRejected ?></div>
                                <div class="bar bar-rejected" style="height: <?= max(10, ($touristApproved + $touristRejected + $touristPending) > 0 ? ($touristRejected / max(1, $touristApproved + $touristRejected + $touristPending)) * 70 : 10) ?>px;"></div>
                                <div class="bar-label">Rejected</div>
                            </div>
                            <div class="bar-item">
                                <div class="bar-value"><?= $touristPending ?></div>
                                <div class="bar bar-pending" style="height: <?= max(10, ($touristApproved + $touristRejected + $touristPending) > 0 ? ($touristPending / max(1, $touristApproved + $touristRejected + $touristPending)) * 70 : 10) ?>px;"></div>
                                <div class="bar-label">Pending</div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="chart-stats-simple">
                    <span class="stat-item"><span class="dot dot-approved"></span><span class="stat-number"><?= $touristApproved ?></span><span class="stat-label">Approved</span></span>
                    <span class="stat-item"><span class="dot dot-rejected"></span><span class="stat-number"><?= $touristRejected ?></span><span class="stat-label">Rejected</span></span>
                    <span class="stat-item"><span class="dot dot-pending"></span><span class="stat-number"><?= $touristPending ?></span><span class="stat-label">Pending</span></span>
                </div>
            </div>

            <!-- Chart 2: Approve Citizen -->
            <div class="chart-box">
                <div class="chart-box-header">
                    <div class="chart-box-title">
                        Citizen registrations
                        <span class="badge-total">Total: <?= $citizenApproved + $citizenRejected + $citizenPending ?></span>
                    </div>
                </div>
                <div class="chart-split">
                    <div class="chart-split-left">
                        <div class="donut-wrapper">
                            <canvas id="citizenRegDonut"></canvas>
                            <div class="donut-center-text">
                                <span class="total-number"><?= $citizenApproved + $citizenRejected + $citizenPending ?></span>
                                <span class="total-label">Total</span>
                            </div>
                        </div>
                    </div>
                    <div class="chart-split-right">
                        <div class="bar-chart-vertical">
                            <div class="bar-item">
                                <div class="bar-value"><?= $citizenApproved ?></div>
                                <div class="bar bar-approved" style="height: <?= max(10, ($citizenApproved + $citizenRejected + $citizenPending) > 0 ? ($citizenApproved / max(1, $citizenApproved + $citizenRejected + $citizenPending)) * 70 : 10) ?>px;"></div>
                                <div class="bar-label">Approved</div>
                            </div>
                            <div class="bar-item">
                                <div class="bar-value"><?= $citizenRejected ?></div>
                                <div class="bar bar-rejected" style="height: <?= max(10, ($citizenApproved + $citizenRejected + $citizenPending) > 0 ? ($citizenRejected / max(1, $citizenApproved + $citizenRejected + $citizenPending)) * 70 : 10) ?>px;"></div>
                                <div class="bar-label">Rejected</div>
                            </div>
                            <div class="bar-item">
                                <div class="bar-value"><?= $citizenPending ?></div>
                                <div class="bar bar-pending" style="height: <?= max(10, ($citizenApproved + $citizenRejected + $citizenPending) > 0 ? ($citizenPending / max(1, $citizenApproved + $citizenRejected + $citizenPending)) * 70 : 10) ?>px;"></div>
                                <div class="bar-label">Pending</div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="chart-stats-simple">
                    <span class="stat-item"><span class="dot dot-approved"></span><span class="stat-number"><?= $citizenApproved ?></span><span class="stat-label">Approved</span></span>
                    <span class="stat-item"><span class="dot dot-rejected"></span><span class="stat-number"><?= $citizenRejected ?></span><span class="stat-label">Rejected</span></span>
                    <span class="stat-item"><span class="dot dot-pending"></span><span class="stat-number"><?= $citizenPending ?></span><span class="stat-label">Pending</span></span>
                </div>
            </div>

            <!-- Chart 3: Citizen Reports -->
            <div class="chart-box">
                <div class="chart-box-header">
                    <div class="chart-box-title">
                        Citizen reports
                        <span class="badge-total">Total: <?= $citizenValidated + $citizenRejectedReports + $citizenReportsCount ?></span>
                    </div>
                </div>
                <div class="chart-split">
                    <div class="chart-split-left">
                        <div class="donut-wrapper">
                            <canvas id="citizenReportDonut"></canvas>
                            <div class="donut-center-text">
                                <span class="total-number"><?= $citizenValidated + $citizenRejectedReports + $citizenReportsCount ?></span>
                                <span class="total-label">Total</span>
                            </div>
                        </div>
                    </div>
                    <div class="chart-split-right">
                        <div class="bar-chart-vertical">
                            <div class="bar-item">
                                <div class="bar-value"><?= $citizenValidated ?></div>
                                <div class="bar bar-approved" style="height: <?= max(10, ($citizenValidated + $citizenRejectedReports + $citizenReportsCount) > 0 ? ($citizenValidated / max(1, $citizenValidated + $citizenRejectedReports + $citizenReportsCount)) * 70 : 10) ?>px;"></div>
                                <div class="bar-label">Validated</div>
                            </div>
                            <div class="bar-item">
                                <div class="bar-value"><?= $citizenRejectedReports ?></div>
                                <div class="bar bar-rejected" style="height: <?= max(10, ($citizenValidated + $citizenRejectedReports + $citizenReportsCount) > 0 ? ($citizenRejectedReports / max(1, $citizenValidated + $citizenRejectedReports + $citizenReportsCount)) * 70 : 10) ?>px;"></div>
                                <div class="bar-label">Rejected</div>
                            </div>
                            <div class="bar-item">
                                <div class="bar-value"><?= $citizenReportsCount ?></div>
                                <div class="bar bar-pending" style="height: <?= max(10, ($citizenValidated + $citizenRejectedReports + $citizenReportsCount) > 0 ? ($citizenReportsCount / max(1, $citizenValidated + $citizenRejectedReports + $citizenReportsCount)) * 70 : 10) ?>px;"></div>
                                <div class="bar-label">Pending</div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="chart-stats-simple">
                    <span class="stat-item"><span class="dot dot-approved"></span><span class="stat-number"><?= $citizenValidated ?></span><span class="stat-label">Validated</span></span>
                    <span class="stat-item"><span class="dot dot-rejected"></span><span class="stat-number"><?= $citizenRejectedReports ?></span><span class="stat-label">Rejected</span></span>
                    <span class="stat-item"><span class="dot dot-pending"></span><span class="stat-number"><?= $citizenReportsCount ?></span><span class="stat-label">Pending</span></span>
                </div>
            </div>

        </div>
    </section>

    <!-- ============================================================
         TWO COLUMN: Top 5 Risk Areas + Emergency Alerts
    ============================================================ -->
    <section class="two-col-grid">

        <!-- Top 5 Risk Areas -->
        <div class="top-areas-card">
            <div class="top-areas-header">
                <h3>Top 5 risk areas</h3>
                <span class="badge">By report count</span>
            </div>
            <div class="top-areas-body">
                <?php if (!empty($top5RiskAreas)): ?>
                    <?php foreach ($top5RiskAreas as $index => $area):
                        $rankClass = '';
                        if ($index === 0) $rankClass = 'gold';
                        elseif ($index === 1) $rankClass = 'silver';
                        elseif ($index === 2) $rankClass = 'bronze';

                        $riskClass = match($area['risk'] ?? 'Green') {
                            'Red' => 'risk-badge-sm-red',
                            'Orange' => 'risk-badge-sm-orange',
                            default => 'risk-badge-sm-green'
                        };
                    ?>
                        <div class="area-item">
                            <span class="rank <?= $rankClass ?>">#<?= $index + 1 ?></span>
                            <div class="area-info">
                                <div class="name"><?= htmlspecialchars($area['name'] ?? 'Unknown') ?></div>
                                <div class="meta">
                                    <span><i class='bx bx-folder' aria-hidden="true"></i> <?= htmlspecialchars($area['category'] ?? 'N/A') ?></span>
                                    <span class="risk-badge-sm <?= $riskClass ?>"><?= $area['risk'] ?? 'Green' ?></span>
                                </div>
                            </div>
                            <span class="count-badge"><?= $area['count'] ?></span>
                        </div>
                    <?php endforeach; ?>
                <?php else: ?>
                    <div class="area-empty">
                        <i class='bx bx-check-circle'></i>
                        <p>No validated reports found.</p>
                    </div>
                <?php endif; ?>
            </div>
        </div>

        <!-- Emergency Alerts -->
        <div class="emergency-card">
            <div class="emergency-header">
                <h3>Emergency alerts</h3>
                <span class="emergency-badge"><?= $emergencyCount ?> pending</span>
            </div>
            <div class="emergency-body">
                <?php if (!empty($emergencyReports)): ?>
                    <?php foreach ($emergencyReports as $report):
                        $createdAt = $report['created_at'] ?? '';
                        $timeAgo = 'Just now';
                        if ($createdAt !== '') {
                            try {
                                $timestamp = strtotime($createdAt);
                                $diff = time() - $timestamp;
                                if ($diff < 60) {
                                    $timeAgo = 'Just now';
                                } elseif ($diff < 3600) {
                                    $timeAgo = floor($diff / 60) . 'm ago';
                                } elseif ($diff < 86400) {
                                    $timeAgo = floor($diff / 3600) . 'h ago';
                                } else {
                                    $timeAgo = floor($diff / 86400) . 'd ago';
                                }
                            } catch (Throwable $e) {
                                $timeAgo = 'N/A';
                            }
                        }
                    ?>
                        <a href="approve_citizen_report.php" class="emergency-item">
                            <span class="icon" aria-hidden="true"><i class='bx bx-alarm-exclamation'></i></span>
                            <div class="info">
                                <div class="ticket"><?= htmlspecialchars($report['ticket_id'] ?? 'N/A') ?></div>
                                <div class="details">
                                    <span><i class='bx bx-folder' aria-hidden="true"></i> <?= htmlspecialchars($report['category'] ?? 'N/A') ?></span>
                                    <span><i class='bx bx-map-pin' aria-hidden="true"></i> <?= htmlspecialchars($report['location'] ?? 'N/A') ?></span>
                                </div>
                            </div>
                            <span class="time"><?= $timeAgo ?></span>
                        </a>
                    <?php endforeach; ?>
                <?php else: ?>
                    <div class="emergency-empty">
                        <i class='bx bx-check-circle'></i>
                        <p>No emergency alerts. All clear!</p>
                    </div>
                <?php endif; ?>
            </div>
            <?php if ($emergencyCount > 5): ?>
                <a href="approve_citizen_report.php?status=pending" class="emergency-view-all">
                    View all <?= $emergencyCount ?> emergency reports →
                </a>
            <?php endif; ?>
        </div>

    </section>

</div>

<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

<script>
document.addEventListener('DOMContentLoaded', function() {

    // Chart 1: Tourist Doughnut
    const touristCtx = document.getElementById('touristDonut');
    if (touristCtx) {
        new Chart(touristCtx, {
            type: 'doughnut',
            data: {
                labels: ['Approved', 'Rejected', 'Pending'],
                datasets: [{
                    data: [<?= $touristApproved ?>, <?= $touristRejected ?>, <?= $touristPending ?>],
                    backgroundColor: ['#32816b', '#c55b64', '#c18d40'],
                    borderWidth: 2,
                    borderColor: '#ffffff'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                cutout: '65%',
                plugins: { legend: { display: false } }
            }
        });
    }

    // Chart 2: Citizen Registration Doughnut
    const citizenRegCtx = document.getElementById('citizenRegDonut');
    if (citizenRegCtx) {
        new Chart(citizenRegCtx, {
            type: 'doughnut',
            data: {
                labels: ['Approved', 'Rejected', 'Pending'],
                datasets: [{
                    data: [<?= $citizenApproved ?>, <?= $citizenRejected ?>, <?= $citizenPending ?>],
                    backgroundColor: ['#32816b', '#c55b64', '#c18d40'],
                    borderWidth: 2,
                    borderColor: '#ffffff'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                cutout: '65%',
                plugins: { legend: { display: false } }
            }
        });
    }

    // Chart 3: Citizen Reports Doughnut
    const citizenReportCtx = document.getElementById('citizenReportDonut');
    if (citizenReportCtx) {
        new Chart(citizenReportCtx, {
            type: 'doughnut',
            data: {
                labels: ['Validated', 'Rejected', 'Pending'],
                datasets: [{
                    data: [<?= $citizenValidated ?>, <?= $citizenRejectedReports ?>, <?= $citizenReportsCount ?>],
                    backgroundColor: ['#32816b', '#c55b64', '#c18d40'],
                    borderWidth: 2,
                    borderColor: '#ffffff'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                cutout: '65%',
                plugins: { legend: { display: false } }
            }
        });
    }

});
</script>

<?php render_admin_end(); ?>

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
.dashboard-page {
    display: flex;
    flex-direction: column;
    gap: 24px;
    padding: 8px 0;
}

/* Header */
.dashboard-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 20px;
    flex-wrap: wrap;
    background: linear-gradient(135deg, #dbeafe 0%, #93c5fd 50%, #bfdbfe 100%);
    padding: 24px 32px;
    border-radius: 16px;
    color: #1a1a2e;
    box-shadow: none;
}

.dashboard-header h1 {
    margin: 0;
    font-size: 26px;
    font-weight: 700;
    color: #1a1a2e;
}

.dashboard-header p {
    margin: 4px 0 0;
    opacity: 0.7;
    font-size: 15px;
    max-width: 500px;
    color: #4b5563;
}

.dashboard-header .header-badge {
    background: #D4CFC9;
    padding: 8px 20px;
    border-radius: 30px;
    font-size: 14px;
    color: #4b5563;
    border: none;
}

/* Card Grid - 4 cards */
.card-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 16px;
}

.metric-card {
    padding: 24px 16px;
    border-radius: 14px;
    background: white;
    box-shadow: 0 1px 3px rgba(0,0,0,0.06);
    border: 1px solid #f1f3f5;
    text-decoration: none;
    color: #1a1a2e;
    text-align: center;
    transition: all 0.3s;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
}

.metric-card:hover {
    transform: translateY(-4px);
    box-shadow: 0 8px 30px rgba(0,0,0,0.10);
    border-color: #d1d5db;
}

.metric-card .card-icon {
    width: 52px;
    height: 52px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;
    margin-bottom: 10px;
}

.metric-card .card-content strong {
    display: block;
    font-size: 16px;
    font-weight: 600;
    color: #1a1a2e;
}

.metric-card .card-content .sub {
    font-size: 12px;
    color: #6b7280;
    font-weight: 400;
    margin-top: 2px;
}

/* =========================================================
   TWO COLUMN SECTION - Top 5 Risk Areas + Emergency Alerts
========================================================= */
.two-col-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 20px;
}

/* =========================================================
   TOP 5 RISK AREAS
========================================================= */
.top-areas-card {
    background: white;
    border-radius: 16px;
    border: 1px solid #f1f3f5;
    overflow: hidden;
}

.top-areas-header {
    padding: 16px 24px;
    border-bottom: 1px solid #f1f3f5;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 10px;
    background: #fafbfc;
}

.top-areas-header h3 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: #1a1a2e;
}

.top-areas-header .badge {
    font-size: 12px;
    color: #6b7280;
    background: #f1f5f9;
    padding: 2px 12px;
    border-radius: 20px;
}

.top-areas-body {
    padding: 16px 20px;
}

.area-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px 12px;
    border-radius: 10px;
    transition: background 0.2s;
    border-bottom: 1px solid #f1f3f5;
}

.area-item:last-child {
    border-bottom: none;
}

.area-item:hover {
    background: #f8fafc;
}

.area-item .rank {
    font-size: 14px;
    font-weight: 700;
    color: #6b7280;
    min-width: 28px;
}

.area-item .rank.gold { color: #f59e0b; }
.area-item .rank.silver { color: #9ca3af; }
.area-item .rank.bronze { color: #d97706; }

.area-item .area-info {
    flex: 1;
}

.area-item .area-info .name {
    font-weight: 600;
    font-size: 14px;
    color: #1a1a2e;
}

.area-item .area-info .meta {
    font-size: 12px;
    color: #6b7280;
}

.area-item .area-info .meta span {
    margin-right: 8px;
}

.area-item .risk-badge-sm {
    display: inline-block;
    padding: 2px 10px;
    border-radius: 10px;
    font-size: 10px;
    font-weight: 600;
}

.risk-badge-sm-red { background: #fde2e5; color: #b42332; }
.risk-badge-sm-orange { background: #fff0df; color: #b95f00; }
.risk-badge-sm-green { background: #def7e8; color: #147a43; }

.area-item .count-badge {
    font-size: 13px;
    font-weight: 600;
    color: #1a1a2e;
    background: #f1f5f9;
    padding: 2px 10px;
    border-radius: 12px;
    min-width: 30px;
    text-align: center;
}

.area-empty {
    text-align: center;
    padding: 30px 20px;
    color: #6b7280;
}

.area-empty i {
    font-size: 28px;
    display: block;
    margin-bottom: 6px;
    opacity: 0.4;
}

/* =========================================================
   EMERGENCY ALERTS
========================================================= */
.emergency-card {
    background: white;
    border-radius: 16px;
    border: 1px solid #f1f3f5;
    overflow: hidden;
}

.emergency-header {
    padding: 16px 24px;
    border-bottom: 1px solid #f1f3f5;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 10px;
    background: #fafbfc;
}

.emergency-header h3 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: #1a1a2e;
}

.emergency-header .emergency-badge {
    font-size: 12px;
    color: #991b1b;
    background: #fee2e2;
    padding: 2px 14px;
    border-radius: 20px;
    font-weight: 600;
}

.emergency-body {
    padding: 16px 20px;
}

.emergency-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px 12px;
    border-radius: 10px;
    transition: background 0.2s;
    border-bottom: 1px solid #f1f3f5;
    cursor: pointer;
}

.emergency-item:last-child {
    border-bottom: none;
}

.emergency-item:hover {
    background: #fef2f2;
}

.emergency-item .icon {
    font-size: 18px;
    flex-shrink: 0;
}

.emergency-item .info {
    flex: 1;
    min-width: 0;
}

.emergency-item .info .ticket {
    font-weight: 600;
    font-size: 13px;
    color: #1a1a2e;
}

.emergency-item .info .details {
    font-size: 12px;
    color: #6b7280;
}

.emergency-item .info .details span {
    margin-right: 8px;
}

.emergency-item .time {
    font-size: 11px;
    color: #6b7280;
    flex-shrink: 0;
}

.emergency-empty {
    text-align: center;
    padding: 30px 20px;
    color: #6b7280;
}

.emergency-empty i {
    font-size: 28px;
    display: block;
    margin-bottom: 6px;
    opacity: 0.4;
}

.emergency-view-all {
    display: block;
    text-align: center;
    padding: 10px;
    border-top: 1px solid #f1f3f5;
    color: #dc2626;
    text-decoration: none;
    font-size: 13px;
    font-weight: 500;
    transition: background 0.2s;
}

.emergency-view-all:hover {
    background: #fef2f2;
}

/* Chart Section */
.chart-section {
    background: white;
    border-radius: 16px;
    border: 1px solid #f1f3f5;
    overflow: hidden;
}

.chart-header {
    padding: 16px 24px;
    border-bottom: 1px solid #f1f3f5;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 10px;
    background: #fafbfc;
}

.chart-header h2 {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
    color: #1a1a2e;
}

.chart-header .chart-badge {
    font-size: 13px;
    color: #6b7280;
    background: #f1f5f9;
    padding: 4px 16px;
    border-radius: 20px;
}

.chart-grid-3 {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 20px;
    padding: 20px;
}

/* Chart Box */
.chart-box {
    background: #ffffff;
    border-radius: 14px;
    padding: 18px 20px 20px;
    border: 1px solid #f1f3f5;
}

.chart-box-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 14px;
}

.chart-box-title {
    font-size: 15px;
    font-weight: 600;
    color: #1a1a2e;
}

.chart-box-title .badge-total {
    font-size: 12px;
    font-weight: 400;
    color: #6b7280;
    background: #f1f5f9;
    padding: 2px 12px;
    border-radius: 12px;
    margin-left: 6px;
}

.chart-box-title .badge-tourist {
    font-size: 11px;
    font-weight: 500;
    color: #1e40af;
    background: #dbeafe;
    padding: 2px 10px;
    border-radius: 10px;
    margin-left: 6px;
}

.chart-box-title .badge-citizen {
    font-size: 11px;
    font-weight: 500;
    color: #5b21b6;
    background: #ede9fe;
    padding: 2px 10px;
    border-radius: 10px;
    margin-left: 6px;
}

.chart-box-title .badge-report {
    font-size: 11px;
    font-weight: 500;
    color: #991b1b;
    background: #fee2e2;
    padding: 2px 10px;
    border-radius: 10px;
    margin-left: 6px;
}

/* Chart Split */
.chart-split {
    display: flex;
    align-items: center;
    gap: 12px;
}

.chart-split-left {
    flex: 0 0 100px;
}

.chart-split-right {
    flex: 1;
    min-width: 0;
}

/* Doughnut */
.donut-wrapper {
    position: relative;
    width: 90px;
    height: 90px;
    margin: 0 auto;
}

.donut-wrapper canvas {
    width: 100% !important;
    height: 100% !important;
}

.donut-center-text {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    text-align: center;
}

.donut-center-text .total-number {
    font-size: 18px;
    font-weight: 700;
    color: #1a1a2e;
    display: block;
    line-height: 1.2;
}

.donut-center-text .total-label {
    font-size: 9px;
    color: #6b7280;
}

/* Bar Chart */
.bar-chart-vertical {
    display: flex;
    align-items: flex-end;
    justify-content: center;
    gap: 12px;
    height: 90px;
    padding: 0 4px 4px 4px;
}

.bar-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    flex: 1;
    max-width: 44px;
}

.bar-item .bar {
    width: 100%;
    max-width: 30px;
    border-radius: 4px 4px 0 0;
    min-height: 4px;
}

.bar-item .bar-approved { background: linear-gradient(180deg, #34d399, #10b981); }
.bar-item .bar-rejected { background: linear-gradient(180deg, #f87171, #dc3545); }
.bar-item .bar-pending { background: linear-gradient(180deg, #fbbf24, #f59e0b); }

.bar-item .bar-value {
    font-size: 13px;
    font-weight: 700;
    color: #1a1a2e;
    margin-bottom: 2px;
}

.bar-item .bar-label {
    font-size: 10px;
    color: #6b7280;
    margin-top: 4px;
    font-weight: 500;
}

/* Stats Labels */
.chart-stats-simple {
    display: flex;
    justify-content: center;
    gap: 16px;
    margin-top: 14px;
    font-size: 12px;
    flex-wrap: wrap;
    padding-top: 12px;
    border-top: 1px solid #f1f3f5;
}

.chart-stats-simple .stat-item {
    display: flex;
    align-items: center;
    gap: 4px;
}

.chart-stats-simple .dot {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    display: inline-block;
}

.dot-approved { background: #10b981; }
.dot-rejected { background: #dc3545; }
.dot-pending { background: #f59e0b; }

.chart-stats-simple .stat-number {
    font-weight: 600;
    font-size: 14px;
    color: #1a1a2e;
}

.chart-stats-simple .stat-label {
    font-size: 11px;
    color: #6b7280;
}

/* Alert */
.alert {
    padding: 14px 18px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    gap: 10px;
}

.alert i {
    font-size: 20px;
}

.alert-error {
    background: #fee2e2;
    color: #991b1b;
}

/* Responsive */
@media (max-width: 1024px) {
    .card-grid {
        grid-template-columns: repeat(2, 1fr);
    }
    .chart-grid-3 {
        grid-template-columns: repeat(2, 1fr);
    }
    .two-col-grid {
        grid-template-columns: 1fr;
    }
}

@media (max-width: 768px) {
    .dashboard-header {
        flex-direction: column;
        align-items: flex-start;
        padding: 18px 22px;
    }

    .card-grid {
        grid-template-columns: repeat(2, 1fr);
    }

    .chart-grid-3 {
        grid-template-columns: 1fr;
        gap: 16px;
        padding: 16px;
    }

    .chart-split {
        flex-direction: column;
        gap: 8px;
    }

    .chart-split-left {
        flex: 0 0 auto;
        width: 100%;
    }

    .donut-wrapper {
        width: 80px;
        height: 80px;
    }

    .bar-chart-vertical {
        height: 70px;
        gap: 16px;
    }

    .bar-item {
        max-width: 45px;
    }

    .bar-item .bar {
        max-width: 32px;
    }
    
    .two-col-grid {
        grid-template-columns: 1fr;
    }
}

@media (max-width: 480px) {
    .card-grid {
        grid-template-columns: 1fr 1fr;
        gap: 10px;
    }

    .metric-card {
        padding: 16px 10px;
    }

    .metric-card .card-icon {
        width: 40px;
        height: 40px;
        font-size: 18px;
    }

    .metric-card .card-content strong {
        font-size: 13px;
    }

    .metric-card .card-content .sub {
        font-size: 10px;
    }

    .dashboard-header h1 {
        font-size: 20px;
    }

    .donut-wrapper {
        width: 70px;
        height: 70px;
    }

    .donut-center-text .total-number {
        font-size: 15px;
    }

    .bar-chart-vertical {
        height: 60px;
        gap: 10px;
    }

    .bar-item {
        max-width: 35px;
    }

    .bar-item .bar {
        max-width: 24px;
    }

    .bar-item .bar-value {
        font-size: 11px;
    }

    .bar-item .bar-label {
        font-size: 8px;
    }

    .chart-stats-simple {
        gap: 8px;
        font-size: 11px;
    }
    
    .chart-box-header {
        flex-direction: column;
        align-items: flex-start;
        gap: 4px;
    }
    
    .area-item {
        flex-wrap: wrap;
        gap: 6px;
    }
    
    .emergency-item {
        flex-wrap: wrap;
        gap: 6px;
    }
}
</style>

<div class="dashboard-page">

    <!-- HEADER -->
    <section class="dashboard-header">
        <div>
            <h1><i class='bx bx-grid-alt'></i> Dashboard</h1>
            <p>Monitor risk zones, process registrations, and review citizen reports.</p>
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

    <!-- CARD GRID - 4 CARDS -->
    <section class="card-grid">
        <!-- Card 1: View Risk Map -->
        <a class="metric-card" href="risk_map.php">
            <div class="card-icon" style="background:#dbeafe;color:#2563eb;">
                <i class='bx bx-map'></i>
            </div>
            <div class="card-content">
                <strong>View Risk Map</strong>
                <div class="sub">View risk zones</div>
            </div>
        </a>

        <!-- Card 2: Approve Tourist -->
        <a class="metric-card" href="approve_tourist.php">
            <div class="card-icon" style="background:#fef3c7;color:#d97706;">
                <i class='bx bx-user-check'></i>
            </div>
            <div class="card-content">
                <strong>Approve Tourist</strong>
                <div class="sub">Review tourist registrations</div>
            </div>
        </a>

        <!-- Card 3: Approve Citizen -->
        <a class="metric-card" href="approve_citizen.php">
            <div class="card-icon" style="background:#ede9fe;color:#7c3aed;">
                <i class='bx bx-user-check'></i>
            </div>
            <div class="card-content">
                <strong>Approve Citizen</strong>
                <div class="sub">Review citizen registrations</div>
            </div>
        </a>

        <!-- Card 4: Citizen Reports -->
        <a class="metric-card" href="approve_citizen_report.php">
            <div class="card-icon" style="background:#fde2e5;color:#dc2626;">
                <i class='bx bx-flag'></i>
            </div>
            <div class="card-content">
                <strong>Citizen Reports</strong>
                <div class="sub">Review incident reports</div>
            </div>
        </a>
    </section>

    <!-- ============================================================
         TWO COLUMN: Top 5 Risk Areas + Emergency Alerts
    ============================================================ -->
    <section class="two-col-grid">

        <!-- Top 5 Risk Areas -->
        <div class="top-areas-card">
            <div class="top-areas-header">
                <h3><i class='bx bx-trophy' style="color:#f59e0b;"></i> Top 5 Risk Areas</h3>
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
                                    <span>📂 <?= htmlspecialchars($area['category'] ?? 'N/A') ?></span>
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
                <h3><i class='bx bx-alarm-exclamation' style="color:#dc2626;"></i> Emergency Alerts</h3>
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
                        <a href="approve_citizen_report.php" class="emergency-item" style="text-decoration:none;color:inherit;display:flex;">
                            <span class="icon">🔴</span>
                            <div class="info">
                                <div class="ticket"><?= htmlspecialchars($report['ticket_id'] ?? 'N/A') ?></div>
                                <div class="details">
                                    <span>📂 <?= htmlspecialchars($report['category'] ?? 'N/A') ?></span>
                                    <span>📍 <?= htmlspecialchars($report['location'] ?? 'N/A') ?></span>
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

    <!-- CHART SECTION - 3 Charts -->
    <section class="chart-section">
        <div class="chart-header">
            <h2><i class='bx bx-stats'></i> Module Status Distribution</h2>
        </div>
        <div class="chart-grid-3">

            <!-- Chart 1: Approve Tourist -->
            <div class="chart-box">
                <div class="chart-box-header">
                    <div class="chart-box-title">
                        Approve Tourist
                        <span class="badge-tourist">Tourist</span>
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
                        Approve Citizen
                        <span class="badge-citizen">Citizen</span>
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
                        Citizen Reports
                        <span class="badge-report">Reports</span>
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
                    backgroundColor: ['#10b981', '#dc3545', '#f59e0b'],
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
                    backgroundColor: ['#10b981', '#dc3545', '#f59e0b'],
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
                    backgroundColor: ['#10b981', '#dc3545', '#f59e0b'],
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
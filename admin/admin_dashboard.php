<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/admin_guard.php';
require_once __DIR__ . '/includes/layout.php';
require_once __DIR__ . '/services/application_service.php';

$admin = require_admin();

$loadError = null;
$pendingCount = 0;
$citizenReportsCount = 0;
$predictionsCount = 0;
$touristApplicationsCount = 0;

// Statistics variables for 3 modules
$zoningApproved = 0;
$zoningRejected = 0;
$touristApproved = 0;
$touristRejected = 0;
$citizenValidated = 0;
$citizenRejected = 0;
$totalTourists = 0;

try {
    // Get SupabaseClient
    $client = new SupabaseClient();
    
    // =========================================================
    // 1. UC203: Risk Predictions (Approve Zoning)
    // =========================================================
    $zoningApprovedData = $client->asService(
        'GET',
        '/rest/v1/risk_predictions?select=id&recommendation=eq.Approve'
    );
    $zoningApproved = is_array($zoningApprovedData) ? count($zoningApprovedData) : 0;
    
    $zoningRejectedData = $client->asService(
        'GET',
        '/rest/v1/risk_predictions?select=id&recommendation=eq.Reject'
    );
    $zoningRejected = is_array($zoningRejectedData) ? count($zoningRejectedData) : 0;
    
    // Zoning Pending
    $zoningPending1 = $client->asService(
        'GET',
        '/rest/v1/risk_predictions?select=id&recommendation=is.null'
    );
    $zoningPending2 = $client->asService(
        'GET',
        '/rest/v1/risk_predictions?select=id&recommendation=eq.Manual%20Review'
    );
    $predictionsCount = (is_array($zoningPending1) ? count($zoningPending1) : 0) + 
                        (is_array($zoningPending2) ? count($zoningPending2) : 0);
    
    // =========================================================
    // 2. UC204: Tourist Registrations
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
    
    // Tourist Pending
    $touristPending = $client->asService(
        'GET',
        '/rest/v1/tourists?select=profile_id&verification_status=eq.pending'
    );
    $touristApplicationsCount = is_array($touristPending) ? count($touristPending) : 0;
    
    // Get total tourists count
    $allTourists = $client->asService(
        'GET',
        '/rest/v1/tourists?select=profile_id'
    );
    $totalTourists = is_array($allTourists) ? count($allTourists) : 0;
    
    // =========================================================
    // 3. UC205: Citizen Reports
    // =========================================================
    $citizenValidatedData = $client->asService(
        'GET',
        '/rest/v1/incident_reports?select=id&status=eq.Validated'
    );
    $citizenValidated = is_array($citizenValidatedData) ? count($citizenValidatedData) : 0;
    
    $citizenRejectedData = $client->asService(
        'GET',
        '/rest/v1/incident_reports?select=id&status=eq.Rejected'
    );
    $citizenRejected = is_array($citizenRejectedData) ? count($citizenRejectedData) : 0;
    
    // Citizen Pending
    $citizenPending = $client->asService(
        'GET',
        '/rest/v1/incident_reports?select=id&status=in.(Pending%20Review,Under%20Investigation)'
    );
    $citizenReportsCount = is_array($citizenPending) ? count($citizenPending) : 0;
    
    // Total pending count
    $pendingCount = $touristApplicationsCount + $predictionsCount + $citizenReportsCount;
    
} catch (Throwable $e) {
    $pendingCount = 0;
    $loadError = 'Pending count is temporarily unavailable.';
    error_log('Dashboard stats error: ' . $e->getMessage());
}

render_admin_start(
    'Predictive Zoning Admin Dashboard',
    $admin,
    'dashboard'
);
?>

<style>
/* =========================================================
   DASHBOARD PAGE
========================================================= */
.dashboard-page {
    display: flex;
    flex-direction: column;
    gap: 28px;
}

/* =========================================================
   HEADER
========================================================= */
.dashboard-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 20px;
    flex-wrap: wrap;
}

.dashboard-header h1 {
    margin: 0;
    font-size: 26px;
    font-weight: 700;
    color: #1a1a2e;
}

.dashboard-header h1 i {
    color: #3b82f6;
}

.dashboard-header p {
    margin: 6px 0 0;
    opacity: .7;
    font-size: 14px;
    max-width: 600px;
}

/* =========================================================
   STATS ROW - 3 CARDS
========================================================= */
.stats-row {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 14px;
}

.stat-card {
    padding: 18px 20px;
    border-radius: 14px;
    background: white;
    box-shadow: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04);
    border: 1px solid #f1f3f5;
    transition: transform 0.2s, box-shadow 0.2s;
    display: flex;
    align-items: center;
    gap: 14px;
}

.stat-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 25px rgba(0,0,0,0.08);
}

.stat-card .stat-icon {
    width: 44px;
    height: 44px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 22px;
    flex-shrink: 0;
}

.stat-icon-blue { background: #dbeafe; }
.stat-icon-orange { background: #fef3c7; }
.stat-icon-green { background: #d1fae5; }

.stat-card .stat-info {
    flex: 1;
}

.stat-card .stat-info .stat-number {
    font-size: 24px;
    font-weight: 700;
    color: #1a1a2e;
    display: block;
    line-height: 1.2;
}

.stat-card .stat-info .stat-label {
    font-size: 12px;
    color: #6b7280;
    margin-top: 2px;
    display: block;
}

.stat-card .stat-info .stat-detail {
    font-size: 11px;
    color: #6b7280;
    margin-top: 2px;
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
}

.stat-card .stat-info .stat-detail span {
    display: inline-flex;
    align-items: center;
    gap: 4px;
}

.stat-dot {
    display: inline-block;
    width: 8px;
    height: 8px;
    border-radius: 50%;
}

.stat-dot-blue { background: #3b82f6; }
.stat-dot-orange { background: #f59e0b; }
.stat-dot-green { background: #10b981; }

/* =========================================================
   CARD GRID - 5 FUNCTIONS
========================================================= */
.card-grid {
    display: grid;
    grid-template-columns: repeat(5, 1fr);
    gap: 16px;
}

.metric-card {
    padding: 20px 18px;
    border-radius: 14px;
    background: white;
    box-shadow: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04);
    border: 1px solid #f1f3f5;
    text-decoration: none;
    color: #1a1a2e;
    transition: all 0.25s ease;
    text-align: center;
    cursor: pointer;
}

.metric-card:hover {
    transform: translateY(-4px);
    box-shadow: 0 12px 35px rgba(0,0,0,0.08);
    border-color: #d1d5db;
}

.metric-card .card-icon {
    width: 48px;
    height: 48px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;
    margin: 0 auto 10px auto;
}

.metric-card .card-content span {
    display: block;
    font-size: 11px;
    color: #6b7280;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.03em;
}

.metric-card .card-content strong {
    display: block;
    font-size: 15px;
    font-weight: 600;
    color: #1a1a2e;
    margin-top: 2px;
}

.metric-card .card-content small {
    display: block;
    font-size: 12px;
    color: #6b7280;
    margin-top: 2px;
}

/* =========================================================
   CHART SECTION - Doughnut + Bar Chart
========================================================= */
.chart-section {
    background: white;
    border-radius: 14px;
    border: 1px solid #f1f3f5;
    box-shadow: 0 1px 3px rgba(0,0,0,0.04);
    overflow: hidden;
}

.chart-header {
    padding: 16px 20px;
    border-bottom: 1px solid #f1f3f5;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 10px;
}

.chart-header h2 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: #1a1a2e;
}

.chart-header h2 i {
    color: #3b82f6;
}

.chart-header .chart-badge {
    font-size: 12px;
    color: #6b7280;
    background: #f8fafc;
    padding: 4px 12px;
    border-radius: 20px;
}

.chart-grid-3 {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 20px;
    padding: 20px 24px 24px 24px;
}

.chart-box {
    background: #ffffff;
    border-radius: 12px;
    padding: 16px 18px 20px 18px;
    border: 1px solid #f1f3f5;
}

.chart-box-title {
    font-size: 13px;
    font-weight: 600;
    color: #4b5563;
    margin-bottom: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    text-align: center;
}

.chart-box-title .badge-total {
    font-size: 10px;
    font-weight: 400;
    color: #6b7280;
    background: #f1f5f9;
    padding: 1px 8px;
    border-radius: 10px;
}

/* =========================================================
   CHART SPLIT - Doughnut (Left) + Bar Chart (Right)
========================================================= */
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

/* Doughnut Chart */
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
    font-size: 16px;
    font-weight: 700;
    color: #1a1a2e;
    display: block;
    line-height: 1.2;
}

.donut-center-text .total-label {
    font-size: 8px;
    color: #6b7280;
}

/* Bar Chart - Vertical */
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
    max-width: 40px;
}

.bar-item .bar {
    width: 100%;
    max-width: 28px;
    border-radius: 4px 4px 0 0;
    transition: height 0.8s ease;
    min-height: 4px;
}

.bar-item .bar-approved { background: #10b981; }
.bar-item .bar-rejected { background: #dc3545; }
.bar-item .bar-pending { background: #f59e0b; }

.bar-item .bar-value {
    font-size: 11px;
    font-weight: 700;
    color: #1a1a2e;
    margin-bottom: 2px;
}

.bar-item .bar-label {
    font-size: 8px;
    color: #6b7280;
    margin-top: 3px;
    font-weight: 500;
}

/* =========================================================
   STATS LABELS (Bottom)
========================================================= */
.chart-stats-simple {
    display: flex;
    justify-content: center;
    gap: 10px;
    margin-top: 10px;
    font-size: 10px;
    flex-wrap: wrap;
    padding-top: 8px;
    border-top: 1px solid #f1f3f5;
}

.chart-stats-simple .stat-item {
    display: flex;
    align-items: center;
    gap: 3px;
}

.chart-stats-simple .dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    display: inline-block;
}

.dot-approved { background: #10b981; }
.dot-rejected { background: #dc3545; }
.dot-pending { background: #f59e0b; }

.chart-stats-simple .stat-number {
    font-weight: 600;
    font-size: 12px;
    color: #1a1a2e;
}

.chart-stats-simple .stat-label {
    font-size: 9px;
    color: #6b7280;
}

/* =========================================================
   ALERTS
========================================================= */
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

/* =========================================================
   RESPONSIVE
========================================================= */
@media (max-width: 1024px) {
    .card-grid {
        grid-template-columns: repeat(3, 1fr);
    }
    .stats-row {
        grid-template-columns: repeat(3, 1fr);
    }
    .chart-grid-3 {
        grid-template-columns: repeat(2, 1fr);
    }
}

@media (max-width: 768px) {
    .dashboard-header {
        flex-direction: column;
        align-items: flex-start;
    }

    .card-grid {
        grid-template-columns: repeat(2, 1fr);
    }

    .stats-row {
        grid-template-columns: 1fr 1fr;
    }

    .stat-card {
        padding: 14px 16px;
    }

    .stat-card .stat-icon {
        width: 36px;
        height: 36px;
        font-size: 18px;
    }

    .stat-card .stat-info .stat-number {
        font-size: 20px;
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
}

@media (max-width: 480px) {
    .card-grid {
        grid-template-columns: 1fr;
    }

    .stats-row {
        grid-template-columns: 1fr;
    }

    .dashboard-header h1 {
        font-size: 22px;
    }

    .donut-wrapper {
        width: 70px;
        height: 70px;
    }

    .donut-center-text .total-number {
        font-size: 14px;
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
        font-size: 10px;
    }

    .bar-item .bar-label {
        font-size: 7px;
    }

    .chart-stats-simple {
        gap: 6px;
        font-size: 9px;
    }
}
</style>

<div class="dashboard-page">

    <!-- HEADER -->
    <section class="dashboard-header">
        <div>
            <h1><i class='bx bx-dashboard'></i> Predictive Zoning Admin Dashboard</h1>
            <p>
                Monitor risk zones, review predictive zoning,
                process tourist registrations, and review citizen reports.
            </p>
        </div>
    </section>

    <!-- ALERTS -->
    <?php if ($loadError !== null): ?>
        <div class="alert alert-error" role="alert">
            <i class='bx bx-error-circle'></i>
            <?= escape($loadError) ?>
        </div>
    <?php endif; ?>

    <!-- STATS ROW -->
    <section class="stats-row">
        <div class="stat-card">
            <div class="stat-icon stat-icon-blue"><i class='bx bx-map'></i></div>
            <div class="stat-info">
                <span class="stat-number"><?= $totalTourists ?></span>
                <span class="stat-label">Total Tourists</span>
                <div class="stat-detail">
                    <span><span class="stat-dot stat-dot-blue"></span> Registered</span>
                </div>
            </div>
        </div>
        <div class="stat-card">
            <div class="stat-icon stat-icon-orange"><i class='bx bx-time'></i></div>
            <div class="stat-info">
                <span class="stat-number"><?= $pendingCount ?></span>
                <span class="stat-label">Pending Applications</span>
                <div class="stat-detail">
                    <span><span class="stat-dot stat-dot-orange"></span> <?= $touristApplicationsCount ?> Tourist · <?= $predictionsCount ?> Zoning · <?= $citizenReportsCount ?> Reports</span>
                </div>
            </div>
        </div>
        <div class="stat-card">
            <div class="stat-icon stat-icon-green"><i class='bx bx-check-circle'></i></div>
            <div class="stat-info">
                <span class="stat-number"><?= $touristApplicationsCount ?></span>
                <span class="stat-label">Pending Tourists</span>
                <div class="stat-detail">
                    <span><span class="stat-dot stat-dot-green"></span> Awaiting approval</span>
                </div>
            </div>
        </div>
    </section>

    <!-- CARD GRID - 5 FUNCTIONS -->
    <section class="card-grid" aria-label="Dashboard functions">
        <a class="metric-card" href="risk_map.php">
            <div class="card-icon" style="background:#dbeafe;color:#2563eb;margin:0 auto 10px auto;">
                <i class='bx bx-map'></i>
            </div>
            <div class="card-content">
                <strong>View Risk Map</strong>
                <small>Interactive risk zones</small>
            </div>
        </a>
        <a class="metric-card" href="approve_zoning.php">
            <div class="card-icon" style="background:#d1fae5;color:#059669;margin:0 auto 10px auto;">
                <i class='bx bx-check-shield'></i>
            </div>
            <div class="card-content">
                <strong>Approve Zoning</strong>
                <small>Review predictions</small>
            </div>
        </a>
        <a class="metric-card" href="approve_tourist_report.php">
            <div class="card-icon" style="background:#fef3c7;color:#d97706;margin:0 auto 10px auto;">
                <i class='bx bx-user-plus'></i>
            </div>
            <div class="card-content">
                <strong>Tourist Registrations</strong>
                <small><?= $touristApplicationsCount ?> pending review</small>
            </div>
        </a>
        <a class="metric-card" href="approve_citizen_report.php">
            <div class="card-icon" style="background:#fde2e5;color:#dc2626;margin:0 auto 10px auto;">
                <i class='bx bx-flag'></i>
            </div>
            <div class="card-content">
                <strong>Citizen Reports</strong>
                <small>Review reports</small>
            </div>
        </a>
        <a class="metric-card" href="profile.php">
            <div class="card-icon" style="background:#e8eefc;color:#3b82f6;margin:0 auto 10px auto;">
                <i class='bx bx-user'></i>
            </div>
            <div class="card-content">
                <strong>Admin Profile</strong>
                <small>Update settings</small>
            </div>
        </a>
    </section>

    <!-- =========================================================
         CHART SECTION - Doughnut + Bar Chart (3 modules)
    ========================================================= -->
    <section class="chart-section">
        <div class="chart-header">
            <h2><i class='bx bx-stats'></i> Module Status Distribution</h2>
            <span class="chart-badge">3 modules · Doughnut + Bar</span>
        </div>
        <div class="chart-grid-3">

            <!-- =====================================================
                 Module 1: Approve Zoning
            ===================================================== -->
            <div class="chart-box">
                <div class="chart-box-title">
                    🤖 Approve Zoning
                    <span class="badge-total">Total: <?= $zoningApproved + $zoningRejected + $predictionsCount ?></span>
                </div>
                
                <div class="chart-split">
                    <div class="chart-split-left">
                        <div class="donut-wrapper">
                            <canvas id="zoningDonut"></canvas>
                            <div class="donut-center-text">
                                <span class="total-number"><?= $zoningApproved + $zoningRejected + $predictionsCount ?></span>
                                <span class="total-label">Total</span>
                            </div>
                        </div>
                    </div>
                    <div class="chart-split-right">
                        <div class="bar-chart-vertical">
                            <div class="bar-item">
                                <div class="bar-value"><?= $zoningApproved ?></div>
                                <div class="bar bar-approved" style="height: <?= max(10, ($zoningApproved + $zoningRejected + $predictionsCount) > 0 ? ($zoningApproved / max(1, $zoningApproved + $zoningRejected + $predictionsCount)) * 80 : 10) ?>px;"></div>
                                <div class="bar-label">✅</div>
                            </div>
                            <div class="bar-item">
                                <div class="bar-value"><?= $zoningRejected ?></div>
                                <div class="bar bar-rejected" style="height: <?= max(10, ($zoningApproved + $zoningRejected + $predictionsCount) > 0 ? ($zoningRejected / max(1, $zoningApproved + $zoningRejected + $predictionsCount)) * 80 : 10) ?>px;"></div>
                                <div class="bar-label">❌</div>
                            </div>
                            <div class="bar-item">
                                <div class="bar-value"><?= $predictionsCount ?></div>
                                <div class="bar bar-pending" style="height: <?= max(10, ($zoningApproved + $zoningRejected + $predictionsCount) > 0 ? ($predictionsCount / max(1, $zoningApproved + $zoningRejected + $predictionsCount)) * 80 : 10) ?>px;"></div>
                                <div class="bar-label">⏳</div>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="chart-stats-simple">
                    <span class="stat-item"><span class="dot dot-approved"></span><span class="stat-number"><?= $zoningApproved ?></span><span class="stat-label">Approved</span></span>
                    <span class="stat-item"><span class="dot dot-rejected"></span><span class="stat-number"><?= $zoningRejected ?></span><span class="stat-label">Rejected</span></span>
                    <span class="stat-item"><span class="dot dot-pending"></span><span class="stat-number"><?= $predictionsCount ?></span><span class="stat-label">Pending</span></span>
                </div>
            </div>

            <!-- =====================================================
                 Module 2: Approve Tourist
            ===================================================== -->
            <div class="chart-box">
                <div class="chart-box-title">
                    🛂 Approve Tourist
                    <span class="badge-total">Total: <?= $touristApproved + $touristRejected + $touristApplicationsCount ?></span>
                </div>
                
                <div class="chart-split">
                    <div class="chart-split-left">
                        <div class="donut-wrapper">
                            <canvas id="touristDonut"></canvas>
                            <div class="donut-center-text">
                                <span class="total-number"><?= $touristApproved + $touristRejected + $touristApplicationsCount ?></span>
                                <span class="total-label">Total</span>
                            </div>
                        </div>
                    </div>
                    <div class="chart-split-right">
                        <div class="bar-chart-vertical">
                            <div class="bar-item">
                                <div class="bar-value"><?= $touristApproved ?></div>
                                <div class="bar bar-approved" style="height: <?= max(10, ($touristApproved + $touristRejected + $touristApplicationsCount) > 0 ? ($touristApproved / max(1, $touristApproved + $touristRejected + $touristApplicationsCount)) * 80 : 10) ?>px;"></div>
                                <div class="bar-label">✅</div>
                            </div>
                            <div class="bar-item">
                                <div class="bar-value"><?= $touristRejected ?></div>
                                <div class="bar bar-rejected" style="height: <?= max(10, ($touristApproved + $touristRejected + $touristApplicationsCount) > 0 ? ($touristRejected / max(1, $touristApproved + $touristRejected + $touristApplicationsCount)) * 80 : 10) ?>px;"></div>
                                <div class="bar-label">❌</div>
                            </div>
                            <div class="bar-item">
                                <div class="bar-value"><?= $touristApplicationsCount ?></div>
                                <div class="bar bar-pending" style="height: <?= max(10, ($touristApproved + $touristRejected + $touristApplicationsCount) > 0 ? ($touristApplicationsCount / max(1, $touristApproved + $touristRejected + $touristApplicationsCount)) * 80 : 10) ?>px;"></div>
                                <div class="bar-label">⏳</div>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="chart-stats-simple">
                    <span class="stat-item"><span class="dot dot-approved"></span><span class="stat-number"><?= $touristApproved ?></span><span class="stat-label">Approved</span></span>
                    <span class="stat-item"><span class="dot dot-rejected"></span><span class="stat-number"><?= $touristRejected ?></span><span class="stat-label">Rejected</span></span>
                    <span class="stat-item"><span class="dot dot-pending"></span><span class="stat-number"><?= $touristApplicationsCount ?></span><span class="stat-label">Pending</span></span>
                </div>
            </div>

            <!-- =====================================================
                 Module 3: Approve Citizen Report
            ===================================================== -->
            <div class="chart-box">
                <div class="chart-box-title">
                    📋 Approve Citizen Report
                    <span class="badge-total">Total: <?= $citizenValidated + $citizenRejected + $citizenReportsCount ?></span>
                </div>
                
                <div class="chart-split">
                    <div class="chart-split-left">
                        <div class="donut-wrapper">
                            <canvas id="citizenDonut"></canvas>
                            <div class="donut-center-text">
                                <span class="total-number"><?= $citizenValidated + $citizenRejected + $citizenReportsCount ?></span>
                                <span class="total-label">Total</span>
                            </div>
                        </div>
                    </div>
                    <div class="chart-split-right">
                        <div class="bar-chart-vertical">
                            <div class="bar-item">
                                <div class="bar-value"><?= $citizenValidated ?></div>
                                <div class="bar bar-approved" style="height: <?= max(10, ($citizenValidated + $citizenRejected + $citizenReportsCount) > 0 ? ($citizenValidated / max(1, $citizenValidated + $citizenRejected + $citizenReportsCount)) * 80 : 10) ?>px;"></div>
                                <div class="bar-label">✅</div>
                            </div>
                            <div class="bar-item">
                                <div class="bar-value"><?= $citizenRejected ?></div>
                                <div class="bar bar-rejected" style="height: <?= max(10, ($citizenValidated + $citizenRejected + $citizenReportsCount) > 0 ? ($citizenRejected / max(1, $citizenValidated + $citizenRejected + $citizenReportsCount)) * 80 : 10) ?>px;"></div>
                                <div class="bar-label">❌</div>
                            </div>
                            <div class="bar-item">
                                <div class="bar-value"><?= $citizenReportsCount ?></div>
                                <div class="bar bar-pending" style="height: <?= max(10, ($citizenValidated + $citizenRejected + $citizenReportsCount) > 0 ? ($citizenReportsCount / max(1, $citizenValidated + $citizenRejected + $citizenReportsCount)) * 80 : 10) ?>px;"></div>
                                <div class="bar-label">⏳</div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Citizen report stats display -->
                <div class="chart-stats-simple">
                    <span class="stat-item">
                        <span class="dot dot-approved"></span>
                        <span class="stat-number"><?= $citizenValidated ?></span>
                        <span class="stat-label">Validated</span>
                    </span>
                    <span class="stat-item">
                        <span class="dot dot-rejected"></span>
                        <span class="stat-number"><?= $citizenRejected ?></span>
                        <span class="stat-label">Rejected</span>
                    </span>
                    <span class="stat-item">
                        <span class="dot dot-pending"></span>
                        <span class="stat-number"><?= $citizenReportsCount ?></span>
                        <span class="stat-label">Pending</span>
                    </span>
                </div>
            </div>

        </div>
    </section>

</div>

<!-- =========================================================
     Chart.js
========================================================= -->
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

<script>
document.addEventListener('DOMContentLoaded', function() {
    
    // =========================================================
    // 1. Zoning Doughnut Chart
    // =========================================================
    const zoningCtx = document.getElementById('zoningDonut');
    if (zoningCtx) {
        new Chart(zoningCtx, {
            type: 'doughnut',
            data: {
                labels: ['Approved', 'Rejected', 'Pending'],
                datasets: [{
                    data: [
                        <?= $zoningApproved ?>,
                        <?= $zoningRejected ?>,
                        <?= $predictionsCount ?>
                    ],
                    backgroundColor: ['#10b981', '#dc3545', '#f59e0b'],
                    borderWidth: 2,
                    borderColor: '#ffffff'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                cutout: '65%',
                plugins: {
                    legend: { display: false }
                }
            }
        });
    }

    // =========================================================
    // 2. Tourist Doughnut Chart
    // =========================================================
    const touristCtx = document.getElementById('touristDonut');
    if (touristCtx) {
        new Chart(touristCtx, {
            type: 'doughnut',
            data: {
                labels: ['Approved', 'Rejected', 'Pending'],
                datasets: [{
                    data: [
                        <?= $touristApproved ?>,
                        <?= $touristRejected ?>,
                        <?= $touristApplicationsCount ?>
                    ],
                    backgroundColor: ['#10b981', '#dc3545', '#f59e0b'],
                    borderWidth: 2,
                    borderColor: '#ffffff'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                cutout: '65%',
                plugins: {
                    legend: { display: false }
                }
            }
        });
    }

    // =========================================================
    // 3. Citizen Doughnut Chart
    // =========================================================
    const citizenCtx = document.getElementById('citizenDonut');
    if (citizenCtx) {
        new Chart(citizenCtx, {
            type: 'doughnut',
            data: {
                labels: ['Validated', 'Rejected', 'Pending'],
                datasets: [{
                    data: [
                        <?= $citizenValidated ?>,
                        <?= $citizenRejected ?>,
                        <?= $citizenReportsCount ?>
                    ],
                    backgroundColor: ['#10b981', '#dc3545', '#f59e0b'],
                    borderWidth: 2,
                    borderColor: '#ffffff'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                cutout: '65%',
                plugins: {
                    legend: { display: false }
                }
            }
        });
    }

});
</script>

<?php render_admin_end(); ?>
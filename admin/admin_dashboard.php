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
   DASHBOARD PAGE - MODERN DESIGN
========================================================= */
.dashboard-page {
    display: flex;
    flex-direction: column;
    gap: 28px;
    padding: 8px 0;
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
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    padding: 28px 32px;
    border-radius: 20px;
    color: white;
    box-shadow: 0 8px 32px rgba(102, 126, 234, 0.35);
}

.dashboard-header h1 {
    margin: 0;
    font-size: 26px;
    font-weight: 700;
    color: #fff;
}

.dashboard-header h1 i {
    color: #fff;
    opacity: 0.9;
}

.dashboard-header p {
    margin: 6px 0 0;
    opacity: 0.85;
    font-size: 14px;
    max-width: 600px;
    color: #fff;
}

.dashboard-header .header-badge {
    background: rgba(255,255,255,0.2);
    backdrop-filter: blur(10px);
    padding: 8px 20px;
    border-radius: 30px;
    font-size: 13px;
    color: #fff;
    border: 1px solid rgba(255,255,255,0.15);
}

/* =========================================================
   CARD GRID - 5 FUNCTIONS
========================================================= */
.card-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 16px;
}

.metric-card {
    padding: 22px 18px;
    border-radius: 16px;
    background: white;
    box-shadow: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04);
    border: 1px solid #f1f3f5;
    text-decoration: none;
    color: #1a1a2e;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    text-align: center;
    cursor: pointer;
    position: relative;
    overflow: hidden;
}

.metric-card::after {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 3px;
    background: linear-gradient(90deg, #667eea, #764ba2);
    opacity: 0;
    transition: opacity 0.3s ease;
}

.metric-card:hover {
    transform: translateY(-6px);
    box-shadow: 0 16px 48px rgba(0,0,0,0.10);
    border-color: #d1d5db;
}

.metric-card:hover::after {
    opacity: 1;
}

.metric-card .card-icon {
    width: 52px;
    height: 52px;
    border-radius: 14px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;
    margin: 0 auto 12px auto;
    transition: transform 0.3s ease;
}

.metric-card:hover .card-icon {
    transform: scale(1.08);
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
    margin-top: 4px;
}

/* =========================================================
   CHART SECTION
========================================================= */
.chart-section {
    background: white;
    border-radius: 16px;
    border: 1px solid #f1f3f5;
    box-shadow: 0 1px 3px rgba(0,0,0,0.04);
    overflow: hidden;
}

.chart-header {
    padding: 18px 24px;
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
    font-size: 16px;
    font-weight: 600;
    color: #1a1a2e;
}

.chart-header h2 i {
    color: #667eea;
}

.chart-header .chart-badge {
    font-size: 12px;
    color: #6b7280;
    background: #f1f5f9;
    padding: 4px 14px;
    border-radius: 20px;
}

.chart-grid-3 {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 20px;
    padding: 24px;
}

/* =========================================================
   CHART BOX - MODERN
========================================================= */
.chart-box {
    background: #ffffff;
    border-radius: 14px;
    padding: 18px 20px 22px;
    border: 1px solid #f1f3f5;
    transition: box-shadow 0.3s ease;
}

.chart-box:hover {
    box-shadow: 0 4px 20px rgba(0,0,0,0.04);
}

.chart-box-title {
    font-size: 13px;
    font-weight: 600;
    color: #1a1a2e;
    margin-bottom: 14px;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    text-align: center;
}

.chart-box-title .badge-total {
    font-size: 10px;
    font-weight: 400;
    color: #6b7280;
    background: #f1f5f9;
    padding: 2px 10px;
    border-radius: 12px;
}

/* =========================================================
   CHART SPLIT
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
    max-width: 40px;
}

.bar-item .bar {
    width: 100%;
    max-width: 28px;
    border-radius: 6px 6px 0 0;
    transition: height 0.8s cubic-bezier(0.4, 0, 0.2, 1);
    min-height: 4px;
}

.bar-item .bar-approved { background: linear-gradient(180deg, #34d399, #10b981); }
.bar-item .bar-rejected { background: linear-gradient(180deg, #f87171, #dc3545); }
.bar-item .bar-pending { background: linear-gradient(180deg, #fbbf24, #f59e0b); }

.bar-item .bar-value {
    font-size: 11px;
    font-weight: 700;
    color: #1a1a2e;
    margin-bottom: 2px;
}

.bar-item .bar-label {
    font-size: 8px;
    color: #6b7280;
    margin-top: 4px;
    font-weight: 500;
}

/* =========================================================
   STATS LABELS
========================================================= */
.chart-stats-simple {
    display: flex;
    justify-content: center;
    gap: 12px;
    margin-top: 12px;
    font-size: 10px;
    flex-wrap: wrap;
    padding-top: 10px;
    border-top: 1px solid #f1f3f5;
}

.chart-stats-simple .stat-item {
    display: flex;
    align-items: center;
    gap: 4px;
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
        grid-template-columns: repeat(2, 1fr);
    }
    .chart-grid-3 {
        grid-template-columns: repeat(2, 1fr);
    }
}

@media (max-width: 768px) {
    .dashboard-header {
        flex-direction: column;
        align-items: flex-start;
        padding: 20px 24px;
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
}

@media (max-width: 480px) {
    .card-grid {
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
            <h1><i class='bx bx-grid-alt'></i> Dashboard</h1>
            <p>
                Monitor risk zones, review predictive zoning,
                process tourist registrations, and review citizen reports.
            </p>
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

    <!-- CARD GRID - 4 FUNCTIONS -->
    <section class="card-grid" aria-label="Dashboard functions">
        <a class="metric-card" href="risk_map.php">
            <div class="card-icon" style="background:#dbeafe;color:#2563eb;">
                <i class='bx bx-map'></i>
            </div>
            <div class="card-content">
                <strong>View Risk Map</strong>
                <small>Interactive risk zones</small>
            </div>
        </a>
        <a class="metric-card" href="approve_zoning.php">
            <div class="card-icon" style="background:#d1fae5;color:#059669;">
                <i class='bx bx-check-shield'></i>
            </div>
            <div class="card-content">
                <strong>Approve Zoning</strong>
                <small>Review predictions</small>
            </div>
        </a>
        <a class="metric-card" href="approve_tourist_report.php">
            <div class="card-icon" style="background:#fef3c7;color:#d97706;">
                <i class='bx bx-user-plus'></i>
            </div>
            <div class="card-content">
                <strong>Tourist Registrations</strong>
                <small><?= $touristApplicationsCount ?> pending review</small>
            </div>
        </a>
        <a class="metric-card" href="approve_citizen_report.php">
            <div class="card-icon" style="background:#fde2e5;color:#dc2626;">
                <i class='bx bx-flag'></i>
            </div>
            <div class="card-content">
                <strong>Citizen Reports</strong>
                <small>Review reports</small>
            </div>
        </a>
    </section>

    <!-- =========================================================
         CHART SECTION - Doughnut + Bar Chart (3 modules)
    ========================================================= -->
    <section class="chart-section">
        <div class="chart-header">
            <h2><i class='bx bx-stats'></i> Module Status Distribution</h2>
            <span class="chart-badge">Real-time data</span>
        </div>
        <div class="chart-grid-3">

            <!-- Module 1: Approve Zoning -->
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

            <!-- Module 2: Approve Tourist -->
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

            <!-- Module 3: Approve Citizen Report -->
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
                <div class="chart-stats-simple">
                    <span class="stat-item"><span class="dot dot-approved"></span><span class="stat-number"><?= $citizenValidated ?></span><span class="stat-label">Validated</span></span>
                    <span class="stat-item"><span class="dot dot-rejected"></span><span class="stat-number"><?= $citizenRejected ?></span><span class="stat-label">Rejected</span></span>
                    <span class="stat-item"><span class="dot dot-pending"></span><span class="stat-number"><?= $citizenReportsCount ?></span><span class="stat-label">Pending</span></span>
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
    
    // Zoning Doughnut
    const zoningCtx = document.getElementById('zoningDonut');
    if (zoningCtx) {
        new Chart(zoningCtx, {
            type: 'doughnut',
            data: {
                labels: ['Approved', 'Rejected', 'Pending'],
                datasets: [{
                    data: [<?= $zoningApproved ?>, <?= $zoningRejected ?>, <?= $predictionsCount ?>],
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

    // Tourist Doughnut
    const touristCtx = document.getElementById('touristDonut');
    if (touristCtx) {
        new Chart(touristCtx, {
            type: 'doughnut',
            data: {
                labels: ['Approved', 'Rejected', 'Pending'],
                datasets: [{
                    data: [<?= $touristApproved ?>, <?= $touristRejected ?>, <?= $touristApplicationsCount ?>],
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

    // Citizen Doughnut
    const citizenCtx = document.getElementById('citizenDonut');
    if (citizenCtx) {
        new Chart(citizenCtx, {
            type: 'doughnut',
            data: {
                labels: ['Validated', 'Rejected', 'Pending'],
                datasets: [{
                    data: [<?= $citizenValidated ?>, <?= $citizenRejected ?>, <?= $citizenReportsCount ?>],
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
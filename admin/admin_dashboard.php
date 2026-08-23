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
    // 4. Citizen Reports
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
    background: #f1f3f5;
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
    background: rgba(0,0,0,0.06);
    padding: 8px 20px;
    border-radius: 30px;
    font-size: 14px;
    color: #4b5563;
    border: none;
}

/* Card Grid */
.card-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
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

.chart-grid-2 {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
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
    gap: 20px;
    margin-top: 14px;
    font-size: 12px;
    flex-wrap: wrap;
    padding-top: 12px;
    border-top: 1px solid #f1f3f5;
}

.chart-stats-simple .stat-item {
    display: flex;
    align-items: center;
    gap: 5px;
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

/* Registration breakdown */
.registration-breakdown {
    display: flex;
    justify-content: center;
    gap: 24px;
    margin-top: 10px;
    font-size: 13px;
    flex-wrap: wrap;
}

.registration-breakdown .breakdown-item {
    display: flex;
    align-items: center;
    gap: 4px;
    color: #4b5563;
}

.registration-breakdown .breakdown-item .badge {
    padding: 2px 10px;
    border-radius: 10px;
    font-size: 11px;
    font-weight: 600;
}

.badge-tourist {
    background: #dbeafe;
    color: #1e40af;
}

.badge-citizen {
    background: #ede9fe;
    color: #5b21b6;
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
    .chart-grid-2 {
        grid-template-columns: repeat(2, 1fr);
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

    .chart-grid-2 {
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
    
    .registration-breakdown {
        gap: 12px;
        font-size: 11px;
    }
    
    .chart-box-header {
        flex-direction: column;
        align-items: flex-start;
        gap: 4px;
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

    <!-- CARD GRID -->
    <section class="card-grid">
        <a class="metric-card" href="risk_map.php">
            <div class="card-icon" style="background:#dbeafe;color:#2563eb;">
                <i class='bx bx-map'></i>
            </div>
            <div class="card-content">
                <strong>View Risk Map</strong>
            </div>
        </a>
        <a class="metric-card" href="approve_registration.php">
            <div class="card-icon" style="background:#fef3c7;color:#d97706;">
                <i class='bx bx-user-plus'></i>
            </div>
            <div class="card-content">
                <strong>Approve Registration</strong>
            </div>
        </a>
        <a class="metric-card" href="approve_citizen_report.php">
            <div class="card-icon" style="background:#fde2e5;color:#dc2626;">
                <i class='bx bx-flag'></i>
            </div>
            <div class="card-content">
                <strong>Citizen Reports</strong>
            </div>
        </a>
    </section>

    <!-- CHART SECTION -->
    <section class="chart-section">
        <div class="chart-header">
            <h2><i class='bx bx-stats'></i> Module Status Distribution</h2>
        </div>
        <div class="chart-grid-2">

            <!-- Module 1: Approve Registration -->
            <div class="chart-box">
                <div class="chart-box-header">
                    <div class="chart-box-title">
                        Approve Registration
                        <span class="badge-total">Total: <?= $registrationApproved + $registrationRejected + $registrationPending ?></span>
                    </div>
                </div>
                <div class="chart-split">
                    <div class="chart-split-left">
                        <div class="donut-wrapper">
                            <canvas id="registrationDonut"></canvas>
                            <div class="donut-center-text">
                                <span class="total-number"><?= $registrationApproved + $registrationRejected + $registrationPending ?></span>
                                <span class="total-label">Total</span>
                            </div>
                        </div>
                    </div>
                    <div class="chart-split-right">
                        <div class="bar-chart-vertical">
                            <div class="bar-item">
                                <div class="bar-value"><?= $registrationApproved ?></div>
                                <div class="bar bar-approved" style="height: <?= max(10, ($registrationApproved + $registrationRejected + $registrationPending) > 0 ? ($registrationApproved / max(1, $registrationApproved + $registrationRejected + $registrationPending)) * 70 : 10) ?>px;"></div>
                                <div class="bar-label">Approved</div>
                            </div>
                            <div class="bar-item">
                                <div class="bar-value"><?= $registrationRejected ?></div>
                                <div class="bar bar-rejected" style="height: <?= max(10, ($registrationApproved + $registrationRejected + $registrationPending) > 0 ? ($registrationRejected / max(1, $registrationApproved + $registrationRejected + $registrationPending)) * 70 : 10) ?>px;"></div>
                                <div class="bar-label">Rejected</div>
                            </div>
                            <div class="bar-item">
                                <div class="bar-value"><?= $registrationPending ?></div>
                                <div class="bar bar-pending" style="height: <?= max(10, ($registrationApproved + $registrationRejected + $registrationPending) > 0 ? ($registrationPending / max(1, $registrationApproved + $registrationRejected + $registrationPending)) * 70 : 10) ?>px;"></div>
                                <div class="bar-label">Pending</div>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="registration-breakdown">
                    <span class="breakdown-item">
                        Tourist:
                        <span class="badge badge-tourist"><?= $touristApproved ?> Approved</span>
                        <span class="badge badge-tourist"><?= $touristRejected ?> Rejected</span>
                        <span class="badge badge-tourist"><?= $touristPending ?> Pending</span>
                    </span>
                    <span class="breakdown-item">
                        Citizen:
                        <span class="badge badge-citizen"><?= $citizenApproved ?> Approved</span>
                        <span class="badge badge-citizen"><?= $citizenRejected ?> Rejected</span>
                        <span class="badge badge-citizen"><?= $citizenPending ?> Pending</span>
                    </span>
                </div>
                
                <div class="chart-stats-simple">
                    <span class="stat-item"><span class="dot dot-approved"></span><span class="stat-number"><?= $registrationApproved ?></span><span class="stat-label">Approved</span></span>
                    <span class="stat-item"><span class="dot dot-rejected"></span><span class="stat-number"><?= $registrationRejected ?></span><span class="stat-label">Rejected</span></span>
                    <span class="stat-item"><span class="dot dot-pending"></span><span class="stat-number"><?= $registrationPending ?></span><span class="stat-label">Pending</span></span>
                </div>
            </div>

            <!-- Module 2: Citizen Reports -->
            <div class="chart-box">
                <div class="chart-box-header">
                    <div class="chart-box-title">
                        Citizen Reports
                        <span class="badge-total">Total: <?= $citizenValidated + $citizenRejectedReports + $citizenReportsCount ?></span>
                    </div>
                </div>
                <div class="chart-split">
                    <div class="chart-split-left">
                        <div class="donut-wrapper">
                            <canvas id="citizenDonut"></canvas>
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

    // Registration Doughnut
    const registrationCtx = document.getElementById('registrationDonut');
    if (registrationCtx) {
        new Chart(registrationCtx, {
            type: 'doughnut',
            data: {
                labels: ['Approved', 'Rejected', 'Pending'],
                datasets: [{
                    data: [<?= $registrationApproved ?>, <?= $registrationRejected ?>, <?= $registrationPending ?>],
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
<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/admin_guard.php';
require_once __DIR__ . '/includes/layout.php';
require_once __DIR__ . '/services/application_service.php';

$admin = require_admin();

$loadError = null;

// Create SupabaseClient instance directly
$client = new SupabaseClient();

// Get Supabase URL
$supabaseUrl = rtrim(getenv('SUPABASE_URL') ?: '', '/');
if (empty($supabaseUrl)) {
    $supabaseUrl = 'https://kfvhnpkkwxipschhlouk.supabase.co';
}

/*
|--------------------------------------------------------------------------
| FR2.3: Date Filtering
|--------------------------------------------------------------------------
*/
$startDate = trim((string)($_GET['start_date'] ?? ''));
$endDate   = trim((string)($_GET['end_date'] ?? ''));

/*
|--------------------------------------------------------------------------
| FR2.4: Severity Filtering (Risk Level)
|--------------------------------------------------------------------------
*/
$severityFilter = trim((string)($_GET['severity'] ?? ''));

/*
|--------------------------------------------------------------------------
| FR2.5: Region Filtering
|--------------------------------------------------------------------------
*/
$regionFilter = trim((string)($_GET['region'] ?? ''));

/*
|--------------------------------------------------------------------------
| FR2.2: Sort By
|--------------------------------------------------------------------------
*/
$sortBy = trim((string)($_GET['sort_by'] ?? 'created_desc'));

/*
|--------------------------------------------------------------------------
| FR2.6: Analytical Metrics Generation
|--------------------------------------------------------------------------
*/
$metrics = [
    'total_reports' => 0,
    'red_zones' => 0,
    'orange_zones' => 0,
    'green_zones' => 0,
    'high_risk_reports' => 0,
    'medium_risk_reports' => 0,
    'low_risk_reports' => 0,
    'red_percentage' => 0,
    'orange_percentage' => 0,
    'green_percentage' => 0,
];

/*
|--------------------------------------------------------------------------
| KL Bounds - Show only Kuala Lumpur area
|--------------------------------------------------------------------------
*/
define('KL_SOUTH', 3.02);
define('KL_NORTH', 3.28);
define('KL_WEST', 101.58);
define('KL_EAST', 101.78);

/*
|--------------------------------------------------------------------------
| FR2.1: Load Incident Reports for Risk Map
|--------------------------------------------------------------------------
*/
$reports = [];
$zones = [];
$validatedReports = [];

try {
    // Get all reports
    $query = '/rest/v1/incident_reports?select=*&order=created_at.desc';
    
    // FR2.3: Date Filtering
    if ($startDate !== '') {
        $query .= '&incident_date=gte.' . rawurlencode($startDate);
    }
    if ($endDate !== '') {
        $query .= '&incident_date=lte.' . rawurlencode($endDate);
    }
    
    $allReports = $client->asService('GET', $query);
    
    if (!is_array($allReports)) {
        $allReports = [];
    }
    
    // Filter Validated in PHP (case-insensitive, handle spaces)
    $reports = array_values(
        array_filter(
            $allReports,
            static function (array $report): bool {
                $status = strtolower(trim($report['status'] ?? ''));
                return $status === 'validated';
            }
        )
    );
    
    // Save all validated reports for table display
    $validatedReports = $reports;
    
    // Only keep reports with coordinates within map bounds (for map display)
    $reportsForMap = array_filter(
        $reports,
        static function (array $report): bool {
            $lat = (float)($report['latitude'] ?? 0);
            $lng = (float)($report['longitude'] ?? 0);
            if ($lat === 0.0 && $lng === 0.0) return false;
            return $lat >= KL_SOUTH && $lat <= KL_NORTH &&
                   $lng >= KL_WEST && $lng <= KL_EAST;
        }
    );
    
    // 地图使用过滤后的数据
    $reports = array_values($reportsForMap);
    
    // FR2.5: Region Filtering - filter by region name (map data only)
    if ($regionFilter !== '') {
        $search = mb_strtolower($regionFilter);
        $reports = array_values(
            array_filter(
                $reports,
                static function (array $report) use ($search): bool {
                    $location = mb_strtolower((string)($report['location'] ?? ''));
                    $address = mb_strtolower((string)($report['address'] ?? ''));
                    return str_contains($location, $search) || str_contains($address, $search);
                }
            )
        );
    }
    
    // Group by coordinates for map display
    $locationGroups = [];
    foreach ($reports as $report) {
        $lat = (float)($report['latitude'] ?? 0);
        $lng = (float)($report['longitude'] ?? 0);
        $key = $lat . ',' . $lng;
        
        if (!isset($locationGroups[$key])) {
            $locationGroups[$key] = [
                'lat' => $lat,
                'lng' => $lng,
                'reports' => [],
                'count' => 0
            ];
        }
        $locationGroups[$key]['reports'][] = $report;
        $locationGroups[$key]['count']++;
    }
    
    // Calculate risk level for each location
    foreach ($locationGroups as $group) {
        $count = $group['count'];
        $lat = $group['lat'];
        $lng = $group['lng'];
        
        if ($count >= 10) {
            $riskLevel = 'Red';
            $metrics['red_zones']++;
            $metrics['high_risk_reports'] += $count;
        } elseif ($count >= 5) {
            $riskLevel = 'Orange';
            $metrics['orange_zones']++;
            $metrics['medium_risk_reports'] += $count;
        } else {
            $riskLevel = 'Green';
            $metrics['green_zones']++;
            $metrics['low_risk_reports'] += $count;
        }
        
        $metrics['total_reports'] += $count;
        
        $firstReport = $group['reports'][0];
        
        $zones[] = [
            'id' => $firstReport['id'] ?? '',
            'name' => $firstReport['location'] ?? 'Unknown Location',
            'lat' => $lat,
            'lng' => $lng,
            'risk' => $riskLevel,
            'count' => $count,
            'category' => $firstReport['category'] ?? 'N/A',
            'status' => $firstReport['status'] ?? 'Validated',
            'description' => $firstReport['description'] ?? '',
            'ticket_id' => $firstReport['ticket_id'] ?? 'N/A',
            'created_at' => $firstReport['created_at'] ?? '',
            'reports' => $group['reports'],
        ];
    }
    
    // FR2.4: Severity Filtering - filter by risk level
    if ($severityFilter !== '') {
        $zones = array_values(
            array_filter(
                $zones,
                static function (array $zone) use ($severityFilter): bool {
                    return $zone['risk'] === $severityFilter;
                }
            )
        );
        // Also filter validatedReports (table data)
        $validatedReports = array_values(
            array_filter(
                $validatedReports,
                function ($report) use ($severityFilter) {
                    $urgency = $report['urgency_level'] ?? 'Normal';
                    $riskMap = ['High' => 'Red', 'Medium' => 'Orange', 'Normal' => 'Green'];
                    $riskLevel = $riskMap[$urgency] ?? 'Green';
                    return $riskLevel === $severityFilter;
                }
            )
        );
    }
    
    // Sort validatedReports (table data)
    usort($validatedReports, function ($a, $b) use ($sortBy) {
        switch ($sortBy) {
            case 'created_desc':
                return strtotime($b['created_at'] ?? '') - strtotime($a['created_at'] ?? '');
            case 'created_asc':
                return strtotime($a['created_at'] ?? '') - strtotime($b['created_at'] ?? '');
            default:
                return strtotime($b['created_at'] ?? '') - strtotime($a['created_at'] ?? '');
        }
    });
    
    // Calculate zone percentages
    $total = $metrics['total_reports'];
    if ($total > 0) {
        $metrics['red_percentage'] = round(($metrics['red_zones'] / $total) * 100, 1);
        $metrics['orange_percentage'] = round(($metrics['orange_zones'] / $total) * 100, 1);
        $metrics['green_percentage'] = round(($metrics['green_zones'] / $total) * 100, 1);
    }
    
} catch (Throwable $e) {
    $loadError = 'Unable to load risk map data. Please refresh the page or try again later.';
    error_log('Load risk map error: ' . $e->getMessage());
}

render_admin_start('View Risk Map', $admin, 'dashboard');

?>

<!--  Chart.js -->
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

<style>
/* =========================================================
   BASE
========================================================= */
.risk-map-page {
    display: flex;
    flex-direction: column;
    gap: 24px;
}

/* =========================================================
   HEADER
========================================================= */
.risk-map-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 20px;
    flex-wrap: wrap;
}

.risk-map-header h1 {
    margin: 0;
    font-size: 24px;
    font-weight: 700;
    color: #1a1a2e;
}

.risk-map-header h1 i {
    color: #3b82f6;
}

.risk-map-header .subtitle {
    display: flex;
    align-items: center;
    gap: 12px;
    margin: 4px 0 0;
    flex-wrap: wrap;
}

.risk-map-header .subtitle p {
    margin: 0;
    opacity: .7;
    font-size: 14px;
}

.risk-map-header .badge-validated {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 2px 12px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 600;
    background: #d1fae5;
    color: #065f46;
}

/* =========================================================
   STATS CARDS - MODERN
========================================================= */
.stats-grid {
    display: grid;
    grid-template-columns: repeat(6, 1fr);
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

.stat-card .stat-percent {
    font-size: 11px;
    opacity: .5;
    margin-top: 2px;
    display: block;
}

.stat-card .stat-icon {
    font-size: 20px;
    display: block;
    margin-bottom: 4px;
}

.stat-total .stat-number { color: #1a1a2e; }
.stat-red .stat-number { color: #dc3545; }
.stat-orange .stat-number { color: #fd7e14; }
.stat-green .stat-number { color: #28a745; }
.stat-high .stat-number { color: #dc3545; }
.stat-low .stat-number { color: #28a745; }

/* =========================================================
   FILTER BAR - MODERN
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

.filter-btn.active-red {
    background: #dc3545;
    color: white;
    border-color: #dc3545;
}

.filter-btn.active-red:hover { background: #c82333; }

.filter-btn.active-orange {
    background: #fd7e14;
    color: white;
    border-color: #fd7e14;
}

.filter-btn.active-orange:hover { background: #e06b0a; }

.filter-btn.active-green {
    background: #28a745;
    color: white;
    border-color: #28a745;
}

.filter-btn.active-green:hover { background: #1e7e34; }

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

.btn-filter-primary:hover { background: #2d2d4e; }

.btn-filter-outline {
    background: white;
    color: #4b5563;
    border: 1px solid #e5e7eb;
}

.btn-filter-outline:hover { background: #f3f4f6; }

.btn-filter-pdf {
    background: #dc3545;
    color: white;
}

.btn-filter-pdf:hover { background: #c82333; }

/* =========================================================
   MAP
========================================================= */
.map-card {
    overflow: hidden;
    border-radius: 16px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04);
    border: 1px solid #f1f3f5;
    background: white;
}

.map-card-header {
    padding: 14px 20px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 10px;
    border-bottom: 1px solid #f1f3f5;
}

.map-card-header h2 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: #1a1a2e;
}

#riskMap {
    width: 100%;
    height: 460px;
    min-height: 380px;
    background: #e8ecf1;
}

/* =========================================================
   LEGEND - MODERN
========================================================= */
.map-legend {
    display: flex;
    gap: 16px;
    flex-wrap: wrap;
    align-items: center;
}

.legend-item {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 12px;
    color: #4b5563;
}

.legend-dot {
    width: 12px;
    height: 12px;
    border-radius: 50%;
    display: inline-block;
    flex-shrink: 0;
}

.legend-dot-red { background: #dc3545; }
.legend-dot-orange { background: #fd7e14; }
.legend-dot-green { background: #28a745; }

.legend-badge {
    font-size: 11px;
    padding: 2px 10px;
    border-radius: 12px;
    background: #f1f5f9;
    color: #6b7280;
}

/* =========================================================
   DATA SECTION
========================================================= */
.data-section {
    background: white;
    border-radius: 16px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04);
    border: 1px solid #f1f3f5;
    overflow: hidden;
}

.data-section-header {
    padding: 14px 20px;
    border-bottom: 1px solid #f1f3f5;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 10px;
}

.data-section-header h3 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: #1a1a2e;
}

.data-section-header .count-badge {
    background: #f1f5f9;
    padding: 4px 14px;
    border-radius: 20px;
    font-size: 12px;
    color: #4b5563;
    font-weight: 500;
}

/* =========================================================
   CHART + STATS
========================================================= */
.chart-stats-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 24px;
    padding: 20px 24px;
    background: #fafbfc;
}

.chart-container {
    position: relative;
    height: 200px;
    max-width: 280px;
    margin: 0 auto;
}

.chart-stats-right {
    display: flex;
    flex-direction: column;
    justify-content: center;
    gap: 10px;
}

.chart-stat-item {
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 10px 14px;
    background: white;
    border-radius: 10px;
    border: 1px solid #f1f3f5;
    transition: border-color 0.2s;
}

.chart-stat-item:hover {
    border-color: #d1d5db;
}

.chart-stat-item .color-dot {
    width: 14px;
    height: 14px;
    border-radius: 50%;
    flex-shrink: 0;
}

.chart-stat-item .color-dot-red { background: #dc3545; }
.chart-stat-item .color-dot-orange { background: #fd7e14; }
.chart-stat-item .color-dot-green { background: #28a745; }

.chart-stat-item .stat-info {
    flex: 1;
}

.chart-stat-item .stat-info .label {
    font-size: 12px;
    color: #6b7280;
    font-weight: 500;
}

.chart-stat-item .stat-info .value {
    font-weight: 600;
    font-size: 14px;
    color: #1a1a2e;
}

/* =========================================================
   TABLE - MODERN
========================================================= */
.table-wrapper {
    overflow-x: auto;
    padding: 0 20px 20px 20px;
}

.data-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
}

.data-table thead th {
    padding: 12px 14px;
    text-align: left;
    font-weight: 600;
    color: #4b5563;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    border-bottom: 2px solid #e5e7eb;
}

.data-table tbody td {
    padding: 12px 14px;
    border-bottom: 1px solid #f1f3f5;
    vertical-align: middle;
}

.data-table tbody tr {
    transition: background 0.15s;
}

.data-table tbody tr:hover {
    background: #f8fafc;
}

.data-table tbody tr:last-child td {
    border-bottom: none;
}

.risk-tag {
    display: inline-block;
    padding: 2px 12px;
    border-radius: 12px;
    font-size: 11px;
    font-weight: 600;
}

.risk-tag-red { background: #fde2e5; color: #b42332; }
.risk-tag-orange { background: #fff0df; color: #b95f00; }
.risk-tag-green { background: #def7e8; color: #147a43; }

.status-tag-validated { 
    display: inline-block;
    padding: 2px 12px;
    border-radius: 12px;
    font-size: 11px;
    font-weight: 500;
    background: #d1fae5;
    color: #065f46;
}

/* =========================================================
   MAP OVERLAY
========================================================= */
.map-overlay {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    background: rgba(255,255,255,0.92);
    padding: 24px 36px;
    border-radius: 16px;
    box-shadow: 0 8px 30px rgba(0,0,0,0.12);
    z-index: 1000;
    text-align: center;
    max-width: 380px;
    backdrop-filter: blur(4px);
    pointer-events: none;
}

.map-overlay i {
    font-size: 44px;
    color: #6b7280;
    display: block;
    margin-bottom: 10px;
}

.map-overlay h3 {
    margin: 0 0 4px 0;
    font-size: 18px;
    color: #1a1a2e;
}

.map-overlay p {
    margin: 0;
    color: #6b7280;
    font-size: 14px;
}

/* =========================================================
   ALERTS
========================================================= */
.risk-alert {
    padding: 14px 18px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    gap: 10px;
}

.risk-alert i {
    font-size: 20px;
}

.risk-error {
    background: #fee2e2;
    color: #991b1b;
}

/* =========================================================
   RESPONSIVE
========================================================= */
@media (max-width: 1024px) {
    .stats-grid {
        grid-template-columns: repeat(3, 1fr);
    }
}

@media (max-width: 768px) {
    .stats-grid {
        grid-template-columns: repeat(2, 1fr);
    }
    
    .filter-bar {
        flex-direction: column;
        align-items: stretch;
        gap: 10px;
    }
    
    .filter-group {
        justify-content: center;
    }
    
    .filter-actions {
        justify-content: center;
    }
    
    #riskMap {
        height: 320px;
        min-height: 280px;
    }

    .chart-stats-grid {
        grid-template-columns: 1fr;
        gap: 16px;
        padding: 16px;
    }

    .chart-container {
        height: 160px;
        max-width: 200px;
    }

    .data-table {
        font-size: 12px;
    }

    .data-table thead th,
    .data-table tbody td {
        padding: 8px 10px;
    }

    .map-card-header {
        flex-direction: column;
        align-items: flex-start;
        gap: 8px;
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
    
    #riskMap {
        height: 260px;
        min-height: 220px;
    }

    .chart-container {
        height: 130px;
        max-width: 160px;
    }

    .map-overlay {
        padding: 16px 20px;
        max-width: 90%;
    }

    .map-overlay i {
        font-size: 32px;
    }

    .data-section-header {
        flex-direction: column;
        align-items: flex-start;
        gap: 6px;
    }

    .table-wrapper {
        padding: 0 12px 12px 12px;
    }

    .filter-input {
        font-size: 11px;
        padding: 4px 8px;
    }

    .filter-btn {
        font-size: 11px;
        padding: 3px 12px;
    }
}
</style>

<div class="risk-map-page">

    <!-- HEADER -->
    <section class="risk-map-header">
        <div>
            <h1><i class='bx bx-map'></i> Predictive Risk Map</h1>
            <div class="subtitle">
                <p>View and analyse current risk zones in <strong>Kuala Lumpur, Malaysia</strong></p>
                <span class="badge-validated">✅ Validated Only</span>
            </div>
        </div>
        <a href="admin_dashboard.php" class="btn-filter btn-filter-outline">
            <i class='bx bx-arrow-back'></i> Dashboard
        </a>
    </section>

    <!-- ALERTS -->
    <?php if ($loadError !== null): ?>
        <div class="risk-alert risk-error" role="alert">
            <i class='bx bx-error-circle'></i>
            <?= htmlspecialchars($loadError, ENT_QUOTES, 'UTF-8') ?>
        </div>
    <?php endif; ?>

    <!-- STATS CARDS -->
    <section class="stats-grid">
        <div class="stat-card stat-total">
            <span class="stat-icon">📋</span>
            <span class="stat-number"><?= $metrics['total_reports'] ?></span>
            <span class="stat-label">Validated Reports</span>
        </div>
        <div class="stat-card stat-red">
            <span class="stat-icon">🔴</span>
            <span class="stat-number"><?= $metrics['red_zones'] ?></span>
            <span class="stat-label">Red Zones</span>
            <span class="stat-percent"><?= $metrics['red_percentage'] ?>% of total</span>
        </div>
        <div class="stat-card stat-orange">
            <span class="stat-icon">🟠</span>
            <span class="stat-number"><?= $metrics['orange_zones'] ?></span>
            <span class="stat-label">Orange Zones</span>
            <span class="stat-percent"><?= $metrics['orange_percentage'] ?>% of total</span>
        </div>
        <div class="stat-card stat-green">
            <span class="stat-icon">🟢</span>
            <span class="stat-number"><?= $metrics['green_zones'] ?></span>
            <span class="stat-label">Green Zones</span>
            <span class="stat-percent"><?= $metrics['green_percentage'] ?>% of total</span>
        </div>
        <div class="stat-card stat-high">
            <span class="stat-icon">⚠️</span>
            <span class="stat-number"><?= $metrics['high_risk_reports'] ?></span>
            <span class="stat-label">High Risk Reports</span>
        </div>
        <div class="stat-card stat-low">
            <span class="stat-icon">✅</span>
            <span class="stat-number"><?= $metrics['low_risk_reports'] ?></span>
            <span class="stat-label">Low Risk Reports</span>
        </div>
    </section>

    <!-- FILTER BAR -->
    <div class="filter-bar">
        <div class="filter-group">
            <a href="?severity=&region=&sort_by=<?= urlencode($sortBy) ?>" class="filter-btn <?= $severityFilter === '' ? 'active' : '' ?>">All</a>
            <a href="?severity=Red&region=<?= urlencode($regionFilter) ?>&sort_by=<?= urlencode($sortBy) ?>" class="filter-btn <?= $severityFilter === 'Red' ? 'active-red' : '' ?>">🔴 Red</a>
            <a href="?severity=Orange&region=<?= urlencode($regionFilter) ?>&sort_by=<?= urlencode($sortBy) ?>" class="filter-btn <?= $severityFilter === 'Orange' ? 'active-orange' : '' ?>">🟠 Orange</a>
            <a href="?severity=Green&region=<?= urlencode($regionFilter) ?>&sort_by=<?= urlencode($sortBy) ?>" class="filter-btn <?= $severityFilter === 'Green' ? 'active-green' : '' ?>">🟢 Green</a>
        </div>
        <div class="filter-actions">
            <form method="get" style="display:flex;gap:6px;align-items:center;flex-wrap:wrap;" id="filterForm">
                <input type="hidden" name="severity" value="<?= htmlspecialchars($severityFilter) ?>">
                <input type="date" name="start_date" class="filter-input" value="<?= htmlspecialchars($startDate) ?>" placeholder="Start">
                <input type="date" name="end_date" class="filter-input" value="<?= htmlspecialchars($endDate) ?>" placeholder="End">
                <input type="text" name="region" class="filter-input" placeholder="Search region..." value="<?= htmlspecialchars($regionFilter) ?>" style="min-width:120px;">
                
                <select name="sort_by" class="filter-input">
                    <option value="created_desc" <?= $sortBy === 'created_desc' ? 'selected' : '' ?>>Newest First</option>
                    <option value="created_asc" <?= $sortBy === 'created_asc' ? 'selected' : '' ?>>Oldest First</option>
                    <option value="count_desc" <?= $sortBy === 'count_desc' ? 'selected' : '' ?>>Most Reports</option>
                    <option value="count_asc" <?= $sortBy === 'count_asc' ? 'selected' : '' ?>>Least Reports</option>
                </select>
                
                <button type="submit" class="btn-filter btn-filter-primary">
                    <i class='bx bx-filter'></i> Apply
                </button>
                <a href="risk_map.php" class="btn-filter btn-filter-outline">
                    <i class='bx bx-reset'></i> Reset
                </a>
                
                <button type="button" onclick="exportPDF()" class="btn-filter btn-filter-pdf">
                    <i class='bx bx-file-pdf'></i> PDF
                </button>
            </form>
        </div>
    </div>

    <!-- MAP -->
    <section class="map-card">
        <div class="map-card-header">
            <h2><i class='bx bx-map-pin'></i> Interactive Risk Map</h2>
            <div class="map-legend">
                <span class="legend-item">
                    <span class="legend-dot legend-red"></span> Red (10+)
                </span>
                <span class="legend-item">
                    <span class="legend-dot legend-orange"></span> Orange (5-9)
                </span>
                <span class="legend-item">
                    <span class="legend-dot legend-green"></span> Green (1-4)
                </span>
                <span class="legend-badge">📍 KL only</span>
            </div>
        </div>
        <div id="riskMap"></div>
        <?php if (count($zones) === 0): ?>
            <div class="map-overlay">
                <i class='bx bx-check-circle'></i>
                <h3>No Validated Reports</h3>
                <p>No validated reports with coordinates found in Kuala Lumpur area.</p>
            </div>
        <?php endif; ?>
    </section>

    <!-- DATA TABLE + CHART -->
    <section class="data-section">
        <div class="data-section-header">
            <h3><i class='bx bx-data'></i> Validated Report Data</h3>
            <span class="count-badge"><?= count($validatedReports) ?> validated reports</span>
        </div>

        <!-- Chart + Stats -->
        <div class="chart-stats-grid">
            <div class="chart-container">
                <canvas id="riskChart"></canvas>
            </div>
            <div class="chart-stats-right">
                <div class="chart-stat-item">
                    <span class="color-dot color-dot-red"></span>
                    <div class="stat-info">
                        <div class="label">Red Zone (High Risk)</div>
                        <div class="value"><?= $metrics['red_zones'] ?> locations · <?= $metrics['high_risk_reports'] ?> reports</div>
                    </div>
                </div>
                <div class="chart-stat-item">
                    <span class="color-dot color-dot-orange"></span>
                    <div class="stat-info">
                        <div class="label">Orange Zone (Medium Risk)</div>
                        <div class="value"><?= $metrics['orange_zones'] ?> locations · <?= $metrics['medium_risk_reports'] ?> reports</div>
                    </div>
                </div>
                <div class="chart-stat-item">
                    <span class="color-dot color-dot-green"></span>
                    <div class="stat-info">
                        <div class="label">Green Zone (Low Risk)</div>
                        <div class="value"><?= $metrics['green_zones'] ?> locations · <?= $metrics['low_risk_reports'] ?> reports</div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Table -->
        <div class="table-wrapper">
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Ticket ID</th>
                        <th>Location</th>
                        <th>Risk Level</th>
                        <th>Category</th>
                        <th>Status</th>
                        <th>Submitted</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (!empty($validatedReports)): ?>
                        <?php foreach ($validatedReports as $report): ?>
                            <?php
                            $urgency = $report['urgency_level'] ?? 'Normal';
                            $riskMap = ['High' => 'Red', 'Medium' => 'Orange', 'Normal' => 'Green'];
                            $riskLevel = $riskMap[$urgency] ?? 'Green';
                            $riskTagClass = match($riskLevel) {
                                'Red' => 'risk-tag-red',
                                'Orange' => 'risk-tag-orange',
                                default => 'risk-tag-green'
                            };
                            $createdAt = $report['created_at'] ?? '';
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
                                <td><strong><?= htmlspecialchars($report['ticket_id'] ?? 'N/A') ?></strong></td>
                                <td><?= htmlspecialchars($report['location'] ?? 'N/A') ?></td>
                                <td><span class="risk-tag <?= $riskTagClass ?>"><?= htmlspecialchars($riskLevel) ?></span></td>
                                <td><?= htmlspecialchars($report['category'] ?? 'N/A') ?></td>
                                <td><span class="status-tag-validated">Validated</span></td>
                                <td><?= htmlspecialchars($formattedDate) ?></td>
                            </tr>
                        <?php endforeach; ?>
                    <?php else: ?>
                        <tr>
                            <td colspan="6" style="text-align:center;padding:40px;color:#6b7280;">No validated reports found</td>
                        </tr>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </section>
</div>

<!-- =========================================================
     PDF CONTENT (Hidden)
========================================================= -->
<div id="pdfContent" style="display:none;background:white;padding:30px;font-family:Arial,sans-serif;color:#1a1a2e;width:100%;max-width:800px;margin:0 auto;">
    <h1 style="text-align:center;font-size:28px;color:#1a1a2e;margin-bottom:5px;">Risk Map Report</h1>
    <p style="text-align:center;color:#6b7280;font-size:14px;margin-top:0;">
        Kuala Lumpur, Malaysia - <?= date('d M Y') ?>
    </p>
    <p style="text-align:center;color:#10b981;font-size:13px;">
        ✅ Showing only Validated (approved) reports
    </p>
    <hr style="border:1px solid #e5e7eb;margin:15px 0;">
    
    <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:20px 0;">
        <div style="padding:15px;border:1px solid #e5e7eb;border-radius:8px;text-align:center;background:#f8fafc;">
            <div style="font-size:28px;font-weight:700;color:#1a1a2e;"><?= $metrics['total_reports'] ?></div>
            <div style="font-size:12px;color:#6b7280;">Validated Reports</div>
        </div>
        <div style="padding:15px;border:1px solid #dc3545;border-radius:8px;text-align:center;background:#fef2f2;">
            <div style="font-size:28px;font-weight:700;color:#dc3545;"><?= $metrics['red_zones'] ?></div>
            <div style="font-size:12px;color:#6b7280;">Red Zones (<?= $metrics['red_percentage'] ?>%)</div>
        </div>
        <div style="padding:15px;border:1px solid #fd7e14;border-radius:8px;text-align:center;background:#fff7ed;">
            <div style="font-size:28px;font-weight:700;color:#fd7e14;"><?= $metrics['orange_zones'] ?></div>
            <div style="font-size:12px;color:#6b7280;">Orange Zones (<?= $metrics['orange_percentage'] ?>%)</div>
        </div>
        <div style="padding:15px;border:1px solid #28a745;border-radius:8px;text-align:center;background:#f0fdf4;">
            <div style="font-size:28px;font-weight:700;color:#28a745;"><?= $metrics['green_zones'] ?></div>
            <div style="font-size:12px;color:#6b7280;">Green Zones (<?= $metrics['green_percentage'] ?>%)</div>
        </div>
        <div style="padding:15px;border:1px solid #dc3545;border-radius:8px;text-align:center;background:#fef2f2;">
            <div style="font-size:28px;font-weight:700;color:#dc3545;"><?= $metrics['high_risk_reports'] ?></div>
            <div style="font-size:12px;color:#6b7280;">High Risk Reports</div>
        </div>
        <div style="padding:15px;border:1px solid #28a745;border-radius:8px;text-align:center;background:#f0fdf4;">
            <div style="font-size:28px;font-weight:700;color:#28a745;"><?= $metrics['low_risk_reports'] ?></div>
            <div style="font-size:12px;color:#6b7280;">Low Risk Reports</div>
        </div>
    </div>
    
    <hr style="border:1px solid #e5e7eb;margin:15px 0;">
    
    <h3 style="font-size:16px;color:#1a1a2e;margin-bottom:10px;">Validated Reports List</h3>
    <table style="width:100%;border-collapse:collapse;font-size:12px;">
        <thead>
            <tr style="background:#f1f5f9;">
                <th style="padding:8px;border:1px solid #e5e7eb;text-align:left;">Ticket ID</th>
                <th style="padding:8px;border:1px solid #e5e7eb;text-align:left;">Location</th>
                <th style="padding:8px;border:1px solid #e5e7eb;text-align:left;">Risk Level</th>
                <th style="padding:8px;border:1px solid #e5e7eb;text-align:left;">Category</th>
                <th style="padding:8px;border:1px solid #e5e7eb;text-align:left;">Submitted</th>
            </tr>
        </thead>
        <tbody>
            <?php foreach ($validatedReports as $report): ?>
                <?php
                $urgency = $report['urgency_level'] ?? 'Normal';
                $riskMap = ['High' => 'Red', 'Medium' => 'Orange', 'Normal' => 'Green'];
                $riskLevel = $riskMap[$urgency] ?? 'Green';
                $createdAt = $report['created_at'] ?? '';
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
                    <td style="padding:6px;border:1px solid #e5e7eb;"><?= htmlspecialchars($report['ticket_id'] ?? 'N/A') ?></td>
                    <td style="padding:6px;border:1px solid #e5e7eb;"><?= htmlspecialchars($report['location'] ?? 'N/A') ?></td>
                    <td style="padding:6px;border:1px solid #e5e7eb;font-weight:600;color:<?= $riskLevel === 'Red' ? '#dc3545' : ($riskLevel === 'Orange' ? '#fd7e14' : '#28a745') ?>;">
                        <?= $riskLevel ?>
                    </td>
                    <td style="padding:6px;border:1px solid #e5e7eb;"><?= htmlspecialchars($report['category'] ?? 'N/A') ?></td>
                    <td style="padding:6px;border:1px solid #e5e7eb;"><?= htmlspecialchars($formattedDate) ?></td>
                </tr>
            <?php endforeach; ?>
            <?php if (empty($validatedReports)): ?>
                <tr>
                    <td colspan="5" style="padding:20px;text-align:center;color:#6b7280;">No validated reports</td>
                </tr>
            <?php endif; ?>
        </tbody>
    </table>
    
    <p style="text-align:center;font-size:11px;color:#6b7280;margin-top:20px;border-top:1px solid #e5e7eb;padding-top:15px;">
        Generated on <?= date('d M Y H:i') ?> | Predictive Zoning Dashboard
    </p>
</div>

<!-- =========================================================
     Leaflet.js
========================================================= -->
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>

<script>
// Risk zone data from PHP
const riskZones = <?= json_encode($zones) ?>;

const KL_BOUNDS = {
    north: 3.28,
    south: 3.02,
    east: 101.78,
    west: 101.58
};

const KL_CENTER = [3.139, 101.6869];
const KL_ZOOM = 13;

const riskColours = {
    Red: '#dc3545',
    Orange: '#fd7e14',
    Green: '#28a745'
};

const riskColoursFill = {
    Red: '#dc3545',
    Orange: '#fd7e14',
    Green: '#28a745'
};

function initialiseRiskMap() {
    if (!document.getElementById('riskMap')) return;

    const map = L.map('riskMap', {
        center: KL_CENTER,
        zoom: KL_ZOOM,
        minZoom: 12,
        maxZoom: 18,
        maxBounds: [
            [KL_BOUNDS.south - 0.02, KL_BOUNDS.west - 0.02],
            [KL_BOUNDS.north + 0.02, KL_BOUNDS.east + 0.02]
        ],
        maxBoundsViscosity: 1.0
    });

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }).addTo(map);

    const klBounds = [
        [KL_BOUNDS.south, KL_BOUNDS.west],
        [KL_BOUNDS.north, KL_BOUNDS.east]
    ];
    
    L.rectangle(klBounds, {
        color: '#1a1a2e',
        weight: 2,
        opacity: 0.3,
        fill: false,
        dashArray: '5, 5'
    }).addTo(map).bindPopup('📍 Kuala Lumpur');

    if (riskZones.length > 0) {
        const bounds = [];

        riskZones.forEach(function(zone) {
            const colour = riskColours[zone.risk] || riskColours.Green;
            const fillColour = riskColoursFill[zone.risk] || riskColoursFill.Green;

            let radius = 150;
            if (zone.risk === 'Red') radius = 500;
            else if (zone.risk === 'Orange') radius = 300;
            else radius = 150;

            const circle = L.circle([zone.lat, zone.lng], {
                radius: radius,
                color: colour,
                fillColor: fillColour,
                fillOpacity: 0.3,
                weight: 2
            }).addTo(map);

            L.marker([zone.lat, zone.lng], {
                icon: L.divIcon({
                    className: 'risk-marker',
                    html: `<div style="width:20px;height:20px;border-radius:50%;background:${colour};border:2px solid white;box-shadow:0 0 4px rgba(0,0,0,0.3);display:flex;align-items:center;justify-content:center;color:white;font-size:10px;font-weight:700;">${zone.count}</div>`,
                    iconSize: [20, 20],
                    iconAnchor: [10, 10]
                })
            }).addTo(map);

            bounds.push([zone.lat, zone.lng]);
        });

        if (bounds.length > 0) {
            map.fitBounds(bounds, { padding: [50, 50] });
        }
    }

    map.on('drag', function() {
        const center = map.getCenter();
        let newLat = center.lat;
        let newLng = center.lng;
        let clamped = false;
        
        if (center.lat < KL_BOUNDS.south) { newLat = KL_BOUNDS.south; clamped = true; }
        if (center.lat > KL_BOUNDS.north) { newLat = KL_BOUNDS.north; clamped = true; }
        if (center.lng < KL_BOUNDS.west) { newLng = KL_BOUNDS.west; clamped = true; }
        if (center.lng > KL_BOUNDS.east) { newLng = KL_BOUNDS.east; clamped = true; }
        
        if (clamped) {
            map.panTo([newLat, newLng], { animate: true });
        }
    });

    window.addEventListener('resize', function() {
        setTimeout(function() { map.invalidateSize(); }, 200);
    });
}

function escapeHtml(value) {
    return String(value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

document.addEventListener('DOMContentLoaded', function() {
    if (typeof L !== 'undefined') {
        initialiseRiskMap();
    } else {
        setTimeout(initialiseRiskMap, 1000);
    }
    
    initChart();
});

function initChart() {
    const ctx = document.getElementById('riskChart');
    if (!ctx) return;
    
    const redZones = <?= $metrics['red_zones'] ?>;
    const orangeZones = <?= $metrics['orange_zones'] ?>;
    const greenZones = <?= $metrics['green_zones'] ?>;
    
    new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: ['Red Zone', 'Orange Zone', 'Green Zone'],
            datasets: [{
                data: [redZones, orangeZones, greenZones],
                backgroundColor: ['#dc3545', '#fd7e14', '#28a745'],
                borderWidth: 3,
                borderColor: '#ffffff'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            cutout: '65%',
            plugins: {
                legend: {
                    display: false
                }
            }
        }
    });
}

function exportPDF() {
    const element = document.getElementById('pdfContent');
    element.style.display = 'block';
    element.style.background = 'white';
    element.style.padding = '20px';
    element.style.position = 'fixed';
    element.style.top = '0';
    element.style.left = '0';
    element.style.zIndex = '9999';
    element.style.width = '100%';
    element.style.maxWidth = '800px';
    
    html2canvas(element, {
        scale: 2,
        useCORS: true,
        logging: false,
        backgroundColor: '#ffffff',
        width: element.scrollWidth,
        height: element.scrollHeight
    }).then(function(canvas) {
        const imgData = canvas.toDataURL('image/jpeg', 0.95);
        const { jsPDF } = window.jspdf;
        const pdf = new jsPDF({
            unit: 'mm',
            format: 'a4',
            orientation: 'portrait'
        });
        
        const pdfWidth = pdf.internal.pageSize.getWidth();
        const pdfHeight = pdf.internal.pageSize.getHeight();
        const imgWidth = canvas.width;
        const imgHeight = canvas.height;
        const ratio = Math.min(pdfWidth / imgWidth, pdfHeight / imgHeight);
        const imgX = (pdfWidth - imgWidth * ratio) / 2;
        const imgY = (pdfHeight - imgHeight * ratio) / 2;
        
        pdf.addImage(imgData, 'JPEG', imgX, imgY, imgWidth * ratio, imgHeight * ratio);
        pdf.save('Risk_Map_Report_' + new Date().toISOString().slice(0,10) + '.pdf');
        
        element.style.display = 'none';
        element.style.position = '';
        element.style.zIndex = '';
        element.style.width = '';
        element.style.maxWidth = '';
        element.style.top = '';
        element.style.left = '';
    }).catch(function(error) {
        console.error('PDF generation error:', error);
        element.style.display = 'none';
        element.style.position = '';
        element.style.zIndex = '';
        element.style.width = '';
        element.style.maxWidth = '';
        element.style.top = '';
        element.style.left = '';
        alert('Error generating PDF. Please try again.');
    });
}
</script>

<?php

render_admin_end();

?>
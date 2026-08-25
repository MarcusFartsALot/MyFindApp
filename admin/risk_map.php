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
    
    // Map uses filtered data
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

/*
|--------------------------------------------------------------------------
| FR1.11: Risk Analysis Report Generation
|--------------------------------------------------------------------------
*/
// ============================================================
// Risk Analysis Data - For PDF Report
// ============================================================

// 1. Executive Summary Data
$riskSummary = [
    'total_reports' => $metrics['total_reports'],
    'total_zones' => count($zones),
    'has_critical_zones' => $metrics['red_zones'] > 0,
    'critical_zone_count' => $metrics['red_zones'],
    'orange_zone_count' => $metrics['orange_zones'],
    'green_zone_count' => $metrics['green_zones'],
    'status_message' => $metrics['red_zones'] > 0 
        ? '⚠️ ' . $metrics['red_zones'] . ' Red Zone(s) detected - Immediate action required!' 
        : ($metrics['orange_zones'] > 0 
            ? '🟠 ' . $metrics['orange_zones'] . ' Orange Zone(s) detected - Enhanced monitoring recommended.' 
            : '✅ No high-risk zones detected. Risk status is stable.'),
    'overall_risk_level' => $metrics['red_zones'] > 0 ? 'High' : ($metrics['orange_zones'] > 0 ? 'Medium' : 'Low'),
];

// 2. High Risk Location Ranking (sorted by report count)
$topRiskLocations = array_values(
    array_slice(
        array_filter($zones, function($zone) {
            return $zone['risk'] === 'Red' || $zone['risk'] === 'Orange';
        }),
        0,
        5
    )
);

// 3. Category Analysis
$categoryAnalysis = [];
foreach ($validatedReports as $report) {
    $cat = $report['category'] ?? 'Unknown';
    if (!isset($categoryAnalysis[$cat])) {
        $categoryAnalysis[$cat] = 0;
    }
    $categoryAnalysis[$cat]++;
}
arsort($categoryAnalysis);

// 4. Trend Analysis - Daily Statistics
$dateTrend = [];
foreach ($validatedReports as $report) {
    $date = date('Y-m-d', strtotime($report['created_at'] ?? 'now'));
    if (!isset($dateTrend[$date])) {
        $dateTrend[$date] = 0;
    }
    $dateTrend[$date]++;
}
// Sort by date
ksort($dateTrend);
// Get last 30 days only
$dateTrend = array_slice($dateTrend, -30, 30, true);

// 5. Recommendations
$recommendations = [];
if ($metrics['red_zones'] > 0) {
    $recommendations[] = '🚨 Immediately address ' . $metrics['red_zones'] . ' Red Zone(s)';
    $recommendations[] = '📋 Schedule an emergency security meeting to develop response plans';
    foreach ($zones as $zone) {
        if ($zone['risk'] === 'Red') {
            $recommendations[] = '   - Priority Focus: ' . htmlspecialchars($zone['name']) . ' (' . $zone['count'] . ' reports)';
        }
    }
}
if ($metrics['orange_zones'] > 0) {
    $recommendations[] = '🟠 Increase monitoring and patrol in ' . $metrics['orange_zones'] . ' Orange Zone(s)';
}
if ($metrics['green_zones'] > 0 && $metrics['red_zones'] == 0) {
    $recommendations[] = '🟢 Maintain regular monitoring of Green Zones';
}
$recommendations[] = '📊 Conduct weekly risk map reviews to track trend changes';
$recommendations[] = '📱 Ensure citizen reporting channels remain open and responsive';

// 6. Risk Distribution (for report)
$riskDistribution = [
    'red' => [
        'zones' => $metrics['red_zones'],
        'reports' => $metrics['high_risk_reports'],
        'percentage' => $metrics['red_percentage']
    ],
    'orange' => [
        'zones' => $metrics['orange_zones'],
        'reports' => $metrics['medium_risk_reports'],
        'percentage' => $metrics['orange_percentage']
    ],
    'green' => [
        'zones' => $metrics['green_zones'],
        'reports' => $metrics['low_risk_reports'],
        'percentage' => $metrics['green_percentage']
    ]
];

// 7. Report Generation Timestamp
$reportGeneratedAt = date('d M Y H:i:s');

render_admin_start('View Risk Map', $admin, 'dashboard');

?>

<!-- Chart.js -->
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
   FILTER BAR
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
   LEGEND
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
   TABLE
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

/* =========================================================
   ZONE DRAWER - Click to Drill Down
========================================================= */
.drawer-overlay {
    display: none;
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
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
    box-shadow: -4px 0 30px rgba(0,0,0,0.2);
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
    flex-shrink: 0;
}

.drawer-header h2 {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
    color: #1a1a2e;
}

.drawer-header h2 i {
    color: #3b82f6;
}

.drawer-header .drawer-close {
    background: none;
    border: none;
    font-size: 28px;
    cursor: pointer;
    color: #6b7280;
    padding: 0 8px;
    line-height: 1;
    transition: color 0.2s;
}

.drawer-header .drawer-close:hover {
    color: #1a1a2e;
}

.drawer-body {
    padding: 24px;
    flex: 1;
    overflow-y: auto;
}

.drawer-body .zone-summary {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 0;
    margin-bottom: 12px;
    border-bottom: 1px solid #f1f3f5;
}

.drawer-body .zone-summary .total {
    font-size: 14px;
    color: #6b7280;
}

.drawer-body .zone-summary .total strong {
    color: #1a1a2e;
}

.drawer-body .zone-summary .risk-level {
    font-size: 13px;
    font-weight: 600;
}

.drawer-body .report-item {
    padding: 14px 16px;
    border: 1px solid #f1f3f5;
    border-radius: 10px;
    margin-bottom: 10px;
    transition: background 0.2s;
    cursor: default;
}

.drawer-body .report-item:hover {
    background: #f8fafc;
    border-color: #d1d5db;
}

.drawer-body .report-item .ticket-id {
    font-weight: 600;
    color: #1a1a2e;
    font-size: 14px;
}

.drawer-body .report-item .report-meta {
    font-size: 12px;
    color: #6b7280;
    margin-top: 4px;
    display: flex;
    flex-wrap: wrap;
    gap: 4px 12px;
}

.drawer-body .report-item .report-meta span {
    display: inline-flex;
    align-items: center;
    gap: 2px;
}

.drawer-body .risk-tag-sm {
    display: inline-block;
    padding: 2px 10px;
    border-radius: 10px;
    font-size: 10px;
    font-weight: 600;
}

.drawer-body .no-reports {
    text-align: center;
    padding: 40px 20px;
    color: #6b7280;
}

.drawer-body .no-reports i {
    font-size: 36px;
    display: block;
    margin-bottom: 8px;
    opacity: 0.4;
}

.loading-spinner {
    text-align: center;
    padding: 40px 20px;
    color: #6b7280;
}

.loading-spinner i {
    font-size: 32px;
    display: block;
    margin-bottom: 8px;
    animation: spin 1s linear infinite;
}

@keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
}

@media (max-width: 768px) {
    .drawer-panel {
        width: 100vw;
        max-width: 100vw;
        right: -100vw;
    }
    
    .drawer-body .report-item .report-meta {
        flex-direction: column;
        gap: 2px;
    }
}
</style>

<div class="risk-map-page">

    <!-- HEADER -->
    <section class="risk-map-header">
        <div>
            <div class="subtitle">
                <p>View and analyse validated incident reports in <strong>Kuala Lumpur, Malaysia</strong></p>
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
            <span class="stat-percent"><?= $metrics['red_percentage'] ?>%</span>
        </div>
        <div class="stat-card stat-orange">
            <span class="stat-icon">🟠</span>
            <span class="stat-number"><?= $metrics['orange_zones'] ?></span>
            <span class="stat-label">Orange Zones</span>
            <span class="stat-percent"><?= $metrics['orange_percentage'] ?>%</span>
        </div>
        <div class="stat-card stat-green">
            <span class="stat-icon">🟢</span>
            <span class="stat-number"><?= $metrics['green_zones'] ?></span>
            <span class="stat-label">Green Zones</span>
            <span class="stat-percent"><?= $metrics['green_percentage'] ?>%</span>
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
                <span class="legend-badge" style="background:#dbeafe;color:#1e40af;">👆 Click zone for details</span>
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
            <h3><i class='bx bx-data'></i> Validated Incident Reports</h3>
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
                    <?php if (!empty($zones)): ?>
                        <?php foreach ($zones as $zone): ?>
                            <?php 
                            $riskLevel = $zone['risk'];
                            $riskTagClass = match($riskLevel) {
                                'Red' => 'risk-tag-red',
                                'Orange' => 'risk-tag-orange',
                                default => 'risk-tag-green'
                            };
                            ?>
                            <?php foreach ($zone['reports'] as $report): ?>
                                <?php
                                $formattedDate = 'N/A';
                                if (!empty($report['created_at'])) {
                                    try {
                                        $formattedDate = date('d M Y H:i', strtotime($report['created_at']));
                                    } catch (Throwable $e) {
                                        $formattedDate = $report['created_at'];
                                    }
                                }
                                ?>
                                <tr>
                                    <td><strong><?= htmlspecialchars($report['ticket_id'] ?? 'N/A') ?></strong></td>
                                    <td><?= htmlspecialchars($zone['name'] ?? 'N/A') ?></td>
                                    <td><span class="risk-tag <?= $riskTagClass ?>"><?= htmlspecialchars($riskLevel) ?></span></td>
                                    <td><?= htmlspecialchars($report['category'] ?? 'N/A') ?></td>
                                    <td><span class="status-tag-validated">Validated</span></td>
                                    <td><?= htmlspecialchars($formattedDate) ?></td>
                                </tr>
                            <?php endforeach; ?>
                        <?php endforeach; ?>
                    <?php else: ?>
                        <tr>
                            <td colspan="6" style="text-align:center;padding:40px;color:#6b7280;">No validated reports found</td>
                        </tr>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>

<!-- =========================================================
     PDF CONTENT - Full Risk Analysis Report (FR1.11)
========================================================= -->
<div id="pdfContent" style="display:none;background:white;padding:30px;font-family:Arial,sans-serif;color:#1a1a2e;width:100%;max-width:800px;margin:0 auto;">

    <!-- =========================================================
         Report Title
    ========================================================= -->
    <h1 style="text-align:center;font-size:28px;color:#1a1a2e;margin-bottom:5px;">📊 Risk Analysis Report</h1>
    <p style="text-align:center;color:#6b7280;font-size:14px;margin-top:0;">
        Kuala Lumpur, Malaysia - <?= date('d M Y') ?>
    </p>
    <p style="text-align:center;color:#10b981;font-size:13px;">
        ✅ Showing only Validated (approved) reports
    </p>
    <hr style="border:1px solid #e5e7eb;margin:15px 0;">

    <!-- =========================================================
         1. Executive Summary
    ========================================================= -->
    <div style="margin:20px 0;padding:15px;background:#f8fafc;border-radius:8px;border-left:4px solid <?= $riskSummary['has_critical_zones'] ? '#dc3545' : '#28a745' ?>;">
        <h3 style="margin:0 0 8px 0;font-size:15px;color:#1a1a2e;">📋 Executive Summary</h3>
        <p style="margin:0 0 6px 0;font-size:13px;color:#4b5563;">
            This report analyzes <strong><?= $riskSummary['total_reports'] ?></strong> validated reports
            across <strong><?= $riskSummary['total_zones'] ?></strong> locations.
            Overall risk level is <strong><?= $riskSummary['overall_risk_level'] ?></strong>.
        </p>
        <p style="margin:0;font-size:13px;font-weight:600;color:<?= $riskSummary['has_critical_zones'] ? '#dc3545' : ($riskSummary['orange_zone_count'] > 0 ? '#fd7e14' : '#28a745') ?>;">
            <?= $riskSummary['status_message'] ?>
        </p>
    </div>

    <!-- =========================================================
         2. Risk Distribution Statistics
    ========================================================= -->
    <h3 style="font-size:16px;color:#1a1a2e;margin:20px 0 10px 0;">📈 Risk Distribution Statistics</h3>
    <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:10px 0 20px 0;">
        <div style="padding:15px;border:1px solid #dc3545;border-radius:8px;text-align:center;background:#fef2f2;">
            <div style="font-size:28px;font-weight:700;color:#dc3545;"><?= $riskDistribution['red']['zones'] ?></div>
            <div style="font-size:12px;color:#6b7280;">🔴 Red Zones</div>
            <div style="font-size:11px;color:#dc3545;"><?= $riskDistribution['red']['percentage'] ?>%</div>
        </div>
        <div style="padding:15px;border:1px solid #fd7e14;border-radius:8px;text-align:center;background:#fff7ed;">
            <div style="font-size:28px;font-weight:700;color:#fd7e14;"><?= $riskDistribution['orange']['zones'] ?></div>
            <div style="font-size:12px;color:#6b7280;">🟠 Orange Zones</div>
            <div style="font-size:11px;color:#fd7e14;"><?= $riskDistribution['orange']['percentage'] ?>%</div>
        </div>
        <div style="padding:15px;border:1px solid #28a745;border-radius:8px;text-align:center;background:#f0fdf4;">
            <div style="font-size:28px;font-weight:700;color:#28a745;"><?= $riskDistribution['green']['zones'] ?></div>
            <div style="font-size:12px;color:#6b7280;">🟢 Green Zones</div>
            <div style="font-size:11px;color:#28a745;"><?= $riskDistribution['green']['percentage'] ?>%</div>
        </div>
    </div>

    <!-- Risk Distribution Table -->
    <table style="width:100%;border-collapse:collapse;font-size:12px;margin-bottom:20px;">
        <thead>
            <tr style="background:#f1f5f9;">
                <th style="padding:8px;border:1px solid #e5e7eb;text-align:left;">Risk Level</th>
                <th style="padding:8px;border:1px solid #e5e7eb;text-align:center;">Zones</th>
                <th style="padding:8px;border:1px solid #e5e7eb;text-align:center;">Reports</th>
                <th style="padding:8px;border:1px solid #e5e7eb;text-align:center;">Percentage</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td style="padding:6px;border:1px solid #e5e7eb;color:#dc3545;font-weight:600;">🔴 High Risk</td>
                <td style="padding:6px;border:1px solid #e5e7eb;text-align:center;"><?= $riskDistribution['red']['zones'] ?></td>
                <td style="padding:6px;border:1px solid #e5e7eb;text-align:center;"><?= $riskDistribution['red']['reports'] ?></td>
                <td style="padding:6px;border:1px solid #e5e7eb;text-align:center;"><?= $riskDistribution['red']['percentage'] ?>%</td>
            </tr>
            <tr>
                <td style="padding:6px;border:1px solid #e5e7eb;color:#fd7e14;font-weight:600;">🟠 Medium Risk</td>
                <td style="padding:6px;border:1px solid #e5e7eb;text-align:center;"><?= $riskDistribution['orange']['zones'] ?></td>
                <td style="padding:6px;border:1px solid #e5e7eb;text-align:center;"><?= $riskDistribution['orange']['reports'] ?></td>
                <td style="padding:6px;border:1px solid #e5e7eb;text-align:center;"><?= $riskDistribution['orange']['percentage'] ?>%</td>
            </tr>
            <tr>
                <td style="padding:6px;border:1px solid #e5e7eb;color:#28a745;font-weight:600;">🟢 Low Risk</td>
                <td style="padding:6px;border:1px solid #e5e7eb;text-align:center;"><?= $riskDistribution['green']['zones'] ?></td>
                <td style="padding:6px;border:1px solid #e5e7eb;text-align:center;"><?= $riskDistribution['green']['reports'] ?></td>
                <td style="padding:6px;border:1px solid #e5e7eb;text-align:center;"><?= $riskDistribution['green']['percentage'] ?>%</td>
            </tr>
            <tr style="background:#f8fafc;font-weight:600;">
                <td style="padding:6px;border:1px solid #e5e7eb;">Total</td>
                <td style="padding:6px;border:1px solid #e5e7eb;text-align:center;"><?= $riskSummary['total_zones'] ?></td>
                <td style="padding:6px;border:1px solid #e5e7eb;text-align:center;"><?= $riskSummary['total_reports'] ?></td>
                <td style="padding:6px;border:1px solid #e5e7eb;text-align:center;">100%</td>
            </tr>
        </tbody>
    </table>

    <!-- =========================================================
         3. High Risk Location Ranking
    ========================================================= -->
    <?php if (!empty($topRiskLocations)): ?>
    <h3 style="font-size:16px;color:#1a1a2e;margin:20px 0 10px 0;">🚨 High Risk Location Ranking</h3>
    <table style="width:100%;border-collapse:collapse;font-size:12px;margin-bottom:20px;">
        <thead>
            <tr style="background:#f1f5f9;">
                <th style="padding:8px;border:1px solid #e5e7eb;text-align:center;">Rank</th>
                <th style="padding:8px;border:1px solid #e5e7eb;text-align:left;">Location</th>
                <th style="padding:8px;border:1px solid #e5e7eb;text-align:center;">Reports</th>
                <th style="padding:8px;border:1px solid #e5e7eb;text-align:center;">Risk Level</th>
                <th style="padding:8px;border:1px solid #e5e7eb;text-align:left;">Primary Category</th>
            </tr>
        </thead>
        <tbody>
            <?php $rank = 1; ?>
            <?php foreach ($topRiskLocations as $zone): ?>
                <tr>
                    <td style="padding:6px;border:1px solid #e5e7eb;text-align:center;font-weight:600;">#<?= $rank++ ?></td>
                    <td style="padding:6px;border:1px solid #e5e7eb;"><?= htmlspecialchars($zone['name']) ?></td>
                    <td style="padding:6px;border:1px solid #e5e7eb;text-align:center;font-weight:600;"><?= $zone['count'] ?></td>
                    <td style="padding:6px;border:1px solid #e5e7eb;text-align:center;font-weight:600;color:<?= $zone['risk'] === 'Red' ? '#dc3545' : '#fd7e14' ?>;">
                        <?= $zone['risk'] ?>
                    </td>
                    <td style="padding:6px;border:1px solid #e5e7eb;"><?= htmlspecialchars($zone['category']) ?></td>
                </tr>
            <?php endforeach; ?>
        </tbody>
    </table>
    <?php endif; ?>

    <!-- =========================================================
         4. Category Analysis
    ========================================================= -->
    <?php if (!empty($categoryAnalysis)): ?>
    <h3 style="font-size:16px;color:#1a1a2e;margin:20px 0 10px 0;">📂 Report Category Distribution</h3>
    <div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:8px;margin-bottom:20px;">
        <?php foreach ($categoryAnalysis as $category => $count): ?>
            <div style="padding:8px 12px;background:#f8fafc;border-radius:6px;border:1px solid #e5e7eb;display:flex;justify-content:space-between;">
                <span style="font-size:12px;color:#4b5563;"><?= htmlspecialchars($category) ?></span>
                <span style="font-size:12px;font-weight:600;color:#1a1a2e;"><?= $count ?></span>
            </div>
        <?php endforeach; ?>
    </div>
    <?php endif; ?>

    <!-- =========================================================
         5. Trend Analysis
    ========================================================= -->
    <?php if (!empty($dateTrend)): ?>
    <h3 style="font-size:16px;color:#1a1a2e;margin:20px 0 10px 0;">📉 Daily Report Trend (Last 30 Days)</h3>
    <table style="width:100%;border-collapse:collapse;font-size:11px;margin-bottom:20px;">
        <thead>
            <tr style="background:#f1f5f9;">
                <th style="padding:6px;border:1px solid #e5e7eb;text-align:left;">Date</th>
                <th style="padding:6px;border:1px solid #e5e7eb;text-align:center;">Reports</th>
                <th style="padding:6px;border:1px solid #e5e7eb;text-align:center;">Trend Indicator</th>
            </tr>
        </thead>
        <tbody>
            <?php 
            $trendValues = array_values($dateTrend);
            $avgTrend = count($trendValues) > 0 ? array_sum($trendValues) / count($trendValues) : 0;
            ?>
            <?php foreach ($dateTrend as $date => $count): ?>
                <tr>
                    <td style="padding:4px 6px;border:1px solid #e5e7eb;"><?= date('d M Y', strtotime($date)) ?></td>
                    <td style="padding:4px 6px;border:1px solid #e5e7eb;text-align:center;font-weight:600;"><?= $count ?></td>
                    <td style="padding:4px 6px;border:1px solid #e5e7eb;text-align:center;">
                        <?php if ($count > $avgTrend * 1.5): ?>
                            <span style="color:#dc3545;">⬆️ Above Average</span>
                        <?php elseif ($count < $avgTrend * 0.5): ?>
                            <span style="color:#28a745;">⬇️ Below Average</span>
                        <?php else: ?>
                            <span style="color:#6b7280;">➖ Normal</span>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>
        </tbody>
    </table>
    <?php endif; ?>

    <!-- =========================================================
         6. Recommendations
    ========================================================= -->
    <h3 style="font-size:16px;color:#1a1a2e;margin:20px 0 10px 0;">✅ Recommendations</h3>
    <div style="margin-bottom:20px;padding:15px;background:#f0fdf4;border-radius:8px;border-left:4px solid #28a745;">
        <ul style="margin:0;padding-left:20px;font-size:13px;color:#4b5563;">
            <?php foreach ($recommendations as $recommendation): ?>
                <li style="margin-bottom:6px;"><?= $recommendation ?></li>
            <?php endforeach; ?>
        </ul>
    </div>

    <!-- =========================================================
         7. Detailed Report List
    ========================================================= -->
    <hr style="border:1px solid #e5e7eb;margin:20px 0;">
    <h3 style="font-size:16px;color:#1a1a2e;margin-bottom:10px;">📋 Detailed Report List</h3>
    <table style="width:100%;border-collapse:collapse;font-size:11px;">
        <thead>
            <tr style="background:#f1f5f9;">
                <th style="padding:6px;border:1px solid #e5e7eb;text-align:left;">Ticket ID</th>
                <th style="padding:6px;border:1px solid #e5e7eb;text-align:left;">Location</th>
                <th style="padding:6px;border:1px solid #e5e7eb;text-align:center;">Risk Level</th>
                <th style="padding:6px;border:1px solid #e5e7eb;text-align:left;">Category</th>
                <th style="padding:6px;border:1px solid #e5e7eb;text-align:left;">Submitted</th>
            </tr>
        </thead>
        <tbody>
            <?php if (!empty($zones)): ?>
                <?php 
                $displayedIds = [];
                foreach ($zones as $zone):
                    foreach ($zone['reports'] as $report):
                        $reportId = $report['id'] ?? '';
                        if (in_array($reportId, $displayedIds)) continue;
                        $displayedIds[] = $reportId;
                        $createdAt = $report['created_at'] ?? '';
                        $formattedDate = 'N/A';
                        if ($createdAt !== '') {
                            try {
                                $formattedDate = date('d M Y H:i', strtotime($createdAt));
                            } catch (Throwable $e) {
                                $formattedDate = $createdAt;
                            }
                        }
                        $riskColor = match($zone['risk']) {
                            'Red' => '#dc3545',
                            'Orange' => '#fd7e14',
                            default => '#28a745'
                        };
                ?>
                        <tr>
                            <td style="padding:4px 6px;border:1px solid #e5e7eb;font-weight:600;"><?= htmlspecialchars($report['ticket_id'] ?? 'N/A') ?></td>
                            <td style="padding:4px 6px;border:1px solid #e5e7eb;"><?= htmlspecialchars($zone['name'] ?? 'N/A') ?></td>
                            <td style="padding:4px 6px;border:1px solid #e5e7eb;text-align:center;font-weight:600;color:<?= $riskColor ?>;">
                                <?= $zone['risk'] ?>
                            </td>
                            <td style="padding:4px 6px;border:1px solid #e5e7eb;"><?= htmlspecialchars($report['category'] ?? 'N/A') ?></td>
                            <td style="padding:4px 6px;border:1px solid #e5e7eb;"><?= htmlspecialchars($formattedDate) ?></td>
                        </tr>
                <?php 
                    endforeach;
                endforeach; 
                ?>
            <?php else: ?>
                <tr>
                    <td colspan="5" style="padding:20px;text-align:center;color:#6b7280;">No validated reports found</td>
                </tr>
            <?php endif; ?>
        </tbody>
    </table>

    <!-- =========================================================
         8. Footer
    ========================================================= -->
    <p style="text-align:center;font-size:10px;color:#6b7280;margin-top:20px;border-top:1px solid #e5e7eb;padding-top:15px;">
        Report Generated: <?= $reportGeneratedAt ?> | Risk Analysis Report | Kuala Lumpur Safety Monitoring System
    </p>
</div>

<!-- =========================================================
     ZONE DRAWER (Click to Drill Down)
========================================================= -->
<div class="drawer-overlay" id="zoneDrawerOverlay" onclick="closeZoneDrawer()"></div>
<div class="drawer-panel" id="zoneDrawerPanel">
    <div class="drawer-header">
        <h2><i class='bx bx-list-ul'></i> Reports in <span id="zoneNameDisplay">Area</span></h2>
        <button class="drawer-close" onclick="closeZoneDrawer()">&times;</button>
    </div>
    <div class="drawer-body" id="zoneDrawerBody">
        <div class="loading-spinner">
            <i class='bx bx-loader-alt'></i>
            <p>Loading reports...</p>
        </div>
    </div>
</div>

<!-- =========================================================
     Google Maps API and Libraries
========================================================= -->
<script src="https://maps.googleapis.com/maps/api/js?key=AIzaSyAqSOx69G4xtBku2qB76XDHJB-W-LORJgc&callback=initMap" async defer></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>

<script>
// Risk zone data from PHP
const riskZones = <?= json_encode($zones) ?>;

// Store all zone data for drawer access
const zoneReportsData = <?= json_encode($zones) ?>;

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

// ============================================================
// Google Maps 
// ============================================================

let riskMap = null;

function initMap() {
    const mapContainer = document.getElementById('riskMap');
    if (!mapContainer) return;

    riskMap = new google.maps.Map(mapContainer, {
        center: { lat: KL_CENTER[0], lng: KL_CENTER[1] },
        zoom: KL_ZOOM,
        minZoom: 12,
        maxZoom: 18,
        restriction: {
            latLngBounds: {
                north: KL_BOUNDS.north + 0.02,
                south: KL_BOUNDS.south - 0.02,
                east: KL_BOUNDS.east + 0.02,
                west: KL_BOUNDS.west - 0.02
            },
            strictBounds: true
        },
        mapTypeId: 'roadmap',
        styles: [
            {
                featureType: 'poi',
                elementType: 'labels',
                stylers: [{ visibility: 'off' }]
            }
        ]
    });

    // KL bounding box
    const klBounds = new google.maps.Rectangle({
        strokeColor: '#1a1a2e',
        strokeOpacity: 0.3,
        strokeWeight: 2,
        fillColor: '#1a1a2e',
        fillOpacity: 0.02,
        map: riskMap,
        bounds: {
            north: KL_BOUNDS.north,
            south: KL_BOUNDS.south,
            east: KL_BOUNDS.east,
            west: KL_BOUNDS.west
        }
    });

    // KL label
    const klLabel = new google.maps.InfoWindow({
        content: '<div style="font-weight:600;color:#1a1a2e;">📍 Kuala Lumpur</div>',
        position: { lat: KL_CENTER[0], lng: KL_CENTER[1] }
    });
    klLabel.open(riskMap);

    // Draw risk zone circles.
    if (riskZones.length > 0) {
        const bounds = new google.maps.LatLngBounds();

        riskZones.forEach(function(zone) {
            const colour = riskColours[zone.risk] || riskColours.Green;
            const fillColour = riskColoursFill[zone.risk] || riskColoursFill.Green;

            let radius = 150;
            if (zone.risk === 'Red') radius = 500;
            else if (zone.risk === 'Orange') radius = 300;
            else radius = 150;

            // Draw circle
            const circle = new google.maps.Circle({
                strokeColor: colour,
                strokeOpacity: 0.8,
                strokeWeight: 2,
                fillColor: fillColour,
                fillOpacity: 0.3,
                map: riskMap,
                center: { lat: zone.lat, lng: zone.lng },
                radius: radius,
                clickable: true
            });

            // Click to Drill Down - open drawer directly (no InfoWindow)
            circle.addListener('click', function(event) {
                // Find the full zone data
                const fullZone = zoneReportsData.find(z => 
                    Math.abs(z.lat - zone.lat) < 0.0001 && 
                    Math.abs(z.lng - zone.lng) < 0.0001
                );
                
                // Open drawer directly, no InfoWindow
                if (fullZone) {
                    openZoneDrawer(fullZone);
                }
            });

            // Marker
            const marker = new google.maps.Marker({
                position: { lat: zone.lat, lng: zone.lng },
                map: riskMap,
                icon: {
                    path: google.maps.SymbolPath.CIRCLE,
                    fillColor: colour,
                    fillOpacity: 1,
                    strokeColor: '#ffffff',
                    strokeWeight: 2,
                    scale: 12,
                    labelOrigin: new google.maps.Point(0, 4)
                },
                label: {
                    text: zone.count.toString(),
                    color: '#ffffff',
                    fontSize: '11px',
                    fontWeight: 'bold'
                }
            });

            // Click marker also opens drawer (no InfoWindow)
            marker.addListener('click', function() {
                const fullZone = zoneReportsData.find(z => 
                    Math.abs(z.lat - zone.lat) < 0.0001 && 
                    Math.abs(z.lng - zone.lng) < 0.0001
                );
                if (fullZone) {
                    openZoneDrawer(fullZone);
                }
            });

            bounds.extend({ lat: zone.lat, lng: zone.lng });
        });

        if (riskZones.length > 0) {
            riskMap.fitBounds(bounds, { padding: 50 });
        }
    }
}

// ============================================================
// Zone Drawer Functions (Click to Drill Down)
// ============================================================

function openZoneDrawer(zone) {
    const overlay = document.getElementById('zoneDrawerOverlay');
    const panel = document.getElementById('zoneDrawerPanel');
    const body = document.getElementById('zoneDrawerBody');
    const title = document.getElementById('zoneNameDisplay');
    
    // Set drawer title
    title.textContent = zone.name || 'Unknown Area';
    
    const reports = zone.reports || [];
    const riskLevel = zone.risk || 'Green';
    const riskColor = riskLevel === 'Red' ? '#dc3545' : riskLevel === 'Orange' ? '#fd7e14' : '#28a745';
    const riskTagClass = riskLevel === 'Red' ? 'risk-tag-red' : riskLevel === 'Orange' ? 'risk-tag-orange' : 'risk-tag-green';
    
    if (reports.length === 0) {
        body.innerHTML = `
            <div class="no-reports">
                <i class='bx bx-check-circle'></i>
                <p>No reports found for this area.</p>
            </div>
        `;
    } else {
        let html = `
            <div class="zone-summary">
                <span class="total"><strong>${reports.length}</strong> report${reports.length > 1 ? 's' : ''} found</span>
                <span class="risk-level" style="color:${riskColor};">${riskLevel}</span>
            </div>
        `;
        
        // Sort reports by created_at (newest first)
        const sortedReports = [...reports].sort((a, b) => {
            return new Date(b.created_at) - new Date(a.created_at);
        });
        
        sortedReports.forEach(function(report) {
            const formattedDate = report.created_at ? new Date(report.created_at).toLocaleString() : 'N/A';
            const urgencyLevel = report.urgency_level || 'Normal';
            const urgencyIcon = urgencyLevel === 'Emergency' ? '🔴' : urgencyLevel === 'High' ? '🟠' : '🟢';
            const ticketId = report.ticket_id || 'N/A';
            const category = report.category || 'N/A';
            const location = report.location || 'N/A';
            
            html += `
                <div class="report-item">
                    <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:6px;">
                        <span class="ticket-id">${ticketId}</span>
                        <span class="risk-tag-sm ${riskTagClass}">${riskLevel}</span>
                    </div>
                    <div class="report-meta">
                        <span>📂 ${category}</span>
                        <span>📍 ${location}</span>
                        <span>${urgencyIcon} ${urgencyLevel}</span>
                        <span>🕐 ${formattedDate}</span>
                    </div>
                </div>
            `;
        });
        
        body.innerHTML = html;
    }
    
    // Show drawer
    overlay.classList.add('active');
    panel.classList.add('active');
    document.body.style.overflow = 'hidden';
}

function closeZoneDrawer() {
    document.getElementById('zoneDrawerOverlay').classList.remove('active');
    document.getElementById('zoneDrawerPanel').classList.remove('active');
    document.body.style.overflow = '';
}

// Refresh the map when the window size changes.
window.addEventListener('resize', function() {
    if (riskMap) {
        setTimeout(function() {
            google.maps.event.trigger(riskMap, 'resize');
        }, 200);
    }
});

// ============================================================
// Chart.js 
// ============================================================
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

// ============================================================
// DOMContentLoaded event
// ============================================================
document.addEventListener('DOMContentLoaded', function() {
    initChart();
});

// ============================================================
// PDF Export function
// ============================================================
function exportPDF() {
    const element = document.getElementById('pdfContent');
    if (!element) {
        alert('PDF content not found. Please refresh and try again.');
        return;
    }
    
    const hasData = <?= !empty($zones) ? 'true' : 'false' ?>;
    if (!hasData) {
        alert('No data available to export. Please ensure there are validated reports.');
        return;
    }
    
    const button = document.querySelector('.btn-filter-pdf');
    const originalText = button.innerHTML;
    button.innerHTML = '<i class="bx bx-loader bx-spin"></i> Generating...';
    button.disabled = true;
    
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
        pdf.save('Risk_Analysis_Report_' + new Date().toISOString().slice(0,10) + '.pdf');
        
        element.style.display = 'none';
        element.style.position = '';
        element.style.zIndex = '';
        element.style.width = '';
        element.style.maxWidth = '';
        element.style.top = '';
        element.style.left = '';
        
        button.innerHTML = originalText;
        button.disabled = false;
    }).catch(function(error) {
        console.error('PDF generation error:', error);
        element.style.display = 'none';
        element.style.position = '';
        element.style.zIndex = '';
        element.style.width = '';
        element.style.maxWidth = '';
        element.style.top = '';
        element.style.left = '';
        
        button.innerHTML = originalText;
        button.disabled = false;
        alert('Error generating PDF. Please try again.');
    });
}
</script>

<?php

render_admin_end();

?>
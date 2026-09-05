<?php
declare(strict_types=1);

// CLI-only visual fixture. It renders the template portion, never the guards,
// queries, credentials, approval handlers, or live application data.
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
set_error_handler(static function (int $severity, string $message, string $file, int $line): never {
    throw new ErrorException($message, 0, $severity, $file, $line);
});
function escape(?string $value): string { return htmlspecialchars($value ?? '', ENT_QUOTES, 'UTF-8'); }
function csrf_token(): string { return 'fixture-no-authentication'; }
function take_flash(): ?array { return null; }
function mask_identity(string $value): string { return $value; }
require dirname(__DIR__) . '/includes/sidebar.php';
$layout = file_get_contents(dirname(__DIR__) . '/includes/layout.php');
$layout = preg_replace('/^<\?php\s*declare\(strict_types=1\);/', '', $layout);
$layout = preg_replace('/^require_once .*;\s*$/m', '', $layout);
eval($layout);

$outputDir = dirname(__DIR__, 2) . '/build/admin_ui_preview';
if (!is_dir($outputDir)) mkdir($outputDir, 0777, true);
if (!is_dir($outputDir . '/assets')) mkdir($outputDir . '/assets');
foreach (['html.css', 'workspace.css'] as $asset) {
    copy(dirname(__DIR__) . '/assets/' . $asset, $outputDir . '/assets/' . $asset);
}

function preview_page(string $file, string $destination, string $tab = 'approve'): void {
    $_SERVER['SCRIPT_NAME'] = '/' . $file;
    $admin = ['full_name' => 'Preview Administrator', 'profile_image' => null];
    $loadError = $actionMessage = $actionError = null;
    $successMessage = $errorMessage = $currentProfileImage = null;
    $currentName = 'Preview Administrator'; $currentPhone = $currentNationality = '';
    $touristApproved = 24; $touristRejected = 3; $touristPending = 8;
    $citizenApproved = 18; $citizenRejected = 2; $citizenPending = 5;
    $registrationApproved = 42; $registrationRejected = 5; $registrationPending = 13;
    $citizenValidated = 16; $citizenRejectedReports = 4; $citizenReportsCount = 7;
    $pendingCount = $file === 'admin_dashboard.php' ? 20 : 0; $emergencyCount = 0;
    $top5RiskAreas = $emergencyReports = [];
    $totalTourists = $totalCitizens = $totalReports = $totalRecords = $approvedCount = $rejectedCount = $resolvedCount = 0;
    $page = $currentPage = $totalPages = 1; $perPage = 10; $offset = 0;
    $statusFilter = 'all'; $urgencyFilter = 'all'; $dateFrom = $dateTo = $searchQuery = '';
    $tourists = $citizens = $reports = $applications = $filteredReports = $items = [];
    $totalItems = 0; $supabaseUrl = '';
    $zones = $validatedReports = []; $regionFilter = $severityFilter = '';
    $sortBy = 'newest'; $activeTab = $tab;
    $metrics = array_fill_keys(['red_zones','orange_zones','green_zones','total_reports','high_risk_reports','medium_risk_reports','low_risk_reports','red_percentage','orange_percentage','green_percentage'], 0);
    $startDate = $endDate = ''; $reportGeneratedAt = 'Sample preview';
    $riskSummary = ['total_reports'=>0,'total_zones'=>0,'has_critical_zones'=>false,'orange_zone_count'=>0,'overall_risk_level'=>'Low','status_message'=>'Sample data only'];
    $riskDistribution = array_fill_keys(['red','orange','green'], ['zones'=>0,'reports'=>0,'percentage'=>0]);
    $topRiskLocations = $categoryAnalysis = $dateTrend = $recommendations = [];
    $pendingApplications = $filteredTourists = $allTourists = [];
    $totalFiltered = $totalTourists = $approvedVisas = $pendingVisas = $expiredVisas = 0;
    $lookAheadData = ['7d' => 0, '14d' => 0, '30d' => 0];
    $visaFilter = 'all'; $searchQuery = ''; $visaStats = []; $reportStats = [];
    $lookAheadDataByVisa = []; $reportVisaFilter = 'all';
    $reportTotal = $reportGreen = $reportYellow = $reportRed = $avgStay = 0; $trendData = [];
    $source = file_get_contents(dirname(__DIR__) . '/' . $file);
    $start = strpos($source, 'render_admin_start(');
    if ($start === false) throw new RuntimeException('Template not found: ' . $file);
    // Include just the render call and what follows; the backend prefix is never executed.
    ob_start();
    eval(substr($source, $start));
    $html = ob_get_clean();
    preg_match('#<ul class="nav-list".*?</ul>#s', $html, $navigation);
    preg_match_all('/<a href="([^"]+)"/', $navigation[0] ?? '', $links);
    $expectedLinks = ['admin_dashboard.php','risk_map.php','approve_tourist.php','approve_citizen.php','approve_citizen_report.php','visa_management.php','profile.php'];
    if (($links[1] ?? []) !== $expectedLinks || substr_count($navigation[0], 'aria-current="page"') !== 1) {
        throw new RuntimeException('Navigation order or current-page indicator failed: ' . $file);
    }
    if ($file === 'admin_dashboard.php') {
        $previous = -1;
        foreach (['<section class="dashboard-metrics"', '<section class="chart-section"', 'class="two-col-grid"'] as $section) {
            $position = strpos($html, $section);
            if ($position === false || $position <= $previous) throw new RuntimeException('Dashboard section order failed.');
            $previous = $position;
        }
    } elseif (str_contains($html, 'page-header workspace-duplicate-title')) {
        throw new RuntimeException('Workflow page title must remain visible.');
    }
    // Never execute workflow scripts, external maps, handlers or data fetches.
    $html = preg_replace_callback('#<script\b[^>]*>.*?</script>#si', static function ($match) use ($file) {
        // Dashboard charts are presentation-only and contain the fixture counts.
        $dashboardChart = $file === 'admin_dashboard.php' && (
            str_contains($match[0], 'https://cdn.jsdelivr.net/npm/chart.js') ||
            str_contains($match[0], '// Chart 1: Tourist Doughnut')
        );
        return str_contains($match[0], 'function toggleSidebar()') || $dashboardChart ? $match[0] : '';
    }, $html);
    $html = preg_replace('/href="([a-z_]+)\.php([^"]*)"/', 'href="$1.html$2"', $html);
    if ($file === 'visa_management.php') {
        $html = str_replace(['href="?tab=approve"', 'href="?tab=monitor"', 'href="?tab=reports"'], ['href="visa_management.html"', 'href="visa_monitor.html"', 'href="visa_reports.html"'], $html);
    }
    $html = preg_replace('/\s+on[a-z]+=("[^"]*"|\x27[^\x27]*\x27)/i', '', $html);
    $notice = '<div style="background:#fcf4e7;color:#76541e;padding:10px 20px;font:12px sans-serif">UI PREVIEW · Sample data only · Forms and workflow actions disabled</div>';
    $html = str_replace('<main class="main-content">', '<main class="main-content">' . $notice, $html);
    $html = str_replace('</head>', '<script>document.addEventListener("submit",e=>e.preventDefault(),true);</script></head>', $html);
    file_put_contents($destination, $html);
    echo "Rendered $file (sample data only)\n";
}

$pages = $argv[1] ?? 'admin_dashboard.php';
foreach (explode(',', $pages) as $file) {
    if (!in_array($file, ['admin_dashboard.php','approve_tourist.php','approve_citizen.php','approve_citizen_report.php','risk_map.php','visa_management.php','profile.php'], true)) {
        throw new RuntimeException('Unsupported preview page.');
    }
    preview_page($file, $outputDir . '/' . str_replace('.php', '.html', $file));
    if ($file === 'visa_management.php') {
        preview_page($file, $outputDir . '/visa_monitor.html', 'monitor');
        preview_page($file, $outputDir . '/visa_reports.html', 'reports');
    }
}

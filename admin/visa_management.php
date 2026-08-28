<?php declare(strict_types=1);
require_once __DIR__ . '/includes/admin_guard.php';
require_once __DIR__ . '/includes/layout.php';
require_once __DIR__ . '/services/visa_service.php';
$admin = require_admin();
$visaService = new VisaService();

$activeTab = $_GET['tab'] ?? 'approve';
if (!in_array($activeTab, ['approve', 'monitor', 'reports'], true)) $activeTab = 'approve';

// ============================================================
// Monitor 筛选参数 (含 Visa Type)
// ============================================================
$statusFilter = $_GET['status_filter'] ?? 'all';
$visaFilter   = $_GET['visa_filter'] ?? 'all';
$searchQuery  = trim($_GET['search'] ?? '');
$sortBy       = $_GET['sort_by'] ?? 'remaining_asc';

// ============================================================
// 处理 POST (Approve / Reject)
// ============================================================
if ($_SERVER['REQUEST_METHOD'] === 'POST' && $activeTab === 'approve') {
    $action = $_POST['action'] ?? '';
    $submissionId = $_POST['submission_id'] ?? null;
    try { verify_csrf($_POST['csrf_token'] ?? null); } catch (RuntimeException $e) {
        flash('error', $e->getMessage());
        redirect('visa_management.php?tab=approve');
    }
    if ($action === 'approve') {
        $effectiveDate = $_POST['visa_effective_date'] ?? '';
        try { $visaService->approveVisa($submissionId, $effectiveDate, $admin) ? flash('success', 'Visa approved.') : flash('error', 'Failed.'); }
        catch (Throwable $e) { flash('error', $e->getMessage()); }
        redirect('visa_management.php?tab=approve');
    } elseif ($action === 'reject') {
        $reason = trim($_POST['rejection_reason'] ?? '');
        try { $visaService->rejectVisa($submissionId, $reason, $admin) ? flash('success', 'Visa rejected.') : flash('error', 'Failed.'); }
        catch (Throwable $e) { flash('error', $e->getMessage()); }
        redirect('visa_management.php?tab=approve');
    }
}

// ============================================================
// 加载数据
// ============================================================
$pendingApplications = $visaService->getPendingApplications();
$approvedTourists = $visaService->getApprovedTourists();
$overstayCount = $visaService->getOverstayCount();
$statusDistribution = $visaService->getStatusDistribution();
$trendData = $visaService->getTrendData();

// ============================================================
// Monitor 筛选逻辑 (含 Visa Type)
// ============================================================
$filteredTourists = $approvedTourists;
foreach ($filteredTourists as &$t) {
    $now = new DateTime();
    if (!empty($t['stay_until_date'])) {
        $stayUntil = new DateTime($t['stay_until_date']);
        $diff = $now->diff($stayUntil);
        $t['_remaining'] = $stayUntil > $now ? $diff->days : -$diff->days;
        $t['_status'] = $t['_remaining'] > 10 ? 'green' : ($t['_remaining'] >= 0 ? 'yellow' : 'red');
        $t['_has_entry'] = true;
    } else {
        $t['_remaining'] = null;
        $t['_status'] = 'inactive';
        $t['_has_entry'] = false;
    }
    $t['_visa_active'] = $visaService->isVisaActive($t);
}
unset($t);

// --- Visa Type 过滤 (FR2.3) ---
if ($visaFilter !== 'all') {
    $filteredTourists = array_filter($filteredTourists, function($t) use ($visaFilter) {
        return ($t['visa_type'] ?? 'SEV') === $visaFilter;
    });
}
// --- Status 过滤 ---
if ($statusFilter !== 'all') {
    $filteredTourists = array_filter($filteredTourists, function($t) use ($statusFilter) {
        return $t['_status'] === $statusFilter;
    });
}
// --- 搜索 ---
if ($searchQuery !== '') {
    $searchLower = strtolower($searchQuery);
    $filteredTourists = array_filter($filteredTourists, function($t) use ($searchLower) {
        return strpos(strtolower($t['full_name'] ?? ''), $searchLower) !== false ||
               strpos(strtolower($t['passport_number'] ?? ''), $searchLower) !== false;
    });
}
// --- 排序 ---
if ($sortBy === 'remaining_asc') {
    usort($filteredTourists, function($a, $b) { return ($a['_remaining'] ?? 9999) - ($b['_remaining'] ?? 9999); });
} elseif ($sortBy === 'remaining_desc') {
    usort($filteredTourists, function($a, $b) { return ($b['_remaining'] ?? -9999) - ($a['_remaining'] ?? -9999); });
} elseif ($sortBy === 'name_asc') {
    usort($filteredTourists, function($a, $b) { return strcmp($a['full_name'] ?? '', $b['full_name'] ?? ''); });
} elseif ($sortBy === 'name_desc') {
    usort($filteredTourists, function($a, $b) { return strcmp($b['full_name'] ?? '', $a['full_name'] ?? ''); });
}
$totalFiltered = count($filteredTourists);

// ============================================================
// Expiry Look-ahead (FR2.7)
// ============================================================
$now = new DateTime();
$lookAheadData = ['7d' => 0, '14d' => 0, '30d' => 0];
$lookAheadDataByVisa = ['SEV' => ['7d' => 0, '14d' => 0, '30d' => 0], 'MEV' => ['7d' => 0, '14d' => 0, '30d' => 0]];

// 基于 $approvedTourists (全部，未过滤)
foreach ($approvedTourists as $t) {
    if (empty($t['stay_until_date'])) continue;
    $stayUntil = new DateTime($t['stay_until_date']);
    if ($stayUntil <= $now) continue; // 已过期不计入
    $diff = $now->diff($stayUntil)->days;
    $visaType = $t['visa_type'] ?? 'SEV';
    if ($diff <= 7) {
        $lookAheadData['7d']++;
        $lookAheadDataByVisa[$visaType]['7d']++;
    }
    if ($diff <= 14) {
        $lookAheadData['14d']++;
        $lookAheadDataByVisa[$visaType]['14d']++;
    }
    if ($diff <= 30) {
        $lookAheadData['30d']++;
        $lookAheadDataByVisa[$visaType]['30d']++;
    }
}

// ============================================================
// 报表数据 (按签证类型筛选)
// ============================================================
$reportVisaFilter = $_GET['report_visa'] ?? 'all';
$reportFiltered = $approvedTourists;
if ($reportVisaFilter !== 'all') {
    $reportFiltered = array_filter($reportFiltered, function($t) use ($reportVisaFilter) {
        return ($t['visa_type'] ?? 'SEV') === $reportVisaFilter;
    });
}
// 计算报表统计
$reportTotal = count($reportFiltered);
$reportGreen = $reportYellow = $reportRed = 0;
$stayDurations = [];
foreach ($reportFiltered as $t) {
    if (!empty($t['stay_until_date'])) {
        $stayUntil = new DateTime($t['stay_until_date']);
        $remaining = $now->diff($stayUntil)->days;
        if ($stayUntil > $now && $remaining > 10) $reportGreen++;
        elseif ($stayUntil > $now && $remaining <= 10) $reportYellow++;
        else $reportRed++;
    }
    // 计算停留时长 (从 entry_date 到 stay_until_date)
    if (!empty($t['entry_date']) && !empty($t['stay_until_date'])) {
        $entry = new DateTime($t['entry_date']);
        $until = new DateTime($t['stay_until_date']);
        $stayDurations[] = $entry->diff($until)->days;
    }
}
$avgStay = count($stayDurations) > 0 ? round(array_sum($stayDurations) / count($stayDurations), 1) : 0;

render_admin_start('Visa Approval & Monitor', $admin, 'visa');
?>

<style>
/* ===== 原有样式 ===== */
.visa-tabs{display:flex;gap:6px;margin-bottom:24px;flex-wrap:wrap;background:#fff;padding:12px 16px;border-radius:14px;border:1px solid #f1f3f5}.visa-tabs .tab-btn{padding:8px 24px;border:1px solid #e5e7eb;border-radius:20px;background:#fff;cursor:pointer;font-size:13px;font-weight:500;color:#4b5563;text-decoration:none;transition:all .2s}.visa-tabs .tab-btn:hover{background:#f3f4f6}.visa-tabs .tab-btn.active{background:#1a1a2e;color:#fff;border-color:#1a1a2e}.visa-tabs .tab-btn i{margin-right:4px}.tab-content{display:none}.tab-content.active{display:block}
.filter-bar{display:flex;flex-direction:column;gap:12px;padding:16px 18px;background:#fff;border-radius:14px;border:1px solid #f1f3f5;box-shadow:0 1px 3px rgba(0,0,0,.04);margin-bottom:16px}
.filter-row{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap}
.filter-group{display:flex;gap:6px;flex-wrap:wrap;align-items:center}
.filter-btn{padding:4px 16px;border:1px solid #e5e7eb;border-radius:20px;background:#fff;cursor:pointer;font-size:12px;color:#4b5563;text-decoration:none;transition:all .2s;font-weight:500}
.filter-btn:hover{background:#f3f4f6;border-color:#d1d5db}
.filter-btn.active{background:#1a1a2e;color:#fff;border-color:#1a1a2e}
.filter-btn.active-green{background:#10b981;color:#fff;border-color:#10b981}
.filter-btn.active-yellow{background:#f59e0b;color:#fff;border-color:#f59e0b}
.filter-btn.active-red{background:#dc3545;color:#fff;border-color:#dc3545}
.filter-label{font-size:11px;font-weight:600;color:#6b7280;text-transform:uppercase;letter-spacing:.05em}
.filter-input{padding:6px 12px;border:1px solid #e5e7eb;border-radius:8px;font-size:12px;background:#fff;transition:border-color .2s;color:#1a1a2e}
.filter-input:focus{outline:none;border-color:#1a1a2e;box-shadow:0 0 0 3px rgba(26,26,46,.08)}
.filter-input-sm{padding:4px 10px;font-size:12px;border:1px solid #e5e7eb;border-radius:6px;background:#fff;min-width:140px}
.btn-filter{padding:6px 16px;font-size:12px;border:none;border-radius:8px;cursor:pointer;font-weight:500;transition:all .2s;display:inline-flex;align-items:center;gap:4px}
.btn-filter-primary{background:#1a1a2e;color:#fff}.btn-filter-primary:hover{background:#2d2d4e}
.btn-filter-reset{background:#f3f4f6;color:#4b5563;border:1px solid #e5e7eb}.btn-filter-reset:hover{background:#e5e7eb}
.filter-stats{font-size:13px;color:#6b7280;font-weight:500}
.status-badge{display:inline-block;padding:3px 12px;border-radius:12px;font-size:11px;font-weight:600}
.status-pending{background:#fef3c7;color:#92400e}
.status-approved{background:#dbeafe;color:#1e40af}
.status-green{background:#d1fae5;color:#065f46}
.status-yellow{background:#fef3c7;color:#92400e}
.status-red{background:#fee2e2;color:#991b1b}
.status-inactive{background:#f3f4f6;color:#6b7280}
.status-active{background:#d1fae5;color:#065f46}
.monitor-table{width:100%;border-collapse:collapse;font-size:13px}
.monitor-table th{background:#f8fafc;padding:10px 14px;text-align:left;font-size:11px;text-transform:uppercase;color:#4b5563;border-bottom:2px solid #e5e7eb}
.monitor-table td{padding:10px 14px;border-bottom:1px solid #f1f3f5;vertical-align:middle;cursor:pointer}
.monitor-table tr:hover td{background:#f8fafc}
.summary-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:12px;margin-bottom:20px}
.summary-card{background:#fff;border:1px solid #f1f3f5;border-radius:12px;padding:16px;text-align:center}
.summary-card .num{font-size:26px;font-weight:700;color:#1a1a2e}
.summary-card .label{font-size:12px;color:#6b7280}
.trend-bar-wrap{display:flex;gap:8px;flex-wrap:wrap;align-items:flex-end;height:120px;padding:8px 0}
.trend-bar-item{flex:1;display:flex;flex-direction:column;align-items:center}
.trend-bar-item .val{font-size:12px;font-weight:600;color:#1a1a2e}
.trend-bar-item .bar{width:100%;background:#dbeafe;border-radius:4px 4px 0 0;height:8px;min-height:8px;transition:height .3s}
.trend-bar-item .lbl{font-size:10px;color:#6b7280;margin-top:4px}

/* Look-ahead Cards */
.lookahead-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:16px}
.lookahead-card{background:#fff;border:1px solid #f1f3f5;border-radius:12px;padding:16px;text-align:center;transition:transform .2s}
.lookahead-card:hover{transform:translateY(-2px)}
.lookahead-card .num{font-size:28px;font-weight:700;color:#1a1a2e}
.lookahead-card .label{font-size:12px;color:#6b7280;margin-top:4px}
.lookahead-card .sub{font-size:11px;color:#9ca3af;margin-top:2px}

/* Reports Chart area */
.report-chart-wrap{display:grid;grid-template-columns:1fr 1fr;gap:20px;align-items:center;padding:16px 0}
.chart-container{position:relative;height:220px;max-width:300px;margin:0 auto}
.chart-stats-list{display:flex;flex-direction:column;gap:8px}
.chart-stat-item{display:flex;align-items:center;gap:12px;padding:8px 12px;background:#f8fafc;border-radius:8px;border-left:4px solid #ccc}
.chart-stat-item .color-dot{width:12px;height:12px;border-radius:50%;flex-shrink:0}
.chart-stat-item .stat-info{flex:1}
.chart-stat-item .stat-info .label{font-size:12px;color:#6b7280}
.chart-stat-item .stat-info .value{font-weight:600;font-size:14px;color:#1a1a2e}

/* Report filter row */
.report-filter{display:flex;gap:10px;margin-bottom:16px;flex-wrap:wrap;align-items:center}
.report-filter .filter-label{font-size:11px;font-weight:600;color:#6b7280;text-transform:uppercase}

/* ===== 右侧抽屉 ===== */
.drawer-overlay{display:none;position:fixed;inset:0;background:rgba(0,0,0,0.4);z-index:999}
.drawer-overlay.active{display:block}
.drawer-panel{position:fixed;top:0;right:-650px;width:650px;max-width:95vw;height:100vh;background:#fff;z-index:1000;transition:right .3s ease;box-shadow:-4px 0 20px rgba(0,0,0,.15);overflow-y:auto;display:flex;flex-direction:column}
.drawer-panel.active{right:0}
.drawer-header{display:flex;justify-content:space-between;align-items:center;padding:20px 24px;border-bottom:1px solid #f1f3f5;background:#fff;position:sticky;top:0;z-index:10;flex-shrink:0}
.drawer-header h2{margin:0;font-size:18px;font-weight:600;color:#1a1a2e}
.drawer-header h2 i{color:#2563eb}
.drawer-close{background:none;border:none;font-size:28px;cursor:pointer;color:#6b7280;padding:0 8px;line-height:1;transition:color .2s}
.drawer-close:hover{color:#1a1a2e}
.drawer-body{padding:24px;flex:1;overflow-y:auto}
.drawer-body .detail-section{margin-bottom:20px}
.drawer-body .detail-section:last-child{margin-bottom:0}
.drawer-body .detail-label{font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.05em;color:#6b7280;margin-bottom:4px;display:block}
.drawer-body .detail-value{font-size:15px;color:#1a1a2e;font-weight:500}
.drawer-body .detail-divider{border:none;border-top:1px solid #f1f3f5;margin:16px 0}
.drawer-body .history-item{display:flex;align-items:center;gap:12px;padding:10px 12px;border-bottom:1px solid #f1f3f5}
.drawer-body .history-item:last-child{border-bottom:none}
.drawer-body .history-item .h-time{font-size:12px;color:#6b7280;min-width:110px}
.drawer-body .history-item .h-status{font-weight:600;font-size:13px}
.drawer-body .history-item .h-source{font-size:11px;color:#6b7280}
.drawer-body .no-history{text-align:center;padding:20px;color:#6b7280}
@keyframes spin{from{transform:rotate(0deg)}to{transform:rotate(360deg)}}
.loading-spinner{text-align:center;padding:40px 20px;color:#6b7280}
.loading-spinner i{font-size:32px;display:block;margin-bottom:8px;animation:spin 1s linear infinite}

/* Responsive */
@media(max-width:768px){.drawer-panel{width:100vw;max-width:100vw;right:-100vw}.filter-row{flex-direction:column;align-items:stretch}.filter-group{justify-content:center}.monitor-table{font-size:12px}.monitor-table th,.monitor-table td{padding:8px 10px}.report-chart-wrap{grid-template-columns:1fr;gap:12px}.lookahead-grid{grid-template-columns:1fr 1fr}}
@media(max-width:480px){.drawer-panel{width:100vw;right:-100vw}.summary-grid{grid-template-columns:1fr 1fr}.trend-bar-wrap{height:80px;gap:4px}.filter-input-sm{min-width:100px;width:100%}.lookahead-grid{grid-template-columns:1fr}}
</style>

<div class="visa-page">
    <!-- Tabs -->
    <div class="visa-tabs">
        <a href="?tab=approve" class="tab-btn <?= $activeTab === 'approve' ? 'active' : '' ?>"><i class='bx bx-check-square'></i> Approve Visa</a>
        <a href="?tab=monitor" class="tab-btn <?= $activeTab === 'monitor' ? 'active' : '' ?>"><i class='bx bx-time'></i> Monitor Status</a>
        <a href="?tab=reports" class="tab-btn <?= $activeTab === 'reports' ? 'active' : '' ?>"><i class='bx bx-stats'></i> Reports</a>
    </div>

    <!-- ===== TAB 1: Approve Visa ===== -->
    <div class="tab-content <?= $activeTab === 'approve' ? 'active' : '' ?>">
        <?php if (empty($pendingApplications)): ?>
            <div class="card" style="text-align:center;padding:40px;">
                <i class='bx bx-check-circle' style="font-size:48px;color:#10b981;"></i>
                <h3 style="margin:12px 0 4px;">No Pending Applications</h3>
                <p style="color:#6b7280;">All visa applications have been processed.</p>
            </div>
        <?php else: foreach ($pendingApplications as $app): ?>
            <div class="approval-card" style="background:#fff;border-radius:16px;border:1px solid #f1f3f5;overflow:hidden;margin-bottom:16px">
                <div class="card-header" style="cursor:pointer;padding:16px 20px;border-bottom:1px solid #f1f3f5;background:#fafbfc;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;transition:background .2s;user-select:none" onclick="toggleCard('<?= escape($app['id']) ?>')">
                    <div class="header-left" style="display:flex;align-items:center;gap:14px;flex-wrap:wrap">
                        <span style="font-weight:700;font-size:15px;color:#1a1a2e"><?= escape($app['reference_id']) ?></span>
                        <span style="font-size:12px;color:#6b7280"><i class='bx bx-time'></i> <?= date('d M Y H:i', strtotime($app['submitted_at'])) ?></span>
                    </div>
                    <div class="header-right" style="display:flex;align-items:center;gap:12px">
                        <span class="status-badge status-pending">Pending</span>
                        <span style="font-size:20px;color:#6b7280;transition:transform .3s" id="toggle_<?= escape($app['id']) ?>"><i class='bx bx-chevron-down'></i></span>
                    </div>
                </div>
                <div class="card-body" style="display:none;padding:20px" id="body_<?= escape($app['id']) ?>">
                    <div style="display:grid;grid-template-columns:1fr 1fr;gap:24px">
                        <div style="display:flex;flex-direction:column;gap:6px">
                            <div class="info-row"><span class="label">Applicant</span><span class="value"><?= escape($app['full_name']) ?></span></div>
                            <div class="info-row"><span class="label">Passport</span><span class="value"><?= escape($app['passport_number']) ?></span></div>
                            <div class="info-row"><span class="label">Nationality</span><span class="value"><?= escape($app['nationality']) ?></span></div>
                            <div class="info-row"><span class="label">Arrival</span><span class="value"><?= escape($app['arrival_date']) ?></span></div>
                            <div class="info-row"><span class="label">Departure</span><span class="value"><?= escape($app['departure_date']) ?></span></div>
                            <div class="info-row"><span class="label">Visa Type</span><span class="value"><?= escape($app['visa_type'] ?? 'SEV') ?></span></div>
                        </div>
                        <div style="display:flex;flex-direction:column;gap:6px">
                            <?php if (!empty($app['pdf_url'])): ?>
                            <div class="info-row"><span class="label">Document</span><span class="value"><a href="<?= escape($app['pdf_url']) ?>" target="_blank" style="color:#2563eb;text-decoration:none;font-weight:500"><i class='bx bx-file-pdf'></i> View PDF</a></span></div>
                            <?php endif; ?>
                            <hr style="border:none;border-top:1px solid #f1f3f5;margin:8px 0 12px">
                            <form method="post" style="display:flex;flex-direction:column;gap:10px">
                                <input type="hidden" name="csrf_token" value="<?= escape(csrf_token()) ?>">
                                <input type="hidden" name="submission_id" value="<?= escape($app['id']) ?>">
                                <div><span style="font-size:11px;color:#6b7280;text-transform:uppercase;font-weight:600">Effective Date</span><input type="date" name="visa_effective_date" value="<?= date('Y-m-d') ?>" style="padding:6px 12px;border:1px solid #e5e7eb;border-radius:8px;font-size:13px;background:#fff;max-width:180px"></div>
                                <div><span style="font-size:11px;color:#6b7280;text-transform:uppercase;font-weight:600">Rejection Reason <span style="font-weight:400;text-transform:none;color:#9ca3af">(optional)</span></span><textarea name="rejection_reason" style="padding:8px 12px;border:1px solid #e5e7eb;border-radius:8px;resize:vertical;font-size:13px;font-family:inherit;min-height:50px;width:100%" rows="2" placeholder="Enter reason if rejecting..."></textarea></div>
                                <div style="display:flex;gap:10px;margin-top:4px">
                                    <button type="submit" name="action" value="approve" style="padding:8px 24px;border:none;border-radius:8px;font-weight:600;font-size:14px;cursor:pointer;transition:all .2s;display:inline-flex;align-items:center;gap:6px;background:#10b981;color:#fff">Approve</button>
                                    <button type="submit" name="action" value="reject" style="padding:8px 24px;border:none;border-radius:8px;font-weight:600;font-size:14px;cursor:pointer;transition:all .2s;display:inline-flex;align-items:center;gap:6px;background:#ef4444;color:#fff">Reject</button>
                                </div>
                            </form>
                        </div>
                    </div>
                </div>
            </div>
        <?php endforeach; endif; ?>
    </div>

    <!-- ===== TAB 2: Monitor Status ===== -->
    <div class="tab-content <?= $activeTab === 'monitor' ? 'active' : '' ?>">

        <!-- Expiry Look-ahead (FR2.7) -->
        <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px;margin-bottom:8px;">
            <span style="font-weight:600;font-size:16px;">📊 Expiry Look-ahead</span>
            <span style="font-size:12px;color:#6b7280;">Based on stay_until_date</span>
        </div>
        <div class="lookahead-grid">
            <div class="lookahead-card">
                <div class="num"><?= $lookAheadData['7d'] ?></div>
                <div class="label">Next 7 Days</div>
                <div class="sub">SEV: <?= $lookAheadDataByVisa['SEV']['7d'] ?? 0 ?> · MEV: <?= $lookAheadDataByVisa['MEV']['7d'] ?? 0 ?></div>
            </div>
            <div class="lookahead-card">
                <div class="num"><?= $lookAheadData['14d'] ?></div>
                <div class="label">Next 14 Days</div>
                <div class="sub">SEV: <?= $lookAheadDataByVisa['SEV']['14d'] ?? 0 ?> · MEV: <?= $lookAheadDataByVisa['MEV']['14d'] ?? 0 ?></div>
            </div>
            <div class="lookahead-card">
                <div class="num"><?= $lookAheadData['30d'] ?></div>
                <div class="label">Next 30 Days</div>
                <div class="sub">SEV: <?= $lookAheadDataByVisa['SEV']['30d'] ?? 0 ?> · MEV: <?= $lookAheadDataByVisa['MEV']['30d'] ?? 0 ?></div>
            </div>
        </div>

        <!-- Filter Bar (含 Visa Type) -->
        <div class="filter-bar">
            <div class="filter-row">
                <div class="filter-group">
                    <span class="filter-label">Status:</span>
                    <a href="?tab=monitor&status_filter=all&visa_filter=<?= $visaFilter ?>&search=<?= urlencode($searchQuery) ?>&sort_by=<?= $sortBy ?>" class="filter-btn <?= $statusFilter === 'all' ? 'active' : '' ?>">All</a>
                    <a href="?tab=monitor&status_filter=green&visa_filter=<?= $visaFilter ?>&search=<?= urlencode($searchQuery) ?>&sort_by=<?= $sortBy ?>" class="filter-btn <?= $statusFilter === 'green' ? 'active-green' : '' ?>">Green</a>
                    <a href="?tab=monitor&status_filter=yellow&visa_filter=<?= $visaFilter ?>&search=<?= urlencode($searchQuery) ?>&sort_by=<?= $sortBy ?>" class="filter-btn <?= $statusFilter === 'yellow' ? 'active-yellow' : '' ?>">Yellow</a>
                    <a href="?tab=monitor&status_filter=red&visa_filter=<?= $visaFilter ?>&search=<?= urlencode($searchQuery) ?>&sort_by=<?= $sortBy ?>" class="filter-btn <?= $statusFilter === 'red' ? 'active-red' : '' ?>">Red</a>
                </div>
                <div class="filter-group">
                    <span class="filter-label">Visa Type:</span>
                    <a href="?tab=monitor&visa_filter=all&status_filter=<?= $statusFilter ?>&search=<?= urlencode($searchQuery) ?>&sort_by=<?= $sortBy ?>" class="filter-btn <?= $visaFilter === 'all' ? 'active' : '' ?>">All</a>
                    <a href="?tab=monitor&visa_filter=SEV&status_filter=<?= $statusFilter ?>&search=<?= urlencode($searchQuery) ?>&sort_by=<?= $sortBy ?>" class="filter-btn <?= $visaFilter === 'SEV' ? 'active' : '' ?>">SEV</a>
                    <a href="?tab=monitor&visa_filter=MEV&status_filter=<?= $statusFilter ?>&search=<?= urlencode($searchQuery) ?>&sort_by=<?= $sortBy ?>" class="filter-btn <?= $visaFilter === 'MEV' ? 'active' : '' ?>">MEV</a>
                </div>
                <div class="filter-group">
                    <span class="filter-label">Sort:</span>
                    <select name="sort_by" class="filter-input filter-input-sm" onchange="this.form.submit()" style="padding:4px 10px;border:1px solid #e5e7eb;border-radius:6px;font-size:12px;">
                        <option value="remaining_asc" <?= $sortBy === 'remaining_asc' ? 'selected' : '' ?>>Remaining (ASC)</option>
                        <option value="remaining_desc" <?= $sortBy === 'remaining_desc' ? 'selected' : '' ?>>Remaining (DESC)</option>
                        <option value="name_asc" <?= $sortBy === 'name_asc' ? 'selected' : '' ?>>Name (A-Z)</option>
                        <option value="name_desc" <?= $sortBy === 'name_desc' ? 'selected' : '' ?>>Name (Z-A)</option>
                    </select>
                </div>
            </div>
            <div class="filter-row">
                <form method="get" style="display:flex;gap:8px;flex-wrap:wrap;align-items:center;width:100%;">
                    <input type="hidden" name="tab" value="monitor">
                    <input type="hidden" name="status_filter" value="<?= $statusFilter ?>">
                    <input type="hidden" name="visa_filter" value="<?= $visaFilter ?>">
                    <input type="hidden" name="sort_by" value="<?= $sortBy ?>">
                    <div class="filter-group">
                        <span class="filter-label">Search:</span>
                        <input type="text" name="search" class="filter-input filter-input-sm" placeholder="Name or Passport..." value="<?= htmlspecialchars($searchQuery) ?>" style="min-width:180px;">
                    </div>
                    <div>
                        <button type="submit" class="btn-filter btn-filter-primary"><i class='bx bx-filter'></i> Apply</button>
                        <a href="?tab=monitor" class="btn-filter btn-filter-reset"><i class='bx bx-reset'></i> Reset</a>
                    </div>
                    <span class="filter-stats"><?= $totalFiltered ?> tourist<?= $totalFiltered !== 1 ? 's' : '' ?> found</span>
                </form>
            </div>
        </div>

        <!-- Tourist Table -->
        <?php if (empty($filteredTourists)): ?>
            <div class="card" style="text-align:center;padding:40px;">
                <i class='bx bx-user' style="font-size:48px;color:#6b7280;"></i>
                <h3 style="margin:12px 0 4px;">No Tourists Found</h3>
                <p style="color:#6b7280;">No tourists matching your filter criteria.</p>
            </div>
        <?php else: ?>
            <div class="card" style="padding:0;overflow:hidden;">
                <div style="overflow-x:auto;">
                    <table class="monitor-table">
                        <thead><tr>
                            <th>Name</th><th>Passport</th><th>Visa Type</th>
                            <th>Entry Date</th><th>Stay Until</th>
                            <th>Remaining</th><th>Status</th><th>Active</th>
                        </tr></thead>
                        <tbody>
                            <?php foreach ($filteredTourists as $t):
                                $remaining = $t['_remaining'];
                                $status = $t['_status'];
                                $statusLabel = $remaining !== null && $remaining > 10 ? 'Legal' : ($remaining !== null && $remaining >= 0 ? 'Expiring Soon' : ($remaining !== null ? 'Overstayed' : 'Inactive'));
                                $remainingDisplay = $remaining !== null ? ($remaining >= 0 ? $remaining . 'd' : 'Overdue') : '—';
                                $activeLabel = $t['_visa_active'] ? 'Active' : 'Inactive';
                                $activeClass = $t['_visa_active'] ? 'active' : 'inactive';
                            ?>
                            <tr onclick="openDrawer('<?= escape($t['id']) ?>')">
                                <td><?= escape($t['full_name']) ?></td>
                                <td><?= escape($t['passport_number']) ?></td>
                                <td><?= escape($t['visa_type'] ?? 'SEV') ?></td>
                                <td><?= !empty($t['entry_date']) ? escape($t['entry_date']) : '—' ?></td>
                                <td><?= !empty($t['stay_until_date']) ? escape($t['stay_until_date']) : '—' ?></td>
                                <td><?= $remainingDisplay ?></td>
                                <td><span class="status-badge status-<?= $status ?>"><?= $statusLabel ?></span></td>
                                <td><span class="status-badge status-<?= $activeClass ?>"><?= $activeLabel ?></span></td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        <?php endif; ?>

        <!-- Overstay List -->
        <?php $overstayList = array_filter($filteredTourists, function($t) { return $t['_remaining'] !== null && $t['_remaining'] < 0; });
        if (!empty($overstayList)): ?>
        <div class="card" style="margin-top:16px;">
            <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px;padding:0 0 12px 0;">
                <h4 style="margin:0;color:#dc2626;"><i class='bx bx-alarm'></i> Overstay List (<?= count($overstayList) ?>)</h4>
                <a href="visa_export.php?type=csv&export=overstay" class="btn-filter btn-filter-primary" style="background:#dc2626;text-decoration:none;padding:4px 16px;font-size:12px;border-radius:6px;color:#fff;">
                    <i class='bx bx-download'></i> Export CSV
                </a>
            </div>
            <div style="overflow-x:auto;">
                <table class="monitor-table">
                    <thead><tr><th>Name</th><th>Passport</th><th>Stay Until</th><th>Overstay Days</th></tr></thead>
                    <tbody>
                        <?php foreach ($overstayList as $t):
                            $days = abs($t['_remaining']);
                        ?>
                        <tr>
                            <td><?= escape($t['full_name']) ?></td>
                            <td><?= escape($t['passport_number']) ?></td>
                            <td><?= escape($t['stay_until_date']) ?></td>
                            <td style="color:#dc2626;font-weight:600;"><?= $days ?> days</td>
                        </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
        <?php endif; ?>
    </div>

    <!-- ===== TAB 3: Reports ===== -->
    <div class="tab-content <?= $activeTab === 'reports' ? 'active' : '' ?>">

        <!-- Visa Type Filter for Reports -->
        <div class="report-filter">
            <span class="filter-label">Visa Type:</span>
            <a href="?tab=reports&report_visa=all" class="filter-btn <?= $reportVisaFilter === 'all' ? 'active' : '' ?>">All</a>
            <a href="?tab=reports&report_visa=SEV" class="filter-btn <?= $reportVisaFilter === 'SEV' ? 'active' : '' ?>">SEV</a>
            <a href="?tab=reports&report_visa=MEV" class="filter-btn <?= $reportVisaFilter === 'MEV' ? 'active' : '' ?>">MEV</a>
            <span style="margin-left:auto;font-size:13px;color:#6b7280;"><?= $reportTotal ?> tourist<?= $reportTotal !== 1 ? 's' : '' ?></span>
        </div>

        <!-- Summary Cards -->
        <div class="summary-grid">
            <div class="summary-card"><div class="num"><?= $reportTotal ?></div><div class="label">Total</div></div>
            <div class="summary-card"><div class="num" style="color:#10b981;"><?= $reportGreen ?></div><div class="label">Green</div></div>
            <div class="summary-card"><div class="num" style="color:#f59e0b;"><?= $reportYellow ?></div><div class="label">Yellow</div></div>
            <div class="summary-card"><div class="num" style="color:#dc2626;"><?= $reportRed ?></div><div class="label">Red</div></div>
            <div class="summary-card"><div class="num" style="color:#2563eb;"><?= $avgStay ?></div><div class="label">Avg Stay (days)</div></div>
        </div>

        <!-- Chart + Stats (FR6.4) -->
        <div class="card">
            <h4 style="margin:0 0 8px;">Status Distribution</h4>
            <div class="report-chart-wrap">
                <div class="chart-container">
                    <canvas id="statusChart"></canvas>
                </div>
                <div class="chart-stats-list">
                    <div class="chart-stat-item" style="border-left-color:#10b981;">
                        <span class="color-dot" style="background:#10b981;"></span>
                        <div class="stat-info">
                            <div class="label">Green (Legal)</div>
                            <div class="value"><?= $reportGreen ?> (<?= $reportTotal > 0 ? round($reportGreen/$reportTotal*100,1) : 0 ?>%)</div>
                        </div>
                    </div>
                    <div class="chart-stat-item" style="border-left-color:#f59e0b;">
                        <span class="color-dot" style="background:#f59e0b;"></span>
                        <div class="stat-info">
                            <div class="label">Yellow (Expiring Soon)</div>
                            <div class="value"><?= $reportYellow ?> (<?= $reportTotal > 0 ? round($reportYellow/$reportTotal*100,1) : 0 ?>%)</div>
                        </div>
                    </div>
                    <div class="chart-stat-item" style="border-left-color:#dc2626;">
                        <span class="color-dot" style="background:#dc2626;"></span>
                        <div class="stat-info">
                            <div class="label">Red (Overstayed)</div>
                            <div class="value"><?= $reportRed ?> (<?= $reportTotal > 0 ? round($reportRed/$reportTotal*100,1) : 0 ?>%)</div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Trend (last 7 days) -->
        <div class="card">
            <h4 style="margin:0 0 12px;">Trend (last 7 days)</h4>
            <?php if (!empty($trendData)): ?>
            <div class="trend-bar-wrap">
                <?php foreach ($trendData as $day): ?>
                <div class="trend-bar-item"><div class="val"><?= $day['count'] ?></div><div class="bar" style="height:<?= max(8,$day['count']*12) ?>px;"></div><div class="lbl"><?= date('d M',strtotime($day['date'])) ?></div></div>
                <?php endforeach; ?>
            </div>
            <?php else: ?>
            <p style="color:#6b7280;">No data available for trend.</p>
            <?php endif; ?>
        </div>

        <!-- Export -->
        <div class="card" style="margin-top:16px;">
            <h4 style="margin:0 0 8px;">Export</h4>
            <div style="display:flex;gap:8px;flex-wrap:wrap;">
                <a href="visa_export.php?type=csv&visa=<?= $reportVisaFilter ?>" class="btn-approve" style="background:#2563eb;text-decoration:none;padding:6px 20px;">Export CSV</a>
                <a href="visa_export.php?type=pdf&visa=<?= $reportVisaFilter ?>" class="btn-reject" style="background:#6b7280;text-decoration:none;padding:6px 20px;">Export PDF</a>
            </div>
        </div>
    </div>
</div>

<!-- =========================================================
     右侧抽屉
========================================================= -->
<div class="drawer-overlay" id="drawerOverlay" onclick="closeDrawer()"></div>
<div class="drawer-panel" id="drawerPanel">
    <div class="drawer-header">
        <h2><i class='bx bx-detail'></i> Tourist Details</h2>
        <button class="drawer-close" onclick="closeDrawer()">&times;</button>
    </div>
    <div class="drawer-body" id="drawerBody">
        <div class="loading-spinner">
            <i class='bx bx-loader-alt'></i>
            <p>Loading...</p>
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script>
// ============================================================
// 折叠功能 (Approve Tab)
// ============================================================
function toggleCard(id) {
    const body = document.getElementById('body_' + id);
    const toggle = document.getElementById('toggle_' + id);
    if (body) {
        body.style.display = body.style.display === 'block' ? 'none' : 'block';
        if (toggle) toggle.classList.toggle('open');
    }
}

// ============================================================
// 抽屉功能 (点击行打开详情)
// ============================================================
const touristsData = <?= json_encode($filteredTourists) ?>;

function openDrawer(touristId) {
    const tourist = touristsData.find(t => t.id === touristId);
    if (!tourist) { alert('Record not found'); return; }

    const overlay = document.getElementById('drawerOverlay');
    const panel = document.getElementById('drawerPanel');
    const body = document.getElementById('drawerBody');

    const now = new Date();
    const stayUntil = tourist.stay_until_date ? new Date(tourist.stay_until_date) : null;
    let statusText = 'Inactive';
    let statusClass = 'status-inactive';
    let remainingText = '—';
    if (stayUntil) {
        const diff = stayUntil - now;
        const days = Math.ceil(diff / (1000 * 60 * 60 * 24));
        remainingText = days >= 0 ? days + ' days' : Math.abs(days) + ' days overdue';
        if (days > 10) { statusText = 'Green (Legal)'; statusClass = 'status-green'; }
        else if (days >= 0) { statusText = 'Yellow (Expiring Soon)'; statusClass = 'status-yellow'; }
        else { statusText = 'Red (Overstayed)'; statusClass = 'status-red'; }
    }

    const isActive = tourist._visa_active !== undefined ? tourist._visa_active : true;
    const activeText = isActive ? '✅ Active' : '❌ Inactive';
    const activeClass = isActive ? 'status-active' : 'status-inactive';

    const history = [
        { time: tourist.verified_at || tourist.submitted_at, from: 'Pending', to: 'Approved', source: 'Admin' },
    ];
    if (tourist.entry_date) {
        history.push({ time: tourist.entry_date, from: 'Not Entered', to: 'Active', source: 'System' });
    }

    body.innerHTML = `
        <div class="detail-section">
            <span class="detail-label">Tourist Information</span>
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px 16px;background:#f8fafc;padding:12px 16px;border-radius:8px;">
                <div><span style="color:#6b7280;font-size:12px;">Name</span><div style="font-weight:600;">${tourist.full_name || 'N/A'}</div></div>
                <div><span style="color:#6b7280;font-size:12px;">Passport</span><div style="font-weight:600;">${tourist.passport_number || 'N/A'}</div></div>
                <div><span style="color:#6b7280;font-size:12px;">Nationality</span><div style="font-weight:600;">${tourist.nationality || 'N/A'}</div></div>
                <div><span style="color:#6b7280;font-size:12px;">Visa Type</span><div style="font-weight:600;">${tourist.visa_type || 'SEV'}</div></div>
                <div><span style="color:#6b7280;font-size:12px;">Visa Effective</span><div style="font-weight:600;">${tourist.visa_effective_date || '—'}</div></div>
                <div><span style="color:#6b7280;font-size:12px;">Visa Expiry</span><div style="font-weight:600;">${tourist.visa_expiry_date || '—'}</div></div>
            </div>
        </div>
        <div class="detail-section">
            <span class="detail-label">Travel Information</span>
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px 16px;background:#f8fafc;padding:12px 16px;border-radius:8px;">
                <div><span style="color:#6b7280;font-size:12px;">Planned Arrival</span><div style="font-weight:600;">${tourist.arrival_date || '—'}</div></div>
                <div><span style="color:#6b7280;font-size:12px;">Planned Departure</span><div style="font-weight:600;">${tourist.departure_date || '—'}</div></div>
                <div><span style="color:#6b7280;font-size:12px;font-weight:600;">✅ Actual Entry</span><div style="font-weight:700;color:#2563eb;">${tourist.entry_date || '—'}</div></div>
                <div><span style="color:#6b7280;font-size:12px;font-weight:600;">✅ Actual Departure</span><div style="font-weight:700;color:#2563eb;">${tourist.actual_departure_date || '—'}</div></div>
                <div><span style="color:#6b7280;font-size:12px;">Stay Until</span><div style="font-weight:600;">${tourist.stay_until_date || '—'}</div></div>
                <div><span style="color:#6b7280;font-size:12px;">Remaining</span><div style="font-weight:600;">${remainingText}</div></div>
            </div>
        </div>
        <div class="detail-section">
            <span class="detail-label">Current Status</span>
            <div style="display:flex;gap:12px;flex-wrap:wrap;padding-top:4px;">
                <span class="status-badge ${statusClass}">${statusText}</span>
                <span class="status-badge ${activeClass}">${activeText}</span>
            </div>
        </div>
        <hr class="detail-divider">
        <div class="detail-section">
            <span class="detail-label">Status History</span>
            ${history.length > 0 ? history.map(h => `
                <div class="history-item">
                    <span class="h-time">${new Date(h.time).toLocaleString()}</span>
                    <span class="h-status">${h.from} → ${h.to}</span>
                    <span class="h-source">${h.source}</span>
                </div>
            `).join('') : '<div class="no-history">No history available</div>'}
        </div>
    `;

    overlay.classList.add('active');
    panel.classList.add('active');
    document.body.style.overflow = 'hidden';
}

function closeDrawer() {
    document.getElementById('drawerOverlay').classList.remove('active');
    document.getElementById('drawerPanel').classList.remove('active');
    document.body.style.overflow = '';
}

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') closeDrawer();
});

// ============================================================
// Chart.js 图表 (Reports Tab)
// ============================================================
document.addEventListener('DOMContentLoaded', function() {
    const ctx = document.getElementById('statusChart');
    if (!ctx) return;
    const green = <?= $reportGreen ?>;
    const yellow = <?= $reportYellow ?>;
    const red = <?= $reportRed ?>;
    new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: ['Green (Legal)', 'Yellow (Expiring Soon)', 'Red (Overstayed)'],
            datasets: [{
                data: [green, yellow, red],
                backgroundColor: ['#10b981', '#f59e0b', '#dc2626'],
                borderWidth: 3,
                borderColor: '#ffffff'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            cutout: '70%',
            plugins: {
                legend: { display: false }
            }
        }
    });
});
</script>

<?php render_admin_end(); ?>
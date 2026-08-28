<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/admin_guard.php';
require_once __DIR__ . '/services/visa_service.php';

$admin = require_admin();
$visaService = new VisaService();

$type = $_GET['type'] ?? 'csv';
$visaFilter = $_GET['visa'] ?? 'all';
$exportType = $_GET['export'] ?? 'all'; // 'all' 或 'overstay'

// 获取数据
$tourists = $visaService->getApprovedTourists();

// 按签证类型过滤
if ($visaFilter !== 'all') {
    $tourists = array_filter($tourists, function($t) use ($visaFilter) {
        return ($t['visa_type'] ?? 'SEV') === $visaFilter;
    });
}

// 计算剩余天数
foreach ($tourists as &$t) {
    $now = new DateTime();
    if (!empty($t['stay_until_date'])) {
        $stayUntil = new DateTime($t['stay_until_date']);
        $diff = $now->diff($stayUntil);
        $t['_remaining'] = $stayUntil > $now ? $diff->days : -$diff->days;
        $t['_status'] = $t['_remaining'] > 10 ? 'Green' : ($t['_remaining'] >= 0 ? 'Yellow' : 'Red');
    } else {
        $t['_remaining'] = 'N/A';
        $t['_status'] = 'Inactive';
    }
    $t['_visa_active'] = $visaService->isVisaActive($t) ? 'Active' : 'Inactive';
}
unset($t);

// 如果是 overstay 导出，只保留逾期游客
if ($exportType === 'overstay') {
    $tourists = array_filter($tourists, function($t) {
        return $t['_remaining'] !== 'N/A' && $t['_remaining'] < 0;
    });
}

if ($type === 'csv') {
    // ============================================================
    // CSV 导出
    // ============================================================
    $filename = ($exportType === 'overstay' ? 'overstay_list_' : 'visa_report_') . date('Y-m-d') . '.csv';
    header('Content-Type: text/csv; charset=UTF-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    header('Cache-Control: no-cache, must-revalidate');

    $output = fopen('php://output', 'w');
    fputcsv($output, [
        'Name', 'Passport', 'Nationality', 'Visa Type',
        'Effective Date', 'Expiry Date', 'Entry Date', 'Stay Until',
        'Remaining Days', 'Status', 'Active'
    ]);

    foreach ($tourists as $t) {
        $remaining = $t['_remaining'];
        $remainingDisplay = $remaining === 'N/A' ? 'N/A' : ($remaining >= 0 ? $remaining . ' days' : abs($remaining) . ' days overdue');
        fputcsv($output, [
            $t['full_name'] ?? '',
            $t['passport_number'] ?? '',
            $t['nationality'] ?? '',
            $t['visa_type'] ?? 'SEV',
            $t['visa_effective_date'] ?? '',
            $t['visa_expiry_date'] ?? '',
            $t['entry_date'] ?? '',
            $t['stay_until_date'] ?? '',
            $remainingDisplay,
            $t['_status'] ?? 'Inactive',
            $t['_visa_active'] ?? 'Inactive'
        ]);
    }

    fclose($output);
    exit;
}

// ============================================================
// PDF 导出 (使用 dompdf)
// ============================================================
// 检查 dompdf 是否安装
$dompdfAvailable = class_exists('Dompdf\Dompdf');

if (!$dompdfAvailable) {
    // 回退方案：生成 HTML 页面，用户可通过浏览器打印为 PDF
    ?>
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Visa Report - <?= date('Y-m-d') ?></title>
        <style>
            body { font-family: Arial, sans-serif; padding: 20px; max-width: 1200px; margin: 0 auto; }
            h1 { text-align: center; color: #1a1a2e; }
            .toolbar { display: flex; gap: 12px; justify-content: center; margin: 16px 0; flex-wrap: wrap; }
            .btn { padding: 8px 20px; border: none; border-radius: 8px; cursor: pointer; font-weight: 600; font-size: 13px; color: #fff; text-decoration: none; display: inline-flex; align-items: center; gap: 6px; }
            .btn-primary { background: #1a1a2e; }
            .btn-primary:hover { background: #2d2d4e; }
            .btn-success { background: #10b981; }
            .btn-success:hover { background: #059669; }
            table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 13px; }
            th { background: #1a1a2e; color: white; padding: 10px 14px; text-align: left; }
            td { padding: 8px 14px; border-bottom: 1px solid #e5e7eb; }
            tr:hover { background: #f8fafc; }
            .green { color: #10b981; font-weight: 600; }
            .yellow { color: #f59e0b; font-weight: 600; }
            .red { color: #dc2626; font-weight: 600; }
            .inactive { color: #6b7280; font-weight: 600; }
            .active { color: #10b981; font-weight: 600; }
            .footer { margin-top: 24px; text-align: center; font-size: 12px; color: #6b7280; border-top: 1px solid #e5e7eb; padding-top: 16px; }
            .stats { display: flex; gap: 20px; justify-content: center; margin: 12px 0; flex-wrap: wrap; }
            .stats .stat { background: #f8fafc; padding: 8px 20px; border-radius: 8px; }
            .stats .stat strong { font-size: 18px; }
            .badge { display: inline-block; padding: 2px 10px; border-radius: 12px; font-size: 11px; font-weight: 600; }
            .badge-green { background: #d1fae5; color: #065f46; }
            .badge-yellow { background: #fef3c7; color: #92400e; }
            .badge-red { background: #fee2e2; color: #991b1b; }
            .badge-inactive { background: #f3f4f6; color: #6b7280; }
            @media print {
                .no-print { display: none !important; }
                body { padding: 10px; }
                table { font-size: 11px; }
                th, td { padding: 4px 8px; }
            }
        </style>
    </head>
    <body>
        <div class="no-print" style="text-align:center;margin-bottom:20px;">
            <h1>Visa Status Report</h1>
            <div class="toolbar">
                <button class="btn btn-primary" onclick="window.print()">
                    <i class='bx bx-printer'></i> Print / Save as PDF
                </button>
                <a href="visa_export.php?type=csv&visa=<?= $visaFilter ?>&export=<?= $exportType ?>" class="btn btn-success">
                    <i class='bx bx-download'></i> Download CSV
                </a>
                <a href="visa_management.php?tab=reports" class="btn" style="background:#6b7280;">
                    <i class='bx bx-arrow-back'></i> Back
                </a>
            </div>
            <p style="color:#6b7280;font-size:13px;">
                💡 Click "Print / Save as PDF" then choose "Save as PDF" in the print dialog.
            </p>
        </div>

        <div id="reportContent">
            <h1>Visa Status Report</h1>
            <p style="text-align:center;color:#6b7280;font-size:13px;">
                Generated: <?= date('d M Y H:i') ?> | Visa Type: <?= ucfirst($visaFilter) ?>
                <?= $exportType === 'overstay' ? ' | ⚠️ Overstay List Only' : '' ?>
            </p>

            <div class="stats">
                <div class="stat"><strong><?= count($tourists) ?></strong> Total</div>
                <div class="stat"><strong style="color:#10b981;"><?= count(array_filter($tourists, fn($t) => $t['_status'] === 'Green')) ?></strong> Green</div>
                <div class="stat"><strong style="color:#f59e0b;"><?= count(array_filter($tourists, fn($t) => $t['_status'] === 'Yellow')) ?></strong> Yellow</div>
                <div class="stat"><strong style="color:#dc2626;"><?= count(array_filter($tourists, fn($t) => $t['_status'] === 'Red')) ?></strong> Red</div>
            </div>

            <?php if (empty($tourists)): ?>
                <p style="text-align:center;padding:40px;color:#6b7280;">No records found.</p>
            <?php else: ?>
            <table>
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Passport</th>
                        <th>Visa</th>
                        <th>Effective</th>
                        <th>Expiry</th>
                        <th>Entry</th>
                        <th>Stay Until</th>
                        <th>Remaining</th>
                        <th>Status</th>
                        <th>Active</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($tourists as $t):
                        $remaining = $t['_remaining'];
                        $remainingDisplay = $remaining === 'N/A' ? '—' : ($remaining >= 0 ? $remaining . 'd' : abs($remaining) . 'd overdue');
                        $statusClass = strtolower($t['_status'] ?? 'inactive');
                        $activeClass = strtolower($t['_visa_active'] ?? 'inactive');
                    ?>
                    <tr>
                        <td><?= htmlspecialchars($t['full_name'] ?? '') ?></td>
                        <td><?= htmlspecialchars($t['passport_number'] ?? '') ?></td>
                        <td><?= htmlspecialchars($t['visa_type'] ?? 'SEV') ?></td>
                        <td><?= $t['visa_effective_date'] ?? '—' ?></td>
                        <td><?= $t['visa_expiry_date'] ?? '—' ?></td>
                        <td><?= $t['entry_date'] ?? '—' ?></td>
                        <td><?= $t['stay_until_date'] ?? '—' ?></td>
                        <td><?= $remainingDisplay ?></td>
                        <td><span class="badge badge-<?= $statusClass ?>"><?= $t['_status'] ?? 'Inactive' ?></span></td>
                        <td><span class="badge badge-<?= $activeClass ?>"><?= $t['_visa_active'] ?? 'Inactive' ?></span></td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
            <?php endif; ?>
            <div class="footer">© <?= date('Y') ?> MyFind Admin · M500 Temporal Status Tracker</div>
        </div>
    </body>
    </html>
    <?php
    exit;
}

// ============================================================
// 如果 dompdf 可用，生成真正的 PDF 下载
// ============================================================
// 注意：需要先运行 composer require dompdf/dompdf
// 然后 require_once __DIR__ . '/vendor/autoload.php';

require_once __DIR__ . '/vendor/autoload.php';

use Dompdf\Dompdf;
use Dompdf\Options;

$options = new Options();
$options->set('defaultFont', 'Arial');
$options->set('isRemoteEnabled', true);

$dompdf = new Dompdf($options);

// 构建 HTML 内容 (复用上面的 HTML，但去除打印按钮)
$html = '<!DOCTYPE html><html><head><meta charset="UTF-8"><style>
    body { font-family: Arial, sans-serif; padding: 20px; }
    h1 { text-align: center; color: #1a1a2e; }
    table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 12px; }
    th { background: #1a1a2e; color: white; padding: 8px 12px; text-align: left; }
    td { padding: 6px 12px; border-bottom: 1px solid #e5e7eb; }
    .green { color: #10b981; font-weight: 600; }
    .yellow { color: #f59e0b; font-weight: 600; }
    .red { color: #dc2626; font-weight: 600; }
    .inactive { color: #6b7280; font-weight: 600; }
    .active { color: #10b981; font-weight: 600; }
    .footer { margin-top: 20px; text-align: center; font-size: 11px; color: #6b7280; border-top: 1px solid #e5e7eb; padding-top: 12px; }
    .stats { display: flex; gap: 16px; justify-content: center; margin: 12px 0; }
    .stats .stat { background: #f8fafc; padding: 6px 16px; border-radius: 6px; font-size: 13px; }
    .badge { display: inline-block; padding: 2px 10px; border-radius: 10px; font-size: 10px; font-weight: 600; }
    .badge-green { background: #d1fae5; color: #065f46; }
    .badge-yellow { background: #fef3c7; color: #92400e; }
    .badge-red { background: #fee2e2; color: #991b1b; }
    .badge-inactive { background: #f3f4f6; color: #6b7280; }
</style></head><body>';

$html .= '<h1>Visa Status Report</h1>';
$html .= '<p style="text-align:center;color:#6b7280;font-size:12px;">Generated: ' . date('d M Y H:i') . ' | Visa Type: ' . ucfirst($visaFilter) . ($exportType === 'overstay' ? ' | ⚠️ Overstay List Only' : '') . '</p>';

$html .= '<div class="stats">';
$html .= '<div class="stat"><strong>' . count($tourists) . '</strong> Total</div>';
$html .= '<div class="stat"><strong style="color:#10b981;">' . count(array_filter($tourists, fn($t) => $t['_status'] === 'Green')) . '</strong> Green</div>';
$html .= '<div class="stat"><strong style="color:#f59e0b;">' . count(array_filter($tourists, fn($t) => $t['_status'] === 'Yellow')) . '</strong> Yellow</div>';
$html .= '<div class="stat"><strong style="color:#dc2626;">' . count(array_filter($tourists, fn($t) => $t['_status'] === 'Red')) . '</strong> Red</div>';
$html .= '</div>';

if (empty($tourists)) {
    $html .= '<p style="text-align:center;padding:40px;color:#6b7280;">No records found.</p>';
} else {
    $html .= '<table><thead><tr><th>Name</th><th>Passport</th><th>Visa</th><th>Effective</th><th>Expiry</th><th>Entry</th><th>Stay Until</th><th>Remaining</th><th>Status</th><th>Active</th></tr></thead><tbody>';
    foreach ($tourists as $t) {
        $remaining = $t['_remaining'];
        $remainingDisplay = $remaining === 'N/A' ? '—' : ($remaining >= 0 ? $remaining . 'd' : abs($remaining) . 'd overdue');
        $statusClass = strtolower($t['_status'] ?? 'inactive');
        $activeClass = strtolower($t['_visa_active'] ?? 'inactive');
        $html .= '<tr><td>' . htmlspecialchars($t['full_name'] ?? '') . '</td>';
        $html .= '<td>' . htmlspecialchars($t['passport_number'] ?? '') . '</td>';
        $html .= '<td>' . htmlspecialchars($t['visa_type'] ?? 'SEV') . '</td>';
        $html .= '<td>' . ($t['visa_effective_date'] ?? '—') . '</td>';
        $html .= '<td>' . ($t['visa_expiry_date'] ?? '—') . '</td>';
        $html .= '<td>' . ($t['entry_date'] ?? '—') . '</td>';
        $html .= '<td>' . ($t['stay_until_date'] ?? '—') . '</td>';
        $html .= '<td>' . $remainingDisplay . '</td>';
        $html .= '<td><span class="badge badge-' . $statusClass . '">' . ($t['_status'] ?? 'Inactive') . '</span></td>';
        $html .= '<td><span class="badge badge-' . $activeClass . '">' . ($t['_visa_active'] ?? 'Inactive') . '</span></td></tr>';
    }
    $html .= '</tbody></table>';
}

$html .= '<div class="footer">© ' . date('Y') . ' MyFind Admin · M500 Temporal Status Tracker</div>';
$html .= '</body></html>';

$dompdf->loadHtml($html);
$dompdf->setPaper('A4', 'landscape');
$dompdf->render();

$filename = ($exportType === 'overstay' ? 'overstay_list_' : 'visa_report_') . date('Y-m-d') . '.pdf';
$dompdf->stream($filename, ['Attachment' => true]);
exit;
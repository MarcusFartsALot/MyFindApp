<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/admin_guard.php';
require_once __DIR__ . '/services/visa_service.php';
require_once __DIR__ . '/services/visa_travel_service.php';

$admin = require_admin();
$supabase = new SupabaseClient();
$visaService = new VisaService($supabase);
$travelService = new VisaTravelService($supabase);

$type = strtolower(trim((string)($_GET['type'] ?? 'csv')));
$visaFilter = strtoupper(trim((string)($_GET['visa'] ?? 'all')));
$exportType = strtolower(trim((string)($_GET['export'] ?? 'all')));

if (!in_array($type, ['csv', 'pdf'], true)) {
    $type = 'csv';
}

if (!in_array($visaFilter, ['ALL', 'SEV', 'MEV'], true)) {
    $visaFilter = 'ALL';
}

if (!in_array($exportType, ['all', 'overstay'], true)) {
    $exportType = 'all';
}

// Helpers

function e(mixed $value): string
{
    return htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8');
}

function formatDateValue(mixed $value): string
{
    if (empty($value)) {
        return '—';
    }

    try {
        return (new DateTime((string)$value))->format('d M Y');
    } catch (Throwable) {
        return (string)$value;
    }
}

function normalizeStatus(mixed $status): string
{
    $status = strtoupper(trim((string)$status));

    $allowed = [
        'ACTIVE',
        'EXPIRING_SOON',
        'DEPARTURE_NOT_REPORTED',
        'NOT_ENTERED',
        'DEPARTED',
        'USED',
        'EXPIRED',
        'PENDING',
        'APPROVED',
        'REJECTED',
        'CANCELLED'
    ];

    return in_array($status, $allowed, true) ? $status : 'UNKNOWN';
}

function statusLabel(string $status): string
{
    return match ($status) {
        'ACTIVE' => 'Active',
        'EXPIRING_SOON' => 'Expiring Soon',
        'DEPARTURE_NOT_REPORTED' => 'Departure Not Reported',
        'NOT_ENTERED' => 'Not Entered',
        'DEPARTED' => 'Departed',
        'USED' => 'Used',
        'EXPIRED' => 'Expired',
        'PENDING' => 'Pending',
        'APPROVED' => 'Approved',
        'REJECTED' => 'Rejected',
        'CANCELLED' => 'Cancelled',
        default => 'Unknown',
    };
}

function statusBadgeClass(string $status): string
{
    return match ($status) {
        'ACTIVE' => 'badge-green',
        'EXPIRING_SOON' => 'badge-yellow',
        'DEPARTURE_NOT_REPORTED' => 'badge-red',
        'NOT_ENTERED' => 'badge-gray',
        'DEPARTED' => 'badge-blue',
        'USED', 'EXPIRED' => 'badge-dark',
        default => 'badge-gray',
    };
}

function remainingDisplay(
    ?int $remaining,
    string $status = 'UNKNOWN'
): string {
    if (
        in_array(
            $status,
            ['NOT_ENTERED', 'DEPARTED', 'USED', 'EXPIRED'],
            true
        )
        || $remaining === null
    ) {
        return '—';
    }

    if ($status === 'DEPARTURE_NOT_REPORTED') {
        return 'Overdue';
    }

    return $remaining === 0
        ? 'Ends today'
        : $remaining . ' days';
}

function csvSafeValue(mixed $value): string
{
    $value = (string)($value ?? '');

    if ($value !== '' && preg_match('/^[=\-+@]/', $value) === 1) {
        return "'" . $value;
    }

    return $value;
}

function buildReportTitle(string $exportType): string
{
    return $exportType === 'overstay'
        ? 'Departure Not Reported Report'
        : 'Visa Status Report';
}

function buildVisaFilterLabel(string $visaFilter): string
{
    return $visaFilter === 'ALL' ? 'All Visa Types' : $visaFilter;
}

function isVisaCurrentlyActive(
    array $tourist,
    string $travelState
): bool {
    if (
        strtolower(
            trim((string)($tourist['status'] ?? ''))
        ) !== 'approved'
    ) {
        return false;
    }

    $effectiveValue =
        $tourist['visa_effective_date'] ?? null;

    $expiryValue =
        $tourist['visa_expiry_date'] ?? null;

    if (!$effectiveValue || !$expiryValue) {
        return false;
    }

    try {
        $today = new DateTimeImmutable('today');

        $effective = new DateTimeImmutable(
            (string)$effectiveValue
        );

        $expiry = new DateTimeImmutable(
            (string)$expiryValue
        );
    } catch (Throwable) {
        return false;
    }

    if ($today < $effective || $today > $expiry) {
        return false;
    }

    if (
        strtoupper(
            trim((string)($tourist['visa_type'] ?? ''))
        ) === 'SEV'
        && $travelState === 'USED'
    ) {
        return false;
    }

    return true;
}

// Load tourists

$tourists = $visaService->getApprovedTourists();

if (!is_array($tourists)) {
    $tourists = [];
}

// Apply visa filter

if ($visaFilter !== 'ALL') {
    $tourists = array_values(array_filter(
        $tourists,
        static function (array $tourist) use ($visaFilter): bool {
            return strtoupper((string)($tourist['visa_type'] ?? '')) === $visaFilter;
        }
    ));
}

// Prepare export data from visa_travel_records

$exportRows = [];

foreach ($tourists as $tourist) {
    if (!is_array($tourist)) {
        continue;
    }

    $submissionId = trim(
        (string)($tourist['id'] ?? '')
    );

    $travelContext = null;

    if ($submissionId !== '') {
        try {
            $travelContext =
                $travelService->getTravelContext(
                    $submissionId
                );
        } catch (Throwable) {
            $travelContext = null;
        }
    }

    $status = normalizeStatus(
        $travelContext['state']
            ?? 'NOT_ENTERED'
    );

    $remaining =
        $travelContext['remaining_days']
            ?? null;

    $currentRecord = is_array(
        $travelContext['current_record'] ?? null
    )
        ? $travelContext['current_record']
        : null;

    $latestRecord = is_array(
        $travelContext['latest_record'] ?? null
    )
        ? $travelContext['latest_record']
        : null;

    $tourist['_status'] = $status;
    $tourist['_status_label'] =
        statusLabel($status);

    $tourist['_remaining'] =
        is_numeric($remaining)
            ? (int)$remaining
            : null;

    $tourist['_visa_active'] =
        isVisaCurrentlyActive(
            $tourist,
            $status
        );

    $tourist['_actual_entry_at'] =
        $currentRecord['actual_entry_at']
        ?? $latestRecord['actual_entry_at']
        ?? null;

    $tourist['_stay_until_date'] =
        $currentRecord['stay_until_date']
        ?? $latestRecord['stay_until_date']
        ?? null;

    $tourist['_actual_departure_at'] =
        $latestRecord['actual_departure_at']
        ?? null;

    $tourist['_trip_count'] =
        is_array($travelContext['records'] ?? null)
            ? count($travelContext['records'])
            : 0;

    $exportRows[] = $tourist;
}

// Apply departure-not-reported filter

if ($exportType === 'overstay') {
    $exportRows = array_values(array_filter(
        $exportRows,
        static function (array $tourist): bool {
            return ($tourist['_status'] ?? '') === 'DEPARTURE_NOT_REPORTED';
        }
    ));
}

// Summary

$totalCount = count($exportRows);

$statusCounts = [
    'ACTIVE' => 0,
    'EXPIRING_SOON' => 0,
    'DEPARTURE_NOT_REPORTED' => 0,
    'NOT_ENTERED' => 0,
    'DEPARTED' => 0,
    'USED' => 0,
    'EXPIRED' => 0,
];

foreach ($exportRows as $tourist) {
    $status = $tourist['_status'] ?? 'UNKNOWN';

    if (isset($statusCounts[$status])) {
        $statusCounts[$status]++;
    }
}

// CSV export

if ($type === 'csv') {
    $filenamePrefix = $exportType === 'overstay'
        ? 'departure_not_reported_'
        : 'visa_report_';

    $filename = $filenamePrefix . date('Y-m-d') . '.csv';

    header('Content-Type: text/csv; charset=UTF-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
    header('Pragma: no-cache');

    $output = fopen('php://output', 'wb');

    if ($output === false) {
        http_response_code(500);
        exit('Unable to create export file.');
    }

    fwrite($output, "\xEF\xBB\xBF");

    fputcsv($output, [
        'Name',
        'Passport Number',
        'Nationality',
        'Purpose of Visit',
        'Visa Type',
        'Visa Effective Date',
        'Visa Expiry Date',
        'Actual Arrival',
        'Stay Until Date',
        'Actual Departure',
        'Remaining Days',
        'Tracking Status',
        'Visa Active',
        'Submitted At',
        'Approved At'
    ]);

    foreach ($exportRows as $tourist) {
        $remaining = $tourist['_remaining'];
        $status = $tourist['_status'] ?? 'UNKNOWN';

        $remainingCsv = in_array(
            $status,
            ['NOT_ENTERED', 'DEPARTED', 'USED', 'EXPIRED'],
            true
        )
            ? 'N/A'
            : (
                $remaining === null
                    ? 'N/A'
                    : (string)$remaining
            );

        fputcsv($output, [
            csvSafeValue($tourist['full_name'] ?? ''),
            csvSafeValue($tourist['passport_number'] ?? ''),
            csvSafeValue($tourist['nationality'] ?? ''),
            csvSafeValue($tourist['purpose_of_visit'] ?? ''),
            csvSafeValue($tourist['visa_type'] ?? ''),
            csvSafeValue($tourist['visa_effective_date'] ?? ''),
            csvSafeValue($tourist['visa_expiry_date'] ?? ''),
            csvSafeValue($tourist['_actual_entry_at'] ?? ''),
            csvSafeValue($tourist['_stay_until_date'] ?? ''),
            csvSafeValue($tourist['_actual_departure_at'] ?? ''),
            csvSafeValue($remainingCsv),
            csvSafeValue($tourist['_status_label'] ?? 'Unknown'),
            csvSafeValue($tourist['_visa_active'] ? 'Active' : 'Inactive'),
            csvSafeValue($tourist['submitted_at'] ?? ''),
            csvSafeValue($tourist['approved_at'] ?? '')
        ]);
    }

    fclose($output);
    exit;
}

// Load Dompdf

$autoloadPath = __DIR__ . '/vendor/autoload.php';

if (is_file($autoloadPath)) {
    require_once $autoloadPath;
}

$dompdfAvailable = class_exists('\Dompdf\Dompdf');
$reportTitle = buildReportTitle($exportType);
$visaFilterLabel = buildVisaFilterLabel($visaFilter);

// Browser-printable fallback

if (!$dompdfAvailable):
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= e($reportTitle) ?> - <?= e(date('Y-m-d')) ?></title>

    <style>
        * { box-sizing: border-box; }
        body { font-family: Arial, Helvetica, sans-serif; margin: 0; padding: 24px; color: #111827; background: #fff; }
        .page { max-width: 1400px; margin: 0 auto; }
        .toolbar { display: flex; justify-content: center; align-items: center; gap: 10px; flex-wrap: wrap; margin-bottom: 22px; }
        .btn { display: inline-flex; align-items: center; justify-content: center; gap: 7px; padding: 9px 16px; border: 0; border-radius: 8px; font-size: 13px; font-weight: 600; cursor: pointer; text-decoration: none; }
        .btn-primary { background: #1a1a2e; color: #fff; }
        .btn-primary:hover { background: #2d2d4e; }
        .btn-success { background: #10b981; color: #fff; }
        .btn-success:hover { background: #059669; }
        .btn-secondary { background: #6b7280; color: #fff; }
        .btn-secondary:hover { background: #4b5563; }
        .print-note { text-align: center; margin: 10px 0 0; color: #6b7280; font-size: 13px; }
        .report-header { text-align: center; margin-bottom: 18px; }
        .report-header h1 { margin: 0 0 8px; color: #1a1a2e; font-size: 26px; }
        .report-meta { margin: 0; color: #6b7280; font-size: 13px; }
        .stats { display: grid; grid-template-columns: repeat(4, minmax(140px, 1fr)); gap: 12px; margin: 20px 0; }
        .stat { padding: 14px 16px; border: 1px solid #e5e7eb; border-radius: 10px; background: #f8fafc; text-align: center; }
        .stat strong { display: block; margin-bottom: 3px; font-size: 22px; }
        .stat span { font-size: 12px; color: #6b7280; }
        .stat-green strong { color: #059669; }
        .stat-yellow strong { color: #d97706; }
        .stat-red strong { color: #dc2626; }
        .warning { margin: 16px 0; padding: 12px 14px; border: 1px solid #fecaca; border-radius: 8px; background: #fef2f2; color: #991b1b; font-size: 13px; }
        .table-wrap { width: 100%; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 12px; }
        thead { display: table-header-group; }
        tr { page-break-inside: avoid; }
        th { padding: 9px 8px; background: #1a1a2e; color: #fff; text-align: left; white-space: nowrap; }
        td { padding: 8px; border-bottom: 1px solid #e5e7eb; vertical-align: top; }
        tbody tr:nth-child(even) { background: #f9fafb; }
        .badge { display: inline-block; padding: 3px 8px; border-radius: 999px; font-size: 10px; font-weight: 700; white-space: nowrap; }
        .badge-green { background: #d1fae5; color: #065f46; }
        .badge-yellow { background: #fef3c7; color: #92400e; }
        .badge-red { background: #fee2e2; color: #991b1b; }
        .badge-gray { background: #f3f4f6; color: #4b5563; }
        .badge-blue { background: #dbeafe; color: #1e40af; }
        .badge-dark { background: #e5e7eb; color: #1f2937; }
        .footer { margin-top: 24px; padding-top: 12px; border-top: 1px solid #e5e7eb; text-align: center; color: #6b7280; font-size: 11px; }
        .empty { padding: 45px 20px; text-align: center; color: #6b7280; border: 1px dashed #d1d5db; border-radius: 10px; margin-top: 18px; }
        @media print {
            .no-print { display: none !important; }
            body { padding: 10px; }
            .page { max-width: none; }
            .report-header h1 { font-size: 20px; }
            .stats { grid-template-columns: repeat(4, 1fr); }
            table { font-size: 9px; }
            th, td { padding: 5px; }
            @page { size: A4 landscape; margin: 10mm; }
        }
        @media (max-width: 800px) {
            body { padding: 12px; }
            .stats { grid-template-columns: repeat(2, 1fr); }
        }
    </style>
</head>

<body>
<div class="page">

    <div class="no-print">
        <div class="toolbar">
            <button type="button" class="btn btn-primary" onclick="window.print()">
                🖨 Print / Save as PDF
            </button>

            <a
                href="visa_export.php?type=csv&amp;visa=<?= e($visaFilter) ?>&amp;export=<?= e($exportType) ?>"
                class="btn btn-success"
            >
                ↓ Download CSV
            </a>

            <a href="visa_management.php?tab=reports" class="btn btn-secondary">
                ← Back to Reports
            </a>
        </div>

        <p class="print-note">
            Click "Print / Save as PDF", then select "Save as PDF" in the print dialog.
        </p>
    </div>

    <div class="report-header">
        <h1><?= e($reportTitle) ?></h1>

        <p class="report-meta">
            Generated: <?= e(date('d M Y H:i')) ?>
            &nbsp;|&nbsp;
            Visa Type: <?= e($visaFilterLabel) ?>
            <?php if ($exportType === 'overstay'): ?>
                &nbsp;|&nbsp; Departure Not Reported Only
            <?php endif; ?>
        </p>
    </div>

    <div class="stats">
        <div class="stat">
            <strong><?= $totalCount ?></strong>
            <span>Total Records</span>
        </div>

        <div class="stat stat-green">
            <strong><?= $statusCounts['ACTIVE'] ?></strong>
            <span>Active</span>
        </div>

        <div class="stat stat-yellow">
            <strong><?= $statusCounts['EXPIRING_SOON'] ?></strong>
            <span>Expiring Soon</span>
        </div>

        <div class="stat stat-red">
            <strong><?= $statusCounts['DEPARTURE_NOT_REPORTED'] ?></strong>
            <span>Departure Not Reported</span>
        </div>
    </div>

    <?php if ($statusCounts['DEPARTURE_NOT_REPORTED'] > 0 && $exportType === 'all'): ?>
        <div class="warning">
            <strong>Attention:</strong>
            <?= $statusCounts['DEPARTURE_NOT_REPORTED'] ?>
            record(s) have no recorded departure and require administrative follow-up.
        </div>
    <?php endif; ?>

    <?php if (empty($exportRows)): ?>

        <div class="empty">
            No records found for the selected export criteria.
        </div>

    <?php else: ?>

        <div class="table-wrap">
            <table>
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Passport</th>
                        <th>Nationality</th>
                        <th>Visa</th>
                        <th>Effective</th>
                        <th>Expiry</th>
                        <th>Actual Arrival</th>
                        <th>Stay Until</th>
                        <th>Actual Departure</th>
                        <th>Remaining</th>
                        <th>Status</th>
                        <th>Visa Active</th>
                    </tr>
                </thead>

                <tbody>
                <?php foreach ($exportRows as $tourist): ?>
                    <?php
                    $status = $tourist['_status'] ?? 'UNKNOWN';
                    $statusLabelText = $tourist['_status_label'] ?? 'Unknown';
                    $statusBadge = statusBadgeClass($status);
                    $remainingText = remainingDisplay($tourist['_remaining'] ?? null, $status);
                    $visaActive = !empty($tourist['_visa_active']);
                    ?>

                    <tr>
                        <td><?= e($tourist['full_name'] ?? '') ?></td>
                        <td><?= e($tourist['passport_number'] ?? '') ?></td>
                        <td><?= e($tourist['nationality'] ?? '—') ?></td>
                        <td><?= e($tourist['visa_type'] ?? '—') ?></td>
                        <td><?= e(formatDateValue($tourist['visa_effective_date'] ?? null)) ?></td>
                        <td><?= e(formatDateValue($tourist['visa_expiry_date'] ?? null)) ?></td>
                        <td><?= e(formatDateValue($tourist['_actual_entry_at'] ?? null)) ?></td>
                        <td><?= e(formatDateValue($tourist['_stay_until_date'] ?? null)) ?></td>
                        <td><?= e(formatDateValue($tourist['_actual_departure_at'] ?? null)) ?></td>
                        <td><?= e($remainingText) ?></td>
                        <td>
                            <span class="badge <?= e($statusBadge) ?>">
                                <?= e($statusLabelText) ?>
                            </span>
                        </td>
                        <td>
                            <span class="badge <?= $visaActive ? 'badge-green' : 'badge-gray' ?>">
                                <?= $visaActive ? 'Active' : 'Inactive' ?>
                            </span>
                        </td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>

    <?php endif; ?>

    <div class="footer">
        Generated by MyFind Admin · Visa Management
        &nbsp;|&nbsp;
        <?= e(date('Y')) ?>
    </div>

</div>
</body>
</html>
<?php
exit;
endif;

// Dompdf export

use Dompdf\Dompdf;
use Dompdf\Options;

$options = new Options();
$options->set('defaultFont', 'Arial');
$options->set('isRemoteEnabled', false);
$options->set('isHtml5ParserEnabled', true);

$dompdf = new Dompdf($options);
$html = '<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>' . e($reportTitle) . '</title>
<style>
@page { size: A4 landscape; margin: 10mm; }
body { font-family: Arial, Helvetica, sans-serif; color: #111827; font-size: 9px; margin: 0; }
h1 { text-align: center; color: #1a1a2e; font-size: 18px; margin: 0 0 5px; }
.meta { text-align: center; color: #6b7280; font-size: 8px; margin-bottom: 10px; }
.stats { width: 100%; margin-bottom: 10px; }
.stats td { width: 25%; padding: 5px; text-align: center; background: #f8fafc; border: 1px solid #e5e7eb; }
.stats strong { display: block; font-size: 13px; }
.stats span { color: #6b7280; font-size: 8px; }
.green-text { color: #059669; }
.yellow-text { color: #d97706; }
.red-text { color: #dc2626; }
.warning { padding: 7px 9px; margin-bottom: 10px; background: #fef2f2; border: 1px solid #fecaca; color: #991b1b; }
table.report { width: 100%; border-collapse: collapse; }
table.report thead { display: table-header-group; }
table.report tr { page-break-inside: avoid; }
table.report th { background: #1a1a2e; color: #fff; padding: 5px 4px; text-align: left; font-size: 7px; }
table.report td { padding: 4px; border-bottom: 1px solid #e5e7eb; font-size: 7px; vertical-align: top; }
.badge { display: inline-block; padding: 2px 4px; font-size: 6.5px; font-weight: bold; }
.badge-green { background: #d1fae5; color: #065f46; }
.badge-yellow { background: #fef3c7; color: #92400e; }
.badge-red { background: #fee2e2; color: #991b1b; }
.badge-gray { background: #f3f4f6; color: #4b5563; }
.badge-blue { background: #dbeafe; color: #1e40af; }
.badge-dark { background: #e5e7eb; color: #1f2937; }
.empty { text-align: center; padding: 35px; color: #6b7280; border: 1px solid #e5e7eb; }
.footer { margin-top: 12px; padding-top: 7px; border-top: 1px solid #e5e7eb; text-align: center; color: #6b7280; font-size: 7px; }
</style>
</head>
<body>';

$html .= '<h1>' . e($reportTitle) . '</h1>';
$html .= '<div class="meta">Generated: ' . e(date('d M Y H:i'));
$html .= ' | Visa Type: ' . e($visaFilterLabel);

if ($exportType === 'overstay') {
    $html .= ' | Departure Not Reported Only';
}

$html .= '</div>';

$html .= '<table class="stats"><tr>';

$html .= '<td><strong>' . $totalCount . '</strong><span>Total Records</span></td>';
$html .= '<td><strong class="green-text">' . $statusCounts['ACTIVE'] . '</strong><span>Active</span></td>';
$html .= '<td><strong class="yellow-text">' . $statusCounts['EXPIRING_SOON'] . '</strong><span>Expiring Soon</span></td>';
$html .= '<td><strong class="red-text">' . $statusCounts['DEPARTURE_NOT_REPORTED'] . '</strong><span>Departure Not Reported</span></td>';

$html .= '</tr></table>';

if ($statusCounts['DEPARTURE_NOT_REPORTED'] > 0 && $exportType === 'all') {
    $html .= '<div class="warning">';
    $html .= '<strong>Attention:</strong> ';
    $html .= $statusCounts['DEPARTURE_NOT_REPORTED'];
    $html .= ' record(s) have no recorded departure and require administrative follow-up.';
    $html .= '</div>';
}

if (empty($exportRows)) {
    $html .= '<div class="empty">No records found for the selected export criteria.</div>';
} else {
    $html .= '
    <table class="report">
        <thead>
            <tr>
                <th>Name</th>
                <th>Passport</th>
                <th>Nationality</th>
                <th>Visa</th>
                <th>Effective</th>
                <th>Expiry</th>
                <th>Actual Arrival</th>
                <th>Stay Until</th>
                <th>Actual Departure</th>
                <th>Remaining</th>
                <th>Status</th>
                <th>Active</th>
            </tr>
        </thead>
        <tbody>';

    foreach ($exportRows as $tourist) {
        $status = $tourist['_status'] ?? 'UNKNOWN';
        $statusLabelText = $tourist['_status_label'] ?? 'Unknown';
        $statusBadge = statusBadgeClass($status);
        $remainingText = remainingDisplay($tourist['_remaining'] ?? null, $status);
        $visaActive = !empty($tourist['_visa_active']);

        $html .= '<tr>';
        $html .= '<td>' . e($tourist['full_name'] ?? '') . '</td>';
        $html .= '<td>' . e($tourist['passport_number'] ?? '') . '</td>';
        $html .= '<td>' . e($tourist['nationality'] ?? '—') . '</td>';
        $html .= '<td>' . e($tourist['visa_type'] ?? '—') . '</td>';
        $html .= '<td>' . e(formatDateValue($tourist['visa_effective_date'] ?? null)) . '</td>';
        $html .= '<td>' . e(formatDateValue($tourist['visa_expiry_date'] ?? null)) . '</td>';
        $html .= '<td>' . e(formatDateValue($tourist['_actual_entry_at'] ?? null)) . '</td>';
        $html .= '<td>' . e(formatDateValue($tourist['_stay_until_date'] ?? null)) . '</td>';
        $html .= '<td>' . e(formatDateValue($tourist['_actual_departure_at'] ?? null)) . '</td>';
        $html .= '<td>' . e($remainingText) . '</td>';

        $html .= '<td><span class="badge ' . e($statusBadge) . '">';
        $html .= e($statusLabelText);
        $html .= '</span></td>';

        $html .= '<td><span class="badge ' . ($visaActive ? 'badge-green' : 'badge-gray') . '">';
        $html .= $visaActive ? 'Active' : 'Inactive';
        $html .= '</span></td>';

        $html .= '</tr>';
    }

    $html .= '</tbody></table>';
}

$html .= '<div class="footer">';
$html .= 'Generated by MyFind Admin · Visa Management | ' . e(date('Y'));
$html .= '</div>';
$html .= '</body></html>';

$dompdf->loadHtml($html);
$dompdf->setPaper('A4', 'landscape');
$dompdf->render();

$filenamePrefix = $exportType === 'overstay'
    ? 'departure_not_reported_'
    : 'visa_report_';

$filename = $filenamePrefix . date('Y-m-d') . '.pdf';

$dompdf->stream($filename, [
    'Attachment' => true
]);

exit;

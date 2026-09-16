<?php

declare(strict_types=1);

require_once __DIR__ . '/includes/admin_guard.php';
require_once __DIR__ . '/includes/layout.php';
require_once __DIR__ . '/services/visa_service.php';
require_once __DIR__ . '/services/visa_travel_service.php';

$admin = require_admin();
$supabase = new SupabaseClient();
$visaService = new VisaService($supabase);
$travelService = new VisaTravelService($supabase);

function e(mixed $value): string
{
    return htmlspecialchars(
        (string)($value ?? ''),
        ENT_QUOTES,
        'UTF-8'
    );
}

function formatDate(mixed $value): string
{
    if ($value === null || $value === '') {
        return '—';
    }

    try {
        return (new DateTimeImmutable((string)$value))
            ->format('d M Y');
    } catch (Throwable) {
        return '—';
    }
}

function formatDateTime(mixed $value): string
{
    if ($value === null || $value === '') {
        return '—';
    }

    try {
        return (new DateTimeImmutable((string)$value))
            ->format('d M Y, H:i');
    } catch (Throwable) {
        return '—';
    }
}

function normalizeStatus(mixed $status): string
{
    return strtoupper(
        trim((string)($status ?? ''))
    );
}

function statusLabel(mixed $status): string
{
    return match (normalizeStatus($status)) {
        'ACTIVE' => 'Active',
        'EXPIRING_SOON' => 'Expiring Soon',
        'DEPARTURE_NOT_REPORTED' => 'Departure Not Reported',
        'NOT_ENTERED' => 'Not Entered',
        'DEPARTED' => 'Departed',
        'USED' => 'Used',
        'EXPIRED' => 'Expired',
        'APPROVED' => 'Approved',
        'PENDING' => 'Pending',
        'REJECTED' => 'Rejected',
        'CANCELLED' => 'Cancelled',
        default => 'Unknown',
    };
}

function statusClass(mixed $status): string
{
    return match (normalizeStatus($status)) {
        'ACTIVE', 'APPROVED' => 'status-green',
        'EXPIRING_SOON', 'PENDING' => 'status-yellow',
        'DEPARTURE_NOT_REPORTED', 'REJECTED' => 'status-red',
        'DEPARTED' => 'status-blue',
        'USED' => 'status-purple',
        'EXPIRED' => 'status-dark',
        default => 'status-gray',
    };
}

function statusIcon(mixed $status): string
{
    return match (normalizeStatus($status)) {
        'ACTIVE' => 'fa-circle-check',
        'EXPIRING_SOON' => 'fa-clock',
        'DEPARTURE_NOT_REPORTED' => 'fa-triangle-exclamation',
        'NOT_ENTERED' => 'fa-right-to-bracket',
        'DEPARTED' => 'fa-plane-departure',
        'USED' => 'fa-circle-check',
        'EXPIRED' => 'fa-calendar-xmark',
        'APPROVED' => 'fa-circle-check',
        'PENDING' => 'fa-clock',
        'REJECTED' => 'fa-circle-xmark',
        'CANCELLED' => 'fa-ban',
        default => 'fa-circle-question',
    };
}

function remainingLabel(
    mixed $remaining,
    mixed $status = null
): string {
    $normalizedStatus = normalizeStatus($status);

    if ($normalizedStatus === 'DEPARTURE_NOT_REPORTED') {
        return 'Overdue';
    }

    if (
        $normalizedStatus === 'NOT_ENTERED'
        || $normalizedStatus === 'DEPARTED'
        || $normalizedStatus === 'USED'
        || $normalizedStatus === 'EXPIRED'
    ) {
        return '—';
    }

    if ($remaining === null || $remaining === '') {
        return '—';
    }

    $days = (int)$remaining;

    if ($days === 0) {
        return 'Ends today';
    }

    return $days . ' days';
}

function safeInt(mixed $value): int
{
    return is_numeric($value)
        ? (int)$value
        : 0;
}

function jsonForJs(mixed $value): string
{
    return json_encode(
        $value,
        JSON_HEX_TAG
        | JSON_HEX_AMP
        | JSON_HEX_APOS
        | JSON_HEX_QUOT
        | JSON_UNESCAPED_UNICODE
        | JSON_UNESCAPED_SLASHES
    ) ?: 'null';
}

// Tab
$activeTab = (string)($_GET['tab'] ?? 'approve');

if (!in_array(
    $activeTab,
    ['approve', 'monitor', 'reports'],
    true
)) {
    $activeTab = 'approve';
}

// PRG message
$message = '';
$messageType = '';

$result = strtolower(
    trim((string)($_GET['result'] ?? ''))
);

$errorMessage = trim(
    (string)($_GET['error'] ?? '')
);

if ($result === 'approved') {
    $message = 'Visa application approved successfully.';
    $messageType = 'success';
} elseif ($result === 'rejected') {
    $message = 'Visa application rejected successfully.';
    $messageType = 'success';
} elseif ($errorMessage !== '') {
    $message = $errorMessage;
    $messageType = 'error';
}

// Approval actions
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = (string)($_POST['action'] ?? '');

    try {
        if ($action === 'approve') {
            $submissionId = trim(
                (string)($_POST['submission_id'] ?? '')
            );

            if ($submissionId === '') {
                throw new RuntimeException(
                    'Invalid visa submission.'
                );
            }

            if (!is_array($admin) || empty($admin)) {
                throw new RuntimeException(
                    'Unable to identify the administrator.'
                );
            }

            $visaService->approveVisa(
                $submissionId,
                $admin
            );

            header(
                'Location: visa_management.php'
                . '?tab=approve&result=approved'
            );
            exit;
        }

        if ($action === 'reject') {
            $submissionId = trim(
                (string)($_POST['submission_id'] ?? '')
            );

            $reason = trim(
                (string)($_POST['rejection_reason'] ?? '')
            );

            if ($submissionId === '') {
                throw new RuntimeException(
                    'Invalid visa submission.'
                );
            }

            if ($reason === '') {
                throw new RuntimeException(
                    'Please provide a rejection reason.'
                );
            }

            $visaService->rejectVisa(
                $submissionId,
                $reason,
                $admin
            );

            header(
                'Location: visa_management.php'
                . '?tab=approve&result=rejected'
            );
            exit;
        }

        throw new RuntimeException(
            'Invalid visa action.'
        );
    } catch (Throwable $exception) {
        header(
            'Location: visa_management.php'
            . '?tab=approve&error='
            . rawurlencode(
                $exception->getMessage()
            )
        );
        exit;
    }
}

// Load submissions
try {
    $pendingApplications =
        $visaService->getPendingApplications();

    $pendingApplications =
        is_array($pendingApplications)
            ? $pendingApplications
            : [];
} catch (Throwable $exception) {
    $pendingApplications = [];

    if ($message === '') {
        $message =
            'Unable to load pending applications: '
            . $exception->getMessage();

        $messageType = 'error';
    }
}

try {
    $approvedTourists =
        $visaService->getApprovedTourists();

    $approvedTourists =
        is_array($approvedTourists)
            ? $approvedTourists
            : [];
} catch (Throwable $exception) {
    $approvedTourists = [];

    if ($message === '') {
        $message =
            'Unable to load approved tourists: '
            . $exception->getMessage();

        $messageType = 'error';
    }
}

// Activity trend remains visa-submission based
try {
    $trendData =
        $visaService->getTrendData();

    $trendData =
        is_array($trendData)
            ? $trendData
            : [];
} catch (Throwable) {
    $trendData = [];
}

$pendingCount = count($pendingApplications);
$totalApproved = count($approvedTourists);

// Build monitoring data from visa_travel_records
$normalizedTourists = [];

$activeCount = 0;
$expiringSoonCount = 0;
$departureNotReportedCount = 0;
$notEnteredCount = 0;
$departedCount = 0;
$usedCount = 0;
$expiredCount = 0;

$sevCount = 0;
$mevCount = 0;
$otherVisaCount = 0;

$totalPermittedDays = 0;
$permittedStayRecords = 0;

foreach ($approvedTourists as $tourist) {
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

    $records = is_array(
        $travelContext['records'] ?? null
    )
        ? $travelContext['records']
        : [];

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

    $status = normalizeStatus(
        $travelContext['state']
            ?? 'NOT_ENTERED'
    );

    $remaining =
        $travelContext['remaining_days']
            ?? null;

    $tourist['_status'] = $status;
    $tourist['_status_label'] =
        statusLabel($status);

    $tourist['_status_class'] =
        statusClass($status);

    $tourist['_remaining_days'] =
        $remaining;

    $tourist['_remaining_label'] =
        remainingLabel(
            $remaining,
            $status
        );

    $tourist['_current_record'] =
        $currentRecord;

    $tourist['_latest_record'] =
        $latestRecord;

    $tourist['_trip_count'] =
        count($records);

    $tourist['_actual_entry_at'] =
        $currentRecord['actual_entry_at']
        ?? $latestRecord['actual_entry_at']
        ?? null;

    $tourist['_stay_until_date'] =
        $currentRecord['stay_until_date']
        ?? null;

    $tourist['_actual_departure_at'] =
        $latestRecord['actual_departure_at']
        ?? null;

    $normalizedTourists[] = $tourist;

    switch ($status) {
        case 'ACTIVE':
            $activeCount++;
            break;

        case 'EXPIRING_SOON':
            $expiringSoonCount++;
            break;

        case 'DEPARTURE_NOT_REPORTED':
            $departureNotReportedCount++;
            break;

        case 'NOT_ENTERED':
            $notEnteredCount++;
            break;

        case 'DEPARTED':
            $departedCount++;
            break;

        case 'USED':
            $usedCount++;
            break;

        case 'EXPIRED':
            $expiredCount++;
            break;
    }

    $visaType = strtoupper(
        trim(
            (string)(
                $tourist['visa_type']
                ?? ''
            )
        )
    );

    if ($visaType === 'SEV') {
        $sevCount++;
    } elseif ($visaType === 'MEV') {
        $mevCount++;
    } else {
        $otherVisaCount++;
    }

    foreach ($records as $record) {
        if (
            !is_array($record)
            || empty($record['actual_entry_at'])
            || empty($record['stay_until_date'])
        ) {
            continue;
        }

        try {
            $entry =
                new DateTimeImmutable(
                    (string)$record[
                        'actual_entry_at'
                    ]
                );

            $stayUntil =
                new DateTimeImmutable(
                    (string)$record[
                        'stay_until_date'
                    ]
                );

            $totalPermittedDays +=
                (int)$entry
                    ->setTime(0, 0)
                    ->diff(
                        $stayUntil
                            ->setTime(0, 0)
                    )
                    ->days;

            $permittedStayRecords++;
        } catch (Throwable) {
        }
    }
}

$avgPermittedStay =
    $permittedStayRecords > 0
        ? round(
            $totalPermittedDays
            / $permittedStayRecords,
            1
        )
        : null;

// Monitor filters
$search = trim(
    (string)($_GET['search'] ?? '')
);

$statusFilter = strtoupper(
    trim(
        (string)(
            $_GET['status_filter']
            ?? 'ALL'
        )
    )
);

$visaFilter = strtoupper(
    trim(
        (string)(
            $_GET['visa_filter']
            ?? 'ALL'
        )
    )
);

$sort = (string)(
    $_GET['sort']
    ?? 'remaining'
);

$allowedStatusFilters = [
    'ALL',
    'ACTIVE',
    'EXPIRING_SOON',
    'DEPARTURE_NOT_REPORTED',
    'NOT_ENTERED',
    'DEPARTED',
    'USED',
    'EXPIRED',
];

if (!in_array(
    $statusFilter,
    $allowedStatusFilters,
    true
)) {
    $statusFilter = 'ALL';
}

if (!in_array(
    $visaFilter,
    ['ALL', 'SEV', 'MEV'],
    true
)) {
    $visaFilter = 'ALL';
}

if (!in_array(
    $sort,
    ['remaining', 'name', 'expiry', 'entry'],
    true
)) {
    $sort = 'remaining';
}

$filteredTourists = [];
$searchLower = strtolower($search);

foreach ($normalizedTourists as $tourist) {
    $fullName = strtolower(
        (string)(
            $tourist['full_name']
            ?? ''
        )
    );

    $passport = strtolower(
        (string)(
            $tourist['passport_number']
            ?? ''
        )
    );

    $referenceId = strtolower(
        (string)(
            $tourist['reference_id']
            ?? ''
        )
    );

    if (
        $search !== ''
        && !str_contains(
            $fullName,
            $searchLower
        )
        && !str_contains(
            $passport,
            $searchLower
        )
        && !str_contains(
            $referenceId,
            $searchLower
        )
    ) {
        continue;
    }

    $status = normalizeStatus(
        $tourist['_status']
            ?? 'NOT_ENTERED'
    );

    if (
        $statusFilter !== 'ALL'
        && $status !== $statusFilter
    ) {
        continue;
    }

    $touristVisaType = strtoupper(
        trim(
            (string)(
                $tourist['visa_type']
                ?? ''
            )
        )
    );

    if (
        $visaFilter !== 'ALL'
        && $touristVisaType
            !== $visaFilter
    ) {
        continue;
    }

    $filteredTourists[] = $tourist;
}

usort(
    $filteredTourists,
    static function (
        array $a,
        array $b
    ) use ($sort): int {
        return match ($sort) {
            'name' => strcasecmp(
                (string)(
                    $a['full_name']
                    ?? ''
                ),
                (string)(
                    $b['full_name']
                    ?? ''
                )
            ),

            'expiry' => strcmp(
                (string)(
                    $a['visa_expiry_date']
                    ?? '9999-12-31'
                ),
                (string)(
                    $b['visa_expiry_date']
                    ?? '9999-12-31'
                )
            ),

            'entry' => strcmp(
                (string)(
                    $a['_actual_entry_at']
                    ?? '9999-12-31'
                ),
                (string)(
                    $b['_actual_entry_at']
                    ?? '9999-12-31'
                )
            ),

            default =>
                (
                    (int)(
                        $a['_remaining_days']
                        ?? PHP_INT_MAX
                    )
                    <=>
                    (int)(
                        $b['_remaining_days']
                        ?? PHP_INT_MAX
                    )
                ),
        };
    }
);

// Reports
$chartActive = $activeCount;
$chartExpiring = $expiringSoonCount;
$chartDepartureNotReported =
    $departureNotReportedCount;

$trendLabels = [];
$trendValues = [];

foreach ($trendData as $item) {
    if (!is_array($item)) {
        continue;
    }

    $label =
        $item['date']
        ?? $item['label']
        ?? $item['day']
        ?? null;

    $value =
        $item['total']
        ?? $item['count']
        ?? $item['value']
        ?? 0;

    if ($label !== null) {
        $trendLabels[] =
            (string)$label;

        $trendValues[] =
            safeInt($value);
    }
}

$expiry7 = 0;
$expiry14 = 0;
$expiry30 = 0;

foreach ($normalizedTourists as $tourist) {
    $remaining =
        $tourist['_remaining_days']
        ?? null;

    $status =
        normalizeStatus(
            $tourist['_status']
            ?? ''
        );

    if (
        $remaining === null
        || $remaining === ''
        || !in_array(
            $status,
            ['ACTIVE', 'EXPIRING_SOON'],
            true
        )
    ) {
        continue;
    }

    $days = (int)$remaining;

    if ($days >= 0 && $days <= 7) {
        $expiry7++;
    }

    if ($days >= 0 && $days <= 14) {
        $expiry14++;
    }

    if ($days >= 0 && $days <= 30) {
        $expiry30++;
    }
}

render_admin_start(
    'Visa Management',
    $admin,
    'visa'
);
?>

<link
    rel="stylesheet"
    href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css"
>

<style>
.visa-page {
    --vm-bg:#f6f8fc;
    --vm-surface:#ffffff;
    --vm-soft:#f8fafc;
    --vm-border:#e5e7eb;
    --vm-text:#0f172a;
    --vm-muted:#64748b;
    --vm-primary:#2563eb;
    --vm-primary-soft:#eff6ff;
    --vm-green:#15803d;
    --vm-green-soft:#f0fdf4;
    --vm-yellow:#b45309;
    --vm-yellow-soft:#fffbeb;
    --vm-red:#b91c1c;
    --vm-red-soft:#fef2f2;
    --vm-blue:#1d4ed8;
    --vm-blue-soft:#eff6ff;
    --vm-purple:#6d28d9;
    --vm-purple-soft:#f5f3ff;
    --vm-shadow:0 8px 28px rgba(15,23,42,.055);
    max-width:1500px;
    margin:0 auto;
    padding:10px 28px 48px;
    color:var(--vm-text);
    font-family:Inter,-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;
}

.visa-page * {
    box-sizing:border-box;
}

.vm-header {
    display:flex;
    justify-content:space-between;
    align-items:flex-start;
    gap:24px;
    margin:4px 0 22px;
}

.vm-eyebrow {
    display:inline-flex;
    align-items:center;
    gap:7px;
    color:var(--vm-primary);
    font-size:11px;
    font-weight:800;
    letter-spacing:.08em;
    text-transform:uppercase;
    margin-bottom:7px;
}

.vm-title {
    margin:0;
    font-size:28px;
    line-height:1.15;
    font-weight:850;
    letter-spacing:-.025em;
}

.vm-subtitle {
    max-width:680px;
    margin:7px 0 0;
    color:var(--vm-muted);
    font-size:13px;
    line-height:1.55;
}

.vm-header-meta {
    display:flex;
    align-items:center;
    gap:9px;
    flex-wrap:wrap;
}

.vm-counter {
    display:flex;
    align-items:center;
    gap:8px;
    min-height:38px;
    padding:7px 11px;
    border:1px solid var(--vm-border);
    border-radius:11px;
    background:#fff;
    box-shadow:0 2px 8px rgba(15,23,42,.025);
    color:#475569;
    font-size:11px;
    font-weight:700;
}

.vm-counter strong {
    color:var(--vm-text);
    font-size:13px;
}

.vm-message {
    display:flex;
    align-items:flex-start;
    gap:10px;
    padding:12px 14px;
    margin-bottom:17px;
    border:1px solid;
    border-radius:12px;
    font-size:12px;
    line-height:1.5;
}

.vm-message.success {
    border-color:#bbf7d0;
    background:var(--vm-green-soft);
    color:#166534;
}

.vm-message.error {
    border-color:#fecaca;
    background:var(--vm-red-soft);
    color:#991b1b;
}

.vm-tabs {
    display:flex;
    gap:4px;
    padding:4px;
    margin-bottom:22px;
    width:max-content;
    max-width:100%;
    border:1px solid var(--vm-border);
    border-radius:13px;
    background:#fff;
    box-shadow:0 2px 10px rgba(15,23,42,.025);
}

.vm-tab {
    display:flex;
    align-items:center;
    gap:8px;
    min-height:38px;
    padding:8px 14px;
    border-radius:9px;
    color:#64748b;
    text-decoration:none;
    font-size:12px;
    font-weight:750;
    transition:.15s ease;
}

.vm-tab:hover {
    background:var(--vm-soft);
    color:#334155;
}

.vm-tab.active {
    background:var(--vm-primary-soft);
    color:#1d4ed8;
}

.vm-tab-count {
    min-width:20px;
    height:20px;
    display:inline-flex;
    align-items:center;
    justify-content:center;
    padding:0 6px;
    border-radius:999px;
    background:#dbeafe;
    color:#1d4ed8;
    font-size:9px;
    font-weight:850;
}

.section {
    border:1px solid var(--vm-border);
    border-radius:16px;
    background:var(--vm-surface);
    box-shadow:var(--vm-shadow);
    overflow:hidden;
}

.section-header {
    display:flex;
    align-items:flex-start;
    justify-content:space-between;
    gap:18px;
    padding:18px 20px;
    border-bottom:1px solid var(--vm-border);
}

.section-title {
    margin:0;
    font-size:15px;
    font-weight:800;
}

.section-description {
    margin:4px 0 0;
    color:var(--vm-muted);
    font-size:11px;
    line-height:1.5;
}

.section-body {
    padding:18px 20px;
}

.summary-pill {
    display:inline-flex;
    align-items:center;
    gap:7px;
    padding:6px 9px;
    border:1px solid var(--vm-border);
    border-radius:999px;
    background:var(--vm-soft);
    color:#64748b;
    font-size:10px;
    font-weight:750;
    white-space:nowrap;
}

.empty-state {
    display:flex;
    flex-direction:column;
    align-items:center;
    justify-content:center;
    text-align:center;
    min-height:210px;
    padding:30px;
    color:#64748b;
}

.empty-icon {
    width:46px;
    height:46px;
    display:flex;
    align-items:center;
    justify-content:center;
    border-radius:14px;
    background:#f1f5f9;
    color:#94a3b8;
    font-size:18px;
    margin-bottom:12px;
}

.empty-state strong {
    color:#334155;
    font-size:13px;
}

.empty-state p {
    max-width:420px;
    margin:5px 0 0;
    font-size:11px;
    line-height:1.55;
}

/* Approval */
.approval-list {
    display:flex;
    flex-direction:column;
}

.approval-item {
    border-bottom:1px solid #edf0f4;
}

.approval-item:last-child {
    border-bottom:0;
}

.approval-item summary {
    list-style:none;
    cursor:pointer;
    padding:14px 18px;
}

.approval-item summary::-webkit-details-marker {
    display:none;
}

.approval-summary {
    display:grid;
    grid-template-columns:minmax(230px,1.7fr) minmax(130px,.8fr) minmax(130px,.9fr) minmax(120px,.8fr) 36px;
    gap:14px;
    align-items:center;
}

.person {
    display:flex;
    align-items:center;
    gap:11px;
    min-width:0;
}

.avatar {
    width:37px;
    height:37px;
    flex:0 0 auto;
    display:flex;
    align-items:center;
    justify-content:center;
    border-radius:11px;
    background:#eef2ff;
    color:#3730a3;
    font-size:12px;
    font-weight:850;
}

.person-name {
    color:#0f172a;
    font-size:12px;
    font-weight:800;
    white-space:nowrap;
    overflow:hidden;
    text-overflow:ellipsis;
}

.person-sub {
    margin-top:2px;
    color:#94a3b8;
    font-size:10px;
    white-space:nowrap;
    overflow:hidden;
    text-overflow:ellipsis;
}

.summary-label {
    color:#94a3b8;
    font-size:9px;
    font-weight:750;
    text-transform:uppercase;
    letter-spacing:.04em;
}

.summary-value {
    margin-top:3px;
    color:#334155;
    font-size:11px;
    font-weight:700;
}

.chevron {
    width:32px;
    height:32px;
    display:flex;
    align-items:center;
    justify-content:center;
    border-radius:9px;
    color:#94a3b8;
    transition:.15s ease;
}

.approval-item[open] .chevron {
    transform:rotate(180deg);
    background:#f1f5f9;
    color:#475569;
}

.approval-detail {
    padding:2px 18px 18px;
    background:#fbfcfe;
}

.detail-grid {
    display:grid;
    grid-template-columns:repeat(4,minmax(0,1fr));
    gap:12px;
    padding:15px;
    border:1px solid #e8edf3;
    border-radius:13px;
    background:#fff;
}

.detail-cell {
    min-width:0;
}

.detail-cell.wide {
    grid-column:span 2;
}

.detail-label {
    color:#94a3b8;
    font-size:9px;
    font-weight:750;
    text-transform:uppercase;
    letter-spacing:.04em;
}

.detail-value {
    margin-top:4px;
    color:#334155;
    font-size:11px;
    font-weight:700;
    line-height:1.45;
    overflow-wrap:anywhere;
}

.approval-actions {
    display:flex;
    align-items:center;
    justify-content:space-between;
    gap:12px;
    flex-wrap:wrap;
    margin-top:13px;
}

.action-group {
    display:flex;
    align-items:center;
    gap:8px;
    flex-wrap:wrap;
}

.btn {
    min-height:36px;
    display:inline-flex;
    align-items:center;
    justify-content:center;
    gap:7px;
    padding:8px 12px;
    border:1px solid transparent;
    border-radius:9px;
    font-size:10px;
    font-weight:800;
    text-decoration:none;
    cursor:pointer;
    transition:.15s ease;
}

.btn:hover {
    transform:translateY(-1px);
}

.btn-view {
    border-color:#bfdbfe;
    background:#fff;
    color:#1d4ed8;
}

.btn-approve {
    border-color:#bbf7d0;
    background:#16a34a;
    color:#fff;
}

.btn-reject {
    border-color:#fecaca;
    background:#fff;
    color:#b91c1c;
}

.btn-primary {
    background:#2563eb;
    color:#fff;
}

.btn-reset {
    border-color:#e2e8f0;
    background:#fff;
    color:#475569;
}

.reject-form {
    display:flex;
    align-items:center;
    gap:7px;
}

.input,
.select {
    min-height:36px;
    width:100%;
    padding:8px 10px;
    border:1px solid #dbe1e8;
    border-radius:9px;
    outline:none;
    background:#fff;
    color:#334155;
    font-size:11px;
}

.input:focus,
.select:focus {
    border-color:#93c5fd;
    box-shadow:0 0 0 3px rgba(59,130,246,.09);
}

.reject-input {
    width:230px;
}

/* Monitor */
.monitor-summary {
    display:grid;
    grid-template-columns:repeat(6,minmax(0,1fr));
    border:1px solid var(--vm-border);
    border-radius:14px;
    background:#fff;
    margin-bottom:14px;
    overflow:hidden;
}

.monitor-stat {
    padding:13px 14px;
    border-right:1px solid #edf0f4;
}

.monitor-stat:last-child {
    border-right:0;
}

.monitor-stat-label {
    color:#94a3b8;
    font-size:9px;
    font-weight:750;
    text-transform:uppercase;
    letter-spacing:.04em;
}

.monitor-stat-value {
    margin-top:4px;
    font-size:18px;
    font-weight:850;
    color:#0f172a;
}

.monitor-stat-note {
    margin-top:2px;
    color:#94a3b8;
    font-size:9px;
}

.filters {
    display:grid;
    grid-template-columns:minmax(220px,1.7fr) repeat(3,minmax(130px,.8fr)) auto;
    gap:9px;
    align-items:end;
    padding:13px;
    margin-bottom:14px;
    border:1px solid var(--vm-border);
    border-radius:13px;
    background:#fff;
}

.filter-field label {
    display:block;
    margin-bottom:5px;
    color:#64748b;
    font-size:9px;
    font-weight:750;
}

.filter-actions {
    display:flex;
    gap:7px;
}

.table-wrap {
    overflow:auto;
}

.data-table {
    width:100%;
    min-width:1000px;
    border-collapse:separate;
    border-spacing:0;
}

.data-table th {
    padding:10px 14px;
    border-bottom:1px solid #e8edf3;
    background:#f8fafc;
    color:#94a3b8;
    font-size:9px;
    font-weight:800;
    letter-spacing:.04em;
    text-transform:uppercase;
    text-align:left;
}

.data-table td {
    padding:13px 14px;
    border-bottom:1px solid #edf0f4;
    color:#334155;
    font-size:11px;
    vertical-align:middle;
}

.data-table tbody tr:last-child td {
    border-bottom:0;
}

.data-table tbody tr:hover td {
    background:#fbfdff;
}

.visa-chip {
    display:inline-flex;
    align-items:center;
    padding:5px 8px;
    border-radius:8px;
    background:#f1f5f9;
    color:#334155;
    font-size:9px;
    font-weight:850;
}

.status-badge {
    display:inline-flex;
    align-items:center;
    gap:6px;
    padding:6px 8px;
    border-radius:999px;
    font-size:9px;
    font-weight:800;
    white-space:nowrap;
}

.status-green {
    background:#ecfdf3;
    color:#15803d;
}

.status-yellow {
    background:#fffbeb;
    color:#b45309;
}

.status-red {
    background:#fef2f2;
    color:#b91c1c;
}

.status-blue {
    background:#eff6ff;
    color:#1d4ed8;
}

.status-purple {
    background:#f5f3ff;
    color:#6d28d9;
}

.status-dark {
    background:#f3f4f6;
    color:#374151;
}

.status-gray {
    background:#f8fafc;
    color:#64748b;
}

.remaining-safe {
    color:#15803d;
    font-weight:800;
}

.remaining-warning {
    color:#b45309;
    font-weight:800;
}

.remaining-danger {
    color:#b91c1c;
    font-weight:800;
}

.remaining-neutral {
    color:#64748b;
    font-weight:700;
}

.table-action {
    width:33px;
    height:33px;
    display:inline-flex;
    align-items:center;
    justify-content:center;
    border:1px solid #dbeafe;
    border-radius:9px;
    background:#fff;
    color:#2563eb;
    text-decoration:none;
    transition:.15s ease;
}

.table-action:hover {
    background:#eff6ff;
}

/* Reports */
.report-grid {
    display:grid;
    grid-template-columns:repeat(4,minmax(0,1fr));
    gap:12px;
}

.report-card {
    border:1px solid var(--vm-border);
    border-radius:14px;
    background:#fff;
    padding:15px;
}

.report-card-label {
    color:#94a3b8;
    font-size:9px;
    font-weight:750;
    text-transform:uppercase;
    letter-spacing:.04em;
}

.report-card-value {
    margin-top:7px;
    color:#0f172a;
    font-size:24px;
    font-weight:850;
}

.report-panels {
    display:grid;
    grid-template-columns:repeat(2,minmax(0,1fr));
    gap:14px;
    margin-top:14px;
}

.report-panel {
    border:1px solid var(--vm-border);
    border-radius:14px;
    background:#fff;
    overflow:hidden;
}

.report-panel-head {
    padding:14px 16px;
    border-bottom:1px solid #edf0f4;
}

.report-panel-title {
    margin:0;
    font-size:12px;
    font-weight:800;
}

.report-panel-subtitle {
    margin:3px 0 0;
    color:#94a3b8;
    font-size:9px;
}

.report-table {
    width:100%;
    border-collapse:collapse;
}

.report-table td,
.report-table th {
    padding:10px 16px;
    border-bottom:1px solid #edf0f4;
    font-size:10px;
    text-align:left;
}

.report-table tr:last-child td {
    border-bottom:0;
}

.report-table td:last-child {
    text-align:right;
    font-weight:800;
    color:#0f172a;
}

.report-highlight {
    padding:18px 16px;
}

.big-value {
    font-size:28px;
    font-weight:850;
    color:#0f172a;
}

.report-note {
    margin:7px 0 0;
    color:#64748b;
    font-size:10px;
    line-height:1.5;
}

.interpretation {
    margin:0;
    padding:14px 16px 14px 32px;
    color:#475569;
    font-size:10px;
    line-height:1.7;
}

@media (max-width:1100px) {
    .monitor-summary {
        grid-template-columns:repeat(3,1fr);
    }

    .monitor-stat:nth-child(3) {
        border-right:0;
    }

    .filters {
        grid-template-columns:repeat(2,1fr);
    }

    .filter-actions {
        grid-column:1/-1;
    }

    .detail-grid,
    .report-grid {
        grid-template-columns:repeat(2,1fr);
    }
}

@media (max-width:760px) {
    .visa-page {
        padding:8px 14px 34px;
    }

    .vm-header {
        flex-direction:column;
    }

    .vm-tabs {
        width:100%;
    }

    .vm-tab {
        flex:1;
        justify-content:center;
    }

    .approval-summary {
        grid-template-columns:1fr 36px;
    }

    .approval-summary > div:not(.person):not(.chevron) {
        display:none;
    }

    .detail-grid,
    .report-grid,
    .report-panels,
    .monitor-summary,
    .filters {
        grid-template-columns:1fr;
    }

    .monitor-stat {
        border-right:0;
        border-bottom:1px solid #edf0f4;
    }

    .monitor-stat:last-child {
        border-bottom:0;
    }

    .detail-cell.wide {
        grid-column:auto;
    }

    .approval-actions,
    .reject-form {
        align-items:stretch;
        flex-direction:column;
    }

    .reject-input {
        width:100%;
    }
}
</style>

<div class="visa-page">

    <div class="vm-header">
        <div>
            <p class="vm-subtitle">
                Review visa submissions, monitor actual travel declarations,
                and analyse visa activity from one workspace.
            </p>
        </div>

        <div class="vm-header-meta">
            <div class="vm-counter">
                <i class="fa-regular fa-clock"></i>
                Pending
                <strong><?= e($pendingCount) ?></strong>
            </div>

            <div class="vm-counter">
                <i class="fa-solid fa-circle-check"></i>
                Approved
                <strong><?= e($totalApproved) ?></strong>
            </div>
            <a
                href="admin_dashboard.php"
                class="btn btn-reset"
            >
                <i class="fa-solid fa-arrow-left"></i>
                Dashboard
            </a>

        </div>
    </div>

    <?php if ($message !== ''): ?>
        <div class="vm-message <?= e($messageType) ?>">
            <i class="fa-solid <?= $messageType === 'success'
                ? 'fa-circle-check'
                : 'fa-triangle-exclamation'
            ?>"></i>

            <div>
                <?= e($message) ?>
            </div>
        </div>
    <?php endif; ?>

    <nav class="vm-tabs" aria-label="Visa management sections">
        <a
            href="?tab=approve"
            class="vm-tab <?= $activeTab === 'approve'
                ? 'active'
                : ''
            ?>"
        >
            <i class="fa-regular fa-circle-check"></i>
            Approval

            <?php if ($pendingCount > 0): ?>
                <span class="vm-tab-count">
                    <?= e($pendingCount) ?>
                </span>
            <?php endif; ?>
        </a>

        <a
            href="?tab=monitor"
            class="vm-tab <?= $activeTab === 'monitor'
                ? 'active'
                : ''
            ?>"
        >
            <i class="fa-solid fa-location-dot"></i>
            Monitor
        </a>

        <a
            href="?tab=reports"
            class="vm-tab <?= $activeTab === 'reports'
                ? 'active'
                : ''
            ?>"
        >
            <i class="fa-solid fa-chart-line"></i>
            Reports
        </a>
    </nav>

    <?php if ($activeTab === 'approve'): ?>
        <section class="section">
            <div class="section-header">
                <div>
                    <h2 class="section-title">
                        Pending Visa Applications
                    </h2>

                    <p class="section-description">
                        Open an application only when you need the complete
                        details and approval controls.
                    </p>
                </div>

                <span class="summary-pill">
                    <?= e($pendingCount) ?>
                    waiting
                </span>
            </div>

            <?php if (empty($pendingApplications)): ?>
                <div class="empty-state">
                    <div class="empty-icon">
                        <i class="fa-solid fa-check"></i>
                    </div>

                    <strong>
                        No pending applications
                    </strong>

                    <p>
                        Every submitted visa application has already
                        been processed.
                    </p>
                </div>
            <?php else: ?>
                <div class="approval-list">
                    <?php foreach ($pendingApplications as $application): ?>
                        <?php
                        if (!is_array($application)) {
                            continue;
                        }

                        $submissionId = (string)(
                            $application['id']
                            ?? ''
                        );

                        $applicantName = (string)(
                            $application['full_name']
                            ?? 'Unknown Applicant'
                        );

                        $referenceId = (string)(
                            $application['reference_id']
                            ?? '—'
                        );

                        $passportNumber = (string)(
                            $application['passport_number']
                            ?? '—'
                        );

                        $nationality = (string)(
                            $application['nationality']
                            ?? '—'
                        );

                        $purpose = (string)(
                            $application['purpose_of_visit']
                            ?? '—'
                        );

                        $visaType = strtoupper(
                            trim(
                                (string)(
                                    $application['visa_type']
                                    ?? ''
                                )
                            )
                        );

                        $initial = $applicantName !== ''
                            ? strtoupper(
                                substr(
                                    $applicantName,
                                    0,
                                    1
                                )
                            )
                            : '?';
                        ?>

                        <details class="approval-item">
                            <summary>
                                <div class="approval-summary">
                                    <div class="person">
                                        <div class="avatar">
                                            <?= e($initial) ?>
                                        </div>

                                        <div>
                                            <div class="person-name">
                                                <?= e($applicantName) ?>
                                            </div>

                                            <div class="person-sub">
                                                <?= e($passportNumber) ?>
                                                ·
                                                <?= e($referenceId) ?>
                                            </div>
                                        </div>
                                    </div>

                                    <div>
                                        <div class="summary-label">
                                            Visa
                                        </div>

                                        <div class="summary-value">
                                            <?= e(
                                                $visaType !== ''
                                                    ? $visaType
                                                    : '—'
                                            ) ?>
                                        </div>
                                    </div>

                                    <div>
                                        <div class="summary-label">
                                            Planned Arrival
                                        </div>

                                        <div class="summary-value">
                                            <?= e(
                                                formatDate(
                                                    $application[
                                                        'arrival_date'
                                                    ] ?? null
                                                )
                                            ) ?>
                                        </div>
                                    </div>

                                    <div>
                                        <div class="summary-label">
                                            Submitted
                                        </div>

                                        <div class="summary-value">
                                            <?= e(
                                                formatDate(
                                                    $application[
                                                        'submitted_at'
                                                    ] ?? null
                                                )
                                            ) ?>
                                        </div>
                                    </div>

                                    <div class="chevron">
                                        <i class="fa-solid fa-chevron-down"></i>
                                    </div>
                                </div>
                            </summary>

                            <div class="approval-detail">
                                <div class="detail-grid">
                                    <div class="detail-cell">
                                        <div class="detail-label">
                                            Reference ID
                                        </div>

                                        <div class="detail-value">
                                            <?= e($referenceId) ?>
                                        </div>
                                    </div>

                                    <div class="detail-cell">
                                        <div class="detail-label">
                                            Passport
                                        </div>

                                        <div class="detail-value">
                                            <?= e($passportNumber) ?>
                                        </div>
                                    </div>

                                    <div class="detail-cell">
                                        <div class="detail-label">
                                            Nationality
                                        </div>

                                        <div class="detail-value">
                                            <?= e($nationality) ?>
                                        </div>
                                    </div>

                                    <div class="detail-cell">
                                        <div class="detail-label">
                                            Visa Type
                                        </div>

                                        <div class="detail-value">
                                            <?= e(
                                                $visaType !== ''
                                                    ? $visaType
                                                    : '—'
                                            ) ?>
                                        </div>
                                    </div>

                                    <div class="detail-cell">
                                        <div class="detail-label">
                                            Planned Arrival
                                        </div>

                                        <div class="detail-value">
                                            <?= e(
                                                formatDate(
                                                    $application[
                                                        'arrival_date'
                                                    ] ?? null
                                                )
                                            ) ?>
                                        </div>
                                    </div>

                                    <div class="detail-cell">
                                        <div class="detail-label">
                                            Planned Departure
                                        </div>

                                        <div class="detail-value">
                                            <?= e(
                                                formatDate(
                                                    $application[
                                                        'departure_date'
                                                    ] ?? null
                                                )
                                            ) ?>
                                        </div>
                                    </div>

                                    <div class="detail-cell">
                                        <div class="detail-label">
                                            Submitted
                                        </div>

                                        <div class="detail-value">
                                            <?= e(
                                                formatDateTime(
                                                    $application[
                                                        'submitted_at'
                                                    ] ?? null
                                                )
                                            ) ?>
                                        </div>
                                    </div>

                                    <div class="detail-cell wide">
                                        <div class="detail-label">
                                            Purpose of Visit
                                        </div>

                                        <div class="detail-value">
                                            <?= e($purpose) ?>
                                        </div>
                                    </div>
                                </div>

                                <div class="approval-actions">
                                    <div class="action-group">
                                        <?php if (!empty(
                                            $application['pdf_url']
                                        )): ?>
                                            <a
                                                href="<?= e(
                                                    $application[
                                                        'pdf_url'
                                                    ]
                                                ) ?>"
                                                target="_blank"
                                                rel="noopener noreferrer"
                                                class="btn btn-view"
                                            >
                                                <i class="fa-regular fa-file-pdf"></i>
                                                View PDF
                                            </a>
                                        <?php else: ?>
                                            <span class="summary-pill">
                                                PDF unavailable
                                            </span>
                                        <?php endif; ?>

                                        <form
                                            method="POST"
                                            onsubmit="return confirm(
                                                'Approve this visa application?'
                                            );"
                                        >
                                            <input
                                                type="hidden"
                                                name="action"
                                                value="approve"
                                            >

                                            <input
                                                type="hidden"
                                                name="submission_id"
                                                value="<?= e(
                                                    $submissionId
                                                ) ?>"
                                            >

                                            <button
                                                type="submit"
                                                class="btn btn-approve"
                                            >
                                                <i class="fa-solid fa-check"></i>
                                                Approve
                                            </button>
                                        </form>
                                    </div>

                                    <form
                                        method="POST"
                                        class="reject-form"
                                    >
                                        <input
                                            type="hidden"
                                            name="action"
                                            value="reject"
                                        >

                                        <input
                                            type="hidden"
                                            name="submission_id"
                                            value="<?= e(
                                                $submissionId
                                            ) ?>"
                                        >

                                        <input
                                            type="text"
                                            name="rejection_reason"
                                            required
                                            maxlength="500"
                                            placeholder="Reason for rejection"
                                            class="input reject-input"
                                        >

                                        <button
                                            type="submit"
                                            class="btn btn-reject"
                                        >
                                            <i class="fa-solid fa-xmark"></i>
                                            Reject
                                        </button>
                                    </form>
                                </div>
                            </div>
                        </details>
                    <?php endforeach; ?>
                </div>
            <?php endif; ?>
        </section>
    <?php endif; ?>

    <?php if ($activeTab === 'monitor'): ?>
        <div class="monitor-summary">
            <div class="monitor-stat">
                <div class="monitor-stat-label">
                    Approved Visas
                </div>
                <div class="monitor-stat-value">
                    <?= e($totalApproved) ?>
                </div>
                <div class="monitor-stat-note">
                    all approved records
                </div>
            </div>

            <div class="monitor-stat">
                <div class="monitor-stat-label">
                    Active Stays
                </div>
                <div class="monitor-stat-value">
                    <?= e($activeCount) ?>
                </div>
                <div class="monitor-stat-note">
                    normal monitoring
                </div>
            </div>

            <div class="monitor-stat">
                <div class="monitor-stat-label">
                    Expiring Soon
                </div>
                <div class="monitor-stat-value">
                    <?= e($expiringSoonCount) ?>
                </div>
                <div class="monitor-stat-note">
                    within 10 days
                </div>
            </div>

            <div class="monitor-stat">
                <div class="monitor-stat-label">
                    Overdue
                </div>
                <div class="monitor-stat-value">
                    <?= e($departureNotReportedCount) ?>
                </div>
                <div class="monitor-stat-note">
                    departure missing
                </div>
            </div>

            <div class="monitor-stat">
                <div class="monitor-stat-label">
                    Not Entered
                </div>
                <div class="monitor-stat-value">
                    <?= e($notEnteredCount) ?>
                </div>
                <div class="monitor-stat-note">
                    no actual arrival
                </div>
            </div>

            <div class="monitor-stat">
                <div class="monitor-stat-label">
                    Completed
                </div>
                <div class="monitor-stat-value">
                    <?= e(
                        $departedCount
                        + $usedCount
                    ) ?>
                </div>
                <div class="monitor-stat-note">
                    departed / used
                </div>
            </div>
        </div>

        <section class="section">
            <div class="section-header">
                <div>
                    <h2 class="section-title">
                        Approved Visa Monitoring
                    </h2>

                    <p class="section-description">
                        Actual travel status is read from
                        visa_travel_records.
                    </p>
                </div>

                <div class="action-group">
                    <span class="summary-pill">
                        <?= e(count($filteredTourists)) ?>
                        shown
                    </span>

                    <a
                        href="visa_export.php?type=csv&export=all"
                        class="btn btn-view"
                        title="Export all approved visa monitoring records as CSV"
                    >
                        <i class="fa-solid fa-file-csv"></i>
                        CSV
                    </a>

                    <a
                        href="visa_export.php?type=pdf&export=all"
                        class="btn btn-view"
                        title="Export all approved visa monitoring records as PDF"
                    >
                        <i class="fa-regular fa-file-pdf"></i>
                        PDF
                    </a>

                    <a
                        href="visa_export.php?type=csv&export=overstay"
                        class="btn btn-reject"
                        title="Export departure-not-reported records as CSV"
                    >
                        <i class="fa-solid fa-triangle-exclamation"></i>
                        Export Overdue
                    </a>
                </div>
            </div>

            <div class="section-body">
                <form
                    method="GET"
                    class="filters"
                >
                    <input
                        type="hidden"
                        name="tab"
                        value="monitor"
                    >

                    <div class="filter-field">
                        <label>
                            Search
                        </label>

                        <input
                            type="text"
                            name="search"
                            value="<?= e($search) ?>"
                            placeholder="Name, passport or reference"
                            class="input"
                        >
                    </div>

                    <div class="filter-field">
                        <label>
                            Status
                        </label>

                        <select
                            name="status_filter"
                            class="select"
                        >
                            <?php foreach (
                                $allowedStatusFilters
                                as $option
                            ): ?>
                                <option
                                    value="<?= e($option) ?>"
                                    <?= $statusFilter === $option
                                        ? 'selected'
                                        : ''
                                    ?>
                                >
                                    <?= e(
                                        $option === 'ALL'
                                            ? 'All statuses'
                                            : statusLabel(
                                                $option
                                            )
                                    ) ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </div>

                    <div class="filter-field">
                        <label>
                            Visa Type
                        </label>

                        <select
                            name="visa_filter"
                            class="select"
                        >
                            <option
                                value="ALL"
                                <?= $visaFilter === 'ALL'
                                    ? 'selected'
                                    : ''
                                ?>
                            >
                                All visa types
                            </option>

                            <option
                                value="SEV"
                                <?= $visaFilter === 'SEV'
                                    ? 'selected'
                                    : ''
                                ?>
                            >
                                SEV
                            </option>

                            <option
                                value="MEV"
                                <?= $visaFilter === 'MEV'
                                    ? 'selected'
                                    : ''
                                ?>
                            >
                                MEV
                            </option>
                        </select>
                    </div>

                    <div class="filter-field">
                        <label>
                            Sort By
                        </label>

                        <select
                            name="sort"
                            class="select"
                        >
                            <option
                                value="remaining"
                                <?= $sort === 'remaining'
                                    ? 'selected'
                                    : ''
                                ?>
                            >
                                Remaining stay
                            </option>

                            <option
                                value="name"
                                <?= $sort === 'name'
                                    ? 'selected'
                                    : ''
                                ?>
                            >
                                Tourist name
                            </option>

                            <option
                                value="expiry"
                                <?= $sort === 'expiry'
                                    ? 'selected'
                                    : ''
                                ?>
                            >
                                Visa expiry
                            </option>

                            <option
                                value="entry"
                                <?= $sort === 'entry'
                                    ? 'selected'
                                    : ''
                                ?>
                            >
                                Actual arrival
                            </option>
                        </select>
                    </div>

                    <div class="filter-actions">
                        <button
                            type="submit"
                            class="btn btn-primary"
                        >
                            <i class="fa-solid fa-filter"></i>
                            Apply
                        </button>

                        <a
                            href="?tab=monitor"
                            class="btn btn-reset"
                        >
                            Reset
                        </a>
                    </div>
                </form>

                <?php if (empty($filteredTourists)): ?>
                    <div class="empty-state">
                        <div class="empty-icon">
                            <i class="fa-solid fa-magnifying-glass"></i>
                        </div>

                        <strong>
                            No matching visa records
                        </strong>

                        <p>
                            Try another status, visa type,
                            or search term.
                        </p>
                    </div>
                <?php else: ?>
                    <div class="table-wrap">
                        <table class="data-table">
                            <thead>
                                <tr>
                                    <th>Tourist</th>
                                    <th>Visa</th>
                                    <th>Actual Arrival</th>
                                    <th>Stay Until</th>
                                    <th>Remaining</th>
                                    <th>Status</th>
                                    <th>Visa Expiry</th>
                                    <th>Trips</th>
                                    <th></th>
                                </tr>
                            </thead>

                            <tbody>
                                <?php foreach (
                                    $filteredTourists
                                    as $tourist
                                ): ?>
                                    <?php
                                    $touristId = (string)(
                                        $tourist['id']
                                        ?? ''
                                    );

                                    $fullName = (string)(
                                        $tourist['full_name']
                                        ?? 'Unknown'
                                    );

                                    $passport = (string)(
                                        $tourist[
                                            'passport_number'
                                        ] ?? '—'
                                    );

                                    $reference = (string)(
                                        $tourist['reference_id']
                                        ?? '—'
                                    );

                                    $touristVisaType =
                                        strtoupper(
                                            trim(
                                                (string)(
                                                    $tourist[
                                                        'visa_type'
                                                    ] ?? '—'
                                                )
                                            )
                                        );

                                    $status =
                                        normalizeStatus(
                                            $tourist['_status']
                                            ?? 'NOT_ENTERED'
                                        );

                                    $remainingClass =
                                        match ($status) {
                                            'ACTIVE' =>
                                                'remaining-safe',
                                            'EXPIRING_SOON' =>
                                                'remaining-warning',
                                            'DEPARTURE_NOT_REPORTED' =>
                                                'remaining-danger',
                                            default =>
                                                'remaining-neutral',
                                        };

                                    $initial =
                                        $fullName !== ''
                                            ? strtoupper(
                                                substr(
                                                    $fullName,
                                                    0,
                                                    1
                                                )
                                            )
                                            : '?';
                                    ?>

                                    <tr>
                                        <td>
                                            <div class="person">
                                                <div class="avatar">
                                                    <?= e($initial) ?>
                                                </div>

                                                <div>
                                                    <div class="person-name">
                                                        <?= e($fullName) ?>
                                                    </div>

                                                    <div class="person-sub">
                                                        <?= e($passport) ?>
                                                        ·
                                                        <?= e($reference) ?>
                                                    </div>
                                                </div>
                                            </div>
                                        </td>

                                        <td>
                                            <span class="visa-chip">
                                                <?= e(
                                                    $touristVisaType
                                                ) ?>
                                            </span>
                                        </td>

                                        <td>
                                            <?= e(
                                                formatDateTime(
                                                    $tourist[
                                                        '_actual_entry_at'
                                                    ] ?? null
                                                )
                                            ) ?>
                                        </td>

                                        <td>
                                            <?= e(
                                                formatDate(
                                                    $tourist[
                                                        '_stay_until_date'
                                                    ] ?? null
                                                )
                                            ) ?>
                                        </td>

                                        <td>
                                            <span class="<?= e(
                                                $remainingClass
                                            ) ?>">
                                                <?= e(
                                                    $tourist[
                                                        '_remaining_label'
                                                    ] ?? '—'
                                                ) ?>
                                            </span>
                                        </td>

                                        <td>
                                            <span class="status-badge <?= e(
                                                $tourist[
                                                    '_status_class'
                                                ] ?? 'status-gray'
                                            ) ?>">
                                                <i class="fa-solid <?= e(
                                                    statusIcon(
                                                        $status
                                                    )
                                                ) ?>"></i>

                                                <?= e(
                                                    statusLabel(
                                                        $status
                                                    )
                                                ) ?>
                                            </span>
                                        </td>

                                        <td>
                                            <?= e(
                                                formatDate(
                                                    $tourist[
                                                        'visa_expiry_date'
                                                    ] ?? null
                                                )
                                            ) ?>
                                        </td>

                                        <td>
                                            <?= e(
                                                $tourist[
                                                    '_trip_count'
                                                ] ?? 0
                                            ) ?>
                                        </td>

                                        <td>
                                            <a
                                                href="visa_travel_records.php?submission_id=<?= rawurlencode(
                                                    $touristId
                                                ) ?>"
                                                class="table-action"
                                                title="View travel records"
                                                aria-label="View travel records for <?= e(
                                                    $fullName
                                                ) ?>"
                                            >
                                                <i class="fa-solid fa-arrow-right"></i>
                                            </a>
                                        </td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                <?php endif; ?>
            </div>
        </section>
    <?php endif; ?>

    <?php if ($activeTab === 'reports'): ?>
        <section class="section">
            <div class="section-header">
                <div>
                    <h2 class="section-title">
                        Visa Monitoring Reports
                    </h2>

                    <p class="section-description">
                        Monitoring metrics based on approved visas
                        and actual travel declarations.
                    </p>
                </div>

                <span class="summary-pill">
                    <i class="fa-solid fa-database"></i>
                    <?= e($totalApproved) ?>
                    approved records
                </span>
            </div>

            <div class="section-body">
                <div class="report-grid">
                    <div class="report-card">
                        <div class="report-card-label">
                            Total Approved
                        </div>

                        <div class="report-card-value">
                            <?= e($totalApproved) ?>
                        </div>
                    </div>

                    <div class="report-card">
                        <div class="report-card-label">
                            Active Stays
                        </div>

                        <div class="report-card-value">
                            <?= e($activeCount) ?>
                        </div>
                    </div>

                    <div class="report-card">
                        <div class="report-card-label">
                            Expiring Soon
                        </div>

                        <div class="report-card-value">
                            <?= e($expiringSoonCount) ?>
                        </div>
                    </div>

                    <div class="report-card">
                        <div class="report-card-label">
                            Departure Not Reported
                        </div>

                        <div class="report-card-value">
                            <?= e(
                                $departureNotReportedCount
                            ) ?>
                        </div>
                    </div>

                    <div class="report-card">
                        <div class="report-card-label">
                            Not Entered
                        </div>

                        <div class="report-card-value">
                            <?= e($notEnteredCount) ?>
                        </div>
                    </div>

                    <div class="report-card">
                        <div class="report-card-label">
                            Departed
                        </div>

                        <div class="report-card-value">
                            <?= e($departedCount) ?>
                        </div>
                    </div>

                    <div class="report-card">
                        <div class="report-card-label">
                            SEV
                        </div>

                        <div class="report-card-value">
                            <?= e($sevCount) ?>
                        </div>
                    </div>

                    <div class="report-card">
                        <div class="report-card-label">
                            MEV
                        </div>

                        <div class="report-card-value">
                            <?= e($mevCount) ?>
                        </div>
                    </div>
                </div>

                <div class="report-panels">
                    <div class="report-panel">
                        <div class="report-panel-head">
                            <h3 class="report-panel-title">
                                Monitoring Risk Distribution
                            </h3>

                            <p class="report-panel-subtitle">
                                Current actual-stay status
                            </p>
                        </div>

                        <table class="report-table">
                            <tr>
                                <td>Active</td>
                                <td><?= e($chartActive) ?></td>
                            </tr>

                            <tr>
                                <td>Expiring Soon</td>
                                <td><?= e($chartExpiring) ?></td>
                            </tr>

                            <tr>
                                <td>Departure Not Reported</td>
                                <td>
                                    <?= e(
                                        $chartDepartureNotReported
                                    ) ?>
                                </td>
                            </tr>
                        </table>
                    </div>

                    <div class="report-panel">
                        <div class="report-panel-head">
                            <h3 class="report-panel-title">
                                Visa Type Distribution
                            </h3>

                            <p class="report-panel-subtitle">
                                Approved visa composition
                            </p>
                        </div>

                        <table class="report-table">
                            <tr>
                                <td>SEV</td>
                                <td><?= e($sevCount) ?></td>
                            </tr>

                            <tr>
                                <td>MEV</td>
                                <td><?= e($mevCount) ?></td>
                            </tr>

                            <tr>
                                <td>Other / Unspecified</td>
                                <td>
                                    <?= e($otherVisaCount) ?>
                                </td>
                            </tr>
                        </table>
                    </div>

                    <div class="report-panel">
                        <div class="report-panel-head">
                            <h3 class="report-panel-title">
                                Stay Expiry Analysis
                            </h3>

                            <p class="report-panel-subtitle">
                                Open stays approaching deadline
                            </p>
                        </div>

                        <table class="report-table">
                            <tr>
                                <td>Within 7 days</td>
                                <td><?= e($expiry7) ?></td>
                            </tr>

                            <tr>
                                <td>Within 14 days</td>
                                <td><?= e($expiry14) ?></td>
                            </tr>

                            <tr>
                                <td>Within 30 days</td>
                                <td><?= e($expiry30) ?></td>
                            </tr>
                        </table>
                    </div>

                    <div class="report-panel">
                        <div class="report-panel-head">
                            <h3 class="report-panel-title">
                                Average Permitted Stay
                            </h3>

                            <p class="report-panel-subtitle">
                                Based on actual trip records
                            </p>
                        </div>

                        <div class="report-highlight">
                            <div class="big-value">
                                <?= $avgPermittedStay !== null
                                    ? e(
                                        (string)$avgPermittedStay
                                    ) . ' days'
                                    : '—'
                                ?>
                            </div>

                            <p class="report-note">
                                Calculated from
                                visa_travel_records using actual
                                entry and stay-until dates.
                            </p>
                        </div>
                    </div>

                    <div class="report-panel">
                        <div class="report-panel-head">
                            <h3 class="report-panel-title">
                                7-Day Visa Activity
                            </h3>

                            <p class="report-panel-subtitle">
                                Approved submission activity
                            </p>
                        </div>

                        <?php if (empty($trendLabels)): ?>
                            <div class="report-highlight">
                                <p class="report-note">
                                    No trend data available.
                                </p>
                            </div>
                        <?php else: ?>
                            <table class="report-table">
                                <thead>
                                    <tr>
                                        <th>Date</th>
                                        <th>Activity</th>
                                    </tr>
                                </thead>

                                <tbody>
                                    <?php foreach (
                                        $trendLabels
                                        as $index => $label
                                    ): ?>
                                        <tr>
                                            <td>
                                                <?= e($label) ?>
                                            </td>

                                            <td>
                                                <?= e(
                                                    $trendValues[
                                                        $index
                                                    ] ?? 0
                                                ) ?>
                                            </td>
                                        </tr>
                                    <?php endforeach; ?>
                                </tbody>
                            </table>
                        <?php endif; ?>
                    </div>

                    <div class="report-panel">
                        <div class="report-panel-head">
                            <h3 class="report-panel-title">
                                Monitoring Interpretation
                            </h3>

                            <p class="report-panel-subtitle">
                                Status meaning used by this module
                            </p>
                        </div>

                        <ul class="interpretation">
                            <li>
                                <strong>Active:</strong>
                                actual arrival exists and the
                                permitted stay remains valid.
                            </li>

                            <li>
                                <strong>Expiring Soon:</strong>
                                10 or fewer permitted-stay days
                                remain.
                            </li>

                            <li>
                                <strong>Departure Not Reported:</strong>
                                permitted stay ended without an
                                actual departure declaration.
                            </li>

                            <li>
                                <strong>Not Entered:</strong>
                                approved visa has no actual
                                arrival record.
                            </li>

                            <li>
                                <strong>Departed:</strong>
                                latest MEV trip has been completed.
                            </li>

                            <li>
                                <strong>Used:</strong>
                                an SEV trip has been completed.
                            </li>

                            <li>
                                <strong>Expired:</strong>
                                visa validity has ended.
                            </li>
                        </ul>
                    </div>
                </div>
            </div>
        </section>
    <?php endif; ?>

</div>

<script>
console.log(
    'Visa Management loaded.',
    <?= jsonForJs([
        'pending' => $pendingCount,
        'approved' => $totalApproved,
        'active' => $activeCount,
        'expiringSoon' =>
            $expiringSoonCount,
        'departureNotReported' =>
            $departureNotReportedCount,
        'notEntered' =>
            $notEnteredCount,
        'departed' =>
            $departedCount,
        'used' =>
            $usedCount,
        'expired' =>
            $expiredCount,
    ]) ?>
);
</script>

<?php render_admin_end(); ?>
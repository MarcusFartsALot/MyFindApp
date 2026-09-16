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


// Report presentation data
$needsAttentionCount =
    $expiringSoonCount
    + $departureNotReportedCount;

$completedCount =
    $departedCount
    + $usedCount;

$attentionTourists = array_values(
    array_filter(
        $normalizedTourists,
        static function (array $tourist): bool {
            $status = normalizeStatus(
                $tourist['_status']
                    ?? ''
            );

            return in_array(
                $status,
                [
                    'EXPIRING_SOON',
                    'DEPARTURE_NOT_REPORTED',
                ],
                true
            );
        }
    )
);

usort(
    $attentionTourists,
    static function (array $a, array $b): int {
        $aStatus = normalizeStatus(
            $a['_status'] ?? ''
        );
        $bStatus = normalizeStatus(
            $b['_status'] ?? ''
        );

        $priority = static fn(string $status): int =>
            $status === 'DEPARTURE_NOT_REPORTED'
                ? 0
                : 1;

        $priorityCompare =
            $priority($aStatus)
            <=> $priority($bStatus);

        if ($priorityCompare !== 0) {
            return $priorityCompare;
        }

        return
            (int)($a['_remaining_days'] ?? PHP_INT_MAX)
            <=>
            (int)($b['_remaining_days'] ?? PHP_INT_MAX);
    }
);

$attentionPreview = array_slice(
    $attentionTourists,
    0,
    6
);

$travelStatusChart = [
    'labels' => [
        'Not Entered',
        'Active',
        'Expiring Soon',
        'Departure Not Reported',
        'Departed',
        'Used',
        'Expired',
    ],
    'values' => [
        $notEnteredCount,
        $activeCount,
        $expiringSoonCount,
        $departureNotReportedCount,
        $departedCount,
        $usedCount,
        $expiredCount,
    ],
];

$visaTypeChart = [
    'labels' => ['SEV', 'MEV'],
    'values' => [$sevCount, $mevCount],
];

if ($otherVisaCount > 0) {
    $visaTypeChart['labels'][] = 'Other';
    $visaTypeChart['values'][] = $otherVisaCount;
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
.report-shell {
    display:flex;
    flex-direction:column;
    gap:14px;
}

.report-toolbar {
    display:flex;
    align-items:flex-start;
    justify-content:space-between;
    gap:18px;
    padding:2px 2px 0;
}

.report-toolbar-copy {
    min-width:0;
}

.report-toolbar-title {
    margin:0;
    font-size:16px;
    font-weight:850;
    letter-spacing:-.015em;
}

.report-toolbar-subtitle {
    margin:4px 0 0;
    color:var(--vm-muted);
    font-size:10px;
    line-height:1.5;
}

.report-toolbar-actions {
    display:flex;
    align-items:center;
    gap:7px;
    flex-wrap:wrap;
}

.report-kpis {
    display:grid;
    grid-template-columns:repeat(4,minmax(0,1fr));
    border:1px solid var(--vm-border);
    border-radius:13px;
    background:#fff;
    overflow:hidden;
}

.report-kpi {
    min-width:0;
    padding:13px 15px;
    border-right:1px solid #edf0f4;
}

.report-kpi:last-child {
    border-right:0;
}

.report-kpi-label {
    color:#94a3b8;
    font-size:8px;
    font-weight:800;
    text-transform:uppercase;
    letter-spacing:.06em;
}

.report-kpi-row {
    display:flex;
    align-items:baseline;
    gap:7px;
    margin-top:3px;
}

.report-kpi-value {
    color:#0f172a;
    font-size:22px;
    line-height:1.1;
    font-weight:850;
}

.report-kpi-note {
    color:#94a3b8;
    font-size:9px;
    line-height:1.35;
}

.report-kpi.attention .report-kpi-value {
    color:#b91c1c;
}

.report-layout {
    display:grid;
    grid-template-columns:minmax(0,1.65fr) minmax(300px,.85fr);
    gap:14px;
}

.report-surface {
    border:1px solid var(--vm-border);
    border-radius:13px;
    background:#fff;
    overflow:hidden;
}

.report-surface-head {
    display:flex;
    align-items:flex-start;
    justify-content:space-between;
    gap:12px;
    padding:13px 15px 11px;
    border-bottom:1px solid #edf0f4;
}

.report-surface-title {
    margin:0;
    color:#0f172a;
    font-size:11px;
    font-weight:850;
}

.report-surface-subtitle {
    margin:3px 0 0;
    color:#94a3b8;
    font-size:8px;
    line-height:1.4;
}

.report-chart-body {
    height:265px;
    padding:13px 14px 10px;
    position:relative;
}

.report-chart-body.compact {
    height:190px;
}

.report-chart-body.trend {
    height:210px;
}

.report-side-stack {
    display:grid;
    gap:14px;
}

.visa-type-wrap {
    display:grid;
    grid-template-columns:145px minmax(0,1fr);
    align-items:center;
    gap:6px;
    padding:10px 12px 12px;
}

.visa-type-chart {
    height:145px;
    position:relative;
}

.report-mini-list {
    display:flex;
    flex-direction:column;
    gap:8px;
}

.report-mini-row {
    display:flex;
    align-items:center;
    justify-content:space-between;
    gap:12px;
    font-size:9px;
}

.report-mini-label {
    display:flex;
    align-items:center;
    gap:7px;
    color:#64748b;
    min-width:0;
}

.report-dot {
    width:7px;
    height:7px;
    border-radius:999px;
    flex:0 0 auto;
}

.report-mini-value {
    color:#0f172a;
    font-weight:850;
}

.report-expiry-strip {
    display:grid;
    grid-template-columns:repeat(3,1fr);
    border-top:1px solid #edf0f4;
}

.report-expiry-item {
    padding:10px 11px;
    border-right:1px solid #edf0f4;
}

.report-expiry-item:last-child {
    border-right:0;
}

.report-expiry-value {
    color:#0f172a;
    font-size:16px;
    font-weight:850;
}

.report-expiry-label {
    margin-top:2px;
    color:#94a3b8;
    font-size:8px;
}

.report-inline-metric {
    display:flex;
    align-items:center;
    justify-content:space-between;
    gap:14px;
    padding:10px 13px;
    border-top:1px solid #edf0f4;
    color:#64748b;
    font-size:9px;
}

.report-inline-metric strong {
    color:#0f172a;
    font-size:11px;
}

.report-attention-head-actions {
    display:flex;
    align-items:center;
    gap:7px;
    flex-wrap:wrap;
}

.attention-table {
    width:100%;
    border-collapse:collapse;
}

.attention-table th {
    padding:8px 13px;
    border-bottom:1px solid #e8edf3;
    background:#f8fafc;
    color:#94a3b8;
    font-size:8px;
    font-weight:800;
    letter-spacing:.04em;
    text-transform:uppercase;
    text-align:left;
}

.attention-table td {
    padding:10px 13px;
    border-bottom:1px solid #edf0f4;
    color:#334155;
    font-size:9px;
    vertical-align:middle;
}

.attention-table tbody tr:last-child td {
    border-bottom:0;
}

.attention-table tbody tr:hover td {
    background:#fbfdff;
}

.attention-person {
    min-width:160px;
}

.attention-person strong {
    display:block;
    color:#0f172a;
    font-size:9px;
}

.attention-person span {
    display:block;
    margin-top:2px;
    color:#94a3b8;
    font-size:8px;
}

.report-empty-inline {
    padding:24px 16px;
    text-align:center;
    color:#94a3b8;
    font-size:9px;
}

.report-footnote {
    display:flex;
    align-items:flex-start;
    gap:8px;
    padding:10px 12px;
    border:1px solid #e8edf3;
    border-radius:11px;
    background:#fbfcfe;
    color:#64748b;
    font-size:8px;
    line-height:1.5;
}

.report-footnote i {
    margin-top:1px;
    color:#94a3b8;
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

    .detail-grid {
        grid-template-columns:repeat(2,1fr);
    }

    .report-layout {
        grid-template-columns:1fr;
    }

    .report-kpis {
        grid-template-columns:repeat(2,1fr);
    }

    .report-kpi:nth-child(2) {
        border-right:0;
    }

    .report-kpi:nth-child(-n+2) {
        border-bottom:1px solid #edf0f4;
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
    .monitor-summary,
    .filters,
    .report-kpis {
        grid-template-columns:1fr;
    }

    .report-toolbar {
        flex-direction:column;
        align-items:stretch;
    }

    .report-toolbar-actions {
        width:100%;
    }

    .report-toolbar-actions .btn {
        flex:1;
    }

    .report-kpi {
        border-right:0;
        border-bottom:1px solid #edf0f4;
    }

    .report-kpi:last-child {
        border-bottom:0;
    }

    .visa-type-wrap {
        grid-template-columns:1fr;
    }

    .visa-type-chart {
        height:165px;
    }

    .report-chart-body {
        height:285px;
    }

    .attention-table {
        min-width:700px;
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
        <div class="report-shell">
            <div class="report-toolbar">
                <div class="report-toolbar-copy">
                    <h2 class="report-toolbar-title">
                        Visa Monitoring Reports
                    </h2>
                    <p class="report-toolbar-subtitle">
                        A compact view of approved visas, actual travel activity,
                        attention cases, and report exports.
                    </p>
                </div>

                <div class="report-toolbar-actions">
                    <a
                        href="visa_export.php?type=csv&export=all"
                        class="btn btn-view"
                        title="Export all approved monitoring records as CSV"
                    >
                        <i class="fa-solid fa-file-csv"></i>
                        CSV
                    </a>

                    <a
                        href="visa_export.php?type=pdf&export=all"
                        class="btn btn-primary"
                        title="Open the PDF report preview"
                    >
                        <i class="fa-regular fa-file-pdf"></i>
                        PDF
                    </a>
                </div>
            </div>

            <div class="report-kpis">
                <div class="report-kpi">
                    <div class="report-kpi-label">
                        Approved Visas
                    </div>
                    <div class="report-kpi-row">
                        <div class="report-kpi-value">
                            <?= e($totalApproved) ?>
                        </div>
                        <div class="report-kpi-note">
                            total approved
                        </div>
                    </div>
                </div>

                <div class="report-kpi">
                    <div class="report-kpi-label">
                        Active Stays
                    </div>
                    <div class="report-kpi-row">
                        <div class="report-kpi-value">
                            <?= e($activeCount) ?>
                        </div>
                        <div class="report-kpi-note">
                            normal monitoring
                        </div>
                    </div>
                </div>

                <div class="report-kpi">
                    <div class="report-kpi-label">
                        Pending Review
                    </div>
                    <div class="report-kpi-row">
                        <div class="report-kpi-value">
                            <?= e($pendingCount) ?>
                        </div>
                        <div class="report-kpi-note">
                            awaiting decision
                        </div>
                    </div>
                </div>

                <div class="report-kpi attention">
                    <div class="report-kpi-label">
                        Needs Attention
                    </div>
                    <div class="report-kpi-row">
                        <div class="report-kpi-value">
                            <?= e($needsAttentionCount) ?>
                        </div>
                        <div class="report-kpi-note">
                            expiring / overdue
                        </div>
                    </div>
                </div>
            </div>

            <div class="report-layout">
                <section class="report-surface">
                    <div class="report-surface-head">
                        <div>
                            <h3 class="report-surface-title">
                                Current Travel Status
                            </h3>
                            <p class="report-surface-subtitle">
                                Approved visas by dynamically derived monitoring state
                            </p>
                        </div>
                        <span class="summary-pill">
                            <?= e($totalApproved) ?> records
                        </span>
                    </div>
                    <div class="report-chart-body">
                        <canvas
                            id="travelStatusChart"
                            aria-label="Current travel status distribution"
                        ></canvas>
                    </div>
                </section>

                <div class="report-side-stack">
                    <section class="report-surface">
                        <div class="report-surface-head">
                            <div>
                                <h3 class="report-surface-title">
                                    Visa Type Distribution
                                </h3>
                                <p class="report-surface-subtitle">
                                    Approved SEV and MEV composition
                                </p>
                            </div>
                        </div>

                        <div class="visa-type-wrap">
                            <div class="visa-type-chart">
                                <canvas
                                    id="visaTypeChart"
                                    aria-label="Visa type distribution"
                                ></canvas>
                            </div>

                            <div class="report-mini-list">
                                <div class="report-mini-row">
                                    <span class="report-mini-label">
                                        <span
                                            class="report-dot"
                                            style="background:#2563eb"
                                        ></span>
                                        SEV
                                    </span>
                                    <span class="report-mini-value">
                                        <?= e($sevCount) ?>
                                    </span>
                                </div>

                                <div class="report-mini-row">
                                    <span class="report-mini-label">
                                        <span
                                            class="report-dot"
                                            style="background:#7c3aed"
                                        ></span>
                                        MEV
                                    </span>
                                    <span class="report-mini-value">
                                        <?= e($mevCount) ?>
                                    </span>
                                </div>

                                <?php if ($otherVisaCount > 0): ?>
                                    <div class="report-mini-row">
                                        <span class="report-mini-label">
                                            <span
                                                class="report-dot"
                                                style="background:#94a3b8"
                                            ></span>
                                            Other
                                        </span>
                                        <span class="report-mini-value">
                                            <?= e($otherVisaCount) ?>
                                        </span>
                                    </div>
                                <?php endif; ?>
                            </div>
                        </div>

                        <div class="report-expiry-strip">
                            <div class="report-expiry-item">
                                <div class="report-expiry-value">
                                    <?= e($expiry7) ?>
                                </div>
                                <div class="report-expiry-label">
                                    within 7 days
                                </div>
                            </div>
                            <div class="report-expiry-item">
                                <div class="report-expiry-value">
                                    <?= e($expiry14) ?>
                                </div>
                                <div class="report-expiry-label">
                                    within 14 days
                                </div>
                            </div>
                            <div class="report-expiry-item">
                                <div class="report-expiry-value">
                                    <?= e($expiry30) ?>
                                </div>
                                <div class="report-expiry-label">
                                    within 30 days
                                </div>
                            </div>
                        </div>

                        <div class="report-inline-metric">
                            <span>Average permitted stay</span>
                            <strong>
                                <?= $avgPermittedStay !== null
                                    ? e((string)$avgPermittedStay) . ' days'
                                    : '—'
                                ?>
                            </strong>
                        </div>
                    </section>
                </div>
            </div>

            <section class="report-surface">
                <div class="report-surface-head">
                    <div>
                        <h3 class="report-surface-title">
                            7-Day Visa Activity
                        </h3>
                        <p class="report-surface-subtitle">
                            Recent visa-submission activity reported by the existing trend source
                        </p>
                    </div>
                </div>

                <?php if (empty($trendLabels)): ?>
                    <div class="report-empty-inline">
                        No trend data available.
                    </div>
                <?php else: ?>
                    <div class="report-chart-body trend">
                        <canvas
                            id="visaActivityChart"
                            aria-label="Seven day visa activity trend"
                        ></canvas>
                    </div>
                <?php endif; ?>
            </section>

            <section class="report-surface">
                <div class="report-surface-head">
                    <div>
                        <h3 class="report-surface-title">
                            Requires Attention
                        </h3>
                        <p class="report-surface-subtitle">
                            Expiring-soon and departure-not-reported records, prioritised for review
                        </p>
                    </div>

                    <div class="report-attention-head-actions">
                        <span class="summary-pill">
                            <?= e($needsAttentionCount) ?> records
                        </span>

                        <?php if ($departureNotReportedCount > 0): ?>
                            <a
                                href="visa_export.php?type=csv&export=overstay"
                                class="btn btn-reject"
                                title="Export departure-not-reported records as CSV"
                            >
                                <i class="fa-solid fa-file-csv"></i>
                                Overdue CSV
                            </a>
                        <?php endif; ?>
                    </div>
                </div>

                <?php if (empty($attentionPreview)): ?>
                    <div class="report-empty-inline">
                        No expiring-soon or overdue travel records require attention.
                    </div>
                <?php else: ?>
                    <div class="table-wrap">
                        <table class="attention-table">
                            <thead>
                                <tr>
                                    <th>Tourist</th>
                                    <th>Visa</th>
                                    <th>Status</th>
                                    <th>Stay Until</th>
                                    <th>Remaining</th>
                                    <th></th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($attentionPreview as $tourist): ?>
                                    <?php
                                    $attentionStatus = normalizeStatus(
                                        $tourist['_status'] ?? ''
                                    );
                                    ?>
                                    <tr>
                                        <td>
                                            <div class="attention-person">
                                                <strong>
                                                    <?= e(
                                                        $tourist['full_name']
                                                            ?? 'Unknown Tourist'
                                                    ) ?>
                                                </strong>
                                                <span>
                                                    <?= e(
                                                        $tourist['passport_number']
                                                            ?? '—'
                                                    ) ?>
                                                </span>
                                            </div>
                                        </td>
                                        <td>
                                            <span class="visa-chip">
                                                <?= e(
                                                    strtoupper(
                                                        (string)(
                                                            $tourist['visa_type']
                                                            ?? '—'
                                                        )
                                                    )
                                                ) ?>
                                            </span>
                                        </td>
                                        <td>
                                            <span class="status-badge <?= e(
                                                statusClass($attentionStatus)
                                            ) ?>">
                                                <i class="fa-solid <?= e(
                                                    statusIcon($attentionStatus)
                                                ) ?>"></i>
                                                <?= e(statusLabel($attentionStatus)) ?>
                                            </span>
                                        </td>
                                        <td>
                                            <?= e(
                                                formatDate(
                                                    $tourist['_stay_until_date']
                                                    ?? null
                                                )
                                            ) ?>
                                        </td>
                                        <td class="<?= $attentionStatus === 'DEPARTURE_NOT_REPORTED'
                                            ? 'remaining-danger'
                                            : 'remaining-warning'
                                        ?>">
                                            <?= e(
                                                remainingLabel(
                                                    $tourist['_remaining_days'] ?? null,
                                                    $attentionStatus
                                                )
                                            ) ?>
                                        </td>
                                        <td>
                                            <a
                                                href="visa_travel_records.php?submission_id=<?= e(
                                                    $tourist['id'] ?? ''
                                                ) ?>"
                                                class="table-action"
                                                title="View visa and travel details"
                                            >
                                                <i class="fa-solid fa-arrow-up-right-from-square"></i>
                                            </a>
                                        </td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                <?php endif; ?>
            </section>

            <div class="report-footnote">
                <i class="fa-solid fa-circle-info"></i>
                <span>
                    Travel states are derived from approved visa validity and
                    visa_travel_records. Report views are read-only and do not
                    alter source visa or travel records.
                </span>
            </div>
        </div>
    <?php endif; ?>

</div>

<?php if ($activeTab === 'reports'): ?>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.7/dist/chart.umd.min.js"></script>
<?php endif; ?>

<script>
console.log(
    'Visa Management loaded.',
    <?= jsonForJs([
        'pending' => $pendingCount,
        'approved' => $totalApproved,
        'active' => $activeCount,
        'expiringSoon' => $expiringSoonCount,
        'departureNotReported' => $departureNotReportedCount,
        'notEntered' => $notEnteredCount,
        'departed' => $departedCount,
        'used' => $usedCount,
        'expired' => $expiredCount,
    ]) ?>
);

<?php if ($activeTab === 'reports'): ?>
(() => {
    if (typeof Chart === 'undefined') {
        console.warn('Chart.js is unavailable; report charts were not rendered.');
        return;
    }

    Chart.defaults.font.family =
        'Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif';
    Chart.defaults.color = '#64748b';

    const travelStatusData = <?= jsonForJs($travelStatusChart) ?>;
    const visaTypeData = <?= jsonForJs($visaTypeChart) ?>;
    const trendLabels = <?= jsonForJs($trendLabels) ?>;
    const trendValues = <?= jsonForJs($trendValues) ?>;

    const travelStatusCanvas = document.getElementById('travelStatusChart');
    if (travelStatusCanvas) {
        new Chart(travelStatusCanvas, {
            type: 'bar',
            data: {
                labels: travelStatusData.labels,
                datasets: [{
                    data: travelStatusData.values,
                    backgroundColor: [
                        '#cbd5e1',
                        '#22c55e',
                        '#f59e0b',
                        '#ef4444',
                        '#3b82f6',
                        '#8b5cf6',
                        '#64748b'
                    ],
                    borderWidth: 0,
                    borderRadius: 5,
                    barThickness: 15,
                }]
            },
            options: {
                indexAxis: 'y',
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        displayColors: false,
                        callbacks: {
                            label: (context) => `${context.raw} record${Number(context.raw) === 1 ? '' : 's'}`,
                        }
                    }
                },
                scales: {
                    x: {
                        beginAtZero: true,
                        ticks: {
                            precision: 0,
                            font: { size: 9 },
                        },
                        grid: { color: '#eef2f7' },
                        border: { display: false },
                    },
                    y: {
                        ticks: {
                            font: { size: 9, weight: '600' },
                        },
                        grid: { display: false },
                        border: { display: false },
                    }
                }
            }
        });
    }

    const visaTypeCanvas = document.getElementById('visaTypeChart');
    if (visaTypeCanvas) {
        new Chart(visaTypeCanvas, {
            type: 'doughnut',
            data: {
                labels: visaTypeData.labels,
                datasets: [{
                    data: visaTypeData.values,
                    backgroundColor: ['#2563eb', '#7c3aed', '#94a3b8'],
                    borderColor: '#ffffff',
                    borderWidth: 3,
                    hoverOffset: 2,
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '70%',
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        callbacks: {
                            label: (context) => `${context.label}: ${context.raw}`,
                        }
                    }
                }
            }
        });
    }

    const activityCanvas = document.getElementById('visaActivityChart');
    if (activityCanvas && trendLabels.length > 0) {
        new Chart(activityCanvas, {
            type: 'line',
            data: {
                labels: trendLabels,
                datasets: [{
                    label: 'Visa Activity',
                    data: trendValues,
                    borderColor: '#2563eb',
                    backgroundColor: 'rgba(37, 99, 235, .08)',
                    fill: true,
                    tension: .35,
                    borderWidth: 2,
                    pointRadius: 3,
                    pointHoverRadius: 4,
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                interaction: {
                    intersect: false,
                    mode: 'index',
                },
                plugins: {
                    legend: { display: false },
                },
                scales: {
                    x: {
                        grid: { display: false },
                        ticks: { font: { size: 9 } },
                        border: { display: false },
                    },
                    y: {
                        beginAtZero: true,
                        ticks: {
                            precision: 0,
                            font: { size: 9 },
                        },
                        grid: { color: '#eef2f7' },
                        border: { display: false },
                    }
                }
            }
        });
    }
})();
<?php endif; ?>
</script>

<?php render_admin_end(); ?>
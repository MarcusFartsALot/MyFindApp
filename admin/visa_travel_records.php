<?php

declare(strict_types=1);

require_once __DIR__ . '/includes/admin_guard.php';
require_once __DIR__ . '/includes/layout.php';
require_once __DIR__ . '/services/visa_travel_service.php';

$admin = require_admin();
$supabase = new SupabaseClient();
$travelService = new VisaTravelService($supabase);

function e(mixed $value): string
{
    return htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8');
}

function formatDate(?string $value): string
{
    if (!$value) {
        return '—';
    }

    try {
        return (new DateTimeImmutable($value))->format('d M Y');
    } catch (Throwable) {
        return '—';
    }
}

function formatDateTime(?string $value): string
{
    if (!$value) {
        return '—';
    }

    try {
        return (new DateTimeImmutable($value))->format('d M Y, H:i');
    } catch (Throwable) {
        return '—';
    }
}

function stateLabel(string $state): string
{
    return match (strtoupper($state)) {
        'NOT_ENTERED' => 'Not Entered',
        'ACTIVE' => 'Active',
        'EXPIRING_SOON' => 'Expiring Soon',
        'DEPARTURE_NOT_REPORTED' => 'Departure Not Reported',
        'DEPARTED' => 'Departed',
        'USED' => 'Used',
        'EXPIRED' => 'Expired',
        default => 'No Tracking',
    };
}

function stateClass(string $state): string
{
    return match (strtoupper($state)) {
        'ACTIVE' => 'state-green',
        'EXPIRING_SOON' => 'state-yellow',
        'DEPARTURE_NOT_REPORTED' => 'state-red',
        'DEPARTED' => 'state-blue',
        'USED' => 'state-purple',
        'EXPIRED' => 'state-dark',
        default => 'state-gray',
    };
}

function travelValue(?string $value): string
{
    $value = trim((string)$value);

    return $value === '' ? '—' : $value;
}

$submissionId = trim((string)($_GET['submission_id'] ?? ''));
$errorMessage = '';
$travelContext = null;

if ($submissionId === '') {
    $errorMessage = 'Missing visa submission ID.';
} else {
    try {
        $travelContext = $travelService->getTravelContext($submissionId);

        if ($travelContext === null) {
            $errorMessage = 'Visa submission not found.';
        }
    } catch (Throwable $e) {
        $errorMessage = $e->getMessage();
    }
}

$submission = $travelContext['submission'] ?? null;
$plannedTravel = $travelContext['planned_travel'] ?? null;
$records = $travelContext['records'] ?? [];
$currentRecord = $travelContext['current_record'] ?? null;
$state = (string)($travelContext['state'] ?? 'NO_TRACKING');
$remainingDays = $travelContext['remaining_days'] ?? null;

render_admin_start('Visa Travel Records', $admin, 'visa');
?>

<link
    rel="stylesheet"
    href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css"
>

<style>
.travel-page {
    --bg:#f5f7fb;
    --surface:#ffffff;
    --soft:#f8fafc;
    --border:#e5e7eb;
    --text:#111827;
    --muted:#6b7280;
    --primary:#2563eb;
    --primary-soft:#eff6ff;
    max-width:1450px;
    margin:0 auto;
    padding:8px 32px 48px;
    color:var(--text);
    font-family:Inter,-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;
}

.travel-page * {
    box-sizing:border-box;
}

.page-head {
    display:flex;
    align-items:flex-start;
    justify-content:space-between;
    gap:20px;
    margin-bottom:22px;
}

.page-head-left {
    display:flex;
    align-items:flex-start;
    gap:14px;
}

.back-btn {
    width:40px;
    height:40px;
    border:1px solid var(--border);
    border-radius:11px;
    background:#fff;
    color:#475569;
    display:flex;
    align-items:center;
    justify-content:center;
    text-decoration:none;
    transition:.15s ease;
}

.back-btn:hover {
    border-color:#bfdbfe;
    color:var(--primary);
    background:var(--primary-soft);
}

.page-title {
    margin:0;
    font-size:25px;
    font-weight:800;
    letter-spacing:-.02em;
}

.page-subtitle {
    margin:5px 0 0;
    color:var(--muted);
    font-size:13px;
}

.state-badge {
    display:inline-flex;
    align-items:center;
    gap:7px;
    padding:8px 12px;
    border-radius:999px;
    font-size:11px;
    font-weight:800;
    white-space:nowrap;
}

.state-green { background:#ecfdf3; color:#15803d; }
.state-yellow { background:#fffbeb; color:#b45309; }
.state-red { background:#fef2f2; color:#b91c1c; }
.state-blue { background:#eff6ff; color:#1d4ed8; }
.state-purple { background:#f5f3ff; color:#6d28d9; }
.state-dark { background:#f3f4f6; color:#374151; }
.state-gray { background:#f8fafc; color:#64748b; }

.alert {
    border:1px solid #fecaca;
    background:#fef2f2;
    color:#991b1b;
    border-radius:14px;
    padding:16px 18px;
    font-size:13px;
    margin-bottom:20px;
}

.visa-card {
    background:linear-gradient(135deg,#0f172a,#1e3a8a);
    border-radius:18px;
    padding:22px;
    color:#fff;
    box-shadow:0 12px 28px rgba(30,58,138,.14);
    margin-bottom:20px;
}

.visa-card-top {
    display:flex;
    align-items:flex-start;
    justify-content:space-between;
    gap:18px;
}

.visa-type {
    font-size:22px;
    font-weight:900;
}

.visa-caption {
    font-size:10px;
    font-weight:800;
    color:rgba(255,255,255,.6);
    letter-spacing:.08em;
    text-transform:uppercase;
    margin-bottom:4px;
}

.visa-grid {
    display:grid;
    grid-template-columns:repeat(4,minmax(0,1fr));
    gap:18px;
    margin-top:22px;
}

.visa-item-value {
    font-size:13px;
    font-weight:700;
    overflow-wrap:anywhere;
}

.grid-2 {
    display:grid;
    grid-template-columns:repeat(2,minmax(0,1fr));
    gap:18px;
    margin-bottom:20px;
}

.card {
    background:var(--surface);
    border:1px solid var(--border);
    border-radius:16px;
    box-shadow:0 5px 18px rgba(15,23,42,.035);
}

.card-head {
    display:flex;
    align-items:center;
    gap:11px;
    padding:17px 18px;
    border-bottom:1px solid var(--border);
}

.card-icon {
    width:36px;
    height:36px;
    border-radius:10px;
    background:var(--primary-soft);
    color:#1e3a8a;
    display:flex;
    align-items:center;
    justify-content:center;
}

.card-title {
    margin:0;
    font-size:14px;
    font-weight:800;
}

.card-subtitle {
    margin:3px 0 0;
    color:var(--muted);
    font-size:11px;
}

.card-body {
    padding:18px;
}

.info-row {
    display:grid;
    grid-template-columns:155px minmax(0,1fr);
    gap:14px;
    margin-bottom:13px;
    font-size:12px;
}

.info-row:last-child {
    margin-bottom:0;
}

.info-label {
    color:#64748b;
    font-weight:600;
}

.info-value {
    color:#0f172a;
    font-weight:700;
    overflow-wrap:anywhere;
}

.note {
    margin-top:15px;
    border:1px solid #e2e8f0;
    background:#f8fafc;
    border-radius:10px;
    padding:11px 12px;
    color:#64748b;
    font-size:10px;
    line-height:1.5;
}

.current-stay {
    margin-bottom:20px;
}

.current-grid {
    display:grid;
    grid-template-columns:170px repeat(3,minmax(0,1fr));
    gap:16px;
    align-items:center;
}

.remaining-box {
    border-radius:14px;
    padding:16px;
    background:#f0fdf4;
    border:1px solid #bbf7d0;
    text-align:center;
}

.remaining-number {
    font-size:30px;
    line-height:1;
    font-weight:900;
    color:#15803d;
}

.remaining-label {
    margin-top:5px;
    font-size:10px;
    color:#64748b;
    font-weight:700;
}

.empty {
    color:#64748b;
    font-size:12px;
    padding:7px 0;
}

.history-title {
    margin:26px 0 12px;
    font-size:16px;
    font-weight:800;
}

.trip {
    margin-bottom:14px;
}

.trip-head {
    display:flex;
    align-items:center;
    justify-content:space-between;
    gap:14px;
    padding:15px 18px;
    border-bottom:1px solid var(--border);
}

.trip-title {
    font-size:13px;
    font-weight:800;
}

.trip-status {
    font-size:9px;
    font-weight:900;
    letter-spacing:.05em;
}

.trip-status.open { color:#15803d; }
.trip-status.completed { color:#2563eb; }

.trip-grid {
    display:grid;
    grid-template-columns:repeat(2,minmax(0,1fr));
    gap:20px;
    padding:18px;
}

.trip-section-title {
    display:flex;
    align-items:center;
    gap:8px;
    margin-bottom:13px;
    font-size:12px;
    font-weight:800;
    color:#334155;
}

.reason {
    margin-top:12px;
    border-left:3px solid #f59e0b;
    background:#fffbeb;
    border-radius:8px;
    padding:10px 11px;
    font-size:11px;
    color:#92400e;
    line-height:1.5;
}

@media (max-width:1000px) {
    .visa-grid {
        grid-template-columns:repeat(2,minmax(0,1fr));
    }

    .grid-2,
    .trip-grid {
        grid-template-columns:1fr;
    }

    .current-grid {
        grid-template-columns:1fr 1fr;
    }
}

@media (max-width:650px) {
    .travel-page {
        padding:8px 16px 36px;
    }

    .page-head,
    .visa-card-top {
        flex-direction:column;
    }

    .visa-grid,
    .current-grid {
        grid-template-columns:1fr;
    }

    .info-row {
        grid-template-columns:1fr;
        gap:3px;
    }
}
</style>

<div class="travel-page">
    <div class="page-head">
        <div class="page-head-left">
            <a
                class="back-btn"
                href="visa_management.php?tab=monitor"
                aria-label="Back to visa monitoring"
            >
                <i class="fa-solid fa-arrow-left"></i>
            </a>

            <div>
                <h1 class="page-title">Visa Travel Records</h1>
                <p class="page-subtitle">
                    Planned travel and actual immigration declarations for one approved visa.
                </p>
            </div>
        </div>

        <?php if ($travelContext !== null): ?>
            <span class="state-badge <?= e(stateClass($state)) ?>">
                <i class="fa-solid fa-circle"></i>
                <?= e(stateLabel($state)) ?>
            </span>
        <?php endif; ?>
    </div>

    <?php if ($errorMessage !== ''): ?>
        <div class="alert">
            <strong>Unable to load travel record.</strong>
            <?= e($errorMessage) ?>
        </div>
    <?php elseif (is_array($submission)): ?>

        <section class="visa-card">
            <div class="visa-card-top">
                <div>
                    <div class="visa-caption">Current Visa</div>
                    <div class="visa-type">
                        <?= e(strtoupper((string)($submission['visa_type'] ?? '—'))) ?>
                    </div>
                </div>

                <span class="state-badge <?= e(stateClass($state)) ?>">
                    <?= e(stateLabel($state)) ?>
                </span>
            </div>

            <div class="visa-grid">
                <div>
                    <div class="visa-caption">Tourist</div>
                    <div class="visa-item-value">
                        <?= e($submission['full_name'] ?? '—') ?>
                    </div>
                </div>

                <div>
                    <div class="visa-caption">Passport</div>
                    <div class="visa-item-value">
                        <?= e($submission['passport_number'] ?? '—') ?>
                    </div>
                </div>

                <div>
                    <div class="visa-caption">Effective</div>
                    <div class="visa-item-value">
                        <?= e(formatDate($submission['visa_effective_date'] ?? null)) ?>
                    </div>
                </div>

                <div>
                    <div class="visa-caption">Valid Until</div>
                    <div class="visa-item-value">
                        <?= e(formatDate($submission['visa_expiry_date'] ?? null)) ?>
                    </div>
                </div>

                <div>
                    <div class="visa-caption">Reference</div>
                    <div class="visa-item-value">
                        <?= e($submission['reference_id'] ?? '—') ?>
                    </div>
                </div>

                <div>
                    <div class="visa-caption">Nationality</div>
                    <div class="visa-item-value">
                        <?= e($submission['nationality'] ?? '—') ?>
                    </div>
                </div>

                <div>
                    <div class="visa-caption">Purpose</div>
                    <div class="visa-item-value">
                        <?= e($submission['purpose_of_visit'] ?? '—') ?>
                    </div>
                </div>

                <div>
                    <div class="visa-caption">Submission ID</div>
                    <div class="visa-item-value">
                        <?= e($submission['id'] ?? '—') ?>
                    </div>
                </div>
            </div>
        </section>

        <div class="grid-2">
            <section class="card">
                <div class="card-head">
                    <div class="card-icon">
                        <i class="fa-regular fa-calendar"></i>
                    </div>
                    <div>
                        <h2 class="card-title">Planned Travel</h2>
                        <p class="card-subtitle">Verified application information</p>
                    </div>
                </div>

                <div class="card-body">
                    <div class="info-row">
                        <div class="info-label">Planned Arrival</div>
                        <div class="info-value">
                            <?= e(formatDate($submission['arrival_date'] ?? null)) ?>
                        </div>
                    </div>

                    <div class="info-row">
                        <div class="info-label">Planned Departure</div>
                        <div class="info-value">
                            <?= e(formatDate($submission['departure_date'] ?? null)) ?>
                        </div>
                    </div>

                    <div class="info-row">
                        <div class="info-label">Planned Method</div>
                        <div class="info-value">
                            <?= e(travelValue($plannedTravel['inferred_method'] ?? null)) ?>
                        </div>
                    </div>

                    <div class="info-row">
                        <div class="info-label">Airline</div>
                        <div class="info-value">
                            <?= e(travelValue($plannedTravel['airline'] ?? null)) ?>
                        </div>
                    </div>

                    <div class="info-row">
                        <div class="info-label">Flight Number</div>
                        <div class="info-value">
                            <?= e(travelValue($plannedTravel['flight_number'] ?? null)) ?>
                        </div>
                    </div>

                    <div class="info-row">
                        <div class="info-label">Destination</div>
                        <div class="info-value">
                            <?= e(travelValue($plannedTravel['intended_destination'] ?? null)) ?>
                        </div>
                    </div>

                    <div class="info-row">
                        <div class="info-label">Accommodation</div>
                        <div class="info-value">
                            <?= e(travelValue($plannedTravel['hotel_name'] ?? null)) ?>
                        </div>
                    </div>

                    <div class="info-row">
                        <div class="info-label">Accommodation Type</div>
                        <div class="info-value">
                            <?= e(travelValue($plannedTravel['accommodation_type'] ?? null)) ?>
                        </div>
                    </div>

                    <div class="info-row">
                        <div class="info-label">Hotel Address</div>
                        <div class="info-value">
                            <?= e(travelValue($plannedTravel['hotel_address'] ?? null)) ?>
                        </div>
                    </div>

                    <div class="note">
                        Planned dates come from the verified visa submission.
                        Additional application travel information is read-only.
                    </div>
                </div>
            </section>

            <section class="card">
                <div class="card-head">
                    <div class="card-icon">
                        <i class="fa-solid fa-location-dot"></i>
                    </div>
                    <div>
                        <h2 class="card-title">Current Actual Travel</h2>
                        <p class="card-subtitle">Latest open travel declaration</p>
                    </div>
                </div>

                <div class="card-body">
                    <?php if (is_array($currentRecord)): ?>
                        <div class="info-row">
                            <div class="info-label">Actual Arrival</div>
                            <div class="info-value">
                                <?= e(formatDateTime($currentRecord['actual_entry_at'] ?? null)) ?>
                            </div>
                        </div>

                        <div class="info-row">
                            <div class="info-label">Entry Method</div>
                            <div class="info-value">
                                <?= e(travelValue($currentRecord['entry_method'] ?? null)) ?>
                            </div>
                        </div>

                        <div class="info-row">
                            <div class="info-label">Entry Point</div>
                            <div class="info-value">
                                <?= e(travelValue($currentRecord['entry_point'] ?? null)) ?>
                            </div>
                        </div>

                        <div class="info-row">
                            <div class="info-label">Entry Reference</div>
                            <div class="info-value">
                                <?= e(travelValue($currentRecord['entry_reference'] ?? null)) ?>
                            </div>
                        </div>

                        <div class="info-row">
                            <div class="info-label">Stay Until</div>
                            <div class="info-value">
                                <?= e(formatDate($currentRecord['stay_until_date'] ?? null)) ?>
                            </div>
                        </div>

                        <?php if (!empty($currentRecord['entry_change_reason'])): ?>
                            <div class="reason">
                                <strong>Entry change reason:</strong>
                                <?= e($currentRecord['entry_change_reason']) ?>
                            </div>
                        <?php endif; ?>
                    <?php else: ?>
                        <div class="empty">
                            There is no open trip for this visa.
                        </div>
                    <?php endif; ?>
                </div>
            </section>
        </div>

        <?php if (is_array($currentRecord)): ?>
            <section class="card current-stay">
                <div class="card-head">
                    <div class="card-icon">
                        <i class="fa-regular fa-clock"></i>
                    </div>
                    <div>
                        <h2 class="card-title">Current Stay</h2>
                        <p class="card-subtitle">Dynamic stay status from actual travel record</p>
                    </div>
                </div>

                <div class="card-body">
                    <div class="current-grid">
                        <div class="remaining-box">
                            <div class="remaining-number">
                                <?= $remainingDays === null ? '—' : e((string)$remainingDays) ?>
                            </div>
                            <div class="remaining-label">days remaining</div>
                        </div>

                        <div>
                            <div class="info-label">Actual Arrival</div>
                            <div class="info-value">
                                <?= e(formatDateTime($currentRecord['actual_entry_at'] ?? null)) ?>
                            </div>
                        </div>

                        <div>
                            <div class="info-label">Permitted Stay Until</div>
                            <div class="info-value">
                                <?= e(formatDate($currentRecord['stay_until_date'] ?? null)) ?>
                            </div>
                        </div>

                        <div>
                            <div class="info-label">Travel State</div>
                            <div class="info-value">
                                <?= e(stateLabel($state)) ?>
                            </div>
                        </div>
                    </div>
                </div>
            </section>
        <?php endif; ?>

        <h2 class="history-title">Travel History</h2>

        <?php if (empty($records)): ?>
            <section class="card">
                <div class="card-body">
                    <div class="empty">
                        No actual arrival has been reported for this visa.
                    </div>
                </div>
            </section>
        <?php else: ?>
            <?php
            $totalTrips = count($records);

            foreach ($records as $index => $record):
                $tripNumber = $totalTrips - $index;
                $isOpen = empty($record['actual_departure_at']);
            ?>
                <section class="card trip">
                    <div class="trip-head">
                        <div class="trip-title">
                            Trip #<?= e((string)$tripNumber) ?>
                        </div>

                        <div class="trip-status <?= $isOpen ? 'open' : 'completed' ?>">
                            <?= $isOpen ? 'CURRENT' : 'COMPLETED' ?>
                        </div>
                    </div>

                    <div class="trip-grid">
                        <div>
                            <div class="trip-section-title">
                                <i class="fa-solid fa-plane-arrival"></i>
                                Arrival
                            </div>

                            <div class="info-row">
                                <div class="info-label">Date & Time</div>
                                <div class="info-value">
                                    <?= e(formatDateTime($record['actual_entry_at'] ?? null)) ?>
                                </div>
                            </div>

                            <div class="info-row">
                                <div class="info-label">Method</div>
                                <div class="info-value">
                                    <?= e(travelValue($record['entry_method'] ?? null)) ?>
                                </div>
                            </div>

                            <div class="info-row">
                                <div class="info-label">Point</div>
                                <div class="info-value">
                                    <?= e(travelValue($record['entry_point'] ?? null)) ?>
                                </div>
                            </div>

                            <div class="info-row">
                                <div class="info-label">Reference</div>
                                <div class="info-value">
                                    <?= e(travelValue($record['entry_reference'] ?? null)) ?>
                                </div>
                            </div>

                            <div class="info-row">
                                <div class="info-label">Stay Until</div>
                                <div class="info-value">
                                    <?= e(formatDate($record['stay_until_date'] ?? null)) ?>
                                </div>
                            </div>

                            <?php if (!empty($record['entry_change_reason'])): ?>
                                <div class="reason">
                                    <strong>Change reason:</strong>
                                    <?= e($record['entry_change_reason']) ?>
                                </div>
                            <?php endif; ?>
                        </div>

                        <div>
                            <div class="trip-section-title">
                                <i class="fa-solid fa-plane-departure"></i>
                                Departure
                            </div>

                            <?php if (!$isOpen): ?>
                                <div class="info-row">
                                    <div class="info-label">Date & Time</div>
                                    <div class="info-value">
                                        <?= e(formatDateTime($record['actual_departure_at'] ?? null)) ?>
                                    </div>
                                </div>

                                <div class="info-row">
                                    <div class="info-label">Method</div>
                                    <div class="info-value">
                                        <?= e(travelValue($record['departure_method'] ?? null)) ?>
                                    </div>
                                </div>

                                <div class="info-row">
                                    <div class="info-label">Point</div>
                                    <div class="info-value">
                                        <?= e(travelValue($record['departure_point'] ?? null)) ?>
                                    </div>
                                </div>

                                <div class="info-row">
                                    <div class="info-label">Reference</div>
                                    <div class="info-value">
                                        <?= e(travelValue($record['departure_reference'] ?? null)) ?>
                                    </div>
                                </div>

                                <?php if (!empty($record['departure_change_reason'])): ?>
                                    <div class="reason">
                                        <strong>Change reason:</strong>
                                        <?= e($record['departure_change_reason']) ?>
                                    </div>
                                <?php endif; ?>
                            <?php else: ?>
                                <div class="empty">
                                    Departure has not been reported yet.
                                </div>
                            <?php endif; ?>
                        </div>
                    </div>
                </section>
            <?php endforeach; ?>
        <?php endif; ?>

    <?php endif; ?>
</div>

<?php render_admin_end(); ?>

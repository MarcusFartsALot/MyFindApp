<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/admin_guard.php';
require_once __DIR__ . '/includes/layout.php';
require_once __DIR__ . '/services/application_service.php';

$admin = require_admin();
$id = $_GET['id'] ?? null;
if (!valid_uuid(is_string($id) ? $id : null)) {
    flash('error', 'Invalid application ID.');
    redirect('new_application.php');
}

$service = new ApplicationService();
try {
    $application = $service->find($id);
    $documentUrl = $service->signedDocumentUrl((string) $application['document_path']);
    $backDocumentPath = $application['document_back_path'] ?? null;
    $backDocumentUrl = is_string($backDocumentPath) && $backDocumentPath !== ''
        ? $service->signedDocumentUrl($backDocumentPath)
        : null;
} catch (Throwable $error) {
    flash('error', $error->getMessage() === 'Registration application not found.'
        ? $error->getMessage()
        : 'Application details could not be loaded.');
    redirect('new_application.php');
}

$documentLabel = $application['document_type'] === 'mykad' ? 'MyKad' : 'Passport';
$status = (string) $application['status'];
render_admin_start('Application Details', $admin, 'applications');
?>
<div class="detail-grid">
    <section class="card details-card">
        <h2>Applicant Information</h2>
        <dl>
            <dt>Full Name</dt>
            <dd><?= escape((string) $application['full_name']) ?></dd>
            <dt>Email</dt>
            <dd><?= escape((string) $application['email']) ?></dd>
            <dt>Phone Number</dt>
            <dd><?= escape((string) ($application['phone_number'] ?? 'Not supplied')) ?></dd>
            <dt>Nationality</dt>
            <dd><?= escape((string) ($application['nationality'] ?? 'Not supplied')) ?></dd>
            <dt>Applicant Type</dt>
            <dd><?= escape(ucfirst((string) $application['requested_role'])) ?></dd>
            <dt>Document Type</dt>
            <dd><?= $documentLabel ?></dd>
            <dt><?= $documentLabel ?> Number</dt>
            <dd><?= escape((string) $application['identity_number']) ?></dd>
            <?php if (($application['requested_role'] ?? '') === 'tourist'): ?>
                <dt>Passport Issue Date</dt>
                <dd><?= escape((string) ($application['passport_issue_date'] ?? 'Not supplied')) ?></dd>
                <dt>Passport Issuing Country</dt>
                <dd><?= escape((string) ($application['passport_issuing_country'] ?? 'Not supplied')) ?></dd>
                <dt>Passport Expiry Date</dt>
                <dd><?= escape((string) ($application['passport_expiry_date'] ?? 'Not supplied')) ?></dd>
                <dt>Country of Residence</dt>
                <dd><?= escape((string) ($application['country_of_residence'] ?? 'Not supplied')) ?></dd>
            <?php endif; ?>
            <dt>Submitted Date</dt>
            <dd><?= escape(date('d M Y, H:i', strtotime((string) $application['submitted_at']))) ?></dd>
            <dt>Status</dt>
            <dd><span class="status <?= escape($status) ?>"><?= escape(ucfirst($status)) ?></span></dd>
        </dl>
    </section>

    <section class="card document-card">
        <h2>Identity Document - <?= $documentLabel ?> Front</h2>
        <p class="privacy-note"><i class='bx bx-lock-alt'></i> Private image; this link expires in five minutes.</p>
        <a href="<?= escape($documentUrl) ?>" target="_blank" rel="noopener noreferrer">
            <img src="<?= escape($documentUrl) ?>" alt="Submitted <?= $documentLabel ?> image">
        </a>
        <?php if ($backDocumentUrl !== null): ?>
            <h3><?= $documentLabel ?> Back</h3>
            <a href="<?= escape($backDocumentUrl) ?>" target="_blank" rel="noopener noreferrer">
                <img src="<?= escape($backDocumentUrl) ?>" alt="Submitted <?= $documentLabel ?> back image">
            </a>
        <?php endif; ?>
    </section>
</div>

<?php if ($status === 'pending'): ?>
    <section class="card action-card">
        <h2>Administrator Decision</h2>
        <div class="decision-actions">
            <form action="approve_application.php" method="post">
                <input type="hidden" name="csrf_token" value="<?= escape(csrf_token()) ?>">
                <input type="hidden" name="profile_id" value="<?= escape($id) ?>">
                <button type="submit" class="button approve">Approve Application</button>
            </form>
            <form action="reject_application.php" method="post" class="reject-form">
                <input type="hidden" name="csrf_token" value="<?= escape(csrf_token()) ?>">
                <input type="hidden" name="profile_id" value="<?= escape($id) ?>">
                <label for="rejection_reason">Rejection Reason (optional)</label>
                <textarea id="rejection_reason" name="rejection_reason" maxlength="1000" rows="3"></textarea>
                <label>
                    <input type="checkbox" required>
                    I understand that rejection permanently deletes this
                    applicant profile and its registration documents.
                </label>
                <button type="submit" class="button reject">Reject Application</button>
            </form>
        </div>
    </section>
<?php elseif ($status === 'rejected' && !empty($application['rejection_reason'])): ?>
    <section class="card">
        <h2>Rejection Reason</h2>
        <p><?= nl2br(escape((string) $application['rejection_reason'])) ?></p>
    </section>
<?php endif; ?>
<?php render_admin_end(); ?>

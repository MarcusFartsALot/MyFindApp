<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/admin_guard.php';
require_once __DIR__ . '/includes/layout.php';
require_once __DIR__ . '/services/application_service.php';

$admin = require_admin();
$applications = [];
$loadError = null;
try {
    $applications = (new ApplicationService())->pendingApplications();
} catch (Throwable) {
    $loadError = 'Applications could not be loaded. Please try again.';
}

render_admin_start('New Application', $admin, 'applications');
?>
<?php if ($loadError !== null): ?>
    <div class="alert alert-error" role="alert"><?= escape($loadError) ?></div>
<?php elseif ($applications === []): ?>
    <section class="empty-state card">
        <i class='bx bx-check-circle'></i>
        <h2>No pending applications</h2>
        <p>New Citizen and Tourist account applications will appear here.</p>
    </section>
<?php else: ?>
    <section class="card table-card">
        <div class="table-wrap">
            <table>
                <thead>
                <tr>
                    <th>Applicant</th>
                    <th>Type</th>
                    <th>IC / Passport</th>
                    <th>Submitted</th>
                    <th>Status</th>
                    <th>Action</th>
                </tr>
                </thead>
                <tbody>
                <?php foreach ($applications as $application): ?>
                    <tr>
                        <td>
                            <strong><?= escape((string) $application['full_name']) ?></strong><br>
                            <small><?= escape((string) $application['email']) ?></small>
                        </td>
                        <td><?= escape(ucfirst((string) $application['requested_role'])) ?></td>
                        <td><?= escape((string) $application['identity_number']) ?></td>
                        <td><?= escape(date('d M Y, H:i', strtotime((string) $application['submitted_at']))) ?></td>
                        <td><span class="status pending">Pending</span></td>
                        <td>
                            <a class="button secondary small" href="application_details.php?id=<?= rawurlencode((string) $application['id']) ?>">View</a>
                        </td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </section>
<?php endif; ?>
<?php render_admin_end(); ?>

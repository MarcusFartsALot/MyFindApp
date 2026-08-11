<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/admin_guard.php';
require_once __DIR__ . '/includes/layout.php';
require_once __DIR__ . '/services/application_service.php';

$admin = require_admin();
$loadError = null;
try {
    $pendingCount = (new ApplicationService())->pendingCount();
} catch (Throwable) {
    $pendingCount = 0;
    $loadError = 'Pending application count is temporarily unavailable.';
}

render_admin_start('Dashboard', $admin, 'dashboard');
?>
<?php if ($loadError !== null): ?>
    <div class="alert alert-error" role="alert"><?= escape($loadError) ?></div>
<?php endif; ?>
<section class="card-grid" aria-label="Dashboard metrics">
    <a class="metric-card" href="new_application.php">
        <i class='bx bx-file'></i>
        <div>
            <span>Pending Applications</span>
            <strong><?= $pendingCount ?></strong>
        </div>
    </a>
</section>
<?php render_admin_end(); ?>

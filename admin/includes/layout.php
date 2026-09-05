<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/sidebar.php';

/** @param array<string, mixed> $admin */
function render_admin_start(string $title, array $admin, string $active): void
{
    // Presentation-only route mapping; authorization stays in each page guard.
    $active = [
        'risk_map.php' => 'risk',
        'approve_tourist.php' => 'tourists',
        'approve_citizen.php' => 'citizens',
        'approve_citizen_report.php' => 'reports',
        'visa_management.php' => 'visa',
        'profile.php' => 'profile',
    ][basename((string) ($_SERVER['SCRIPT_NAME'] ?? ''))] ?? $active;
    ?>
    <!doctype html>
    <html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="referrer" content="same-origin">
        <title><?= escape($title) ?> | MyFind Admin</title>
        <link href="https://unpkg.com/boxicons@2.1.4/css/boxicons.min.css" rel="stylesheet">
        <link href="assets/html.css" rel="stylesheet">
        <link href="assets/workspace.css" rel="stylesheet">
    </head>
    <body class="admin-workspace" data-workspace="<?= escape($active) ?>">
    <?php render_sidebar($admin, $active); ?>
    <main class="main-content">
        <header class="workspace-topbar">
            <div><span class="workspace-eyebrow">ADMIN WORKSPACE</span><span class="workspace-breadcrumb">MyFind <span aria-hidden="true">/</span> <?= escape($title) ?></span></div>
            <a href="profile.php" class="workspace-account-link" aria-label="Account settings"><i class="bx bx-user-circle" aria-hidden="true"></i><span><?= escape((string) ($admin['full_name'] ?? 'Administrator')) ?></span></a>
        </header>
        <header class="page-header <?= $active === 'dashboard' ? 'workspace-duplicate-title' : '' ?>">
            <h1><?= escape($title) ?></h1>
        </header>
        <?php if ($message = take_flash()): ?>
            <div class="alert alert-<?= escape($message['type']) ?>" role="alert">
                <?= escape($message['message']) ?>
            </div>
        <?php endif; ?>
    <?php
}

function render_admin_end(): void
{
    ?>
    </main>
    <script>
        const sidebar = document.getElementById('sidebar');
        const closeButton = document.getElementById('btn');
        const searchButton = document.getElementById('sidebar-search');
        const sidebarIcon = closeButton?.querySelector('i');

        function syncSidebar() {
            const expanded = !!sidebar?.classList.contains('open');
            closeButton?.setAttribute('aria-expanded', String(expanded));
            closeButton?.setAttribute('aria-label', expanded ? 'Collapse navigation' : 'Expand navigation');
            sidebarIcon?.classList.toggle('bx-menu-alt-right', expanded);
            sidebarIcon?.classList.toggle('bx-menu', !expanded);
        }

        function toggleSidebar() {
            sidebar?.classList.toggle('open');
            syncSidebar();
            // Map pages already listen for resize; preserve their existing logic.
            window.dispatchEvent(new Event('resize'));
        }

        if (window.matchMedia('(max-width: 900px)').matches) sidebar?.classList.remove('open');
        syncSidebar();
        closeButton?.addEventListener('click', toggleSidebar);
        sidebar?.addEventListener('transitionend', function (event) {
            if (event.target === sidebar && event.propertyName === 'width') window.dispatchEvent(new Event('resize'));
        });
        searchButton?.addEventListener('click', function () {
            if (!sidebar?.classList.contains('open')) toggleSidebar();
        });
    </script>
    </body>
    </html>
    <?php
}

<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/sidebar.php';

/** @param array<string, mixed> $admin */
function render_admin_start(string $title, array $admin, string $active): void
{
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
    </head>
    <body>
    <?php render_sidebar($admin, $active); ?>
    <main class="main-content">
        <header class="page-header">
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

        function toggleSidebar() {
            sidebar?.classList.toggle('open');
            if (sidebar?.classList.contains('open')) {
                closeButton?.classList.replace('bx-menu', 'bx-menu-alt-right');
            } else {
                closeButton?.classList.replace('bx-menu-alt-right', 'bx-menu');
            }
        }

        closeButton?.addEventListener('click', toggleSidebar);
        closeButton?.addEventListener('keydown', function (event) {
            if (event.key === 'Enter' || event.key === ' ') {
                event.preventDefault();
                toggleSidebar();
            }
        });
        searchButton?.addEventListener('click', function () {
            if (!sidebar?.classList.contains('open')) toggleSidebar();
        });
    </script>
    </body>
    </html>
    <?php
}

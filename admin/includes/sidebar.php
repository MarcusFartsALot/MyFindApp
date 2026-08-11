<?php
declare(strict_types=1);

/** @param array<string, mixed> $admin */
function render_sidebar(array $admin, string $active): void
{
    $name = escape((string) ($admin['full_name'] ?? 'Administrator'));
    $job = 'System Administrator';
    ?>
    <aside class="sidebar" id="sidebar">
        <div class="logo-details">
            <i class='bx bx-shield-quarter icon'></i>
            <div class="logo_name">MyFind Admin</div>
            <i class='bx bx-menu' id="btn" role="button" tabindex="0" aria-label="Toggle sidebar"></i>
        </div>
        <ul class="nav-list">
            <li>
                <i class='bx bx-search' id="sidebar-search"></i>
                <input type="text" placeholder="Search..." aria-label="Search navigation">
                <span class="tooltip">Search</span>
            </li>
            <li class="<?= $active === 'dashboard' ? 'active' : '' ?>">
                <a href="admin_dashboard.php">
                    <i class='bx bx-grid-alt'></i>
                    <span class="links_name">Dashboard</span>
                </a>
                <span class="tooltip">Dashboard</span>
            </li>
            <li class="<?= $active === 'applications' ? 'active' : '' ?>">
                <a href="new_application.php">
                    <i class='bx bx-file'></i>
                    <span class="links_name">New Application</span>
                </a>
                <span class="tooltip">New Application</span>
            </li>
            <li>
                <a href="#" aria-label="Users">
                    <i class='bx bx-user'></i>
                    <span class="links_name">User</span>
                </a>
                <span class="tooltip">User</span>
            </li>
            <li>
                <a href="#" aria-label="Messages">
                    <i class='bx bx-chat'></i>
                    <span class="links_name">Messages</span>
                </a>
                <span class="tooltip">Messages</span>
            </li>
            <li>
                <a href="#" aria-label="Analytics">
                    <i class='bx bx-pie-chart-alt-2'></i>
                    <span class="links_name">Analytics</span>
                </a>
                <span class="tooltip">Analytics</span>
            </li>
            <li>
                <a href="#" aria-label="File Manager">
                    <i class='bx bx-folder'></i>
                    <span class="links_name">File Manager</span>
                </a>
                <span class="tooltip">Files</span>
            </li>
            <li>
                <a href="#" aria-label="Settings">
                    <i class='bx bx-cog'></i>
                    <span class="links_name">Setting</span>
                </a>
                <span class="tooltip">Setting</span>
            </li>
            <li class="profile">
                <div class="profile-details">
                    <div class="profile-avatar"><i class='bx bx-user'></i></div>
                    <div class="name_job">
                        <div class="name"><?= $name ?></div>
                        <div class="job"><?= $job ?></div>
                    </div>
                </div>
                <form action="logout.php" method="post" class="logout-form">
                    <input type="hidden" name="csrf_token" value="<?= escape(csrf_token()) ?>">
                    <button type="submit" aria-label="Logout" title="Logout">
                        <i class='bx bx-log-out' id="log_out"></i>
                    </button>
                </form>
            </li>
        </ul>
    </aside>
    <?php
}

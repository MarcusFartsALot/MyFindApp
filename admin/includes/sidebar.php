<?php
declare(strict_types=1);

/** @param array<string, mixed> $admin */
function render_sidebar(array $admin, string $active): void
{
    $name = escape((string) ($admin['full_name'] ?? 'Administrator'));
    $job = 'System Administrator';
    $profileImage = $admin['profile_image'] ?? null;
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
            <li class="<?= $active === 'admin_management' ? 'active' : '' ?>">
                <a href="admin_management.php">
                    <i class='bx bx-user'></i>
                    <span class="links_name">Admins</span>
                </a>
                <span class="tooltip">Admins</span>
            </li>
            <li class="<?= $active === 'profile' ? 'active' : '' ?>">
                <a href="profile.php">
                    <i class='bx bx-cog'></i>
                    <span class="links_name">Settings</span>
                </a>
                <span class="tooltip">Settings</span>
            </li>
            <li class="profile">
                <div class="profile-details">
                    <div class="profile-avatar">
                        <?php if (!empty($profileImage)): ?>
                            <img src="<?= escape($profileImage) ?>" alt="<?= $name ?>" class="profile-avatar-img">
                        <?php else: ?>
                            <i class='bx bx-user'></i>
                        <?php endif; ?>
                    </div>
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
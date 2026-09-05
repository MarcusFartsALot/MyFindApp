<?php
declare(strict_types=1);

/** @param array<string, mixed> $admin */
function render_sidebar(array $admin, string $active): void
{
    $name = escape((string) ($admin['full_name'] ?? 'Administrator'));
    $job = 'System Administrator';
    $profileImage = $admin['profile_image'] ?? null;
    ?>
    <aside class="sidebar open" id="sidebar" aria-label="Admin navigation">
        <div class="logo-details">
            <i class='bx bx-compass icon' aria-hidden="true"></i>
            <div class="logo_name">MyFind<span>ADMINISTRATION</span></div>
            <button type="button" id="btn" class="sidebar-toggle" aria-label="Collapse navigation" aria-expanded="true" aria-controls="sidebar-navigation"><i class="bx bx-menu-alt-right" aria-hidden="true"></i></button>
        </div>
        <ul class="nav-list" id="sidebar-navigation">
            <?php foreach ([
                ['dashboard', 'admin_dashboard.php', 'bx-grid-alt', 'Dashboard'],
                ['risk', 'risk_map.php', 'bx-map-alt', 'View Risk Map'],
                ['tourists', 'approve_tourist.php', 'bx-world', 'Approve Tourist'],
                ['citizens', 'approve_citizen.php', 'bx-id-card', 'Approve Citizen'],
                ['reports', 'approve_citizen_report.php', 'bx-message-square-detail', 'Citizen Reports'],
                ['visa', 'visa_management.php', 'bx-calendar-check', 'Visa & Monitor'],
                ['profile', 'profile.php', 'bx-cog', 'Settings'],
            ] as [$key, $href, $icon, $label]): ?>
            <li class="<?= $active === $key ? 'active' : '' ?> <?= $key === 'profile' ? 'nav-settings' : '' ?>">
                <a href="<?= escape($href) ?>" aria-label="<?= escape($label) ?>" title="<?= escape($label) ?>" <?= $active === $key ? 'aria-current="page"' : '' ?>>
                    <i class="bx <?= escape($icon) ?>" aria-hidden="true"></i>
                    <span class="links_name"><?= escape($label) ?></span>
                </a>
                <span class="tooltip" aria-hidden="true"><?= escape($label) ?></span>
            </li>
            <?php endforeach; ?>
        </ul>
            <div class="sidebar-account">
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
            </div>
    </aside>
    <?php
}

<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/admin_guard.php';
require_once __DIR__ . '/includes/layout.php';
require_once __DIR__ . '/services/application_service.php';

$admin = require_admin();

$successMessage = null;
$errorMessage = null;

$appService = new ApplicationService();

// ============================================================
// Handle POST Actions
// ============================================================
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';

    // --- Add Admin ---
    if ($action === 'add_admin') {
        $email = trim((string) ($_POST['email'] ?? ''));
        $fullName = trim((string) ($_POST['full_name'] ?? ''));
        $password = $_POST['password'] ?? '';
        $confirmPassword = $_POST['confirm_password'] ?? '';
        $currentAdminId = $admin['id'] ?? '';

        try {
            if (empty($email)) {
                $errorMessage = 'Email address is required.';
            } elseif (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
                $errorMessage = 'Please enter a valid email address.';
            } elseif (empty($fullName)) {
                $errorMessage = 'Full name is required.';
            } elseif (empty($password)) {
                $errorMessage = 'Password is required.';
            } elseif (strlen($password) < 8) {
                $errorMessage = 'Password must be at least 8 characters.';
            } elseif ($password !== $confirmPassword) {
                $errorMessage = 'Passwords do not match.';
            } elseif (empty($currentAdminId)) {
                $errorMessage = 'Invalid admin session. Please log in again.';
            } else {
                $result = $appService->addAdminWithPassword($email, $fullName, $password, $currentAdminId);

                if ($result) {
                    $successMessage = 'Admin created successfully! ' . htmlspecialchars($fullName) . ' can now log in.';
                } else {
                    $errorMessage = 'Unable to create admin. Please try again.';
                }
            }
        } catch (Throwable $e) {
            $errorMessage = $e->getMessage();
            error_log('Add admin error: ' . $e->getMessage());
        }
    }

    // --- Remove Admin ---
    if ($action === 'remove_admin') {
        $profileId = trim((string) ($_POST['profile_id'] ?? ''));
        $currentAdminId = $admin['id'] ?? '';

        try {
            if (empty($profileId)) {
                $errorMessage = 'Invalid admin ID.';
            } elseif (empty($currentAdminId)) {
                $errorMessage = 'Invalid admin session. Please log in again.';
            } else {
                $result = $appService->removeAdmin($profileId, $currentAdminId);

                if ($result) {
                    $successMessage = 'Admin has been removed successfully.';
                } else {
                    $errorMessage = 'Unable to remove admin. Please try again.';
                }
            }
        } catch (Throwable $e) {
            $errorMessage = $e->getMessage();
            error_log('Remove admin error: ' . $e->getMessage());
        }
    }
}

// ============================================================
// Load All Admins
// ============================================================
$admins = [];
$loadError = null;
$totalAdmins = 0;

try {
    $admins = $appService->getAllAdmins();
    $totalAdmins = count($admins);
} catch (Throwable $e) {
    $loadError = 'Unable to load admin list. Please refresh the page.';
    error_log('Load admins error: ' . $e->getMessage());
}

render_admin_start('Admin Management', $admin, 'admin_management');

?>

<style>
/* ============================================================
   PAGE LAYOUT
============================================================ */
.admin-mgmt-page {
    display: flex;
    flex-direction: column;
    gap: 24px;
}

.admin-mgmt-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 20px;
    flex-wrap: wrap;
}

.admin-mgmt-header h1 {
    margin: 0;
    font-size: 24px;
    font-weight: 700;
    color: #1a1a2e;
}

.admin-mgmt-header h1 i {
    color: #8b5cf6;
}

.admin-mgmt-header .subtitle {
    display: flex;
    align-items: center;
    gap: 12px;
    margin: 4px 0 0;
    flex-wrap: wrap;
}

.admin-mgmt-header .subtitle p {
    margin: 0;
    opacity: .7;
    font-size: 14px;
}

.admin-mgmt-header .badge-admins {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 2px 12px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 600;
    background: #ede9fe;
    color: #5b21b6;
}

/* ============================================================
   ADD ADMIN FORM CARD
============================================================ */
.add-card {
    background: white;
    border-radius: 16px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04);
    border: 1px solid #f1f3f5;
    overflow: hidden;
}

.add-card .card-header {
    padding: 16px 20px;
    border-bottom: 1px solid #f1f3f5;
    display: flex;
    align-items: center;
    gap: 12px;
    background: #fafbfc;
}

.add-card .card-header .card-icon {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 20px;
    flex-shrink: 0;
    background: #ede9fe;
    color: #8b5cf6;
}

.add-card .card-header .title-group h3 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: #1a1a2e;
}

.add-card .card-header .title-group p {
    margin: 2px 0 0;
    font-size: 13px;
    color: #6b7280;
}

.add-card .card-body {
    padding: 20px;
}

.add-form {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
}

.add-form .form-group {
    display: flex;
    flex-direction: column;
}

.add-form .form-group label {
    display: block;
    font-size: 13px;
    font-weight: 600;
    color: #1a1a2e;
    margin-bottom: 4px;
}

.add-form .form-group label .required {
    color: #dc3545;
}

.add-form input[type="text"],
.add-form input[type="email"],
.add-form input[type="password"] {
    width: 100%;
    padding: 10px 14px;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    font-size: 14px;
    font-family: inherit;
    box-sizing: border-box;
    transition: border-color 0.2s, box-shadow 0.2s;
    background: white;
}

.add-form input:focus {
    outline: none;
    border-color: #8b5cf6;
    box-shadow: 0 0 0 3px rgba(139, 92, 246, 0.1);
}

.password-wrapper {
    position: relative;
    display: flex;
    align-items: center;
}

.password-wrapper input {
    width: 100%;
    padding: 10px 48px 10px 14px;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    font-size: 14px;
    font-family: inherit;
    box-sizing: border-box;
    transition: border-color 0.2s, box-shadow 0.2s;
    background: white;
}

.password-wrapper input:focus {
    outline: none;
    border-color: #8b5cf6;
    box-shadow: 0 0 0 3px rgba(139, 92, 246, 0.1);
}

.password-wrapper .toggle-password {
    position: absolute;
    right: 12px;
    background: none;
    border: none;
    color: #6b7280;
    cursor: pointer;
    font-size: 20px;
    padding: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: color 0.2s;
}

.password-wrapper .toggle-password:hover {
    color: #1a1a2e;
}

.password-wrapper .toggle-password:focus {
    outline: none;
}

.btn-add-admin {
    padding: 10px 28px;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    background: #8b5cf6;
    color: white;
    min-height: 46px;
}

.btn-add-admin:hover {
    background: #7c3aed;
}

.btn-add-admin:disabled {
    opacity: 0.6;
    cursor: not-allowed;
}

.btn-add-admin-wrapper {
    grid-column: 1 / -1;
    display: flex;
    gap: 12px;
    align-items: center;
    flex-wrap: wrap;
    padding-top: 4px;
}

.btn-add-admin-wrapper .hint {
    font-size: 12px;
    color: #6b7280;
}

.btn-add-admin-wrapper .hint i {
    margin-right: 4px;
}

/* ============================================================
   ALERTS
============================================================ */
.alert {
    padding: 14px 18px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    gap: 10px;
}

.alert i {
    font-size: 20px;
}

.alert-success {
    background: #d1fae5;
    color: #065f46;
}

.alert-error {
    background: #fee2e2;
    color: #991b1b;
}

/* ============================================================
   ADMIN TABLE
============================================================ */
.table-card {
    background: white;
    border-radius: 16px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04);
    border: 1px solid #f1f3f5;
    overflow: hidden;
}

.table-card .table-header {
    padding: 14px 20px;
    border-bottom: 1px solid #f1f3f5;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 10px;
    background: #fafbfc;
}

.table-card .table-header h3 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: #1a1a2e;
}

.table-card .table-header .count-badge {
    background: #f1f5f9;
    padding: 4px 14px;
    border-radius: 20px;
    font-size: 12px;
    color: #4b5563;
    font-weight: 500;
}

.admin-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 14px;
}

.admin-table thead {
    background: #f8fafc;
    border-bottom: 2px solid #e5e7eb;
}

.admin-table th {
    padding: 12px 16px;
    text-align: left;
    font-weight: 600;
    color: #4b5563;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
}

.admin-table td {
    padding: 12px 16px;
    border-bottom: 1px solid #f1f3f5;
    vertical-align: middle;
}

.admin-table tbody tr:hover {
    background: #f8fafc;
}

.admin-table tbody tr:last-child td {
    border-bottom: none;
}

.admin-table .admin-avatar {
    width: 36px;
    height: 36px;
    border-radius: 50%;
    background: #ede9fe;
    color: #5b21b6;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 600;
    font-size: 14px;
    flex-shrink: 0;
}

.admin-table .admin-avatar img {
    width: 100%;
    height: 100%;
    border-radius: 50%;
    object-fit: cover;
}

.admin-table .name-cell {
    display: flex;
    align-items: center;
    gap: 12px;
}

.admin-table .name-cell .name-text {
    font-weight: 500;
    color: #1a1a2e;
}

.admin-table .admin-role {
    display: inline-block;
    padding: 2px 12px;
    border-radius: 12px;
    font-size: 11px;
    font-weight: 600;
    background: #ede9fe;
    color: #5b21b6;
}

.admin-table .status-active {
    display: inline-block;
    padding: 2px 12px;
    border-radius: 12px;
    font-size: 11px;
    font-weight: 600;
    background: #d1fae5;
    color: #065f46;
}

.admin-table .btn-remove {
    padding: 4px 14px;
    border: none;
    border-radius: 6px;
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
    background: #fee2e2;
    color: #991b1b;
}

.admin-table .btn-remove:hover {
    background: #fca5a5;
}

.admin-table .btn-remove:disabled {
    opacity: 0.4;
    cursor: not-allowed;
}

.admin-table .btn-remove-self {
    padding: 4px 14px;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    font-size: 12px;
    font-weight: 500;
    background: #f3f4f6;
    color: #6b7280;
    cursor: not-allowed;
}

/* ============================================================
   EMPTY STATE
============================================================ */
.empty-state {
    padding: 40px 20px;
    text-align: center;
    color: #6b7280;
}

.empty-state i {
    font-size: 40px;
    display: block;
    margin-bottom: 8px;
    opacity: 0.4;
}

.empty-state h4 {
    margin: 0 0 4px 0;
    color: #1a1a2e;
}

.empty-state p {
    margin: 0;
    font-size: 13px;
}

/* ============================================================
   RESPONSIVE
============================================================ */
@media (max-width: 768px) {
    .add-form {
        grid-template-columns: 1fr;
        gap: 12px;
    }

    .btn-add-admin-wrapper {
        grid-column: 1;
        flex-direction: column;
        align-items: stretch;
    }

    .btn-add-admin {
        width: 100%;
        justify-content: center;
    }

    .admin-table {
        font-size: 12px;
    }

    .admin-table th,
    .admin-table td {
        padding: 8px 10px;
    }

    .admin-mgmt-header {
        flex-direction: column;
        align-items: flex-start;
    }
}

@media (max-width: 480px) {
    .admin-table .name-cell .name-text {
        font-size: 12px;
    }

    .admin-table .admin-avatar {
        width: 28px;
        height: 28px;
        font-size: 11px;
    }

    .admin-table .btn-remove,
    .admin-table .btn-remove-self {
        font-size: 11px;
        padding: 3px 10px;
    }

    .table-card .table-header {
        flex-direction: column;
        align-items: flex-start;
        gap: 4px;
    }

    .password-wrapper input {
        padding: 8px 44px 8px 12px;
        font-size: 13px;
    }
}
</style>

<div class="admin-mgmt-page">

    <!-- HEADER -->
    <section class="admin-mgmt-header">
        <div>
            <div class="subtitle">
                <p>Manage system administrators</p>
            </div>
        </div>
    </section>

    <!-- ALERTS -->
    <?php if ($successMessage !== null): ?>
        <div class="alert alert-success" role="alert">
            <i class='bx bx-check-circle'></i>
            <?= htmlspecialchars($successMessage, ENT_QUOTES, 'UTF-8') ?>
        </div>
    <?php endif; ?>

    <?php if ($errorMessage !== null): ?>
        <div class="alert alert-error" role="alert">
            <i class='bx bx-error-circle'></i>
            <?= htmlspecialchars($errorMessage, ENT_QUOTES, 'UTF-8') ?>
        </div>
    <?php endif; ?>

    <?php if ($loadError !== null): ?>
        <div class="alert alert-error" role="alert">
            <i class='bx bx-error-circle'></i>
            <?= htmlspecialchars($loadError, ENT_QUOTES, 'UTF-8') ?>
        </div>
    <?php endif; ?>

    <!-- ADD ADMIN FORM -->
    <section class="add-card">
        <div class="card-header">
            <div class="card-icon"><i class='bx bx-user-plus'></i></div>
            <div class="title-group">
                <h3>Create New Admin</h3>
                <p>Add a new administrator to the system</p>
            </div>
        </div>
        <div class="card-body">
            <form method="post" class="add-form" id="addAdminForm">
                <input type="hidden" name="action" value="add_admin">

                <div class="form-group">
                    <label for="full_name">Full Name <span class="required">*</span></label>
                    <input type="text" id="full_name" name="full_name" placeholder="Enter full name" required>
                </div>

                <div class="form-group">
                    <label for="email">Email Address <span class="required">*</span></label>
                    <input type="email" id="email" name="email" placeholder="Enter email address" required>
                </div>

                <div class="form-group">
                    <label for="password">Password <span class="required">*</span></label>
                    <div class="password-wrapper">
                        <input type="password" id="password" name="password" placeholder="Min 8 characters" required minlength="8">
                        <button type="button" class="toggle-password" onclick="togglePassword('password')" tabindex="-1">
                            <i class='bx bx-hide' id="password_icon"></i>
                        </button>
                    </div>
                </div>

                <div class="form-group">
                    <label for="confirm_password">Confirm Password <span class="required">*</span></label>
                    <div class="password-wrapper">
                        <input type="password" id="confirm_password" name="confirm_password" placeholder="Re-enter password" required minlength="8">
                        <button type="button" class="toggle-password" onclick="togglePassword('confirm_password')" tabindex="-1">
                            <i class='bx bx-hide' id="confirm_password_icon"></i>
                        </button>
                    </div>
                </div>

                <div class="btn-add-admin-wrapper">
                    <button type="submit" class="btn-add-admin">
                        <i class='bx bx-user-plus'></i> Create Admin
                    </button>
                    <span class="hint">
                        <i class='bx bx-info-circle'></i>
                        The admin will be created immediately with the password you set.
                    </span>
                </div>
            </form>
        </div>
    </section>

    <!-- ADMIN LIST -->
    <section class="table-card">
        <div class="table-header">
            <h3><i class='bx bx-list-ul'></i> Current Administrators</h3>
            <span class="count-badge"><?= $totalAdmins ?> admin<?= $totalAdmins !== 1 ? 's' : '' ?></span>
        </div>

        <div style="overflow-x: auto;">
            <table class="admin-table">
                <thead>
                    <tr>
                        <th>Admin</th>
                        <th>Email</th>
                        <th>Role</th>
                        <th>Status</th>
                        <th style="text-align: center;">Action</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (!empty($admins)): ?>
                        <?php foreach ($admins as $adminUser): ?>
                            <?php
                            $profileId = $adminUser['id'] ?? '';
                            $fullName = $adminUser['full_name'] ?? 'Unknown';
                            $email = $adminUser['email'] ?? 'N/A';
                            $profileImage = $adminUser['profile_image'] ?? null;

                            $isCurrentAdmin = $profileId === ($admin['id'] ?? '');
                            $initial = strtoupper(substr($fullName, 0, 1));
                            ?>
                            <tr>
                                <td>
                                    <div class="name-cell">
                                        <?php if (!empty($profileImage)): ?>
                                            <div class="admin-avatar">
                                                <img src="<?= htmlspecialchars($profileImage, ENT_QUOTES, 'UTF-8') ?>" alt="<?= htmlspecialchars($fullName) ?>">
                                            </div>
                                        <?php else: ?>
                                            <div class="admin-avatar"><?= htmlspecialchars($initial) ?></div>
                                        <?php endif; ?>
                                        <span class="name-text">
                                            <?= htmlspecialchars($fullName, ENT_QUOTES, 'UTF-8') ?>
                                            <?php if ($isCurrentAdmin): ?>
                                                <span style="font-size: 10px; color: #6b7280; font-weight: 400;">(You)</span>
                                            <?php endif; ?>
                                        </span>
                                    </div>
                                </td>
                                <td><?= htmlspecialchars($email, ENT_QUOTES, 'UTF-8') ?></td>
                                <td><span class="admin-role">Administrator</span></td>
                                <td><span class="status-active">Active</span></td>
                                <td style="text-align: center;">
                                    <?php if ($isCurrentAdmin): ?>
                                        <span class="btn-remove-self" title="You cannot remove your own account">Cannot Remove</span>
                                    <?php else: ?>
                                        <form method="post" style="display: inline;"
                                              onsubmit="return confirm('Are you sure you want to remove this admin?\n\nAdmin: <?= htmlspecialchars($fullName, ENT_QUOTES, 'UTF-8') ?>\nEmail: <?= htmlspecialchars($email, ENT_QUOTES, 'UTF-8') ?>\n\nThis action cannot be undone.');">
                                            <input type="hidden" name="action" value="remove_admin">
                                            <input type="hidden" name="profile_id" value="<?= htmlspecialchars($profileId, ENT_QUOTES, 'UTF-8') ?>">
                                            <button type="submit" class="btn-remove">
                                                <i class='bx bx-trash'></i> Remove
                                            </button>
                                        </form>
                                    <?php endif; ?>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    <?php else: ?>
                        <tr>
                            <td colspan="5">
                                <div class="empty-state">
                                    <i class='bx bx-user'></i>
                                    <h4>No Admins Found</h4>
                                    <p>Create your first admin using the form above.</p>
                                </div>
                            </td>
                        </tr>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </section>

</div>

<script>
function togglePassword(inputId) {
    const input = document.getElementById(inputId);
    const icon = document.getElementById(inputId + '_icon');

    if (input.type === 'password') {
        input.type = 'text';
        icon.className = 'bx bx-show';
    } else {
        input.type = 'password';
        icon.className = 'bx bx-hide';
    }
}
</script>

<?php
render_admin_end();
?>
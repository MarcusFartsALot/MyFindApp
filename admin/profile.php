<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/admin_guard.php';
require_once __DIR__ . '/includes/layout.php';
require_once __DIR__ . '/services/application_service.php';

$admin = require_admin();

$successMessage = null;
$errorMessage = null;

$appService = new ApplicationService();
$userId = $admin['id'] ?? null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $currentPassword = trim((string)($_POST['current_password'] ?? ''));
    $newPassword = trim((string)($_POST['new_password'] ?? ''));
    $confirmPassword = trim((string)($_POST['confirm_password'] ?? ''));

    try {
        if (empty($currentPassword)) {
            $errorMessage = 'Current password is required.';
        } elseif (empty($newPassword)) {
            $errorMessage = 'New password is required.';
        } elseif (strlen($newPassword) < 8) {
            $errorMessage = 'New password must be at least 8 characters.';
        } elseif ($newPassword !== $confirmPassword) {
            $errorMessage = 'Passwords do not match.';
        } else {
            $result = $appService->updateAdminPassword($userId, $newPassword);
            
            if ($result) {
                $successMessage = 'Password changed successfully!';
            } else {
                $errorMessage = 'Unable to change password. Please try again.';
            }
        }
    } catch (Throwable $e) {
        $errorMessage = 'Unable to change password. Please try again later.';
        error_log('Update password error: ' . $e->getMessage());
    }
}

render_admin_start('Change Password', $admin, 'profile');
?>

<style>
/* =========================================================
   PAGE LAYOUT
========================================================= */
.profile-page {
    display: flex;
    flex-direction: column;
    gap: 24px;
}

/* =========================================================
   HEADER
========================================================= */
.profile-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 20px;
    flex-wrap: wrap;
}

.profile-header h1 {
    margin: 0;
    font-size: 24px;
    font-weight: 700;
    color: #1a1a2e;
}

.profile-header h1 i {
    color: #3b82f6;
}

.profile-header .subtitle {
    display: flex;
    align-items: center;
    gap: 12px;
    margin: 4px 0 0;
    flex-wrap: wrap;
}

.profile-header .subtitle p {
    margin: 0;
    opacity: .7;
    font-size: 14px;
}

.profile-header .badge-profile {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 2px 12px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 600;
    background: #dbeafe;
    color: #1e40af;
}

/* =========================================================
   PROFILE CARD
========================================================= */
.profile-card {
    background: white;
    border-radius: 16px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04);
    border: 1px solid #f1f3f5;
    overflow: hidden;
    max-width: 600px;
}

.profile-card .card-header {
    padding: 20px 24px;
    border-bottom: 1px solid #f1f3f5;
    display: flex;
    align-items: center;
    gap: 16px;
    background: #f8fafc;
}

.profile-card .card-header .avatar {
    width: 56px;
    height: 56px;
    border-radius: 50%;
    background: #dbeafe;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;
    color: #3b82f6;
    flex-shrink: 0;
}

.profile-card .card-header .title-group h2 {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
    color: #1a1a2e;
}

.profile-card .card-header .title-group p {
    margin: 2px 0 0;
    font-size: 13px;
    color: #6b7280;
}

/* =========================================================
   FORM
========================================================= */
.profile-form {
    padding: 24px;
}

.form-group {
    margin-bottom: 18px;
}

.form-group:last-child {
    margin-bottom: 0;
}

.form-group label {
    display: block;
    font-size: 13px;
    font-weight: 600;
    color: #1a1a2e;
    margin-bottom: 4px;
}

.form-group label .required {
    color: #dc3545;
}

.form-group .hint {
    display: block;
    font-size: 12px;
    color: #6b7280;
    margin-top: 4px;
}

/* Password Wrapper */
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
}

.password-wrapper input:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
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

/* =========================================================
   BUTTONS
========================================================= */
.btn-group {
    display: flex;
    gap: 12px;
    margin-top: 20px;
    flex-wrap: wrap;
}

.btn {
    padding: 10px 24px;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    text-decoration: none;
}

.btn-success {
    background: #10b981;
    color: white;
}

.btn-success:hover {
    background: #059669;
}

.btn-outline {
    background: transparent;
    border: 1px solid #e5e7eb;
    color: #4b5563;
}

.btn-outline:hover {
    background: #f3f4f6;
}

/* =========================================================
   ALERTS
========================================================= */
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

/* =========================================================
   RESPONSIVE
========================================================= */
@media (max-width: 768px) {
    .profile-card .card-header {
        flex-direction: column;
        text-align: center;
    }

    .btn-group {
        flex-direction: column;
    }

    .btn {
        width: 100%;
        justify-content: center;
    }

    .profile-header {
        flex-direction: column;
        align-items: flex-start;
    }

    .profile-card {
        max-width: 100%;
    }
}

@media (max-width: 480px) {
    .profile-header h1 {
        font-size: 22px;
    }

    .profile-card .card-header .avatar {
        width: 48px;
        height: 48px;
        font-size: 20px;
    }

    .profile-form {
        padding: 16px;
    }

    .password-wrapper input {
        padding: 8px 44px 8px 12px;
        font-size: 13px;
    }
}
</style>

<div class="profile-page">

    <!-- HEADER -->
    <section class="profile-header">
        <div>
            <div class="subtitle">
                <p>Update your password to keep your account secure</p>
                <span class="badge-profile">🔐 Change Password</span>
            </div>
        </div>
        <a href="admin_dashboard.php" class="btn btn-outline" style="padding:8px 20px;border:1px solid #e5e7eb;border-radius:8px;text-decoration:none;color:#4b5563;font-size:13px;display:inline-flex;align-items:center;gap:6px;transition:all 0.2s;font-weight:500;" onmouseover="this.style.background='#f3f4f6'" onmouseout="this.style.background='transparent'">
            <i class='bx bx-arrow-back'></i> Dashboard
        </a>
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

    <!-- PROFILE CARD -->
    <div class="profile-card">
        <div class="card-header">
            <div class="avatar">
                <i class='bx bx-lock'></i>
            </div>
            <div class="title-group">
                <h2>Change Password</h2>
                <p><?= htmlspecialchars($admin['email'] ?? 'Admin', ENT_QUOTES, 'UTF-8') ?></p>
            </div>
        </div>

        <form class="profile-form" method="post" id="profileForm">

            <!-- Current Password -->
            <div class="form-group">
                <label for="current_password">Current Password <span class="required">*</span></label>
                <div class="password-wrapper">
                    <input type="password" id="current_password" name="current_password" placeholder="Enter current password" required>
                    <button type="button" class="toggle-password" onclick="togglePassword('current_password')" tabindex="-1">
                        <i class='bx bx-hide' id="current_password_icon"></i>
                    </button>
                </div>
                <span class="hint">Enter your current password to verify</span>
            </div>

            <!-- New Password -->
            <div class="form-group">
                <label for="new_password">New Password <span class="required">*</span></label>
                <div class="password-wrapper">
                    <input type="password" id="new_password" name="new_password" placeholder="Enter new password (min 8 chars)" required>
                    <button type="button" class="toggle-password" onclick="togglePassword('new_password')" tabindex="-1">
                        <i class='bx bx-hide' id="new_password_icon"></i>
                    </button>
                </div>
                <span class="hint">Must be at least 8 characters</span>
            </div>

            <!-- Confirm Password -->
            <div class="form-group">
                <label for="confirm_password">Confirm New Password <span class="required">*</span></label>
                <div class="password-wrapper">
                    <input type="password" id="confirm_password" name="confirm_password" placeholder="Re-enter new password" required>
                    <button type="button" class="toggle-password" onclick="togglePassword('confirm_password')" tabindex="-1">
                        <i class='bx bx-hide' id="confirm_password_icon"></i>
                    </button>
                </div>
            </div>

            <div class="btn-group">
                <button type="submit" class="btn btn-success">
                    <i class='bx bx-lock'></i> Change Password
                </button>
            </div>

        </form>
    </div>
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

<?php render_admin_end(); ?>
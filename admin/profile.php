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
$authId = $admin['auth_id'] ?? null;

// ============================================================
// HANDLE FORM SUBMISSIONS
// ============================================================
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';

    // --- Update Profile ---
    if ($action === 'update_profile') {
        $name = trim((string)($_POST['name'] ?? ''));
        $phone = trim((string)($_POST['phone'] ?? ''));
        $nationality = trim((string)($_POST['nationality'] ?? ''));

        try {
            if (empty($name)) {
                $errorMessage = 'Name is required.';
            } elseif (empty($phone)) {
                $errorMessage = 'Phone number is required.';
            } elseif (empty($nationality)) {
                $errorMessage = 'Nationality is required.';
            } else {
                $result = $appService->updateAdminProfile($userId, [
                    'full_name' => $name,
                    'phone_number' => $phone,
                    'nationality' => $nationality
                ]);

                if ($result) {
                    $successMessage = 'Profile updated successfully!';
                    // Refresh admin data
                    $_SESSION['admin_profile'] = $appService->getAdminById($userId);
                    $admin = $_SESSION['admin_profile'];
                } else {
                    $errorMessage = 'Unable to update profile. Please try again.';
                }
            }
        } catch (Throwable $e) {
            $errorMessage = $e->getMessage();
            error_log('Update profile error: ' . $e->getMessage());
        }
    }

    // --- Update Password ---
    if ($action === 'update_password') {
        $currentPassword = trim((string)($_POST['current_password'] ?? ''));
        $newPassword = trim((string)($_POST['new_password'] ?? ''));
        $confirmPassword = trim((string)($_POST['confirm_password'] ?? ''));
        $adminEmail = $admin['email'] ?? '';

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
                $result = $appService->updateAdminPasswordWithVerification(
                    $authId,
                    $adminEmail,
                    $currentPassword,
                    $newPassword
                );

                if ($result) {
                    $successMessage = 'Password changed successfully!';
                } else {
                    $errorMessage = 'Current password is incorrect or unable to change password.';
                }
            }
        } catch (Throwable $e) {
            $errorMessage = 'Unable to change password. Please try again later.';
            error_log('Update password error: ' . $e->getMessage());
        }
    }

    // --- Upload Profile Image ---
    if ($action === 'upload_image') {
        try {
            if (isset($_FILES['profile_image']) && $_FILES['profile_image']['error'] === UPLOAD_ERR_OK) {
                $file = $_FILES['profile_image'];
                $allowedTypes = ['image/jpeg', 'image/png', 'image/jpg', 'image/webp'];
                $maxSize = 2 * 1024 * 1024; // 2MB

                // Validate file type
                $finfo = finfo_open(FILEINFO_MIME_TYPE);
                $mimeType = finfo_file($finfo, $file['tmp_name']);
                finfo_close($finfo);

                if (!in_array($mimeType, $allowedTypes)) {
                    $errorMessage = 'Only JPG, PNG, and WEBP images are allowed.';
                } elseif ($file['size'] > $maxSize) {
                    $errorMessage = 'Image size must be less than 2MB.';
                } else {
                    // Generate unique filename
                    $extension = pathinfo($file['name'], PATHINFO_EXTENSION);
                    $filename = 'profile_' . time() . '_' . bin2hex(random_bytes(8)) . '.' . $extension;

                    // Upload to Supabase Storage
                    $result = $appService->uploadAdminProfileImage(
                        $userId,
                        $file['tmp_name'],
                        $filename,
                        $mimeType
                    );

                    if ($result) {
                        $successMessage = 'Profile image updated successfully!';
                        // Refresh admin data
                        $_SESSION['admin_profile'] = $appService->getAdminById($userId);
                        $admin = $_SESSION['admin_profile'];
                    } else {
                        $errorMessage = 'Unable to upload image. Please try again.';
                    }
                }
            } else {
                $errorMessage = 'Please select an image to upload.';
            }
        } catch (Exception $e) {
            $errorMessage = $e->getMessage();
            error_log('Upload image error: ' . $e->getMessage());
        } catch (Throwable $e) {
            $errorMessage = 'Unable to upload image. Please try again later.';
            error_log('Upload image error: ' . $e->getMessage());
        }
    }

    // --- Remove Profile Image ---
    if ($action === 'remove_image') {
        try {
            $result = $appService->removeAdminProfileImage($userId);

            if ($result) {
                $successMessage = 'Profile image removed successfully!';
                // Refresh admin data
                $_SESSION['admin_profile'] = $appService->getAdminById($userId);
                $admin = $_SESSION['admin_profile'];
            } else {
                $errorMessage = 'Unable to remove image. Please try again.';
            }
        } catch (Throwable $e) {
            $errorMessage = 'Unable to remove image. Please try again later.';
            error_log('Remove image error: ' . $e->getMessage());
        }
    }
}

// Get current values
$currentName = $admin['full_name'] ?? '';
$currentPhone = $admin['phone_number'] ?? '';
$currentNationality = $admin['nationality'] ?? '';
$currentProfileImage = $admin['profile_image'] ?? null;

render_admin_start('Profile Settings', $admin, 'profile');
?>

<style>
/* ============================================================
   PAGE LAYOUT
============================================================ */
.profile-page {
    display: flex;
    flex-direction: column;
    gap: 24px;
}

/* ============================================================
   HEADER
============================================================ */
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

/* ============================================================
   PROFILE GRID
============================================================ */
.profile-grid {
    display: grid;
    grid-template-columns: 280px 1fr;
    gap: 24px;
}

@media (max-width: 768px) {
    .profile-grid {
        grid-template-columns: 1fr;
    }
}

/* ============================================================
   PROFILE CARD
============================================================ */
.profile-card {
    background: white;
    border-radius: 16px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04);
    border: 1px solid #f1f3f5;
    overflow: hidden;
}

.profile-card .card-header {
    padding: 16px 20px;
    border-bottom: 1px solid #f1f3f5;
    display: flex;
    align-items: center;
    gap: 12px;
    background: #f8fafc;
}

.profile-card .card-header .card-icon {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 20px;
    flex-shrink: 0;
}

.profile-card .card-header .card-icon.blue {
    background: #dbeafe;
    color: #3b82f6;
}

.profile-card .card-header .card-icon.green {
    background: #d1fae5;
    color: #10b981;
}

.profile-card .card-header .card-icon.purple {
    background: #ede9fe;
    color: #8b5cf6;
}

.profile-card .card-header .title-group h3 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: #1a1a2e;
}

.profile-card .card-header .title-group p {
    margin: 2px 0 0;
    font-size: 13px;
    color: #6b7280;
}

.profile-card .card-body {
    padding: 20px;
}

/* ============================================================
   AVATAR / IMAGE UPLOAD
============================================================ */
.avatar-section {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16px;
    padding: 20px 0;
}

.avatar-wrapper {
    position: relative;
    width: 150px;
    height: 150px;
    border-radius: 50%;
    overflow: hidden;
    border: 3px solid #e5e7eb;
    background: #f3f4f6;
    flex-shrink: 0;
}

.avatar-wrapper img {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.avatar-wrapper .avatar-placeholder {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 56px;
    color: #9ca3af;
    background: #f3f4f6;
}

.avatar-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    justify-content: center;
}

.avatar-actions .btn-sm {
    padding: 6px 14px;
    font-size: 12px;
    border-radius: 6px;
    border: none;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 4px;
    transition: all 0.2s;
    font-weight: 500;
}

.avatar-actions .btn-sm.upload {
    background: #3b82f6;
    color: white;
}

.avatar-actions .btn-sm.upload:hover {
    background: #2563eb;
}

.avatar-actions .btn-sm.remove {
    background: #fee2e2;
    color: #dc2626;
}

.avatar-actions .btn-sm.remove:hover {
    background: #fca5a5;
}

.avatar-actions .btn-sm.remove:disabled {
    opacity: 0.5;
    cursor: not-allowed;
}

#imageInput {
    display: none;
}

/* ============================================================
   FORM
============================================================ */
.profile-form .form-group {
    margin-bottom: 16px;
}

.profile-form .form-group:last-child {
    margin-bottom: 0;
}

.profile-form .form-group label {
    display: block;
    font-size: 13px;
    font-weight: 600;
    color: #1a1a2e;
    margin-bottom: 4px;
}

.profile-form .form-group label .required {
    color: #dc3545;
}

.profile-form .form-group .hint {
    display: block;
    font-size: 12px;
    color: #6b7280;
    margin-top: 4px;
}

.profile-form input[type="text"],
.profile-form input[type="email"],
.profile-form input[type="tel"] {
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

.profile-form input:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}

.profile-form input:disabled {
    background: #f3f4f6;
    cursor: not-allowed;
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

/* ============================================================
   BUTTONS
============================================================ */
.btn-group {
    display: flex;
    gap: 12px;
    margin-top: 8px;
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

.btn-primary {
    background: #3b82f6;
    color: white;
}

.btn-primary:hover {
    background: #2563eb;
}

.btn-outline {
    background: transparent;
    border: 1px solid #e5e7eb;
    color: #4b5563;
}

.btn-outline:hover {
    background: #f3f4f6;
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
   DIVIDER
============================================================ */
.divider {
    border: none;
    border-top: 1px solid #f1f3f5;
    margin: 0;
}

/* ============================================================
   RESPONSIVE
============================================================ */
@media (max-width: 480px) {
    .profile-header h1 {
        font-size: 22px;
    }

    .profile-card .card-body {
        padding: 16px;
    }

    .password-wrapper input {
        padding: 8px 44px 8px 12px;
        font-size: 13px;
    }

    .btn-group {
        flex-direction: column;
    }

    .btn-group .btn {
        width: 100%;
        justify-content: center;
    }

    .avatar-wrapper {
        width: 120px;
        height: 120px;
    }

    .avatar-wrapper .avatar-placeholder {
        font-size: 44px;
    }
}
</style>

<div class="profile-page">

    <!-- HEADER -->
    <section class="profile-header">
        <div>
            <div class="subtitle">
                <p>Manage your account information and security</p>
                <span class="badge-profile"><?= htmlspecialchars($admin['role'] ?? 'Admin', ENT_QUOTES, 'UTF-8') ?></span>
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

    <!-- PROFILE GRID -->
    <div class="profile-grid">

        <!-- LEFT COLUMN: Avatar -->
        <div>
            <div class="profile-card">
                <div class="card-header">
                    <div class="card-icon purple">
                        <i class='bx bx-image'></i>
                    </div>
                    <div class="title-group">
                        <h3>Profile Picture</h3>
                        <p>Upload or change your photo</p>
                    </div>
                </div>
                <div class="card-body">
                    <div class="avatar-section">
                        <div class="avatar-wrapper">
                            <?php if (!empty($currentProfileImage)): ?>
                                <img src="<?= htmlspecialchars($currentProfileImage, ENT_QUOTES, 'UTF-8') ?>" alt="Profile Image" id="profilePreview">
                            <?php else: ?>
                                <div class="avatar-placeholder" id="profilePlaceholder">
                                    <i class='bx bx-user'></i>
                                </div>
                                <img src="" alt="Profile Image" id="profilePreview" style="display:none;">
                            <?php endif; ?>
                        </div>

                        <div class="avatar-actions">
                            <button class="btn-sm upload" onclick="document.getElementById('imageInput').click()">
                                <i class='bx bx-upload'></i> Upload
                            </button>
                            <?php if (!empty($currentProfileImage)): ?>
                                <form method="post" style="display:inline;" onsubmit="return confirm('Are you sure you want to remove your profile image?');">
                                    <input type="hidden" name="action" value="remove_image">
                                    <button type="submit" class="btn-sm remove">
                                        <i class='bx bx-trash'></i> Remove
                                    </button>
                                </form>
                            <?php endif; ?>
                        </div>

                        <form method="post" enctype="multipart/form-data" id="imageUploadForm">
                            <input type="hidden" name="action" value="upload_image">
                            <input type="file" id="imageInput" name="profile_image" accept="image/*" onchange="document.getElementById('imageUploadForm').submit()">
                        </form>

                        <small style="color:#6b7280;font-size:11px;text-align:center;">
                            JPG, PNG, WEBP &bull; Max 2MB
                        </small>
                    </div>
                </div>
            </div>
        </div>

        <!-- RIGHT COLUMN: Profile Info & Password -->
        <div style="display:flex;flex-direction:column;gap:24px;">

            <!-- Profile Info Card -->
            <div class="profile-card">
                <div class="card-header">
                    <div class="card-icon blue">
                        <i class='bx bx-user'></i>
                    </div>
                    <div class="title-group">
                        <h3>Personal Information</h3>
                        <p>Update your profile details</p>
                    </div>
                </div>

                <form class="profile-form" method="post">
                    <input type="hidden" name="action" value="update_profile">

                    <div class="card-body">
                        <div class="form-group">
                            <label for="email">Email Address</label>
                            <input type="email" id="email" value="<?= htmlspecialchars($admin['email'] ?? '', ENT_QUOTES, 'UTF-8') ?>" disabled>
                            <span class="hint">Email cannot be changed</span>
                        </div>

                        <div class="form-group">
                            <label for="name">Full Name <span class="required">*</span></label>
                            <input type="text" id="name" name="name" value="<?= htmlspecialchars($currentName, ENT_QUOTES, 'UTF-8') ?>" placeholder="Enter your full name" required>
                        </div>

                        <div class="form-group">
                            <label for="phone">Phone Number <span class="required">*</span></label>
                            <input type="tel" id="phone" name="phone" value="<?= htmlspecialchars($currentPhone, ENT_QUOTES, 'UTF-8') ?>" placeholder="Enter your phone number" required>
                        </div>

                        <div class="form-group">
                            <label for="nationality">Nationality <span class="required">*</span></label>
                            <input type="text" id="nationality" name="nationality" value="<?= htmlspecialchars($currentNationality, ENT_QUOTES, 'UTF-8') ?>" placeholder="Enter your nationality" required>
                        </div>

                        <div class="btn-group">
                            <button type="submit" class="btn btn-primary">
                                <i class='bx bx-save'></i> Save Changes
                            </button>
                        </div>
                    </div>
                </form>
            </div>

            <!-- Change Password Card -->
            <div class="profile-card">
                <div class="card-header">
                    <div class="card-icon green">
                        <i class='bx bx-lock-alt'></i>
                    </div>
                    <div class="title-group">
                        <h3>Change Password</h3>
                        <p>Update your security credentials</p>
                    </div>
                </div>

                <form class="profile-form" method="post">
                    <input type="hidden" name="action" value="update_password">

                    <div class="card-body">
                        <div class="form-group">
                            <label for="current_password">Current Password <span class="required">*</span></label>
                            <div class="password-wrapper">
                                <input type="password" id="current_password" name="current_password" placeholder="Enter current password" required>
                                <button type="button" class="toggle-password" onclick="togglePassword('current_password')" tabindex="-1">
                                    <i class='bx bx-hide' id="current_password_icon"></i>
                                </button>
                            </div>
                        </div>

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
                    </div>
                </form>
            </div>

        </div>
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

document.getElementById('imageInput')?.addEventListener('change', function(e) {
    const file = e.target.files[0];
    if (file) {
        const reader = new FileReader();
        reader.onload = function(ev) {
            const preview = document.getElementById('profilePreview');
            const placeholder = document.getElementById('profilePlaceholder');
            preview.src = ev.target.result;
            preview.style.display = 'block';
            if (placeholder) placeholder.style.display = 'none';
        };
        reader.readAsDataURL(file);
    }
});
</script>

<?php render_admin_end(); ?>
<?php
declare(strict_types=1);

require_once __DIR__ . '/services/admin_password_recovery_service.php';

header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
header('Referrer-Policy: no-referrer');

$errorMessage = null;
$recoveryProfile = null;
$pendingVerifier = $_SESSION['admin_recovery_code_verifier'] ?? null;
$pendingRequestedAt = $_SESSION['admin_recovery_request_at'] ?? null;
$waitingForLink = is_string($pendingVerifier)
    && $pendingVerifier !== ''
    && is_int($pendingRequestedAt)
    && time() - $pendingRequestedAt <= ADMIN_RECOVERY_CODE_LIFETIME;
if (!$waitingForLink && is_string($pendingVerifier)) {
    clear_pending_admin_recovery_request();
}

$authError = trim((string) ($_GET['error'] ?? $_GET['error_code'] ?? ''));
if ($authError !== '') {
    clear_pending_admin_recovery_request();
    $waitingForLink = false;
    $errorMessage = 'Supabase could not verify this password-reset link. Request a new link and try again.';
}

$authCode = trim((string) ($_GET['code'] ?? ''));
if ($authCode !== '' && $errorMessage === null) {
    try {
        exchange_admin_recovery_code($authCode);
        // Remove the one-time authorization code from the address bar and
        // browser history before displaying the password form.
        redirect('admin_reset_password.php');
    } catch (SupabaseApiException $error) {
        error_log(
            'Admin recovery code exchange failed: HTTP '
            . $error->statusCode . ' ' . $error->getMessage()
        );
        $errorMessage = 'Password recovery is temporarily unavailable. Request a new link and try again.';
    } catch (Throwable $error) {
        $errorMessage = $error->getMessage();
    }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        verify_csrf($_POST['csrf_token'] ?? null);
        $newPassword = (string) ($_POST['new_password'] ?? '');
        $confirmPassword = (string) ($_POST['confirm_password'] ?? '');

        $validationError = admin_password_validation_error($newPassword);
        if ($validationError !== null) {
            throw new RuntimeException($validationError);
        }
        if (!hash_equals($newPassword, $confirmPassword)) {
            throw new RuntimeException('The password confirmation does not match.');
        }

        update_admin_recovery_password($newPassword);
        flash(
            'success',
            'Your Administrator password has been reset. Log in with your new password.'
        );
        redirect('admin_login.php');
    } catch (SupabaseApiException $error) {
        error_log(
            'Admin password update failed: HTTP '
            . $error->statusCode . ' ' . $error->getMessage()
        );
        $errorMessage = 'Password recovery is temporarily unavailable. Please try again later.';
    } catch (Throwable $error) {
        $errorMessage = $error->getMessage();
    }
}

try {
    $recoveryProfile = current_admin_recovery();
    $waitingForLink = false;
} catch (Throwable $error) {
    if ($errorMessage === null && !$waitingForLink) {
        $errorMessage = $error->getMessage();
    }
}

$recoveryReady = is_array($recoveryProfile);
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="referrer" content="no-referrer">
    <title>Reset Admin Password | MyFind</title>
    <link href="https://unpkg.com/boxicons@2.1.4/css/boxicons.min.css" rel="stylesheet">
    <link href="assets/html.css" rel="stylesheet">
</head>
<body class="login-page">
<div class="login-page-background" aria-hidden="true"></div>
<main class="admin-login-card">
    <section class="admin-login-welcome" aria-labelledby="welcome-title">
        <div class="admin-brand">
            <span class="admin-brand-mark"><i class='bx bx-map-alt'></i></span>
            <span>MyFind</span>
        </div>

        <div class="admin-welcome-copy">
            <span class="admin-welcome-label">Secure recovery</span>
            <h2 id="welcome-title">Set a New Password</h2>
            <p>Your recovery identity and Administrator role are verified before any password can be changed.</p>
        </div>

        <div class="admin-security-note">
            <i class='bx bx-lock-alt' aria-hidden="true"></i>
            <div>
                <strong>Short-lived access</strong>
                <span>The verified reset session expires after 15 minutes</span>
            </div>
        </div>
    </section>

    <section class="admin-login-panel" aria-labelledby="reset-title">
        <header class="admin-login-heading">
            <span class="admin-login-eyebrow">Administrator recovery</span>
            <h1 id="reset-title">
                <?= $recoveryReady ? 'Create New Password' : ($waitingForLink ? 'Check Your Email' : 'Reset Link Required') ?>
            </h1>
            <p>
                <?php if ($recoveryReady): ?>
                    Choose a strong password for <?= escape((string) ($recoveryProfile['email'] ?? 'your Administrator account')) ?>.
                <?php elseif ($waitingForLink): ?>
                    Open the reset link from your email in this browser to continue.
                <?php else: ?>
                    Request a new Administrator reset link before choosing a password.
                <?php endif; ?>
            </p>
        </header>

        <?php if ($errorMessage !== null): ?>
            <div class="alert alert-error login-alert" role="alert">
                <i class='bx bx-error-circle' aria-hidden="true"></i>
                <span><?= escape($errorMessage) ?></span>
            </div>
        <?php elseif ($waitingForLink): ?>
            <div class="alert alert-success login-alert" role="status">
                <i class='bx bx-envelope-open' aria-hidden="true"></i>
                <span>The reset link must be opened in the same browser that requested it.</span>
            </div>
        <?php endif; ?>

        <?php if ($recoveryReady): ?>
            <form method="post" action="admin_reset_password.php" class="admin-login-form">
                <input type="hidden" name="csrf_token" value="<?= escape(csrf_token()) ?>">

                <div class="admin-form-field">
                    <label for="new_password">New password</label>
                    <div class="admin-input-wrap">
                        <i class='bx bx-lock-alt' aria-hidden="true"></i>
                        <input
                            id="new_password"
                            name="new_password"
                            type="password"
                            placeholder="Enter a strong password"
                            autocomplete="new-password"
                            minlength="8"
                            maxlength="128"
                            required
                            autofocus
                        >
                        <button
                            type="button"
                            class="password-toggle"
                            aria-label="Show new password"
                            aria-pressed="false"
                            data-password-toggle="new_password"
                        >
                            <i class='bx bx-show' aria-hidden="true"></i>
                        </button>
                    </div>
                </div>

                <div class="admin-form-field">
                    <label for="confirm_password">Confirm new password</label>
                    <div class="admin-input-wrap">
                        <i class='bx bx-check-shield' aria-hidden="true"></i>
                        <input
                            id="confirm_password"
                            name="confirm_password"
                            type="password"
                            placeholder="Enter the password again"
                            autocomplete="new-password"
                            minlength="8"
                            maxlength="128"
                            required
                        >
                        <button
                            type="button"
                            class="password-toggle"
                            aria-label="Show confirmed password"
                            aria-pressed="false"
                            data-password-toggle="confirm_password"
                        >
                            <i class='bx bx-show' aria-hidden="true"></i>
                        </button>
                    </div>
                </div>

                <ul class="admin-password-rules" aria-label="Password requirements">
                    <li>8 to 128 characters</li>
                    <li>Uppercase and lowercase letters</li>
                    <li>At least one number and one special character</li>
                </ul>

                <button type="submit" class="button primary admin-login-submit">
                    <span>Update Password</span>
                    <i class='bx bx-check' aria-hidden="true"></i>
                </button>
            </form>
        <?php endif; ?>

        <div class="admin-auth-links">
            <?php if (!$recoveryReady): ?>
                <a href="admin_forgot_password.php" class="admin-text-link">
                    <i class='bx bx-refresh' aria-hidden="true"></i>
                    Request New Reset Link
                </a>
            <?php endif; ?>
            <a href="admin_login.php" class="admin-text-link secondary">
                <i class='bx bx-left-arrow-alt' aria-hidden="true"></i>
                Back to Administrator Login
            </a>
        </div>

        <p class="admin-login-help">
            <i class='bx bx-shield-quarter' aria-hidden="true"></i>
            Completing recovery closes the reset session and requests a global Supabase sign-out. Log in again using the new password.
        </p>
    </section>
</main>
<script>
    document.querySelectorAll('[data-password-toggle]').forEach((button) => {
        button.addEventListener('click', () => {
            const input = document.getElementById(button.dataset.passwordToggle);
            if (!input) return;

            const willShow = input.type === 'password';
            input.type = willShow ? 'text' : 'password';
            button.setAttribute('aria-label', willShow ? 'Hide password' : 'Show password');
            button.setAttribute('aria-pressed', String(willShow));
            button.querySelector('i')?.classList.toggle('bx-show', !willShow);
            button.querySelector('i')?.classList.toggle('bx-hide', willShow);
            input.focus();
        });
    });
</script>
</body>
</html>

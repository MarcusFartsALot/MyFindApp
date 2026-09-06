<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/admin_guard.php';
require_once __DIR__ . '/services/admin_password_recovery_service.php';

header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
header('Referrer-Policy: no-referrer');

try {
    current_admin();
    redirect('admin_dashboard.php');
} catch (Throwable) {
    // The recovery form is only needed when no valid Admin session exists.
}

$errorMessage = null;
$requestAccepted = false;
$emailValue = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $startedAtNanoseconds = hrtime(true);
    $validEmailWasSubmitted = false;
    try {
        verify_csrf($_POST['csrf_token'] ?? null);
        $emailValue = strtolower(trim((string) ($_POST['email'] ?? '')));
        if (strlen($emailValue) > 254
            || filter_var($emailValue, FILTER_VALIDATE_EMAIL) === false
        ) {
            throw new RuntimeException('Enter a valid email address.');
        }
        $validEmailWasSubmitted = true;

        try {
            request_admin_password_reset($emailValue);
            $requestAccepted = true;
        } catch (AdminRecoveryRequestError $error) {
            $errorMessage = $error->getMessage();
        } catch (Throwable $error) {
            // Do not expose raw database/provider errors or claim success.
            $status = $error instanceof SupabaseApiException
                ? ' HTTP ' . $error->statusCode
                : '';
            error_log('Admin password reset request failed.' . $status);
            $errorMessage = 'Password recovery is temporarily unavailable. Please try again later.';
        }
    } catch (Throwable $error) {
        $errorMessage = $error->getMessage();
    } finally {
        if ($validEmailWasSubmitted) {
            admin_recovery_wait_for_uniform_response($startedAtNanoseconds);
        }
    }
}
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="referrer" content="no-referrer">
    <title>Forgot Admin Password | MyFind</title>
    <link href="https://unpkg.com/boxicons@2.1.4/css/boxicons.min.css" rel="stylesheet">
    <link href="assets/html.css" rel="stylesheet">
    <link href="assets/auth-theme.css" rel="stylesheet">
</head>
<body class="login-page myfind-auth-page">
<div class="login-page-background" aria-hidden="true"></div>
<main class="admin-login-card">
    <section class="admin-login-welcome" aria-labelledby="welcome-title">
        <div class="admin-brand">
            <span class="admin-brand-mark"><i class='bx bx-map-alt'></i></span>
            <span>MyFind</span>
        </div>

        <div class="admin-welcome-copy">
            <span class="admin-welcome-label">Account recovery</span>
            <h2 id="welcome-title">Recover Access</h2>
            <p>Use your authorized administrator email to receive a secure password-reset link.</p>
        </div>

        <div class="admin-security-note">
            <i class='bx bx-shield-quarter' aria-hidden="true"></i>
            <div>
                <strong>Verified account recovery</strong>
                <span>Only registered administrators can request a link</span>
            </div>
        </div>
    </section>

    <section class="admin-login-panel" aria-labelledby="recovery-title">
        <header class="admin-login-heading">
            <span class="admin-login-eyebrow">Administrator recovery</span>
            <h1 id="recovery-title"><?= $requestAccepted ? 'Request Received' : 'Forgot Password?' ?></h1>
            <p>
                <?php if ($requestAccepted): ?>
                    Your Administrator account was verified and the email service accepted your reset request.
                <?php else: ?>
                    Enter your Administrator email and we will send instructions to reset your password.
                <?php endif; ?>
            </p>
        </header>

        <?php if ($errorMessage !== null): ?>
            <div class="alert alert-error login-alert" role="alert">
                <i class='bx bx-error-circle' aria-hidden="true"></i>
                <span><?= escape($errorMessage) ?></span>
            </div>
        <?php elseif ($requestAccepted): ?>
            <div class="alert alert-success login-alert" role="status">
                <i class='bx bx-mail-send' aria-hidden="true"></i>
                <span>Check your inbox and spam folder for your reset link. Email delivery can take a few minutes.</span>
            </div>
        <?php endif; ?>

        <?php if (!$requestAccepted): ?>
            <form method="post" action="admin_forgot_password.php" class="admin-login-form">
                <input type="hidden" name="csrf_token" value="<?= escape(csrf_token()) ?>">

                <div class="admin-form-field">
                    <label for="email">Administrator email</label>
                    <div class="admin-input-wrap">
                        <i class='bx bx-envelope' aria-hidden="true"></i>
                        <input
                            id="email"
                            name="email"
                            type="email"
                            value="<?= escape($emailValue) ?>"
                            placeholder="admin@example.com"
                            autocomplete="username"
                            maxlength="254"
                            required
                            autofocus
                        >
                    </div>
                </div>

                <button type="submit" class="button primary admin-login-submit">
                    <span>Send Reset Link</span>
                    <i class='bx bx-send' aria-hidden="true"></i>
                </button>
            </form>
        <?php endif; ?>

        <div class="admin-auth-links">
            <a href="admin_login.php" class="admin-text-link">
                <i class='bx bx-left-arrow-alt' aria-hidden="true"></i>
                Back to Administrator Login
            </a>
        </div>

        <p class="admin-login-help">
            <i class='bx bx-info-circle' aria-hidden="true"></i>
            Maximum 3 requests per email in 24 hours, at least 60 seconds apart. Use only the newest successfully sent link.
        </p>
    </section>
</main>
</body>
</html>

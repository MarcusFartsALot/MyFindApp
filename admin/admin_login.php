<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/admin_guard.php';

try {
    current_admin();
    redirect('admin_dashboard.php');
} catch (Throwable) {
    // Rendering the login page is expected when there is no valid session.
}

$errorMessage = null;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        verify_csrf($_POST['csrf_token'] ?? null);
        $email = filter_var(trim((string) ($_POST['email'] ?? '')), FILTER_VALIDATE_EMAIL);
        $password = (string) ($_POST['password'] ?? '');
        if (!is_string($email) || $password === '') {
            throw new RuntimeException('Enter a valid email and password.');
        }
        attempt_admin_login($email, $password);
        redirect('admin_dashboard.php');
    } catch (AdminAccessDenied $error) {
        $errorMessage = $error->getMessage();
    } catch (SupabaseApiException $error) {
        $errorMessage = in_array($error->statusCode, [400, 401], true)
            ? 'Incorrect email or password.'
            : 'Login is temporarily unavailable. Please try again.';
    } catch (Throwable $error) {
        $errorMessage = $error->getMessage();
    }
}
$sessionMessage = take_flash();
$showLogin = !($landingOnly ?? false) || $errorMessage !== null || $sessionMessage !== null;
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>About MyFind | Admin Portal</title>
    <link href="https://unpkg.com/boxicons@2.1.4/css/boxicons.min.css" rel="stylesheet">
    <link href="assets/html.css" rel="stylesheet">
    <link href="assets/about.css" rel="stylesheet">
    <link href="assets/auth-theme.css" rel="stylesheet">
</head>
<body class="about-page">
<?php require __DIR__ . '/includes/about_content.php'; ?>
<dialog class="login-dialog" aria-labelledby="login-title" <?= $showLogin ? 'data-start-open' : '' ?>>
<button class="dialog-close" type="button" aria-label="Close login">×</button>
<div class="admin-login-card">
    <section class="admin-login-welcome" aria-labelledby="welcome-title">
        <div class="admin-brand">
            <span class="admin-brand-mark"><i class='bx bx-map-alt'></i></span>
            <span>MyFind</span>
        </div>

        <div class="admin-welcome-copy">
            <span class="admin-welcome-label">Administration portal</span>
            <h2 id="welcome-title">Welcome Back</h2>
            <p>Manage applications and keep the MyFind community safe from one secure workspace.</p>
        </div>

        <div class="admin-security-note">
            <i class='bx bx-shield-quarter' aria-hidden="true"></i>
            <div>
                <strong>Protected access</strong>
                <span>Authorized administrators only</span>
            </div>
        </div>
    </section>

    <section class="admin-login-panel" aria-labelledby="login-title">
        <a href="index.php" class="admin-landing-back">
            <i class="bx bx-arrow-back" aria-hidden="true"></i> Back to home
        </a>
        <header class="admin-login-heading">
            <span class="admin-login-eyebrow">Secure sign in</span>
            <h1 id="login-title">Administrator Login</h1>
            <p>Enter your authorized administrator account details to continue.</p>
        </header>

        <?php if ($errorMessage !== null): ?>
            <div class="alert alert-error login-alert" role="alert">
                <i class='bx bx-error-circle' aria-hidden="true"></i>
                <span><?= escape($errorMessage) ?></span>
            </div>
        <?php elseif ($sessionMessage !== null): ?>
            <div class="alert alert-<?= escape($sessionMessage['type']) ?> login-alert" role="alert">
                <i class='bx bx-info-circle' aria-hidden="true"></i>
                <span><?= escape($sessionMessage['message']) ?></span>
            </div>
        <?php endif; ?>

        <form method="post" action="admin_login.php" class="admin-login-form">
            <input type="hidden" name="csrf_token" value="<?= escape(csrf_token()) ?>">

            <div class="admin-form-field">
                <label for="email">Email address</label>
                <div class="admin-input-wrap">
                    <i class='bx bx-envelope' aria-hidden="true"></i>
                    <input
                        id="email"
                        name="email"
                        type="email"
                        value="<?= escape((string) ($_POST['email'] ?? '')) ?>"
                        placeholder="admin@example.com"
                        autocomplete="username"
                        required
                        autofocus
                    >
                </div>
            </div>

            <div class="admin-form-field">
                <label for="password">Password</label>
                <div class="admin-input-wrap">
                    <i class='bx bx-lock-alt' aria-hidden="true"></i>
                    <input
                        id="password"
                        name="password"
                        type="password"
                        placeholder="Enter your password"
                        autocomplete="current-password"
                        required
                    >
                    <button
                        type="button"
                        class="password-toggle"
                        aria-label="Show password"
                        aria-pressed="false"
                        data-password-toggle
                    >
                        <i class='bx bx-hide' aria-hidden="true"></i>
                    </button>
                </div>
            </div>

            <div class="admin-login-actions">
                <a href="admin_forgot_password.php" class="admin-forgot-link">
                    Forgot password?
                </a>

                <button type="submit" class="button primary admin-login-submit">
                    <span>Log In</span>
                    <i class='bx bx-right-arrow-alt' aria-hidden="true"></i>
                </button>
            </div>
        </form>

        <p class="admin-login-help">
            <i class='bx bx-lock' aria-hidden="true"></i>
            Your session is protected and restricted to approved administrator profiles.
        </p>
    </section>
</div>
</dialog>
<script>
    // Reveal sections once; all content stays visible if JavaScript is off.
    if ('IntersectionObserver' in window && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
        const reveal = new IntersectionObserver(entries => entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('is-visible');
                reveal.unobserve(entry.target);
            }
        }), { threshold: 0.08 });
        document.querySelectorAll('.about-section').forEach(section => {
            section.classList.add('reveal-section');
            reveal.observe(section);
        });
    }
    const dialog = document.querySelector('.login-dialog');
    let loginTrigger;
    function openLogin(trigger) {
        loginTrigger = trigger;
        dialog.showModal();
        document.body.classList.add('login-open');
    }
    document.querySelectorAll('[data-open-login]').forEach(link => link.addEventListener('click', event => {
        if (!dialog.showModal) return;
        event.preventDefault();
        openLogin(link);
    }));
    document.querySelector('.dialog-close').addEventListener('click', () => dialog.close());
    dialog.addEventListener('click', event => { if (event.target === dialog) dialog.close(); });
    dialog.addEventListener('close', () => {
        document.body.classList.remove('login-open');
        (loginTrigger || document.querySelector('[data-open-login]')).focus();
    });
    if (dialog.hasAttribute('data-start-open')) openLogin();
    const passwordToggle = document.querySelector('[data-password-toggle]');
    const passwordInput = document.getElementById('password');

    passwordToggle?.addEventListener('click', () => {
        const willShow = passwordInput.type === 'password';
        passwordInput.type = willShow ? 'text' : 'password';
        passwordToggle.setAttribute('aria-label', willShow ? 'Hide password' : 'Show password');
        passwordToggle.setAttribute('aria-pressed', String(willShow));
        passwordToggle.querySelector('i')?.classList.toggle('bx-show', willShow);
        passwordToggle.querySelector('i')?.classList.toggle('bx-hide', !willShow);
        passwordInput.focus();
    });
</script>
</body>
</html>

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
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Admin Login | MyFind</title>
    <link href="https://unpkg.com/boxicons@2.1.4/css/boxicons.min.css" rel="stylesheet">
    <link href="assets/html.css" rel="stylesheet">
</head>
<body class="login-page">
<main class="login-card">
    <i class='bx bx-shield-quarter login-icon'></i>
    <h1>Administrator Login</h1>
    <p>Sign in with your authorized Supabase administrator account.</p>
    <?php if ($errorMessage !== null): ?>
        <div class="alert alert-error" role="alert"><?= escape($errorMessage) ?></div>
    <?php elseif ($sessionMessage !== null): ?>
        <div class="alert alert-<?= escape($sessionMessage['type']) ?>" role="alert">
            <?= escape($sessionMessage['message']) ?>
        </div>
    <?php endif; ?>
    <form method="post" action="admin_login.php" class="stacked-form">
        <input type="hidden" name="csrf_token" value="<?= escape(csrf_token()) ?>">
        <label for="email">Email</label>
        <input id="email" name="email" type="email" autocomplete="username" required>
        <label for="password">Password</label>
        <input id="password" name="password" type="password" autocomplete="current-password" required>
        <button type="submit" class="button primary">Login</button>
    </form>
</main>
</body>
</html>

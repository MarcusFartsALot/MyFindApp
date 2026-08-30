<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/config/env.php';

if (session_status() !== PHP_SESSION_ACTIVE) {
    $secure = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off');
    session_name(Env::get('SESSION_NAME', 'myfind_admin') ?? 'myfind_admin');
    $configuredSessionPath = trim(Env::get('SESSION_SAVE_PATH', '') ?? '');
    $sessionPath = $configuredSessionPath !== ''
        ? $configuredSessionPath
        : sys_get_temp_dir();
    if (!is_dir($sessionPath) || !is_writable($sessionPath)) {
        throw new RuntimeException(
            'The PHP session directory does not exist or is not writable.'
        );
    }
    session_save_path($sessionPath);
    // Supabase recovery codes can remain valid for one hour. Keep the PHP
    // session that owns the PKCE verifier for longer than that, even on PHP
    // installations whose default garbage-collection lifetime is 24 minutes.
    $sessionGcLifetime = max(
        7200,
        (int) ini_get('session.gc_maxlifetime')
    );
    ini_set('session.gc_maxlifetime', (string) $sessionGcLifetime);
    session_set_cookie_params([
        'lifetime' => 0,
        'path' => '/',
        'secure' => $secure,
        'httponly' => true,
        // Lax allows Supabase's top-level recovery redirect to carry the PHP
        // session that contains the PKCE verifier. Cross-site POST requests
        // still do not receive this cookie and every form is CSRF protected.
        'samesite' => 'Lax',
    ]);
    ini_set('session.use_strict_mode', '1');
    session_start();
}

function escape(?string $value): string
{
    return htmlspecialchars($value ?? '', ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function redirect(string $location): never
{
    header('Location: ' . $location, true, 302);
    exit;
}

function csrf_token(): string
{
    if (!isset($_SESSION['csrf_token'])
        || !is_string($_SESSION['csrf_token'])
        || preg_match('/^[a-f0-9]{64}$/', $_SESSION['csrf_token']) !== 1
    ) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

function verify_csrf(?string $token): void
{
    $expected = $_SESSION['csrf_token'] ?? null;
    $isValidToken = is_string($token)
        && preg_match('/^[a-f0-9]{64}$/', $token) === 1;
    $isValidExpected = is_string($expected)
        && preg_match('/^[a-f0-9]{64}$/', $expected) === 1;

    if (!$isValidToken || !$isValidExpected || !hash_equals($expected, $token)) {
        throw new RuntimeException('The form expired. Refresh the page and try again.');
    }
}

function flash(string $type, string $message): void
{
    $_SESSION['flash'] = ['type' => $type, 'message' => $message];
}

/** @return array{type:string,message:string}|null */
function take_flash(): ?array
{
    $value = $_SESSION['flash'] ?? null;
    unset($_SESSION['flash']);
    return is_array($value) ? $value : null;
}

function valid_uuid(?string $value): bool
{
    return is_string($value)
        && preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i', $value) === 1;
}

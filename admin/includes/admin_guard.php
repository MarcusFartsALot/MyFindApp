<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';
require_once dirname(__DIR__) . '/config/supabase.php';

final class AdminAccessDenied extends RuntimeException
{
}

/** @return array<string, mixed> */
function attempt_admin_login(string $email, string $password): array
{
    $client = new SupabaseClient();
    $auth = $client->anonymous(
        'POST',
        '/auth/v1/token?grant_type=password',
        ['email' => strtolower(trim($email)), 'password' => $password]
    );

    $accessToken = $auth['access_token'] ?? null;
    $refreshToken = $auth['refresh_token'] ?? null;
    $userId = $auth['user']['id'] ?? null;
    if (!is_string($accessToken) || !is_string($refreshToken) || !is_string($userId)) {
        throw new RuntimeException('Supabase did not return a valid session.');
    }

    // Authentication has already succeeded. Use the trusted server client for
    // this authorization lookup so a missing user-facing RLS policy cannot
    // hide an otherwise valid Admin profile.
    $rows = $client->asService(
        'GET',
        '/rest/v1/profiles?select=*&auth_id=eq.' . rawurlencode($userId) . '&limit=1'
    );
    $profile = $rows[0] ?? null;
    if (!is_array($profile) || ($profile['role'] ?? null) !== 'admin') {
        try {
            $client->asUser('POST', '/auth/v1/logout', $accessToken);
        } catch (Throwable) {
            // The local session is still cleared below.
        }
        clear_admin_session();
        if (!is_array($profile)) {
            throw new AdminAccessDenied(
                'This Auth account is not linked to an Administrator profile.'
            );
        }
        throw new AdminAccessDenied('Access denied. Administrator account required.');
    }

    session_regenerate_id(true);
    $_SESSION['access_token'] = $accessToken;
    $_SESSION['refresh_token'] = $refreshToken;
    $_SESSION['admin_profile'] = $profile;
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    return $profile;
}

/** @return array<string, mixed> */
function current_admin(): array
{
    $accessToken = $_SESSION['access_token'] ?? null;
    $refreshToken = $_SESSION['refresh_token'] ?? null;
    if (!is_string($accessToken) || !is_string($refreshToken)) {
        throw new AdminAccessDenied('Administrator login required.');
    }

    $client = new SupabaseClient();
    try {
        $user = $client->asUser('GET', '/auth/v1/user', $accessToken);
    } catch (SupabaseApiException $error) {
        if ($error->statusCode !== 401) {
            throw $error;
        }
        $refreshed = $client->anonymous(
            'POST',
            '/auth/v1/token?grant_type=refresh_token',
            ['refresh_token' => $refreshToken]
        );
        $accessToken = $refreshed['access_token'] ?? null;
        $newRefreshToken = $refreshed['refresh_token'] ?? null;
        if (!is_string($accessToken) || !is_string($newRefreshToken)) {
            clear_admin_session();
            throw new AdminAccessDenied('Administrator session expired.');
        }
        $_SESSION['access_token'] = $accessToken;
        $_SESSION['refresh_token'] = $newRefreshToken;
        $user = $client->asUser('GET', '/auth/v1/user', $accessToken);
    }

    $userId = $user['id'] ?? null;
    if (!is_string($userId)) {
        clear_admin_session();
        throw new AdminAccessDenied('Administrator session is invalid.');
    }
    $rows = $client->asService(
        'GET',
        '/rest/v1/profiles?select=*&auth_id=eq.' . rawurlencode($userId) . '&limit=1'
    );
    $profile = $rows[0] ?? null;
    if (!is_array($profile)) {
        clear_admin_session();
        throw new AdminAccessDenied(
            'This Auth account is not linked to an Administrator profile.'
        );
    }
    if (($profile['role'] ?? null) !== 'admin') {
        clear_admin_session();
        throw new AdminAccessDenied('Access denied. Administrator account required.');
    }

    $_SESSION['admin_profile'] = $profile;
    return $profile;
}

/** @return array<string, mixed> */
function require_admin(bool $apiEndpoint = false): array
{
    try {
        return current_admin();
    } catch (Throwable $error) {
        clear_admin_session();
        if ($apiEndpoint) {
            http_response_code(403);
            header('Content-Type: text/plain; charset=utf-8');
            exit('Access denied. Administrator account required.');
        }
        flash('error', $error instanceof AdminAccessDenied
            ? $error->getMessage()
            : 'Your administrator session could not be validated.');
        redirect('admin_login.php');
    }
}

function clear_admin_session(): void
{
    $_SESSION = [];
    if (ini_get('session.use_cookies')) {
        $params = session_get_cookie_params();
        setcookie(session_name(), '', [
            'expires' => time() - 42000,
            'path' => $params['path'],
            'domain' => $params['domain'],
            'secure' => $params['secure'],
            'httponly' => $params['httponly'],
            'samesite' => $params['samesite'] ?? 'Lax',
        ]);
    }
    session_regenerate_id(true);
}

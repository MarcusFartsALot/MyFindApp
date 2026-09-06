<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/includes/bootstrap.php';
require_once dirname(__DIR__) . '/config/supabase.php';

const ADMIN_RECOVERY_SESSION_LIFETIME = 900;
const ADMIN_RECOVERY_CODE_LIFETIME = 3600;
const ADMIN_RECOVERY_EMAIL_LIMIT = 3;
const ADMIN_RECOVERY_EMAIL_WINDOW = 86400;
const ADMIN_RECOVERY_IP_LIMIT = 20;
const ADMIN_RECOVERY_IP_WINDOW = 3600;
const ADMIN_RECOVERY_REQUEST_COOLDOWN = 60;
const ADMIN_RECOVERY_MINIMUM_RESPONSE_MS = 800;

// Only these deliberately user-facing errors may be displayed by the form.
final class AdminRecoveryRequestError extends RuntimeException {}

/** @param array<string, mixed>|null $profile */
function admin_recovery_registered_auth_id(?array $profile): string
{
    if ($profile === null) {
        throw new AdminRecoveryRequestError('Email not registered in system.');
    }
    if (($profile['role'] ?? null) !== 'admin') {
        throw new AdminRecoveryRequestError(
            'This email is not an Administrator account. Use Forgot password in the MyFind app.'
        );
    }
    $authId = $profile['auth_id'] ?? null;
    if (!is_string($authId) || !valid_uuid($authId)) {
        throw new AdminRecoveryRequestError(
            'This registration is not linked to an active login account. Please contact support.'
        );
    }
    return $authId;
}

function admin_recovery_base64url(string $value): string
{
    return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
}

function admin_password_reset_redirect_url(): string
{
    $configured = trim(Env::get('ADMIN_PASSWORD_RESET_URL', '') ?? '');
    if ($configured !== '') {
        $parts = parse_url($configured);
        $scheme = strtolower((string) ($parts['scheme'] ?? ''));
        $host = strtolower((string) ($parts['host'] ?? ''));
        $isLocal = in_array($host, ['localhost', '127.0.0.1', '::1'], true);

        if (!filter_var($configured, FILTER_VALIDATE_URL)
            || !in_array($scheme, ['http', 'https'], true)
            || ($scheme !== 'https' && !$isLocal)
            || isset($parts['query'])
            || isset($parts['fragment'])
        ) {
            throw new RuntimeException(
                'ADMIN_PASSWORD_RESET_URL must be an HTTPS URL, or an HTTP localhost URL, without a query or fragment.'
            );
        }

        return $configured;
    }

    // Local development convenience. Production must use the configured URL
    // so an untrusted Host header can never control a password-reset email.
    $host = strtolower((string) ($_SERVER['HTTP_HOST'] ?? ''));
    if (preg_match('/^(?:localhost|127\.0\.0\.1)(?::[0-9]{1,5})?$/', $host) !== 1) {
        throw new RuntimeException(
            'Set ADMIN_PASSWORD_RESET_URL in the project-root .admin.env file before using password recovery.'
        );
    }

    $scriptName = str_replace('\\', '/', (string) ($_SERVER['SCRIPT_NAME'] ?? ''));
    $directory = rtrim(dirname($scriptName), '/.');
    return 'http://' . $host . ($directory === '' ? '' : $directory)
        . '/admin_reset_password.php';
}

function request_admin_password_reset(string $email): void
{
    $normalizedEmail = strtolower(trim($email));
    if (strlen($normalizedEmail) > 254
        || filter_var($normalizedEmail, FILTER_VALIDATE_EMAIL) === false
    ) {
        throw new AdminRecoveryRequestError('Enter a valid email address.');
    }

    // Keep abuse limits on both registered and unknown email lookups. Keys are
    // HMACs; the rate-limit store never contains emails or IPs in plain text.
    if (!admin_recovery_request_allowed($normalizedEmail)) {
        throw new AdminRecoveryRequestError(
            'Reset request limit reached. Wait at least 60 seconds between requests. '
            . 'A maximum of 3 requests per email is allowed in 24 hours.'
        );
    }

    $client = new SupabaseClient();
    $profile = admin_recovery_profile_by_email($client, $normalizedEmail);

    // Explicit account feedback is intentional. Never send for a missing,
    // non-Administrator or unlinked profile.
    $authId = admin_recovery_registered_auth_id($profile);

    try {
        $authUser = $client->asService(
            'GET',
            '/auth/v1/admin/users/' . rawurlencode($authId)
        );
    } catch (Throwable $error) {
        throw new RuntimeException(
            'Password recovery is temporarily unavailable. Please try again later.',
            0,
            $error
        );
    }
    $authEmail = strtolower(trim((string) ($authUser['email'] ?? '')));
    if ($authEmail === '' || !hash_equals($normalizedEmail, $authEmail)) {
        throw new AdminRecoveryRequestError(
            'The registered email does not match its login account. Please contact support.'
        );
    }

    $redirectUrl = admin_password_reset_redirect_url();
    $codeVerifier = admin_recovery_base64url(random_bytes(64));
    $codeChallenge = admin_recovery_base64url(
        hash('sha256', $codeVerifier, true)
    );
    try {
        $client->anonymous(
            'POST',
            '/auth/v1/recover?redirect_to=' . rawurlencode($redirectUrl),
            [
                'email' => $normalizedEmail,
                'code_challenge' => $codeChallenge,
                'code_challenge_method' => 's256',
            ]
        );
    } catch (SupabaseApiException $error) {
        $message = strtolower($error->getMessage() . ' ' . $error->responseBody);
        if ($error->statusCode === 429) {
            error_log('Admin password recovery was rate limited by Supabase.');
            throw new AdminRecoveryRequestError(
                'The email service is temporarily rate limited. No new reset link was sent. Please try again later.'
            );
        }
        if ($error->statusCode === 400 && str_contains($message, 'redirect')) {
            throw new RuntimeException(
                'Admin password recovery is not configured correctly. Add the reset URL to Supabase Auth Redirect URLs.'
            );
        }
        throw $error;
    } catch (Throwable $error) {
        throw new RuntimeException(
            'Password recovery is temporarily unavailable. Please try again later.',
            0,
            $error
        );
    }

    // Replace the pending verifier only after Supabase accepts the email
    // request. A failed or rate-limited resend must not invalidate the last
    // link that was sent successfully.
    $_SESSION['admin_recovery_code_verifier'] = $codeVerifier;
    $_SESSION['admin_recovery_request_at'] = time();
}

function admin_recovery_wait_for_uniform_response(int $startedAtNanoseconds): void
{
    $targetMilliseconds = ADMIN_RECOVERY_MINIMUM_RESPONSE_MS + random_int(0, 150);
    $elapsedMilliseconds = (int) ((hrtime(true) - $startedAtNanoseconds) / 1_000_000);
    $remainingMilliseconds = $targetMilliseconds - $elapsedMilliseconds;
    if ($remainingMilliseconds > 0) {
        usleep($remainingMilliseconds * 1000);
    }
}

function admin_recovery_request_allowed(string $normalizedEmail): bool
{
    try {
        return admin_recovery_shared_rate_limit_allows($normalizedEmail);
    } catch (Throwable $error) {
        // Supabase still applies its own Auth email limits. A session fallback
        // avoids disabling recovery when a local temp directory is read-only.
        error_log('Shared Admin recovery rate limiter unavailable; using session fallback.');
        return admin_recovery_session_rate_limit_allows($normalizedEmail);
    }
}

function admin_recovery_rate_limit_secret(): string
{
    $configured = trim(Env::get('ADMIN_RECOVERY_RATE_LIMIT_SECRET', '') ?? '');
    return $configured !== ''
        ? $configured
        : Env::required('SUPABASE_SERVICE_ROLE_KEY');
}

function admin_recovery_client_ip(): string
{
    $candidate = trim((string) ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
    return filter_var($candidate, FILTER_VALIDATE_IP) !== false
        ? $candidate
        : 'unknown';
}

/** @param list<int> $timestamps @return list<int> */
function admin_recovery_recent_timestamps(
    array $timestamps,
    int $earliestAllowed
): array {
    return array_values(array_filter(
        $timestamps,
        static fn (mixed $timestamp): bool => is_int($timestamp)
            && $timestamp >= $earliestAllowed
    ));
}

/** @param list<int> $emailTimes @param list<int> $ipTimes */
function admin_recovery_rate_limit_decision(
    array $emailTimes,
    array $ipTimes,
    int $now
): bool {
    $emailTimes = admin_recovery_recent_timestamps(
        $emailTimes,
        $now - ADMIN_RECOVERY_EMAIL_WINDOW
    );
    $ipTimes = admin_recovery_recent_timestamps(
        $ipTimes,
        $now - ADMIN_RECOVERY_IP_WINDOW
    );

    $lastEmailRequest = $emailTimes === [] ? null : max($emailTimes);
    return count($emailTimes) < ADMIN_RECOVERY_EMAIL_LIMIT
        && count($ipTimes) < ADMIN_RECOVERY_IP_LIMIT
        && ($lastEmailRequest === null
            || $now - $lastEmailRequest >= ADMIN_RECOVERY_REQUEST_COOLDOWN);
}

function admin_recovery_shared_rate_limit_allows(string $normalizedEmail): bool
{
    $configuredPath = trim(Env::get('ADMIN_RECOVERY_RATE_LIMIT_FILE', '') ?? '');
    $storageDirectory = session_save_path() !== ''
        ? session_save_path()
        : sys_get_temp_dir();
    $path = $configuredPath !== ''
        ? $configuredPath
        : rtrim($storageDirectory, '\\/') . DIRECTORY_SEPARATOR
            . 'myfind_admin_recovery_rate_limits.json';
    $handle = @fopen($path, 'c+');
    if ($handle === false) {
        throw new RuntimeException('Could not open the recovery rate-limit store.');
    }

    try {
        if (!flock($handle, LOCK_EX)) {
            throw new RuntimeException('Could not lock the recovery rate-limit store.');
        }

        rewind($handle);
        $contents = stream_get_contents($handle);
        $decoded = is_string($contents) && $contents !== ''
            ? json_decode($contents, true)
            : [];
        $records = is_array($decoded) ? $decoded : [];

        $secret = admin_recovery_rate_limit_secret();
        $emailKey = 'email:' . hash_hmac('sha256', $normalizedEmail, $secret);
        $ipKey = 'ip:' . hash_hmac('sha256', admin_recovery_client_ip(), $secret);
        $now = time();

        // Prune all expired values while the file is locked so it cannot grow
        // indefinitely. The longest configured window is one day.
        foreach ($records as $key => $timestamps) {
            if (!is_string($key) || !is_array($timestamps)) {
                unset($records[$key]);
                continue;
            }
            $recent = admin_recovery_recent_timestamps(
                $timestamps,
                $now - ADMIN_RECOVERY_EMAIL_WINDOW
            );
            if ($recent === []) {
                unset($records[$key]);
            } else {
                $records[$key] = $recent;
            }
        }

        $emailTimes = is_array($records[$emailKey] ?? null)
            ? $records[$emailKey]
            : [];
        $ipTimes = is_array($records[$ipKey] ?? null)
            ? $records[$ipKey]
            : [];
        $allowed = admin_recovery_rate_limit_decision(
            $emailTimes,
            $ipTimes,
            $now
        );

        if ($allowed) {
            $emailTimes[] = $now;
            $ipTimes[] = $now;
            $records[$emailKey] = $emailTimes;
            $records[$ipKey] = $ipTimes;
        }

        $json = json_encode($records, JSON_THROW_ON_ERROR);
        rewind($handle);
        if (!ftruncate($handle, 0) || fwrite($handle, $json) === false) {
            throw new RuntimeException('Could not update the recovery rate-limit store.');
        }
        fflush($handle);
        return $allowed;
    } finally {
        flock($handle, LOCK_UN);
        fclose($handle);
    }
}

function admin_recovery_session_rate_limit_allows(string $normalizedEmail): bool
{
    $secret = admin_recovery_rate_limit_secret();
    $emailKey = hash_hmac('sha256', $normalizedEmail, $secret);
    $now = time();
    $records = $_SESSION['admin_recovery_rate_limit'] ?? [];
    $records = is_array($records) ? $records : [];
    $emailTimes = is_array($records[$emailKey] ?? null)
        ? $records[$emailKey]
        : [];
    $ipTimes = is_array($records['ip'] ?? null) ? $records['ip'] : [];
    $emailTimes = admin_recovery_recent_timestamps(
        $emailTimes,
        $now - ADMIN_RECOVERY_EMAIL_WINDOW
    );
    $ipTimes = admin_recovery_recent_timestamps(
        $ipTimes,
        $now - ADMIN_RECOVERY_IP_WINDOW
    );
    $allowed = admin_recovery_rate_limit_decision($emailTimes, $ipTimes, $now);
    if ($allowed) {
        $emailTimes[] = $now;
        $ipTimes[] = $now;
    }
    $records[$emailKey] = $emailTimes;
    $records['ip'] = $ipTimes;
    $_SESSION['admin_recovery_rate_limit'] = $records;
    return $allowed;
}

/** @return array<string, mixed>|null */
function admin_recovery_profile_by_email(
    SupabaseClient $client,
    string $normalizedEmail
): ?array {
    try {
        $rows = $client->asService(
            'GET',
            '/rest/v1/profiles?select=id,auth_id,role,email'
            . '&email=eq.' . rawurlencode($normalizedEmail)
            . '&role=eq.admin&limit=1'
        );
    } catch (Throwable $error) {
        throw new RuntimeException(
            'Password recovery is temporarily unavailable. Please try again later.',
            0,
            $error
        );
    }

    $profile = $rows[0] ?? null;
    return is_array($profile) ? $profile : null;
}

/** @return array<string, mixed>|null */
function admin_recovery_profile_by_auth_id(
    SupabaseClient $client,
    string $authUserId
): ?array {
    try {
        $rows = $client->asService(
            'GET',
            '/rest/v1/profiles?select=id,auth_id,role,email'
            . '&auth_id=eq.' . rawurlencode($authUserId)
            . '&role=eq.admin&limit=1'
        );
    } catch (Throwable $error) {
        throw new RuntimeException(
            'Administrator verification is temporarily unavailable. Please try again later.',
            0,
            $error
        );
    }

    $profile = $rows[0] ?? null;
    return is_array($profile) ? $profile : null;
}

/** @return array<string, mixed> */
function exchange_admin_recovery_code(string $authCode): array
{
    $authCode = trim($authCode);
    $codeVerifier = $_SESSION['admin_recovery_code_verifier'] ?? null;
    $requestedAt = $_SESSION['admin_recovery_request_at'] ?? null;

    if ($authCode === ''
        || strlen($authCode) > 2048
        || !is_string($codeVerifier)
        || $codeVerifier === ''
        || !is_int($requestedAt)
        || time() - $requestedAt > ADMIN_RECOVERY_CODE_LIFETIME
    ) {
        clear_pending_admin_recovery_request();
        throw new RuntimeException(
            'This password-reset link is invalid, expired, or was opened in a different browser.'
        );
    }

    $client = new SupabaseClient();
    try {
        $auth = $client->anonymous(
            'POST',
            '/auth/v1/token?grant_type=pkce',
            ['auth_code' => $authCode, 'code_verifier' => $codeVerifier]
        );
    } catch (SupabaseApiException $error) {
        clear_pending_admin_recovery_request();
        throw new RuntimeException(
            'This password-reset link is invalid or has expired. Request a new link.',
            0,
            $error
        );
    } catch (Throwable $error) {
        clear_pending_admin_recovery_request();
        throw new RuntimeException(
            'Password recovery is temporarily unavailable. Please try again later.',
            0,
            $error
        );
    }

    clear_pending_admin_recovery_request();
    $accessToken = $auth['access_token'] ?? null;
    if (!is_string($accessToken) || $accessToken === '') {
        throw new RuntimeException('Supabase did not return a valid recovery session.');
    }

    return establish_admin_recovery_session($accessToken);
}

/** @return array<string, mixed> */
function establish_admin_recovery_session(string $accessToken): array
{
    $accessToken = trim($accessToken);
    if ($accessToken === '' || strlen($accessToken) > 8192) {
        throw new RuntimeException('This password-reset link is invalid or has expired.');
    }

    $client = new SupabaseClient();
    try {
        $user = $client->asUser('GET', '/auth/v1/user', $accessToken);
    } catch (Throwable $error) {
        throw new RuntimeException(
            'This password-reset link is invalid or has expired.',
            0,
            $error
        );
    }

    $userId = $user['id'] ?? null;
    if (!valid_uuid(is_string($userId) ? $userId : null)) {
        throw new RuntimeException('This password-reset link is invalid or has expired.');
    }

    $profile = admin_recovery_profile_by_auth_id($client, $userId);
    if (!is_array($profile)) {
        try {
            $client->asUser('POST', '/auth/v1/logout?scope=local', $accessToken);
        } catch (Throwable) {
            // The recovery token is still never copied into an Admin session.
        }
        clear_active_admin_recovery_session();
        throw new RuntimeException(
            'This reset link is not associated with an Administrator account.'
        );
    }

    session_regenerate_id(true);
    $_SESSION['admin_recovery_access_token'] = $accessToken;
    $_SESSION['admin_recovery_user_id'] = $userId;
    $_SESSION['admin_recovery_started_at'] = time();
    $_SESSION['admin_recovery_profile'] = $profile;
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));

    return $profile;
}

/** @return array<string, mixed> */
function current_admin_recovery(): array
{
    $accessToken = $_SESSION['admin_recovery_access_token'] ?? null;
    $expectedUserId = $_SESSION['admin_recovery_user_id'] ?? null;
    $startedAt = $_SESSION['admin_recovery_started_at'] ?? null;

    if (!is_string($accessToken)
        || !valid_uuid(is_string($expectedUserId) ? $expectedUserId : null)
        || !is_int($startedAt)
        || time() - $startedAt > ADMIN_RECOVERY_SESSION_LIFETIME
    ) {
        clear_active_admin_recovery_session();
        throw new RuntimeException('This password-reset session is invalid or has expired.');
    }

    $client = new SupabaseClient();
    try {
        $user = $client->asUser('GET', '/auth/v1/user', $accessToken);
    } catch (Throwable $error) {
        clear_active_admin_recovery_session();
        throw new RuntimeException(
            'This password-reset session is invalid or has expired.',
            0,
            $error
        );
    }

    $userId = $user['id'] ?? null;
    if (!is_string($userId) || !hash_equals($expectedUserId, $userId)) {
        clear_active_admin_recovery_session();
        throw new RuntimeException('This password-reset session is invalid or has expired.');
    }

    $profile = admin_recovery_profile_by_auth_id($client, $userId);
    if (!is_array($profile)) {
        clear_active_admin_recovery_session();
        throw new RuntimeException('Administrator access is no longer available for this account.');
    }

    $_SESSION['admin_recovery_profile'] = $profile;
    return $profile;
}

function admin_password_validation_error(string $password): ?string
{
    $characterCount = mb_strlen($password, 'UTF-8');
    if ($characterCount < 8) {
        return 'Password must be at least 8 characters.';
    }
    if ($characterCount > 128) {
        return 'Password must be no more than 128 characters.';
    }
    if (preg_match('/[A-Z]/', $password) !== 1) {
        return 'Password must include an uppercase letter.';
    }
    if (preg_match('/[a-z]/', $password) !== 1) {
        return 'Password must include a lowercase letter.';
    }
    if (preg_match('/[0-9]/', $password) !== 1) {
        return 'Password must include a number.';
    }
    if (preg_match('/[^A-Za-z0-9]/', $password) !== 1) {
        return 'Password must include a special character.';
    }
    return null;
}

function update_admin_recovery_password(string $newPassword): void
{
    current_admin_recovery();
    $accessToken = (string) $_SESSION['admin_recovery_access_token'];

    $client = new SupabaseClient();
    try {
        $client->asUser(
            'PUT',
            '/auth/v1/user',
            $accessToken,
            ['password' => $newPassword]
        );

        try {
            // A recovered password should end all existing Administrator
            // sessions. The user signs in again with the new credential.
            $client->asUser('POST', '/auth/v1/logout?scope=global', $accessToken);
        } catch (Throwable) {
            // The password update succeeded; local recovery state is still removed.
        }
    } catch (SupabaseApiException $error) {
        if (in_array($error->statusCode, [400, 401, 403, 422], true)) {
            throw new RuntimeException(
                'The password could not be updated. Request a new reset link and try again.',
                0,
                $error
            );
        }
        throw $error;
    } catch (Throwable $error) {
        throw new RuntimeException(
            'Password recovery is temporarily unavailable. Please try again later.',
            0,
            $error
        );
    }

    clear_admin_recovery_session();
    session_regenerate_id(true);
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

function clear_admin_recovery_session(): void
{
    clear_active_admin_recovery_session();
    clear_pending_admin_recovery_request();
}

function clear_active_admin_recovery_session(): void
{
    unset(
        $_SESSION['admin_recovery_access_token'],
        $_SESSION['admin_recovery_user_id'],
        $_SESSION['admin_recovery_started_at'],
        $_SESSION['admin_recovery_profile']
    );
}

function clear_pending_admin_recovery_request(): void
{
    unset(
        $_SESSION['admin_recovery_code_verifier'],
        $_SESSION['admin_recovery_request_at']
    );
}

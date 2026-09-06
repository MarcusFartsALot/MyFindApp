<?php
declare(strict_types=1);

// Read-only CLI check: never sends recovery email or changes user records.
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once dirname(__DIR__) . '/config/env.php';
require_once dirname(__DIR__) . '/config/supabase.php';

function diagnostic_error(Throwable $error): array
{
    while ($error->getPrevious() !== null) $error = $error->getPrevious();
    $message = $error->getMessage();
    foreach (['SUPABASE_ANON_KEY', 'SUPABASE_SERVICE_ROLE_KEY'] as $key) {
        $secret = Env::get($key, '') ?? '';
        if ($secret !== '') $message = str_replace($secret, '[redacted]', $message);
    }
    $message = preg_replace('/[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}/i', '[email]', $message);
    return ['type' => get_class($error), 'status' => $error instanceof SupabaseApiException ? $error->statusCode : null, 'reason' => substr($message, 0, 300)];
}

$checks = ['configuration' => []];
foreach (['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'SUPABASE_SERVICE_ROLE_KEY', 'ADMIN_PASSWORD_RESET_URL'] as $key) {
    $checks['configuration'][$key . '_present'] = trim(Env::get($key, '') ?? '') !== '';
}
$checks['configuration']['default_admin_env_exists'] = is_file(dirname(__DIR__) . '/.env');
$checks['configuration']['root_admin_env_exists'] = is_file(dirname(__DIR__, 2) . '/.admin.env');
$checks['configuration']['curl_available'] = function_exists('curl_init');
$checks['configuration']['openssl_available'] = extension_loaded('openssl');

try {
    $client = new SupabaseClient();
    $profiles = $client->asService('GET', '/rest/v1/profiles?select=id,auth_id,role,email&role=eq.admin&limit=5');
    $checks['admin_profile_lookup'] = ['ok' => true, 'count_up_to_5' => count($profiles)];
    foreach ($profiles as $index => $profile) {
        $authId = $profile['auth_id'] ?? null;
        $result = ['linked' => is_string($authId) && $authId !== ''];
        if ($result['linked']) {
            try {
                $user = $client->asService('GET', '/auth/v1/admin/users/' . rawurlencode($authId));
                $result['auth_lookup_ok'] = true;
                $result['email_matches'] = strtolower(trim((string) ($user['email'] ?? ''))) === strtolower(trim((string) ($profile['email'] ?? '')));
            } catch (Throwable $error) {
                $result['auth_lookup_error'] = diagnostic_error($error);
            }
        }
        $checks['admin_accounts'][] = $result;
    }
} catch (Throwable $error) {
    $checks['admin_profile_lookup'] = ['ok' => false, 'error' => diagnostic_error($error)];
}
echo json_encode($checks, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL;

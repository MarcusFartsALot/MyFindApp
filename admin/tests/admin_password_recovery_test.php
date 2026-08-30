<?php
declare(strict_types=1);

session_save_path(sys_get_temp_dir());
session_id('myfindrecoverytest' . bin2hex(random_bytes(8)));
require_once dirname(__DIR__) . '/services/admin_password_recovery_service.php';
require_once dirname(__DIR__) . '/includes/admin_guard.php';

/** @param mixed $actual */
function assert_recovery_test(mixed $actual, mixed $expected, string $message): void
{
    if ($actual !== $expected) {
        throw new RuntimeException(
            $message . ' Expected ' . var_export($expected, true)
            . ', received ' . var_export($actual, true) . '.'
        );
    }
}

$passwordCases = [
    ['short!', 'Password must be at least 8 characters.'],
    ['Aa1!😀', 'Password must be at least 8 characters.'],
    ['lowercase1!', 'Password must include an uppercase letter.'],
    ['UPPERCASE1!', 'Password must include a lowercase letter.'],
    ['NoNumber!', 'Password must include a number.'],
    ['NoSpecial1', 'Password must include a special character.'],
    [str_repeat('Aa1!', 33), 'Password must be no more than 128 characters.'],
    ['StrongPassword1!', null],
];

foreach ($passwordCases as [$password, $expected]) {
    assert_recovery_test(
        admin_password_validation_error($password),
        $expected,
        'Unexpected password validation result.'
    );
}

unset($_SESSION['csrf_token']);
$emptyCsrfWasRejected = false;
try {
    verify_csrf('');
} catch (RuntimeException) {
    $emptyCsrfWasRejected = true;
}
assert_recovery_test(
    $emptyCsrfWasRejected,
    true,
    'An empty CSRF value must fail when the session has no token.'
);

$validCsrf = csrf_token();
verify_csrf($validCsrf);
$invalidCsrfWasRejected = false;
try {
    verify_csrf(str_repeat('0', 64));
} catch (RuntimeException) {
    $invalidCsrfWasRejected = true;
}
assert_recovery_test(
    $invalidCsrfWasRejected,
    true,
    'A well-formed but incorrect CSRF value must be rejected.'
);

$now = time();
assert_recovery_test(
    admin_recovery_rate_limit_decision([], [], $now),
    true,
    'A first recovery request should be allowed.'
);
assert_recovery_test(
    admin_recovery_rate_limit_decision([$now - 10], [], $now),
    false,
    'A reset request inside the cooldown should be blocked.'
);
assert_recovery_test(
    admin_recovery_rate_limit_decision(
        [$now - 180, $now - 120, $now - 60],
        [],
        $now
    ),
    false,
    'A fourth email request in one day should be blocked.'
);
assert_recovery_test(
    admin_recovery_rate_limit_decision(
        [$now - ADMIN_RECOVERY_EMAIL_WINDOW - 1],
        [],
        $now
    ),
    true,
    'Expired email request records must not count against the limit.'
);

$rateLimitFile = tempnam(sys_get_temp_dir(), 'myfind-admin-recovery-test-');
if ($rateLimitFile === false) {
    throw new RuntimeException('Could not create the rate-limit test file.');
}
putenv('ADMIN_RECOVERY_RATE_LIMIT_FILE=' . $rateLimitFile);
putenv('ADMIN_RECOVERY_RATE_LIMIT_SECRET=unit-test-only-secret');
$_SERVER['REMOTE_ADDR'] = '192.0.2.10';
$rateLimitEmail = 'admin-rate-limit-test@example.invalid';
assert_recovery_test(
    admin_recovery_shared_rate_limit_allows($rateLimitEmail),
    true,
    'The first shared rate-limit request should be allowed.'
);
assert_recovery_test(
    admin_recovery_shared_rate_limit_allows($rateLimitEmail),
    false,
    'An immediate shared rate-limit resend should be blocked.'
);
$rateLimitContents = file_get_contents($rateLimitFile);
assert_recovery_test(
    is_string($rateLimitContents) && str_contains($rateLimitContents, $rateLimitEmail),
    false,
    'The shared rate-limit store must not contain plaintext email addresses.'
);
unlink($rateLimitFile);
putenv('ADMIN_RECOVERY_RATE_LIMIT_FILE');
putenv('ADMIN_RECOVERY_RATE_LIMIT_SECRET');

$encoded = admin_recovery_base64url("\xfb\xff\x00\x10");
assert_recovery_test(
    preg_match('/^[A-Za-z0-9_-]+$/', $encoded),
    1,
    'PKCE values must use URL-safe Base64 characters.'
);
assert_recovery_test(
    str_contains($encoded, '='),
    false,
    'PKCE values must not contain Base64 padding.'
);

$_SESSION['admin_recovery_code_verifier'] = 'pending-verifier';
$_SESSION['admin_recovery_request_at'] = time();
$_SESSION['admin_recovery_access_token'] = 'temporary-access-token';
$_SESSION['admin_recovery_user_id'] = '00000000-0000-4000-8000-000000000000';
$_SESSION['admin_recovery_started_at'] = time();

clear_active_admin_recovery_session();
assert_recovery_test(
    isset($_SESSION['admin_recovery_code_verifier']),
    true,
    'Clearing an active reset must not remove a pending PKCE verifier.'
);
assert_recovery_test(
    isset($_SESSION['admin_recovery_access_token']),
    false,
    'Active recovery tokens must be removed.'
);

clear_admin_recovery_session();
assert_recovery_test(
    isset($_SESSION['admin_recovery_code_verifier']),
    false,
    'A full recovery cleanup must remove the PKCE verifier.'
);

$_SESSION['admin_recovery_access_token'] = 'recovery-token-is-not-a-login-token';
$_SESSION['admin_recovery_user_id'] = '00000000-0000-4000-8000-000000000000';
$_SESSION['admin_recovery_started_at'] = time();
$recoveryGrantedPortalAccess = false;
try {
    current_admin();
    $recoveryGrantedPortalAccess = true;
} catch (AdminAccessDenied) {
    // Expected: normal Admin access requires the separate login-session keys.
}
assert_recovery_test(
    $recoveryGrantedPortalAccess,
    false,
    'A password-recovery session must never grant Admin Portal access.'
);
clear_admin_recovery_session();

session_destroy();
echo "Admin password recovery tests passed.\n";

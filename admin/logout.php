<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/admin_guard.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    header('Allow: POST');
    exit('Method not allowed.');
}

try {
    verify_csrf($_POST['csrf_token'] ?? null);
    $accessToken = $_SESSION['access_token'] ?? null;
    if (is_string($accessToken)) {
        try {
            (new SupabaseClient())->asUser('POST', '/auth/v1/logout', $accessToken);
        } catch (Throwable) {
            // Local logout must still complete if the network is unavailable.
        }
    }
} finally {
    clear_admin_session();
}

redirect('admin_login.php');

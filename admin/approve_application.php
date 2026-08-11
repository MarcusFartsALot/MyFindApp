<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/admin_guard.php';
require_once __DIR__ . '/services/application_service.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    header('Allow: POST');
    exit('Method not allowed.');
}

$admin = require_admin(true);
$profileId = $_POST['profile_id'] ?? null;

try {
    verify_csrf($_POST['csrf_token'] ?? null);
    if (!valid_uuid(is_string($profileId) ? $profileId : null)) {
        throw new RuntimeException('Invalid application ID.');
    }
    (new ApplicationService())->approve($profileId, $admin);
    flash(
        'success',
        'User is registered. Their temporary password is their IC or passport '
        . 'number. The mobile app will require a new password on first login.'
    );
} catch (SupabaseApiException $error) {
    error_log(
        'Module 400 approval Supabase error: HTTP '
        . $error->statusCode . ' - ' . $error->getMessage()
    );
    $message = str_contains(strtolower($error->getMessage()), 'already')
        ? 'An authentication account or profile already exists for this email.'
        : 'Account creation failed. No approval was recorded.';
    flash('error', $message);
} catch (Throwable $error) {
    error_log('Module 400 approval error: ' . $error->getMessage());
    $safeMessage = in_array($error->getMessage(), [
        'This application has already been processed.',
        'This application already has an authentication account.',
        'Application has an invalid role.',
        'The application has an invalid IC number.',
        'The passport number must contain 6-20 letters or numbers.',
        'Invalid application ID.',
        'The form expired. Refresh the page and try again.',
    ], true) ? $error->getMessage() : 'Approval could not be completed safely.';
    flash('error', $safeMessage);
}

redirect('new_application.php');

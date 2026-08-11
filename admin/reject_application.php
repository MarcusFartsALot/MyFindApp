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
    $reason = isset($_POST['rejection_reason'])
        ? trim((string) $_POST['rejection_reason'])
        : null;
    $emailSent = (new ApplicationService())->reject($profileId, $admin, $reason);
    flash(
        $emailSent ? 'success' : 'warning',
        $emailSent
            ? 'Application, applicant profile, and documents were deleted. '
                . 'The rejection email was sent.'
            : 'Application, applicant profile, and documents were deleted, '
                . 'but the email could not be sent. Check the server mail configuration.'
    );
} catch (Throwable $error) {
    error_log('Module 400 rejection error: ' . $error->getMessage());
    $safeMessage = in_array($error->getMessage(), [
        'This application has already been processed.',
        'This application already has an authentication account.',
        'Application has an invalid role.',
        'Invalid application ID.',
        'Rejection reason must be 1,000 characters or fewer.',
        'Registration document paths are missing.',
        'Registration document path is invalid.',
        'Pending registration application not found.',
        'Pending registration profile could not be deleted.',
        'The application could not be validated for deletion.',
        'The rejected application was not deleted.',
        'The form expired. Refresh the page and try again.',
    ], true) ? $error->getMessage() : 'Rejection could not be completed safely.';
    flash('error', $safeMessage);
}

redirect('new_application.php');

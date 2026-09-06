# Activate the password-reset check and registration rollback

The PHP admin check is ready without a new database function. The Flutter app
needs migration 202609060001 before its new check can run. No database changes
were applied remotely by this task.

1. In your Supabase project's SQL Editor, run the full contents of
   `migrations/202609060001_password_reset_email_check.sql`.
2. Run `migrations/202609060002_restore_registration_flow.sql`. This disconnects
   the later duplicate-image triggers if they were installed. It is also safe
   when they were never installed. No profiles, applications, stored documents,
   fingerprint records, identity/email constraints or RLS policies are deleted.
3. Fully restart the Flutter app and hard-refresh the admin website.

Do not turn RLS off, expose profiles publicly, or put a service-role key in Dart.
The lookup returns only a reset-eligibility category. Showing “Email not
registered in system” intentionally reveals account existence, as requested.

## What registration now does

**Later updates:** Passport date/country autofill and MyKad-back OCR screening
have since been added. Identity-number preflight checks require the separate
setup in `M400_IDENTITY_NUMBER_SETUP.md`. The rollback description below records
the earlier state; it is not the complete current feature list.

Registration was restored to before the 5 September 2026, 9:30 PM request:
manual details and identity numbers, private OCR matching, normal document
uploads, existing email/identity uniqueness, and administrator approval.
Automatic detail filling, the new gender check and image-fingerprint checks
are no longer invoked. The optional password-change policy is unchanged.
The pre-rollback Dart files are saved in
`build/m400_registration_before_rollback_20260906/`.

The older document-check setup guide is superseded by this rollback. Do not
reapply its migration after the rollback migration. Unused parsing helpers and
their tests are retained; the registration flow no longer calls them.

## Checks to perform

- Login → Back to home: returns to the landing page, including after logout/reset.
- An unregistered email: displays the error and does not request a reset email.
- An active registered email: requests a reset link; an admin must use the portal.
- Pending/unlinked registration: asks for approval/support, not an unusable link.
- Supabase failure or sending quota: shows an error, not a success confirmation.
- Existing three-request/24-hour limits remain; Supabase has independent limits.
- Register both roles using manually typed details and matching document numbers.

Run automated checks with `flutter test test/password_reset_email_check_test.dart
test/login_back_navigation_test.dart test/document_ocr_service_test.dart
test/password_reset_rate_limiter_test.dart` and
`C:\xampp\php\php.exe admin/tests/admin_password_recovery_test.php`.

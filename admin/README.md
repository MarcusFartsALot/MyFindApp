# Module 400 PHP Admin Portal

This folder is the server-only administrator portal for reviewing Citizen and
Tourist account applications. The service-role key must never be copied into
Flutter, JavaScript, HTML, or source control.

## Requirements

- PHP 8.1 or newer with `curl`, `json`, `mbstring`, and sessions enabled
- HTTPS in production
- A working PHP mail transport, or an SMTP relay configured for PHP `mail()`
- The Module 400 Supabase migration applied

## Configure

1. Copy `.env.example` to `.env` on the PHP server.
2. Set `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and the server-only
   `SUPABASE_SERVICE_ROLE_KEY`.
3. Set `MAIL_FROM` and configure the host's mail transport only if rejection
   notices must be delivered from PHP.
4. Point the web server document root at `admin/`, or deny direct HTTP access to
   `config/`, `includes/`, `services/`, `.env`, and `.env.example`. The included
   `config/.htaccess` protects `config/` on Apache, but server-level rules are
   still recommended.

## First administrator

Create the initial admin through the Supabase Dashboard or another trusted
server process. First create the email/password under **Authentication >
Users**. Then add a `profiles` row whose `auth_id` is the Auth user ID and whose
`role` is `admin`. There is no separate Admin table in this schema. Flutter
registration never offers the admin role.

Passwords belong only to Supabase Auth (`auth.users`). Never add a plaintext or
hashed password column to any public table.

## Approved-user password

Approval creates a confirmed Supabase Auth user. The normalized IC number
(12 digits without hyphens) or passport number (uppercase letters/numbers
without spaces) is the temporary password. The mobile app forces the user to
replace it at first login. The password exists only in Supabase Auth and is not
stored in `profiles`, `citizens`, or `tourists`.

This temporary credential contains personal information and is intentionally
short-lived. For production, a random one-time password or verified email link
is safer. Keep Supabase's service-role key on the PHP server only.

## Email delivery

Approval does not send email, so local SMTP is not required for approval.
Rejection notices use PHP's `mail()` behind a reusable service.
On a local Windows/PHP installation, configure `SMTP` and `smtp_port` in
`php.ini`. On Linux, configure a sendmail-compatible MTA. For a hosted
deployment, route `mail()` through the organization's authenticated SMTP relay.

Rejecting a pending application permanently removes its private registration
documents through the Storage API, then atomically deletes its Citizen/Tourist
row and pending `profiles` row. Pending applications do not have an Auth user;
unrelated Auth accounts are never deleted merely because an email matches.

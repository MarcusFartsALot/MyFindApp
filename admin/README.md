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

1. Copy `admin/.env.example` to `.admin.env` in the project root. Secrets stay
   outside the public `admin/` document root.
2. Set `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and the server-only
   `SUPABASE_SERVICE_ROLE_KEY`.
3. Set `ADMIN_PASSWORD_RESET_URL` to the exact public callback, for example
   `http://localhost:8081/admin_reset_password.php` during local development.
   Optionally set `ADMIN_RECOVERY_RATE_LIMIT_SECRET` to a separate long random
   server-only value; otherwise the service-role key protects the anonymous
   rate-limit identifiers. `SESSION_SAVE_PATH` may point to an existing private,
   writable directory; by default the operating-system temp directory is used.
4. In **Supabase Dashboard > Authentication > URL Configuration**, add that
   exact callback to **Redirect URLs**. Keep the Flutter mobile deep link too.
5. Set `MAIL_FROM` and configure the host's mail transport only if rejection
   notices must be delivered from PHP.
6. Point the web server document root at `admin/`, or deny direct HTTP access to
   `config/`, `includes/`, `services/`, `.env`, and `.env.example`. The included
   `config/.htaccess` protects `config/` on Apache, but server-level rules are
   still recommended.

## Run locally

From the project root, start the Administrator portal with the included
security router:

```powershell
C:\xampp\php\php.exe -S localhost:8081 -t admin admin/router.php
```

Then open `http://localhost:8081/admin_login.php`. Do not run the portal with a
plain `php -S localhost:8081` command from inside `admin/`: PHP's development
server would otherwise make `.env` downloadable. Stop and restart any older
local server using the command above.

## Administrator password recovery

The Login page links to `admin_forgot_password.php`. The portal sends a
Supabase recovery email only when the submitted address belongs to a linked
`profiles.role = admin` account, while always showing the same public response
to prevent account enumeration.

Recovery uses a PKCE authorization code. The email link must normally be opened
in the same browser that requested it because the verifier remains in the
HttpOnly PHP session. The callback exchanges the one-time code server-side,
revalidates the Supabase user and Administrator profile, and creates a separate
15-minute recovery session. It does not create a normal Admin Portal login
session. After a successful password update, the portal requests a global
Supabase sign-out before returning the user to `admin_login.php`.

The PHP layer accepts at most three reset-link requests per normalized email in
a rolling 24-hour period, includes a 60-second resend cooldown, and limits each
source IP to 20 attempts per hour. Its shared local store contains only keyed
hashes, never plaintext email addresses or IPs. Supabase's own Auth email limits
still apply. If the portal is deployed on multiple PHP servers, configure a
shared database or cache-backed limiter instead of relying on one server's
temporary file.

The shared Supabase Recovery email template should keep using
`{{ .ConfirmationURL }}`. Hardcoding either the PHP callback or the Flutter deep
link in that template would break the other client.

Supabase's built-in SMTP service is best-effort and currently permits only a
small project-wide number of Auth emails. Registration, confirmation, OTP, and
password-recovery messages share that quota. Configure custom SMTP under
**Authentication > Emails > SMTP Settings** when repeated or reliable delivery
is required. The public form intentionally cannot confirm whether a particular
email was sent because that would reveal which addresses are Administrator
accounts; use Supabase Auth logs to distinguish `mail.send` from HTTP 429.

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
without spaces) is the initial password. The mobile app lets the user change it
later from Settings but does not force a first-login reset. The password exists
only in Supabase Auth and is not stored in `profiles`, `citizens`, or `tourists`.

This initial credential contains personal information and remains valid until
the user changes it. For production, a random one-time password or verified
email link is safer. Keep Supabase's service-role key on the PHP server only.

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

# Registration identity checks and passport autofill

## Required database setup

The app now calls `module400_registration_identity_available` while an applicant
types a valid IC/passport number, and again before uploading registration photos.
The connected schema was checked read-only: `citizens.ic_number` and
`tourists.passport_number` exist, but the new lookup was not installed at that time.
This task has not applied the migration to the live database.

1. Open the same Supabase project used by `lib/config/app_config.dart`.
2. In **SQL Editor → New query**, paste the full contents of
   `migrations/202609060003_unique_registration_identity.sql` and click **Run**.
3. Keep RLS enabled. No direct anonymous SELECT grants or service-role keys in Dart
   are needed. The public lookup returns one boolean, never another user's records.
4. Fully restart the Flutter app.

The migration does not replace the existing registration/approval functions or
change duplicate-image checks. It adds normalized unique indexes so simultaneous
submissions cannot create duplicate identities. Pending and approved records are
both covered, as are other rows still in the role tables. IC hyphens/spaces and
passport case/formatting differences are normalized for comparison. Uniqueness is
per identity type: IC in citizens, passport number in tourists (not visa history).

If pre-existing normalized duplicates are found, the migration rolls back with a
review message. Do not delete accounts blindly. Resolve the correct records with
the administrator, then rerun. The migration does not merge or delete user data.
Until the lookup is installed/reachable, registration fails closed with a setup
or connection error rather than treating the number as available.

Existence feedback intentionally reveals whether a number is registered, as
requested. For a public deployment, apply server-side abuse/rate controls to this
anonymous endpoint. A typing debounce is not a server-side rate limit.

## Passport capture changes

Previously, autofill ran only after the entered passport number matched the OCR,
and MRZ parsing required exactly 44 characters on both lines. Now:

- A readable passport can fill issue date, expiry date and issuing country before
  entering the number. The number itself remains manual.
- A missing/mismatched number still prevents registration until corrected.
- Parsing accepts missing trailing MRZ fillers while keeping fixed field positions
  and expiry check-digit validation. Common printed country/date labels, bilingual
  month names and explicitly printed abbreviated years are supported.
- Fields remain reviewable/editable. A message explains when no details are read.
- Retakes clear old OCR-only values and preserve manual corrections. OCR cannot
  invent a missing issue date or guarantee every country's photo layout will parse.
- No raw OCR text is rendered, logged or sent to an external AI service.

## Manual verification

1. Enter an existing IC (also try with/without hyphens) or existing passport number
   (also try lowercase). Expect an already-registered message and no submission.
2. Enter an unused valid number. Expect an available message; final submission
   rechecks it. Availability is not a reservation.
3. Capture a clear full passport details page before entering its number. Readable
   dates/country should fill. Enter the number shown in the photo to verify it.
4. Try a mismatched number, unrelated image, unreadable photo and expired passport.
   Autofill must never bypass document matching or date validation.
5. Retake the passport after manually correcting a field; the correction should stay.

Automated checks: `flutter test --no-pub`. These use fake services/fixtures, not
real camera OCR or live registration writes.

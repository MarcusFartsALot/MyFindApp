# M400 duplicate-document setup

Apply `migrations/202609050001_unique_registration_documents.sql` in the
Supabase SQL Editor after the existing M400 migrations. Keep RLS enabled.
The Flutter registration flow now requires this RPC; it intentionally stops
if the database check is unavailable. No service-role key belongs in Flutter.

## Check before going live

The implementation is for standard Supabase uploads with a **server-generated
MD5 ETag** (`storage.objects.metadata.eTag`), not custom `user_metadata`.
Check your existing bucket metadata before applying it:

```sql
select count(*) as total_images,
       count(*) filter (where lower(trim(both '"' from metadata->>'eTag'))
         ~ '^[0-9a-f]{32}$') as compatible_images
from storage.objects where bucket_id = 'registration-documents';
```

If these counts differ, or your storage uses multipart/non-MD5 ETags, stop:
use a server-side download-and-hash/backfill service instead. Do not enable
this implementation on that backend or invent fingerprints for missing files.
Exact bytes must be preserved (the app no longer resizes/recompresses picks).

Before migration, also audit linked legacy documents with missing metadata/objects.
The migration refuses to enable partial coverage if any of these rows exist:

```sql
with sources as (
  select profile_id, ic_front_url::text as object_path from public.citizens
  union all select profile_id, ic_back_url::text from public.citizens
  union all select profile_id, passport_front_url::text from public.tourists
  union all select profile_id, passport_back_url::text from public.tourists
)
select s.profile_id, s.object_path
from sources s
left join storage.objects o on o.bucket_id = 'registration-documents'
  and o.name = s.object_path
where nullif(s.object_path, '') is not null
  and (o.id is null or coalesce(lower(trim(both '"' from o.metadata->>'eTag')), '')
    !~ '^[0-9a-f]{32}$');
```

Resolve every returned row before relying on historical coverage. The migration
does not delete old users or images. It backfills compatible linked images and
blocks their reuse, including legacy images shared by multiple old profiles.
After migration, audit pre-existing duplicates (review manually, never delete blindly):

```sql
select lower(trim(both '"' from o.metadata->>'eTag')) as fingerprint,
       count(*) as uses
from public.module400_document_sources() s
join storage.objects o on o.bucket_id = 'registration-documents'
  and o.name = s.object_path
group by 1 having count(*) > 1;
```

## Test with non-sensitive test documents

1. Register with fresh front/back images: submission succeeds.
2. Reuse a linked image under a different filename: image selection reports a duplicate.
3. Bypass the phone check and call the existing submission RPC: the database trigger rejects duplicates too.
4. Submit two applications concurrently with the same image: only one may commit.
5. Use the same file for front and back: submission is rejected.
6. Approve an existing application: status-only updates still work.
7. Reject/delete a pending application through the Admin Portal: its fingerprint
   claims are released with the profile. Orphan uploaded files alone are not registrations.
8. Keep raw OCR hidden. Names/nationality/dates are editable; IC/passport numbers
   must be typed manually and still match OCR before submission.

This detects **identical files**, not visually similar documents. Cropping,
recompression, metadata changes, or taking a new photo changes the fingerprint.
Keep identity-number uniqueness and administrator review. MD5 here is a storage
compatibility checksum, not proof of identity or cryptographic authenticity.

References: [Supabase Storage schema](https://supabase.com/docs/guides/storage/schema/design)
and [server-generated versus user metadata](https://github.com/supabase/storage/blob/master/src/storage/uploader.ts).

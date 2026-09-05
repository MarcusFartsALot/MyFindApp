-- Run after the existing M400 migrations. Never changes/deletes Storage rows.
-- Exact-file matching for standard uploads with Storage-generated MD5 ETags.
-- Crops/re-encodes/photographs are different files; identity-number uniqueness
-- and administrator review must remain enabled. Not a biometric check.
begin;

create table if not exists public.module400_document_fingerprints (
  fingerprint text primary key check (fingerprint ~ '^[0-9a-f]{32}$'),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  object_path text not null,
  created_at timestamptz not null default now()
);
alter table public.module400_document_fingerprints enable row level security;
revoke all on public.module400_document_fingerprints from public, anon, authenticated;
grant all on public.module400_document_fingerprints to service_role;

-- Private helpers: public applicants receive only a boolean from the RPC below.
create or replace function public.module400_document_sources()
returns table (profile_id uuid, object_path text)
language sql stable security definer set search_path = '' as $$
  select c.profile_id, c.ic_front_url::text from public.citizens c
  union all select c.profile_id, c.ic_back_url::text from public.citizens c
  union all select t.profile_id, t.passport_front_url::text from public.tourists t
  union all select t.profile_id, t.passport_back_url::text from public.tourists t;
$$;
revoke all on function public.module400_document_sources() from public, anon, authenticated;

-- Do not silently enable partial protection for legacy images we cannot hash.
do $$
begin
  if exists (
    select 1 from public.module400_document_sources() s
    left join storage.objects o on o.bucket_id = 'registration-documents' and o.name = s.object_path
    where nullif(s.object_path, '') is not null
      and (o.id is null or coalesce(lower(trim(both '"' from o.metadata->>'eTag')), '') !~ '^[0-9a-f]{32}$')
  ) then
    raise exception 'Existing registration documents need a metadata/path backfill before enabling duplicate checks. See M400_DOCUMENT_CHECK_SETUP.md.';
  end if;
end;
$$;

-- Backfill registered/pending users from trusted metadata, not from filenames
-- or client-supplied custom user_metadata. Existing duplicate rows are retained.
insert into public.module400_document_fingerprints(fingerprint, profile_id, object_path)
select distinct on (lower(trim(both '"' from o.metadata->>'eTag')))
  lower(trim(both '"' from o.metadata->>'eTag')), s.profile_id, s.object_path
from public.module400_document_sources() s
join storage.objects o on o.bucket_id = 'registration-documents' and o.name = s.object_path
where lower(trim(both '"' from o.metadata->>'eTag')) ~ '^[0-9a-f]{32}$'
order by lower(trim(both '"' from o.metadata->>'eTag')), s.profile_id, s.object_path
on conflict (fingerprint) do nothing;

create or replace function public.module400_registration_document_available(p_fingerprint text)
returns boolean
language sql stable security definer set search_path = '' as $$
  select case when p_fingerprint is null or p_fingerprint !~ '^[0-9a-f]{32}$'
    then false
    else not exists (
      select 1 from public.module400_document_fingerprints f
      where f.fingerprint = p_fingerprint
    ) and not exists (
      -- Also covers legacy duplicate owners if the original claim owner is
      -- subsequently deleted. No applicant can see these paths/profile IDs.
      select 1 from public.module400_document_sources() s
      join storage.objects o on o.bucket_id = 'registration-documents' and o.name = s.object_path
      where lower(trim(both '"' from o.metadata->>'eTag')) = p_fingerprint
    ) end;
$$;
revoke all on function public.module400_registration_document_available(text) from public;
grant execute on function public.module400_registration_document_available(text) to anon, authenticated;

create or replace function public.module400_claim_document_images()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_front text;
  v_back text;
  v_path text;
  v_hash text;
  v_first_hash text;
  v_metadata jsonb;
begin
  if tg_table_name = 'citizens' then
    v_front := new.ic_front_url;
    v_back := new.ic_back_url;
  else
    v_front := new.passport_front_url;
    v_back := new.passport_back_url;
  end if;
  -- Updating verification_status during approval does NOT invoke this trigger.
  if tg_op = 'UPDATE' then
    if new.profile_id is distinct from old.profile_id then
      raise exception 'Document ownership cannot be transferred.';
    end if;
    delete from public.module400_document_fingerprints where profile_id = new.profile_id;
  end if;
  if nullif(v_front, '') is null then
    raise exception 'Document uniqueness could not be verified. Please contact support.';
  end if;
  foreach v_path in array array[v_front, v_back] loop
    if nullif(v_path, '') is null then continue; end if;
    -- Scope to the new applicant's standard upload folder, not arbitrary files.
    if v_path !~ ('^(citizens|tourists)/' || new.profile_id::text || '/(mykad|passport)_(front|back)\.(jpg|jpeg|png)$') then
      raise exception 'Document uniqueness could not be verified. Please contact support.';
    end if;
    select o.metadata into v_metadata from storage.objects o
      where o.bucket_id = 'registration-documents' and o.name = v_path;
    v_hash := lower(trim(both '"' from v_metadata->>'eTag'));
    if v_hash is null or v_hash !~ '^[0-9a-f]{32}$'
       or coalesce(v_metadata->>'mimetype', '') not in ('image/jpeg', 'image/png') then
      raise exception 'Document uniqueness could not be verified. Please contact support.';
    end if;
    if v_first_hash = v_hash then
      raise exception 'Front and back must be different document images.';
    end if;
    v_first_hash := v_hash;
    if exists (
      select 1 from public.module400_document_sources() s
      join storage.objects o on o.bucket_id = 'registration-documents' and o.name = s.object_path
      where s.profile_id <> new.profile_id
        and lower(trim(both '"' from o.metadata->>'eTag')) = v_hash
    ) then
      raise exception using errcode = '23505',
        message = 'This identity document image is already used by another registration.';
    end if;
    begin
      -- The primary key serializes competing applications using the same file.
      -- Failure rolls back the profile, role row, and both claims atomically.
      insert into public.module400_document_fingerprints(fingerprint, profile_id, object_path)
      values (v_hash, new.profile_id, v_path);
    exception when unique_violation then
      raise exception using errcode = '23505',
        message = 'This identity document image is already used by another registration.';
    end;
  end loop;
  return new;
end;
$$;
revoke all on function public.module400_claim_document_images() from public, anon, authenticated;

drop trigger if exists module400_citizen_document_uniqueness on public.citizens;
create trigger module400_citizen_document_uniqueness
before insert or update of profile_id, ic_front_url, ic_back_url on public.citizens
for each row execute function public.module400_claim_document_images();
drop trigger if exists module400_tourist_document_uniqueness on public.tourists;
create trigger module400_tourist_document_uniqueness
before insert or update of profile_id, passport_front_url, passport_back_url on public.tourists
for each row execute function public.module400_claim_document_images();

-- Rejected applications are deleted with their profiles by the existing RPC;
-- ON DELETE CASCADE releases the fingerprints for a corrected registration.
notify pgrst, 'reload schema';
commit;

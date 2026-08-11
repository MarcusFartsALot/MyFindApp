-- MODULE 400 - User Login and Role Authorization
--
-- This migration uses the EXISTING profiles, citizens and tourists
-- tables. It deliberately does not create a registration/application table.

create extension if not exists pgcrypto;

-- Link approved profiles to Supabase Auth without invalidating legacy rows.
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_auth_id_fkey'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_auth_id_fkey
      foreign key (auth_id) references auth.users(id) on delete set null
      not valid;
  end if;
end
$$;

-- Anonymous Flutter applicants cannot insert directly into the tables. This
-- narrowly scoped function forces auth_id=NULL, a Citizen/Tourist role and a
-- pending verification state. The two inserts run in one database transaction.
create or replace function public.submit_registration_application(
  p_profile_id uuid,
  p_full_name text,
  p_email text,
  p_phone_number text,
  p_nationality text,
  p_role text,
  p_identity_number text,
  p_front_path text,
  p_back_path text default null,
  p_passport_issue_date date default null,
  p_passport_expiry_date date default null,
  p_passport_issuing_country text default null,
  p_country_of_residence text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(btrim(p_email));
  v_identity text := upper(regexp_replace(p_identity_number, '[^A-Z0-9]', '', 'g'));
begin
  if p_profile_id is null then
    raise exception 'Invalid profile ID.';
  end if;
  if p_role not in ('citizen', 'tourist') then
    raise exception 'Only Citizen or Tourist registration is allowed.';
  end if;
  if char_length(btrim(p_full_name)) not between 2 and 150 then
    raise exception 'Enter a valid full name.';
  end if;
  if v_email !~* '^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$' then
    raise exception 'Enter a valid email address.';
  end if;
  if nullif(btrim(p_phone_number), '') is null then
    raise exception 'Phone number is required.';
  end if;
  if nullif(btrim(p_nationality), '') is null then
    raise exception 'Nationality is required.';
  end if;
  if exists (select 1 from public.profiles where lower(email::text) = v_email) then
    raise exception using errcode = '23505', message = 'Email is already registered.';
  end if;

  if p_role = 'citizen' then
    if v_identity !~ '^[0-9]{12}$' then
      raise exception 'Enter a valid 12-digit IC number.';
    end if;
    if exists (select 1 from public.citizens where ic_number::text = v_identity) then
      raise exception using errcode = '23505', message = 'IC number is already registered.';
    end if;
    if p_front_path !~ (
      '^citizens/' || p_profile_id::text || '/mykad_front\.(jpg|jpeg|png)$'
    ) or p_back_path is null or p_back_path !~ (
      '^citizens/' || p_profile_id::text || '/mykad_back\.(jpg|jpeg|png)$'
    ) then
      raise exception 'Valid MyKad front and back document paths are required.';
    end if;

    -- Literal role values work with either varchar or a user_role enum column.
    insert into public.profiles (
      id, auth_id, full_name, email, phone_number, nationality, role
    ) values (
      p_profile_id, null, btrim(p_full_name), v_email,
      btrim(p_phone_number), btrim(p_nationality), 'citizen'
    );

    insert into public.citizens (
      profile_id, ic_number, ic_front_url, ic_back_url,
      verification_status, rejection_reason, verified_at, verified_by
    ) values (
      p_profile_id, v_identity, p_front_path, p_back_path,
      'pending', null, null, null
    );
  else
    if v_identity !~ '^[A-Z0-9]{6,20}$' then
      raise exception 'Enter a valid passport number.';
    end if;
    if exists (
      select 1 from public.tourists where upper(passport_number::text) = v_identity
    ) then
      raise exception using errcode = '23505', message = 'Passport number is already registered.';
    end if;
    if p_passport_expiry_date is null or p_passport_expiry_date <= current_date then
      raise exception 'Passport expiry date must be in the future.';
    end if;
    if p_passport_issue_date is not null
       and p_passport_issue_date > p_passport_expiry_date then
      raise exception 'Passport issue date must be before its expiry date.';
    end if;
    if nullif(btrim(p_passport_issuing_country), '') is null then
      raise exception 'Passport issuing country is required.';
    end if;
    if p_front_path !~ (
      '^tourists/' || p_profile_id::text || '/passport_front\.(jpg|jpeg|png)$'
    ) then
      raise exception 'A valid passport document path is required.';
    end if;
    if p_back_path is not null and p_back_path !~ (
      '^tourists/' || p_profile_id::text || '/passport_back\.(jpg|jpeg|png)$'
    ) then
      raise exception 'The optional passport back path is invalid.';
    end if;

    insert into public.profiles (
      id, auth_id, full_name, email, phone_number, nationality, role
    ) values (
      p_profile_id, null, btrim(p_full_name), v_email,
      btrim(p_phone_number), btrim(p_nationality), 'tourist'
    );

    insert into public.tourists (
      profile_id, passport_number, passport_front_url, passport_back_url,
      passport_issue_date, passport_expiry_date, passport_issuing_country,
      country_of_residence, verification_status, rejection_reason,
      verified_at, verified_by
    ) values (
      p_profile_id, v_identity, p_front_path, p_back_path,
      p_passport_issue_date, p_passport_expiry_date,
      btrim(p_passport_issuing_country), nullif(btrim(p_country_of_residence), ''),
      'pending', null, null, null
    );
  end if;

  return p_profile_id;
end;
$$;

revoke all on function public.submit_registration_application(
  uuid, text, text, text, text, text, text, text, text, date, date, text, text
) from public;
grant execute on function public.submit_registration_application(
  uuid, text, text, text, text, text, text, text, text, date, date, text, text
) to anon, authenticated;

alter table public.profiles enable row level security;
alter table public.citizens enable row level security;
alter table public.tourists enable row level security;

grant all on table public.profiles, public.citizens, public.tourists
  to service_role;
revoke all on table public.profiles, public.citizens, public.tourists
  from anon, authenticated;
grant select on table public.profiles, public.citizens, public.tourists
  to authenticated;
grant update (full_name, phone_number, nationality, profile_image, updated_at)
  on table public.profiles to authenticated;

drop policy if exists module400_profiles_select_own on public.profiles;
create policy module400_profiles_select_own
on public.profiles for select to authenticated
using (auth_id = auth.uid());

drop policy if exists module400_profiles_update_own on public.profiles;
create policy module400_profiles_update_own
on public.profiles for update to authenticated
using (auth_id = auth.uid())
with check (auth_id = auth.uid());

drop policy if exists module400_citizens_select_own on public.citizens;
create policy module400_citizens_select_own
on public.citizens for select to authenticated
using (
  exists (
    select 1 from public.profiles
    where profiles.id = citizens.profile_id and profiles.auth_id = auth.uid()
  )
);

drop policy if exists module400_tourists_select_own on public.tourists;
create policy module400_tourists_select_own
on public.tourists for select to authenticated
using (
  exists (
    select 1 from public.profiles
    where profiles.id = tourists.profile_id and profiles.auth_id = auth.uid()
  )
);

-- Private identity-document storage. Database columns keep object paths, not
-- public URLs. PHP uses the service role to create short-lived signed URLs.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'registration-documents',
  'registration-documents',
  false,
  10485760,
  array['image/jpeg', 'image/png']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists module400_registration_document_upload on storage.objects;
create policy module400_registration_document_upload
on storage.objects for insert
to anon, authenticated
with check (
  bucket_id = 'registration-documents'
  and (
    name ~ '^citizens/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/mykad_(front|back)\.(jpg|jpeg|png)$'
    or name ~ '^tourists/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/passport_(front|back)\.(jpg|jpeg|png)$'
  )
  and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png')
);

comment on function public.submit_registration_application is
  'Creates a pending Citizen/Tourist profile and role row without an Auth user.';

notify pgrst, 'reload schema';

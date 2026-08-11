-- Prevent a new pending Citizen/Tourist application from using an email that
-- already belongs to a Supabase Auth account. This runs inside Postgres so the
-- mobile client never receives permission to list or query auth.users.
create or replace function public.module400_registration_email_available(
  p_email text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_email text := lower(btrim(p_email));
begin
  if v_email !~* '^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$' then
    return false;
  end if;

  return not exists (
    select 1
    from public.profiles
    where lower(public.profiles.email::text) = v_email
  ) and not exists (
    select 1
    from auth.users
    where lower(auth.users.email::text) = v_email
  );
end;
$$;

revoke all on function public.module400_registration_email_available(text)
  from public;
grant execute on function public.module400_registration_email_available(text)
  to anon, authenticated;

comment on function public.module400_registration_email_available(text) is
  'Checks profiles and Supabase Auth before Module 400 uploads registration documents.';

create or replace function public.module400_reject_duplicate_auth_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.auth_id is null
     and new.role::text in ('citizen', 'tourist')
     and exists (
       select 1
       from auth.users
       where lower(auth.users.email::text) = lower(new.email::text)
     ) then
    raise exception using
      errcode = '23505',
      message = 'Email is already registered.';
  end if;

  return new;
end;
$$;

revoke all on function public.module400_reject_duplicate_auth_email()
  from public, anon, authenticated;

drop trigger if exists module400_profiles_reject_auth_email
  on public.profiles;

create trigger module400_profiles_reject_auth_email
before insert or update of email, auth_id, role
on public.profiles
for each row
execute function public.module400_reject_duplicate_auth_email();

comment on function public.module400_reject_duplicate_auth_email() is
  'Blocks pending Module 400 applications whose email already exists in Supabase Auth.';

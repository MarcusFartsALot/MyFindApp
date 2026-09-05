-- M400: explicitly check reset eligibility before requesting an Auth email.
-- Intentional product behaviour: the result reveals whether an email is
-- registered, but never exposes user IDs, profiles, tokens or other columns.
-- Keep RLS enabled; the client only gets EXECUTE on this narrow function.
begin;

create or replace function public.module400_password_reset_eligibility(p_email text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_email text := lower(btrim(p_email));
begin
  if v_email is null or length(v_email) > 254
     or v_email !~* '^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$' then
    raise exception 'Enter a valid email address.';
  end if;

  if not exists (select 1 from public.profiles p where lower(p.email::text) = v_email)
     and not exists (select 1 from auth.users u where lower(u.email::text) = v_email) then
    return 'not_registered';
  end if;

  if exists (
    select 1 from public.profiles p
    where lower(p.email::text) = v_email and p.role::text = 'admin'
  ) then
    return 'admin_portal';
  end if;

  if exists (
    select 1 from public.profiles p
    join auth.users u on u.id = p.auth_id
    where lower(p.email::text) = v_email and lower(u.email::text) = v_email
      and p.role::text in ('citizen', 'tourist')
  ) then
    return 'eligible';
  end if;

  -- Pending applications have profiles but do not yet have Auth passwords.
  return 'not_active';
end;
$$;

revoke all on function public.module400_password_reset_eligibility(text) from public;
grant execute on function public.module400_password_reset_eligibility(text) to anon, authenticated;
notify pgrst, 'reload schema';
commit;

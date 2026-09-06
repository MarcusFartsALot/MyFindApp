-- M400: normalized identity uniqueness plus a privacy-limited preflight lookup.
-- No profiles, applications or document files are deleted or rewritten.
-- If existing normalized duplicates are found, the whole migration rolls back.
begin;

-- A unique index is the final concurrent-write safeguard, even if a caller
-- skips the availability check. Include every status, not just approved users.
do $$
begin
  if exists (
    select 1 from public.citizens
    where nullif(regexp_replace(ic_number::text, '[^0-9]', '', 'g'), '') is not null
    group by regexp_replace(ic_number::text, '[^0-9]', '', 'g') having count(*) > 1
  ) then
    raise exception 'Existing duplicate IC numbers need administrator review before enabling identity uniqueness. No records were changed.';
  end if;
  if exists (
    select 1 from public.tourists
    where nullif(regexp_replace(upper(passport_number::text), '[^A-Z0-9]', '', 'g'), '') is not null
    group by regexp_replace(upper(passport_number::text), '[^A-Z0-9]', '', 'g') having count(*) > 1
  ) then
    raise exception 'Existing duplicate passport numbers need administrator review before enabling identity uniqueness. No records were changed.';
  end if;
end;
$$;

create unique index if not exists module400_citizens_ic_number_normalized_key
  on public.citizens ((nullif(regexp_replace(ic_number::text, '[^0-9]', '', 'g'), '')));
create unique index if not exists module400_tourists_passport_number_normalized_key
  on public.tourists ((nullif(regexp_replace(upper(passport_number::text), '[^A-Z0-9]', '', 'g'), '')));

create or replace function public.module400_registration_identity_available(
  p_role text, p_identity_number text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_identity text;
begin
  if p_role is null or p_role not in ('citizen', 'tourist')
     or p_identity_number is null or length(p_identity_number) > 40 then
    raise exception 'Invalid identity lookup.' using errcode = '22023';
  end if;
  if p_role = 'citizen' then
    if btrim(p_identity_number) !~ '^[0-9 -]+$' then
      raise exception 'Invalid IC number.' using errcode = '22023';
    end if;
    v_identity := regexp_replace(p_identity_number, '[^0-9]', '', 'g');
    if v_identity !~ '^[0-9]{12}$' then
      raise exception 'Invalid IC number.' using errcode = '22023';
    end if;
    return not exists (
      select 1 from public.citizens
      where nullif(regexp_replace(ic_number::text, '[^0-9]', '', 'g'), '') = v_identity
    );
  end if;

  if btrim(p_identity_number) !~* '^[A-Z0-9 -]+$' then
    raise exception 'Invalid passport number.' using errcode = '22023';
  end if;
  v_identity := regexp_replace(upper(p_identity_number), '[^A-Z0-9]', '', 'g');
  if v_identity !~ '^[A-Z0-9]{6,20}$' then
    raise exception 'Invalid passport number.' using errcode = '22023';
  end if;
  return not exists (
    select 1 from public.tourists
    where nullif(regexp_replace(upper(passport_number::text), '[^A-Z0-9]', '', 'g'), '') = v_identity
  );
end;
$$;

revoke all on function public.module400_registration_identity_available(text, text) from public;
grant execute on function public.module400_registration_identity_available(text, text) to anon, authenticated;
comment on function public.module400_registration_identity_available(text, text) is
  'Returns only whether a Citizen IC or Tourist passport number is available. Intentionally reveals existence, never account data. Keep table RLS enabled.';
notify pgrst, 'reload schema';
commit;

-- Delete a rejected registration's role row and profile in one transaction.
-- Document objects are removed through the Storage API before this function is
-- called; deleting storage.objects with SQL would orphan the physical files.
create or replace function public.module400_delete_pending_application(
  p_profile_id uuid,
  p_validate_only boolean default false
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_role text;
  v_deleted_rows integer;
begin
  select public.profiles.role::text
  into v_role
  from public.profiles
  where public.profiles.id = p_profile_id
    and public.profiles.auth_id is null
  for update;

  if v_role not in ('citizen', 'tourist') then
    raise exception 'Pending registration application not found.';
  end if;

  if v_role = 'citizen' and not exists (
    select 1
    from public.citizens
    where public.citizens.profile_id = p_profile_id
      and public.citizens.verification_status = 'pending'
  ) then
    raise exception 'Pending registration application not found.';
  end if;
  if v_role = 'tourist' and not exists (
    select 1
    from public.tourists
    where public.tourists.profile_id = p_profile_id
      and public.tourists.verification_status = 'pending'
  ) then
    raise exception 'Pending registration application not found.';
  end if;

  if p_validate_only then
    return jsonb_build_object('valid', true, 'deleted', false);
  end if;

  if v_role = 'citizen' then
    delete from public.citizens
    where public.citizens.profile_id = p_profile_id
      and public.citizens.verification_status = 'pending';
  else
    delete from public.tourists
    where public.tourists.profile_id = p_profile_id
      and public.tourists.verification_status = 'pending';
  end if;

  get diagnostics v_deleted_rows = row_count;
  if v_deleted_rows <> 1 then
    raise exception 'Pending registration application not found.';
  end if;

  delete from public.profiles
  where public.profiles.id = p_profile_id
    and public.profiles.auth_id is null;

  get diagnostics v_deleted_rows = row_count;
  if v_deleted_rows <> 1 then
    raise exception 'Pending registration profile could not be deleted.';
  end if;

  return jsonb_build_object('valid', true, 'deleted', true);
end;
$$;

revoke all on function public.module400_delete_pending_application(uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.module400_delete_pending_application(uuid, boolean)
  to service_role;

comment on function public.module400_delete_pending_application(uuid, boolean) is
  'Atomically deletes a pending Module 400 Citizen/Tourist role row and profile.';

notify pgrst, 'reload schema';

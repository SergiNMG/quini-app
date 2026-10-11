-- F1.7: one-time, server-only promotion of the first invited Auth user.
-- Auth creation/invitation remains in Supabase Auth Admin API; this RPC only promotes.
create function public.bootstrap_first_admin(p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  candidate_role public.user_role;
  candidate_active boolean;
  candidate_invitation text;
  email_confirmed timestamptz;
begin
  -- Serialize competing bootstrap requests, then lock the target profile.
  perform pg_catalog.pg_advisory_xact_lock(134757153, 1);

  if exists (select 1 from public.profiles where role = 'ADMIN'::public.user_role) then
    raise exception using errcode = 'P0001', message = 'An administrator already exists';
  end if;

  select p.role, p.activo, p.invitation_code_used, u.email_confirmed_at
    into candidate_role, candidate_active, candidate_invitation, email_confirmed
    from public.profiles p
    join auth.users u on u.id = p.id
   where p.id = p_profile_id
   for update of p;

  if not found then
    raise exception using errcode = 'P0001', message = 'Bootstrap profile not found';
  end if;
  if candidate_role <> 'PLAYER'::public.user_role or not candidate_active then
    raise exception using errcode = 'P0001', message = 'Bootstrap target must be an active PLAYER';
  end if;
  if email_confirmed is null then
    raise exception using errcode = 'P0001', message = 'Bootstrap email must be confirmed first';
  end if;
  if candidate_invitation is null or not exists (
    select 1 from public.invitation_codes i
     where i.code = candidate_invitation and i.usado and i.usado_por = p_profile_id
  ) then
    raise exception using errcode = 'P0001', message = 'Bootstrap target must have consumed a valid invitation';
  end if;

  update public.profiles
     set role = 'ADMIN'::public.user_role
   where id = p_profile_id and role = 'PLAYER'::public.user_role and activo;
  if not found then
    raise exception using errcode = 'P0001', message = 'Bootstrap profile changed concurrently';
  end if;
end;
$$;

revoke all on function public.bootstrap_first_admin(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.bootstrap_first_admin(uuid) to service_role;

comment on function public.bootstrap_first_admin(uuid) is
  'One-time server-only bootstrap. Promotes exactly one active, email-confirmed, invitation-backed PLAYER when no ADMIN profile exists.';

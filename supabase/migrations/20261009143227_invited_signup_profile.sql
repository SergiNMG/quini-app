-- F1.6: authoritative invitation gate and profile provisioning in the Auth txn.
-- Direct auth.users creation/signUp without an unused invitation fails closed.
create function public.handle_invited_signup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  invite_code text;
  requested_username text;
  claimed_code text;
begin
  invite_code := nullif(btrim(new.raw_user_meta_data ->> 'invitation_code'), '');
  requested_username := nullif(btrim(new.raw_user_meta_data ->> 'username'), '');

  if invite_code is null then
    raise exception using errcode = 'P0001', message = 'A valid invitation code is required';
  end if;
  if requested_username is null then
    raise exception using errcode = 'P0001', message = 'A non-empty username is required';
  end if;
  if new.email is null or btrim(new.email) = '' then
    raise exception using errcode = 'P0001', message = 'An email address is required';
  end if;

  -- Profile insertion and conditional invite consumption execute inside the same
  -- transaction that inserts auth.users. Any later error rolls all three back.
  -- The unique, conditional UPDATE acquires the invite row lock and lets at most
  -- one concurrent Auth creation consume this code.
  insert into public.profiles (
    id, username, email, role, activo, invitation_code_used
  ) values (
    new.id, requested_username, new.email, 'PLAYER'::public.user_role, true, invite_code
  );

  update public.invitation_codes
     set usado = true,
         usado_por = new.id
   where code = invite_code
     and usado = false
     and usado_por is null
  returning code into claimed_code;

  if not found then
    raise exception using errcode = 'P0001', message = 'Invitation code is invalid or already used';
  end if;

  -- raw_user_meta_data is caller-controlled. In particular, never derive role,
  -- activo, email or other privileged profile fields from it.
  return new;
end;
$$;

revoke all on function public.handle_invited_signup()
  from public, anon, authenticated, service_role;
grant execute on function public.handle_invited_signup() to supabase_auth_admin;

create trigger trg_auth_user_invited_profile
  after insert on auth.users
  for each row execute function public.handle_invited_signup();

comment on function public.handle_invited_signup() is
  'Atomically consumes an unused invitation and provisions a PLAYER profile in the auth.users insert transaction. Client metadata can never choose role or activo.';

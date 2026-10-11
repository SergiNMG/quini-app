-- F1.6: Auth signup, invite consumption and profile provisioning are atomic.
begin;
set local statement_timeout = '30s';
set local lock_timeout = '5s';
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
-- @fixtures
create temporary table tap_results (position integer primary key, line text);
insert into pg_temp.tap_results select 0, plan(23);

insert into public.invitation_codes (id, code) values
  ('93000000-0000-4000-8000-000000000001', 'F16-VALID-ONE'),
  ('93000000-0000-4000-8000-000000000002', 'F16-ROLLBACK'),
  ('93000000-0000-4000-8000-000000000003', 'F16-EMPTY-USERNAME');

insert into pg_temp.tap_results select 1, ok(
  exists(select 1 from pg_trigger t where t.tgrelid = 'auth.users'::regclass
    and t.tgname = 'trg_auth_user_invited_profile' and not t.tgisinternal
    and t.tgfoid = 'public.handle_invited_signup()'::regprocedure),
  'Auth users has the invitation profile trigger'
);
insert into pg_temp.tap_results select 2, ok(
  (select p.prosecdef and p.proconfig @> array['search_path=""']
    and has_function_privilege('supabase_auth_admin', p.oid, 'execute')
    and not has_function_privilege('anon', p.oid, 'execute')
    and not has_function_privilege('authenticated', p.oid, 'execute')
    and not has_function_privilege('service_role', p.oid, 'execute')
    from pg_proc p where p.oid = 'public.handle_invited_signup()'::regprocedure),
  'Signup trigger is schema-isolated SECURITY DEFINER and not callable by API roles'
);
insert into pg_temp.tap_results select 3, throws_ok(
  $sql$insert into auth.users (id, email, raw_user_meta_data)
    values ('63000000-0000-4000-8000-000000000002', 'missing@example.invalid', jsonb_build_object('username', 'missing.code'))$sql$,
  'P0001', null::text, 'Auth creation without invitation is rejected'
);
insert into pg_temp.tap_results select 4, throws_ok(
  $sql$insert into auth.users (id, email, raw_user_meta_data)
    values ('63000000-0000-4000-8000-000000000003', 'invalid@example.invalid', jsonb_build_object('username', 'invalid.code', 'invitation_code', 'INVALID'))$sql$,
  'P0001', null::text, 'Auth creation with unknown invitation is rejected'
);
insert into pg_temp.tap_results select 5, ok(
  (select not usado and usado_por is null from public.invitation_codes
    where id = '93000000-0000-4000-8000-000000000001'),
  'Invalid signup leaves a valid invitation unused'
);
insert into pg_temp.tap_results select 6, throws_ok(
  $sql$insert into auth.users (id, email, raw_user_meta_data)
    values ('63000000-0000-4000-8000-000000000004', 'empty@example.invalid', jsonb_build_object('username', '   ', 'invitation_code', 'F16-EMPTY-USERNAME'))$sql$,
  'P0001', null::text, 'Whitespace-only username is rejected'
);
insert into pg_temp.tap_results select 7, is(
  (select count(*)::integer from auth.users where id in (
    '63000000-0000-4000-8000-000000000002',
    '63000000-0000-4000-8000-000000000003',
    '63000000-0000-4000-8000-000000000004')),
  0, 'Rejected Auth users are rolled back'
);
insert into pg_temp.tap_results select 8, is(
  (select count(*)::integer from public.profiles where id in (
    '63000000-0000-4000-8000-000000000002',
    '63000000-0000-4000-8000-000000000003',
    '63000000-0000-4000-8000-000000000004')),
  0, 'Rejected signups do not leave orphan profiles'
);
insert into pg_temp.tap_results select 9, ok(
  (select not usado and usado_por is null from public.invitation_codes
    where id = '93000000-0000-4000-8000-000000000003'),
  'Validation error leaves its invitation unused'
);

-- Caller metadata contains deliberately malicious role/active/email values.
-- The trigger must use auth.users.email and hard-code a PLAYER profile.
insert into auth.users (id, email, raw_user_meta_data) values (
  '63000000-0000-4000-8000-000000000001',
  'signup-primary@example.invalid',
  jsonb_build_object('username', '  invited.player  ', 'invitation_code', ' F16-VALID-ONE ',
    'role', 'ADMIN', 'activo', 'false', 'email', 'spoofed@example.invalid')
);
insert into pg_temp.tap_results select 10, ok(
  exists(select 1 from auth.users where id = '63000000-0000-4000-8000-000000000001'
    and email = 'signup-primary@example.invalid'),
  'Successful signup creates the Auth account'
);
insert into pg_temp.tap_results select 11, ok(
  (select p.id = '63000000-0000-4000-8000-000000000001'::uuid
    and p.username = 'invited.player' and p.email = 'signup-primary@example.invalid'
    and p.role = 'PLAYER'::public.user_role and p.activo
    and p.invitation_code_used = 'F16-VALID-ONE'
    from public.profiles p where p.id = '63000000-0000-4000-8000-000000000001'),
  'Valid signup creates a normalized PLAYER profile from trusted Auth fields'
);
insert into pg_temp.tap_results select 12, ok(
  (select u.email = 'signup-primary@example.invalid'
    and u.raw_user_meta_data ->> 'role' = 'ADMIN'
    and u.raw_user_meta_data ->> 'activo' = 'false'
    from auth.users u where u.id = '63000000-0000-4000-8000-000000000001'),
  'Untrusted role/active/email metadata cannot override profile fields'
);
insert into pg_temp.tap_results select 13, ok(
  (select usado and usado_por = '63000000-0000-4000-8000-000000000001'::uuid
    from public.invitation_codes where id = '93000000-0000-4000-8000-000000000001'),
  'Successful Auth creation consumes the invitation for its profile'
);
insert into pg_temp.tap_results select 14, ok(
  (select not usado and usado_por is null from public.invitation_codes
    where id = '93000000-0000-4000-8000-000000000002'),
  'A code remains unused until its Auth creation completes profile provisioning'
);
insert into pg_temp.tap_results select 15, throws_ok(
  $sql$insert into auth.users (id, email, raw_user_meta_data)
    values ('63000000-0000-4000-8000-000000000005', 'duplicate@example.invalid', jsonb_build_object('username', 'invited.player', 'invitation_code', 'F16-ROLLBACK'))$sql$,
  '23505', null::text, 'Duplicate username fails profile provisioning'
);
insert into pg_temp.tap_results select 16, ok(
  (select not usado and usado_por is null from public.invitation_codes
    where id = '93000000-0000-4000-8000-000000000002'),
  'Profile conflict does not consume the invitation'
);
insert into pg_temp.tap_results select 17, is(
  (select count(*)::integer from auth.users where id = '63000000-0000-4000-8000-000000000005'),
  0, 'Profile conflict rolls back auth.users insertion'
);
insert into pg_temp.tap_results select 18, throws_ok(
  $sql$insert into auth.users (id, email, raw_user_meta_data)
    values ('63000000-0000-4000-8000-000000000006', 'signup-reuse@example.invalid', jsonb_build_object('username', 'another.player', 'invitation_code', 'F16-VALID-ONE'))$sql$,
  'P0001', null::text, 'A used invitation cannot create a second Auth user'
);
insert into pg_temp.tap_results select 19, is(
  (select count(*)::integer from auth.users where id = '63000000-0000-4000-8000-000000000006'),
  0, 'Reused invitation leaves no Auth user'
);
insert into pg_temp.tap_results select 20, is(
  (select count(*)::integer from public.profiles where username = 'another.player'),
  0, 'Reused invitation leaves no profile'
);
insert into pg_temp.tap_results select 21, is(
  (select count(*)::integer from public.profiles where id = '63000000-0000-4000-8000-000000000001'),
  1, 'Exactly one profile is linked to the successful Auth account'
);
insert into pg_temp.tap_results select 22, is(
  (select count(*)::integer from public.invitation_codes
    where usado and usado_por = '63000000-0000-4000-8000-000000000001'),
  1, 'Successful account owns exactly one consumed invite'
);
insert into pg_temp.tap_results select 23, ok(
  not exists(select 1 from public.profiles p left join auth.users u on u.id = p.id where u.id is null),
  'All Auth-triggered profiles reference an Auth user'
);

insert into pg_temp.tap_results select 1000, finish();
select line as tap from pg_temp.tap_results order by position;
rollback;

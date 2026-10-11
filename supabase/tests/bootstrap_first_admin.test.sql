-- F1.7: only the server-side bootstrap may promote one invited admin.
begin;
set local statement_timeout = '30s';
set local lock_timeout = '5s';
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
-- @fixtures
create temporary table tap_results (position integer primary key, line text);
insert into pg_temp.tap_results select 0, plan(13);

insert into public.invitation_codes (id, code) values
  ('95000000-0000-4000-8000-000000000001', 'SQL_BOOTSTRAP_A'),
  ('95000000-0000-4000-8000-000000000002', 'SQL_BOOTSTRAP_B');
insert into auth.users (id, email, raw_user_meta_data) values
  ('65000000-0000-4000-8000-000000000001', 'bootstrap-a@example.invalid',
    jsonb_build_object('username', '__sql_bootstrap_a', 'invitation_code', 'SQL_BOOTSTRAP_A')),
  ('65000000-0000-4000-8000-000000000002', 'bootstrap-b@example.invalid',
    jsonb_build_object('username', '__sql_bootstrap_b', 'invitation_code', 'SQL_BOOTSTRAP_B'));

insert into pg_temp.tap_results select 1, ok(
  (select p.prosecdef and p.proconfig @> array['search_path=""']
    and has_function_privilege('service_role', p.oid, 'execute')
    and not has_function_privilege('anon', p.oid, 'execute')
    and not has_function_privilege('authenticated', p.oid, 'execute')
    from pg_proc p where p.oid = 'public.bootstrap_first_admin(uuid)'::regprocedure),
  'Bootstrap RPC is isolated and callable only by the trusted service role'
);
insert into pg_temp.tap_results select 2, ok(
  position('pg_advisory_xact_lock' in pg_get_functiondef('public.bootstrap_first_admin(uuid)'::regprocedure)) > 0,
  'Bootstrap serializes competing first-admin promotions'
);
insert into pg_temp.tap_results select 3, is(
  (select count(*)::integer from public.profiles where role = 'PLAYER'::public.user_role),
  2, 'The invitations create ordinary PLAYER profiles before bootstrap'
);

update public.profiles set activo = false where id = '65000000-0000-4000-8000-000000000002';
insert into pg_temp.tap_results select 4, throws_ok(
  $$select public.bootstrap_first_admin('65000000-0000-4000-8000-000000000002')$$,
  'P0001', null::text, 'An inactive PLAYER cannot become the first admin'
);
insert into pg_temp.tap_results select 5, is(
  (select count(*)::integer from public.profiles where role = 'ADMIN'::public.user_role),
  0, 'Rejected bootstrap leaves no administrator'
);
update public.profiles set activo = true where id = '65000000-0000-4000-8000-000000000002';
insert into pg_temp.tap_results select 6, throws_ok(
  $$select public.bootstrap_first_admin('65000000-0000-4000-8000-000000000001')$$,
  'P0001', null::text, 'An unconfirmed Auth email cannot become the first admin'
);
insert into pg_temp.tap_results select 7, is(
  (select role::text from public.profiles where id = '65000000-0000-4000-8000-000000000001'),
  'PLAYER', 'Unconfirmed target remains an ordinary player'
);

update auth.users set email_confirmed_at = clock_timestamp()
  where id = '65000000-0000-4000-8000-000000000001';
set local role service_role;
select public.bootstrap_first_admin('65000000-0000-4000-8000-000000000001');
reset role;
insert into pg_temp.tap_results select 8, ok(
  (select role = 'ADMIN'::public.user_role and activo
    from public.profiles where id = '65000000-0000-4000-8000-000000000001'),
  'Service-role bootstrap promotes the selected active, confirmed PLAYER'
);
insert into pg_temp.tap_results select 9, ok(
  (select usado and usado_por = '65000000-0000-4000-8000-000000000001'::uuid
    from public.invitation_codes where id = '95000000-0000-4000-8000-000000000001'),
  'Bootstrap profile is backed by its consumed invitation'
);
insert into pg_temp.tap_results select 10, is(
  (select role::text from public.profiles where id = '65000000-0000-4000-8000-000000000002'),
  'PLAYER', 'Other invited players remain players'
);
insert into pg_temp.tap_results select 11, throws_ok(
  $$select public.bootstrap_first_admin('65000000-0000-4000-8000-000000000002')$$,
  'P0001', null::text, 'Once an admin exists no other profile can use bootstrap'
);
insert into pg_temp.tap_results select 12, is(
  (select count(*)::integer from public.profiles where role = 'ADMIN'::public.user_role),
  1, 'Exactly one initial administrator is created'
);
insert into pg_temp.tap_results select 13, ok(
  not exists(select 1 from public.profiles p left join auth.users u on u.id = p.id where u.id is null),
  'Bootstrap creates no profile without an Auth identity'
);

insert into pg_temp.tap_results select 1000, finish();
select line as tap from pg_temp.tap_results order by position;
rollback;

-- F1.5: virtual participants are explicit NULL sides, never Auth users.
-- Replaced profiles remain FK-linked and historical rows are not rewritten.
begin;
set local statement_timeout = '30s';
set local lock_timeout = '5s';
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
-- @fixtures
create temporary table tap_results (position integer primary key, line text);
insert into pg_temp.tap_results select 0, plan(27);

insert into auth.users (id) values
  ('62000000-0000-4000-8000-000000000001'),
  ('62000000-0000-4000-8000-000000000002'),
  ('62000000-0000-4000-8000-000000000003'),
  ('62000000-0000-4000-8000-000000000004');
insert into public.profiles (id, username, email) values
  ('62000000-0000-4000-8000-000000000001', '__sql_virtual_a', 'virtual-a@example.invalid'),
  ('62000000-0000-4000-8000-000000000002', '__sql_virtual_b', 'virtual-b@example.invalid'),
  ('62000000-0000-4000-8000-000000000003', '__sql_virtual_c', 'virtual-c@example.invalid'),
  ('62000000-0000-4000-8000-000000000004', '__sql_virtual_d', 'virtual-d@example.invalid');
update public.profiles set activo = false
  where id in ('62000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000004');
insert into public.seasons (id, nombre, fecha_inicio)
values ('32000000-0000-4000-8000-000000000001', 'SQL virtual season', '2026-01-01');
insert into public.matchdays (id, season_id, numero)
values ('42000000-0000-4000-8000-000000000001', '32000000-0000-4000-8000-000000000001', 1);

insert into public.duels (id, matchday_id, player_a_id, player_b_id)
values ('72000000-0000-4000-8000-000000000001', '42000000-0000-4000-8000-000000000001',
  '62000000-0000-4000-8000-000000000002', '62000000-0000-4000-8000-000000000003');

insert into pg_temp.tap_results select 1, is(
  (select count(*)::integer from pg_constraint
    where contype = 'f' and connamespace = 'public'::regnamespace
      and confdeltype = 'r' and confupdtype = 'r'),
  14, 'Both replacement references also preserve their profiles');
insert into pg_temp.tap_results select 2, ok(
  (select player_a_id = '62000000-0000-4000-8000-000000000002'::uuid
      and player_b_id = '62000000-0000-4000-8000-000000000003'::uuid
      and player_a_replaced_id is null and player_b_replaced_id is null
    from public.duels where id = '72000000-0000-4000-8000-000000000001'),
  'Existing real duels remain byte-for-byte participant identities');
insert into pg_temp.tap_results select 3, ok(
  (select is_nullable = 'YES' from information_schema.columns
    where table_schema = 'public' and table_name = 'duels' and column_name = 'player_a_id')
  and (select is_nullable = 'YES' from information_schema.columns
    where table_schema = 'public' and table_name = 'duels' and column_name = 'player_b_id'),
  'Either duel side may be represented without an Auth profile');
insert into pg_temp.tap_results select 4, ok(
  (select count(*) = 2 from pg_indexes where schemaname = 'public'
    and indexname in ('idx_duels_player_a_replaced', 'idx_duels_player_b_replaced')),
  'Replacement foreign keys have indexes');
insert into pg_temp.tap_results select 5, is(
  (select count(*)::integer from public.profiles
    where id in ('62000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000004')),
  2, 'Virtual fixture identities remain ordinary retained profiles, not virtual Auth accounts');

insert into public.duels (id, matchday_id, player_a_id, player_b_id, player_b_replaced_id)
values ('72000000-0000-4000-8000-000000000002', '42000000-0000-4000-8000-000000000001',
  '62000000-0000-4000-8000-000000000002', null, '62000000-0000-4000-8000-000000000001');
insert into pg_temp.tap_results select 6, ok(
  (select player_a_id = '62000000-0000-4000-8000-000000000002'::uuid
      and player_a_replaced_id is null and player_b_id is null
      and player_b_replaced_id = '62000000-0000-4000-8000-000000000001'::uuid
    from public.duels where id = '72000000-0000-4000-8000-000000000002'),
  'A real player can face an explicit virtual replacement of an inactive profile');

insert into public.duels (id, matchday_id, player_a_id, player_a_replaced_id, player_b_id)
values ('72000000-0000-4000-8000-000000000003', '42000000-0000-4000-8000-000000000001',
  null, '62000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000003');
insert into pg_temp.tap_results select 7, ok(
  (select player_a_id is null and player_a_replaced_id = '62000000-0000-4000-8000-000000000001'::uuid
      and player_b_id = '62000000-0000-4000-8000-000000000003'::uuid and player_b_replaced_id is null
    from public.duels where id = '72000000-0000-4000-8000-000000000003'),
  'The virtual side can be stored in position A too');

insert into public.duels (id, matchday_id, player_a_replaced_id, player_b_replaced_id)
values ('72000000-0000-4000-8000-000000000004', '42000000-0000-4000-8000-000000000001',
  '62000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000004');
insert into pg_temp.tap_results select 8, ok(
  (select player_a_id is null and player_b_id is null
      and player_a_replaced_id = '62000000-0000-4000-8000-000000000001'::uuid
      and player_b_replaced_id = '62000000-0000-4000-8000-000000000004'::uuid
    from public.duels where id = '72000000-0000-4000-8000-000000000004'),
  'A future virtual-versus-virtual duel retains both replaced profiles');

insert into pg_temp.tap_results select 9, throws_ok(
  $sql$insert into public.duels (matchday_id, player_a_id, player_b_id)
    values ('42000000-0000-4000-8000-000000000001', null, '62000000-0000-4000-8000-000000000002')$sql$,
  '23514', null::text, 'A null participant without replacement provenance is invalid');
insert into pg_temp.tap_results select 10, throws_ok(
  $sql$insert into public.duels (matchday_id, player_a_id, player_a_replaced_id, player_b_id)
    values ('42000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000002', '62000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000003')$sql$,
  '23514', null::text, 'A real participant cannot also be marked virtual');
insert into pg_temp.tap_results select 11, throws_ok(
  $sql$insert into public.duels (matchday_id, player_a_id, player_b_id)
    values ('42000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000002', '62000000-0000-4000-8000-000000000002')$sql$,
  '23514', null::text, 'A real player cannot duel themself');
insert into pg_temp.tap_results select 12, throws_ok(
  $sql$insert into public.duels (matchday_id, player_a_replaced_id, player_b_replaced_id)
    values ('42000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000001')$sql$,
  '23514', null::text, 'The same inactive player cannot occupy both replaced sides');
insert into pg_temp.tap_results select 13, throws_ok(
  $sql$insert into public.duels (matchday_id, player_a_replaced_id, player_b_id)
    values ('42000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000001')$sql$,
  '23514', null::text, 'A player cannot be paired against their own virtual replacement');
insert into pg_temp.tap_results select 14, throws_ok(
  $sql$insert into public.duels (matchday_id, player_b_replaced_id, player_a_id)
    values ('42000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000002', '62000000-0000-4000-8000-000000000003')$sql$,
  '23514', null::text, 'An active profile cannot be recorded as a retired replacement');
insert into pg_temp.tap_results select 15, throws_ok(
  $sql$insert into public.duels (matchday_id, player_a_id, player_b_replaced_id)
    values ('42000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000004')$sql$,
  '23514', null::text, 'An inactive profile cannot be newly assigned as a real opponent');
insert into pg_temp.tap_results select 16, throws_ok(
  $sql$insert into public.duels (matchday_id, player_a_id, player_b_replaced_id)
    values ('42000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000002', 'ffffffff-ffff-4fff-8fff-ffffffffffff')$sql$,
  '23503', null::text, 'Replacement provenance must reference a retained profile');

update public.duels set aciertos_a = 0, aciertos_b = 0, puntos_a = 1, puntos_b = 0, resultado = 'EMPATE'
  where id = '72000000-0000-4000-8000-000000000002';
insert into pg_temp.tap_results select 17, lives_ok(
  $sql$update public.duels set aciertos_a = 0, aciertos_b = 0, puntos_a = 1, puntos_b = 0, resultado = 'EMPATE' where id = '72000000-0000-4000-8000-000000000002'$sql$,
  'The real side may receive a one-point draw while the virtual side scores zero');
insert into pg_temp.tap_results select 18, throws_ok(
  $sql$update public.duels set aciertos_b = 1 where id = '72000000-0000-4000-8000-000000000002'$sql$,
  '23514', null::text, 'Virtual side can never accumulate hits');
insert into pg_temp.tap_results select 19, throws_ok(
  $sql$update public.duels set puntos_b = 1 where id = '72000000-0000-4000-8000-000000000002'$sql$,
  '23514', null::text, 'Virtual side can never earn points');
update public.duels set aciertos_a = 0, aciertos_b = 0, puntos_a = 0, puntos_b = 0, resultado = null
  where id = '72000000-0000-4000-8000-000000000004';
insert into pg_temp.tap_results select 20, ok(
  (select aciertos_a = 0 and aciertos_b = 0 and puntos_a = 0 and puntos_b = 0 and resultado is null
    from public.duels where id = '72000000-0000-4000-8000-000000000004'),
  'Virtual versus virtual can be represented as resolved and non-scoring');
insert into pg_temp.tap_results select 21, throws_ok(
  $sql$update public.duels set aciertos_a = 1 where id = '72000000-0000-4000-8000-000000000004'$sql$,
  '23514', null::text, 'Neither virtual-versus-virtual side may accrue hits');

insert into pg_temp.tap_results select 22, throws_ok(
  $sql$update public.duels set player_b_replaced_id = '62000000-0000-4000-8000-000000000004' where id = '72000000-0000-4000-8000-000000000002'$sql$,
  '55000', null::text, 'Virtual replacement provenance is immutable after publication');
insert into pg_temp.tap_results select 23, throws_ok(
  $sql$update public.duels set player_b_id = '62000000-0000-4000-8000-000000000003', player_b_replaced_id = null where id = '72000000-0000-4000-8000-000000000002'$sql$,
  '55000', null::text, 'An existing virtual opponent cannot be converted into a real player');

update public.profiles set activo = true where id = '62000000-0000-4000-8000-000000000001';
insert into pg_temp.tap_results select 24, ok(
  (select player_b_id is null and player_b_replaced_id = '62000000-0000-4000-8000-000000000001'::uuid
      and puntos_b = 0 from public.duels where id = '72000000-0000-4000-8000-000000000002'),
  'Later reactivation does not turn an already published virtual side back into a real player');

-- The old real-vs-real duel must remain unchanged despite the later soft deletion.
insert into pg_temp.tap_results select 25, ok(
  (select player_a_id = '62000000-0000-4000-8000-000000000002'::uuid
      and player_b_id = '62000000-0000-4000-8000-000000000003'::uuid
      and player_a_replaced_id is null and player_b_replaced_id is null
    from public.duels where id = '72000000-0000-4000-8000-000000000001'),
  'Existing published real duel is not retroactively virtualized');
insert into pg_temp.tap_results select 26, ok(
  (select array_agg(t.tgname::text order by t.tgname)
    from pg_trigger t where t.tgrelid = 'public.duels'::regclass
      and not t.tgisinternal and t.tgtype = 7)
    = array['trg_duels_00_structure', 'trg_duels_01_participant_state'],
  'Duel insertion locks matchday/season before sorted participant profiles');
insert into pg_temp.tap_results select 27, ok(
  (select p.prosecdef and p.proconfig @> array['search_path=""']
    and not has_function_privilege('anon', p.oid, 'execute')
    and not has_function_privilege('authenticated', p.oid, 'execute')
    and not has_function_privilege('service_role', p.oid, 'execute')
    from pg_proc p where p.oid = 'public.guard_duel_participants()'::regprocedure),
  'SECURITY DEFINER trigger is schema-isolated and not an API-callable RPC');

insert into pg_temp.tap_results select 1000, finish();
select line as tap from pg_temp.tap_results order by position;
rollback;

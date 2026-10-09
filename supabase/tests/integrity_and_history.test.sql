-- F1.4 integrity regression suite. Test identities/accounts are fictitious and rolled back.
-- Authorization, scoring and five-match atomicity remain later tasks.
begin;
set local statement_timeout = '30s';
set local lock_timeout = '5s';
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
-- @fixtures
create temporary table tap_results (position integer primary key, line text);
insert into pg_temp.tap_results select 0, plan(62);

insert into auth.users (id) values ('61000000-0000-4000-8000-000000000001'), ('61000000-0000-4000-8000-000000000002'), ('61000000-0000-4000-8000-000000000003');
insert into public.profiles (id, username, email) values
  ('61000000-0000-4000-8000-000000000001', '__sql_integrity_a', 'integrity-a@example.invalid'),
  ('61000000-0000-4000-8000-000000000002', '__sql_integrity_b', 'integrity-b@example.invalid'),
  ('61000000-0000-4000-8000-000000000003', '__sql_integrity_c', 'integrity-c@example.invalid');
insert into public.seasons (id, nombre, fecha_inicio) values
  ('31000000-0000-4000-8000-000000000001', 'SQL integrity season', '2026-01-01'),
  ('31000000-0000-4000-8000-000000000002', 'SQL integrity other season', '2026-01-01');
insert into public.matchdays (id, season_id, numero) values
  ('41000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000001', 1), ('41000000-0000-4000-8000-000000000002', '31000000-0000-4000-8000-000000000001', 2);
insert into public.matches (id, matchday_id, competition_id, equipo_local_id, equipo_visitante_id) values
  ('51000000-0000-4000-8000-000000000001', '41000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000002'),
  ('51000000-0000-4000-8000-000000000002', '41000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000004');
insert into public.duels (id, matchday_id, player_a_id, player_b_id)
  values ('71000000-0000-4000-8000-000000000001', '41000000-0000-4000-8000-000000000001', '61000000-0000-4000-8000-000000000001', '61000000-0000-4000-8000-000000000002');
insert into public.predictions (id, match_id, player_id, pronostico)
  values ('81000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000001', '61000000-0000-4000-8000-000000000001', '1');
insert into public.invitation_codes (id, code, usado, usado_por) values
  ('91000000-0000-4000-8000-000000000001', 'SQL_F14_USED', true, '61000000-0000-4000-8000-000000000001'),
  ('91000000-0000-4000-8000-000000000002', 'SQL_F14_UNUSED', false, null);

insert into pg_temp.tap_results select 1, is((select count(*)::integer from pg_constraint
  where contype = 'f' and connamespace = 'public'::regnamespace
    and confdeltype = 'r' and confupdtype = 'r'), 14, 'All profile references restrict deletion and rekeying, including virtual provenance');

insert into pg_temp.tap_results select 2, throws_ok($statement$delete from auth.users where id='61000000-0000-4000-8000-000000000001'$statement$, '23503', null::text, 'Auth deletion cannot cascade into profiles/history');

insert into pg_temp.tap_results select 3, throws_ok($statement$delete from public.profiles where id='61000000-0000-4000-8000-000000000001'$statement$, '55000', null::text, 'Retained profiles cannot be physically deleted');

insert into pg_temp.tap_results select 4, throws_ok($statement$delete from public.teams where id='20000000-0000-4000-8000-000000000001'$statement$, '55000', null::text, 'Retained teams cannot be physically deleted');

insert into pg_temp.tap_results select 5, throws_ok($statement$delete from public.competitions where id='10000000-0000-4000-8000-000000000001'$statement$, '55000', null::text, 'Retained competitions cannot be physically deleted');

insert into pg_temp.tap_results select 6, throws_ok($statement$delete from public.seasons where id='31000000-0000-4000-8000-000000000001'$statement$, '55000', null::text, 'Retained seasons cannot be physically deleted');

insert into pg_temp.tap_results select 7, throws_ok($statement$delete from public.matchdays where id='41000000-0000-4000-8000-000000000001'$statement$, '55000', null::text, 'Retained matchdays cannot be physically deleted');

insert into pg_temp.tap_results select 8, throws_ok($statement$delete from public.matches where id='51000000-0000-4000-8000-000000000001'$statement$, '55000', null::text, 'Retained matches cannot be physically deleted');

insert into pg_temp.tap_results select 9, throws_ok($statement$delete from public.predictions where id='81000000-0000-4000-8000-000000000001'$statement$, '55000', null::text, 'Retained predictions cannot be physically deleted');

insert into pg_temp.tap_results select 10, throws_ok($statement$delete from public.duels where id='71000000-0000-4000-8000-000000000001'$statement$, '55000', null::text, 'Retained duels cannot be physically deleted');

insert into pg_temp.tap_results select 11, throws_ok($statement$delete from public.invitation_codes where id='91000000-0000-4000-8000-000000000001'$statement$, '55000', null::text, 'Retained invitation_codes cannot be physically deleted');

insert into pg_temp.tap_results select 12, lives_ok($statement$delete from public.invitation_codes where id='91000000-0000-4000-8000-000000000002'$statement$, 'Unused invitation can be deleted by a trusted authorized operation');

insert into pg_temp.tap_results select 13, throws_ok($statement$truncate public.teams cascade$statement$, '55000', null::text, 'TRUNCATE CASCADE cannot erase history');

insert into pg_temp.tap_results select 14, ok(not exists(
  select 1 from unnest(array['anon','authenticated','service_role']) r(role_name)
  cross join unnest(array['public.profiles','public.invitation_codes','public.competitions',
    'public.teams','public.seasons','public.matchdays','public.matches','public.predictions','public.duels']) t(table_name)
  where has_table_privilege(r.role_name,t.table_name,'DELETE')
    or has_table_privilege(r.role_name,t.table_name,'TRUNCATE')
), 'API roles have no ordinary DELETE or TRUNCATE privileges');

insert into pg_temp.tap_results select 15, throws_ok($statement$update public.competitions set id='ffffffff-ffff-4fff-8fff-ffffffffffff' where id='10000000-0000-4000-8000-000000000001'$statement$, '55000', null::text, 'Catalog identity is immutable');

insert into pg_temp.tap_results select 16, throws_ok($statement$update public.matchdays set season_id='31000000-0000-4000-8000-000000000002' where id='41000000-0000-4000-8000-000000000001'$statement$, '55000', null::text, 'A matchday cannot move to another season');

insert into pg_temp.tap_results select 17, throws_ok($statement$update public.matchdays set numero=3 where id='41000000-0000-4000-8000-000000000001'$statement$, '55000', null::text, 'A persisted matchday cannot be renumbered');

insert into pg_temp.tap_results select 18, throws_ok($statement$update public.matches set matchday_id='41000000-0000-4000-8000-000000000002' where id='51000000-0000-4000-8000-000000000001'$statement$, '55000', null::text, 'A match cannot move between matchdays');

insert into pg_temp.tap_results select 19, throws_ok($statement$update public.predictions set player_id='61000000-0000-4000-8000-000000000002' where id='81000000-0000-4000-8000-000000000001'$statement$, '55000', null::text, 'Prediction ownership is immutable');

insert into pg_temp.tap_results select 20, throws_ok($statement$update public.predictions set match_id='51000000-0000-4000-8000-000000000002' where id='81000000-0000-4000-8000-000000000001'$statement$, '55000', null::text, 'A prediction cannot move to another match');

insert into pg_temp.tap_results select 21, throws_ok($statement$update public.duels set player_b_id='61000000-0000-4000-8000-000000000003' where id='71000000-0000-4000-8000-000000000001'$statement$, '55000', null::text, 'A retained duel cannot be reassigned');

insert into pg_temp.tap_results select 22, throws_ok($statement$update public.invitation_codes set code='SQL_F14_REWRITTEN' where id='91000000-0000-4000-8000-000000000001'$statement$, '55000', null::text, 'Consumed invitation code is immutable');

insert into pg_temp.tap_results select 23, throws_ok($statement$update public.invitation_codes set usado=false where id='91000000-0000-4000-8000-000000000001'$statement$, '55000', null::text, 'Consumed invitation cannot be reset for reuse');

insert into pg_temp.tap_results select 24, throws_ok($statement$insert into public.matchdays(season_id,numero) values('31000000-0000-4000-8000-000000000001',0)$statement$, '23514', null::text, 'Zero matchday number is rejected');

insert into pg_temp.tap_results select 25, throws_ok($statement$insert into public.matchdays(season_id,numero) values('31000000-0000-4000-8000-000000000001',-1)$statement$, '23514', null::text, 'Negative matchday number is rejected');

insert into pg_temp.tap_results select 26, throws_ok($statement$update public.seasons set fecha_fin='2025-12-31' where id='31000000-0000-4000-8000-000000000001'$statement$, '23514', null::text, 'Season end cannot precede its start');

insert into pg_temp.tap_results select 27, throws_ok($statement$update public.matchdays set fecha_inicio='1900-01-01' where id='41000000-0000-4000-8000-000000000001'$statement$, '23514', null::text, 'Matchday cannot start before creation');

insert into pg_temp.tap_results select 28, throws_ok($statement$insert into public.seasons(nombre,estado) values('SQL invalid final season','FINALIZADA')$statement$, '23514', null::text, 'New seasons must start active');

insert into pg_temp.tap_results select 29, throws_ok($statement$insert into public.matchdays(season_id,numero,estado,fecha_inicio) values('31000000-0000-4000-8000-000000000001',3,'EN_CURSO',clock_timestamp())$statement$, '23514', null::text, 'New matchdays must start open');

insert into pg_temp.tap_results select 30, throws_ok($statement$update public.matchdays set estado='FINALIZADA',fecha_inicio=clock_timestamp() where id='41000000-0000-4000-8000-000000000001'$statement$, '23514', null::text, 'Open matchday cannot skip directly to finalized');

insert into pg_temp.tap_results select 31, throws_ok($statement$update public.duels set aciertos_a=-1,aciertos_b=2,puntos_a=0,puntos_b=3,resultado='B_GANA' where id='71000000-0000-4000-8000-000000000001'$statement$, '23514', null::text, 'Negative hit count is rejected');

insert into pg_temp.tap_results select 32, throws_ok($statement$update public.duels set aciertos_a=6,aciertos_b=2,puntos_a=3,puntos_b=0,resultado='A_GANA' where id='71000000-0000-4000-8000-000000000001'$statement$, '23514', null::text, 'Hit count above five is rejected');

insert into pg_temp.tap_results select 33, throws_ok($statement$update public.duels set aciertos_a=2,aciertos_b=6,puntos_a=0,puntos_b=3,resultado='B_GANA' where id='71000000-0000-4000-8000-000000000001'$statement$, '23514', null::text, 'Second player hit count above five is rejected');

insert into pg_temp.tap_results select 34, throws_ok($statement$update public.duels set aciertos_a=1,aciertos_b=1,puntos_a=2,puntos_b=1,resultado='EMPATE' where id='71000000-0000-4000-8000-000000000001'$statement$, '23514', null::text, 'Two points is not a valid score');

insert into pg_temp.tap_results select 35, throws_ok($statement$update public.duels set aciertos_a=1,aciertos_b=1,puntos_a=1,puntos_b=-1,resultado='EMPATE' where id='71000000-0000-4000-8000-000000000001'$statement$, '23514', null::text, 'Negative points are rejected');

insert into pg_temp.tap_results select 36, throws_ok($statement$update public.duels set aciertos_a=1 where id='71000000-0000-4000-8000-000000000001'$statement$, '23514', null::text, 'Partially calculated duel is rejected');

insert into pg_temp.tap_results select 37, throws_ok($statement$update public.duels set aciertos_a=3,aciertos_b=1,puntos_a=3,puntos_b=0,resultado=null where id='71000000-0000-4000-8000-000000000001'$statement$, '23514', null::text, 'NULL result does not bypass nonzero score consistency');

insert into pg_temp.tap_results select 38, throws_ok($statement$update public.duels set aciertos_a=3,aciertos_b=1,puntos_a=0,puntos_b=3,resultado='A_GANA' where id='71000000-0000-4000-8000-000000000001'$statement$, '23514', null::text, 'Outcome and point direction must agree');

insert into pg_temp.tap_results select 39, lives_ok($statement$update public.duels set aciertos_a=3,aciertos_b=1,puntos_a=3,puntos_b=0,resultado='A_GANA' where id='71000000-0000-4000-8000-000000000001'$statement$, 'Complete valid win is accepted');

insert into pg_temp.tap_results select 40, lives_ok($statement$update public.duels set aciertos_a=0,aciertos_b=0,puntos_a=0,puntos_b=0,resultado=null where id='71000000-0000-4000-8000-000000000001'$statement$, 'Resolved non-scoring duel is distinct from pending');

insert into pg_temp.tap_results select 41, lives_ok($statement$update public.duels set aciertos_a=0,aciertos_b=0,puntos_a=1,puntos_b=0,resultado='EMPATE' where id='71000000-0000-4000-8000-000000000001'$statement$, 'Score schema reserves asymmetric draw for future virtual opponent');

insert into pg_temp.tap_results select 42, lives_ok($statement$update public.profiles set activo=false where id='61000000-0000-4000-8000-000000000001'$statement$, 'Soft deletion preserves profile and historical assignments');

insert into pg_temp.tap_results select 43, is((select count(*)::integer from public.predictions where id='81000000-0000-4000-8000-000000000001' and player_id='61000000-0000-4000-8000-000000000001'),1,'Existing prediction survives deactivation');

insert into pg_temp.tap_results select 44, lives_ok($statement$update public.teams set activo=false where id='20000000-0000-4000-8000-000000000001'; update public.competitions set activo=false where id='10000000-0000-4000-8000-000000000001'$statement$, 'Catalog deactivation remains possible');

insert into pg_temp.tap_results select 45, throws_ok($statement$update public.matches set equipo_visitante_id='20000000-0000-4000-8000-000000000005' where id='51000000-0000-4000-8000-000000000001'$statement$, '23514', null::text, 'Predicted match cannot silently change teams while open');

insert into pg_temp.tap_results select 46, lives_ok($statement$update public.matchdays set estado='EN_CURSO',fecha_inicio=clock_timestamp() where id='41000000-0000-4000-8000-000000000001'$statement$, 'Admin lifecycle can start an open matchday');

insert into pg_temp.tap_results select 47, throws_ok($statement$update public.matchdays set estado='ABIERTA',fecha_inicio=null where id='41000000-0000-4000-8000-000000000001'$statement$, '23514', null::text, 'Started matchday cannot reopen');

insert into pg_temp.tap_results select 48, throws_ok($statement$insert into public.matches(matchday_id,competition_id,equipo_local_id,equipo_visitante_id) values('41000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000002')$statement$, '23514', null::text, 'Started matchday cannot gain a new match');

insert into pg_temp.tap_results select 49, throws_ok($statement$insert into public.duels(matchday_id,player_a_id,player_b_id) values('41000000-0000-4000-8000-000000000001','61000000-0000-4000-8000-000000000001','61000000-0000-4000-8000-000000000003')$statement$, '23514', null::text, 'Started matchday cannot gain a new duel');

insert into pg_temp.tap_results select 50, throws_ok($statement$insert into public.predictions(match_id,player_id,pronostico) values('51000000-0000-4000-8000-000000000002','61000000-0000-4000-8000-000000000003','X')$statement$, '23514', null::text, 'Started matchday cannot accept first prediction');

insert into pg_temp.tap_results select 51, throws_ok($statement$update public.matches set equipo_visitante_id='20000000-0000-4000-8000-000000000005' where id='51000000-0000-4000-8000-000000000002'$statement$, '23514', null::text, 'Even an unpredicted match cannot change teams after start');

insert into pg_temp.tap_results select 52, lives_ok($statement$update public.matchdays set estado='FINALIZADA' where id='41000000-0000-4000-8000-000000000001'$statement$, 'Started matchday can finalize');

insert into pg_temp.tap_results select 53, throws_ok($statement$update public.matchdays set estado='EN_CURSO' where id='41000000-0000-4000-8000-000000000001'$statement$, '23514', null::text, 'Finalized matchday cannot reopen');

update public.matchdays set estado='EN_CURSO',fecha_inicio=clock_timestamp() where id='41000000-0000-4000-8000-000000000002';
update public.matchdays set estado='FINALIZADA' where id='41000000-0000-4000-8000-000000000002';

insert into pg_temp.tap_results select 54, lives_ok($statement$update public.seasons set estado='FINALIZADA',fecha_fin='2026-12-31' where id='31000000-0000-4000-8000-000000000001'$statement$, 'Active season can close');

insert into pg_temp.tap_results select 55, throws_ok($statement$update public.seasons set estado='ACTIVA' where id='31000000-0000-4000-8000-000000000001'$statement$, '23514', null::text, 'Closed season cannot reopen');

insert into pg_temp.tap_results select 56, throws_ok($statement$insert into public.matchdays(season_id,numero) values('31000000-0000-4000-8000-000000000001',3)$statement$, '23514', null::text, 'Closed season cannot gain a new matchday');

insert into pg_temp.tap_results select 57, throws_ok($statement$insert into public.matches(matchday_id,competition_id,equipo_local_id,equipo_visitante_id) values('41000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000002')$statement$, '23514', null::text, 'Closed history cannot gain a new match');

insert into pg_temp.tap_results select 58, throws_ok($statement$insert into public.duels(matchday_id,player_a_id,player_b_id) values('41000000-0000-4000-8000-000000000001','61000000-0000-4000-8000-000000000001','61000000-0000-4000-8000-000000000003')$statement$, '23514', null::text, 'Closed history cannot gain a new duel');

insert into pg_temp.tap_results select 59, throws_ok($statement$insert into public.predictions(match_id,player_id,pronostico) values('51000000-0000-4000-8000-000000000002','61000000-0000-4000-8000-000000000003','X')$statement$, '23514', null::text, 'Closed history cannot gain a first prediction');

insert into pg_temp.tap_results select 60, lives_ok($statement$update public.predictions set pronostico='X',acierto=true where id='81000000-0000-4000-8000-000000000001'$statement$, 'Admin correction of an existing prediction remains possible in closed history');

insert into pg_temp.tap_results select 61, lives_ok($statement$update public.duels set aciertos_a=5,aciertos_b=1,puntos_a=3,puntos_b=0,resultado='A_GANA' where id='71000000-0000-4000-8000-000000000001'$statement$, 'Derived duel recalculation remains possible in closed history');

insert into pg_temp.tap_results select 62, is((select pronostico::text from public.predictions where id='81000000-0000-4000-8000-000000000001'),'X','Corrected prediction retains its historical owner and match');
insert into pg_temp.tap_results select 1000, finish();
select line as tap from pg_temp.tap_results order by position;
rollback;

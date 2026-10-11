-- F1.8 RLS/grants regression suite. All identities/data roll back.
begin;
set local statement_timeout='30s';
set local lock_timeout='5s';
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
-- @fixtures
create temporary table tap_results(position integer primary key,line text);
insert into pg_temp.tap_results select 0, plan(60);

insert into public.invitation_codes(id,code) values
 ('96000000-0000-4000-8000-000000000001','RLS_FIX_A'),('96000000-0000-4000-8000-000000000002','RLS_FIX_B'),('96000000-0000-4000-8000-000000000003','RLS_FIX_C'),('96000000-0000-4000-8000-000000000004','RLS_FIX_ADMIN'),('96000000-0000-4000-8000-000000000005','RLS_UNUSED');
insert into auth.users(id,email,raw_user_meta_data) values
 ('66000000-0000-4000-8000-000000000001','rls-a@example.invalid',jsonb_build_object('username','rls_a','invitation_code','RLS_FIX_A')),
 ('66000000-0000-4000-8000-000000000002','rls-b@example.invalid',jsonb_build_object('username','rls_b','invitation_code','RLS_FIX_B')),
 ('66000000-0000-4000-8000-000000000003','rls-c@example.invalid',jsonb_build_object('username','rls_c','invitation_code','RLS_FIX_C')),
 ('66000000-0000-4000-8000-000000000004','rls-admin@example.invalid',jsonb_build_object('username','rls_admin','invitation_code','RLS_FIX_ADMIN'));
update public.profiles set role='ADMIN' where id='66000000-0000-4000-8000-000000000004';
insert into public.seasons(id,nombre,fecha_inicio) values('33000000-0000-4000-8000-000000000001','SQL RLS season','2026-01-01');
insert into public.matchdays(id,season_id,numero) values
 ('43000000-0000-4000-8000-000000000001','33000000-0000-4000-8000-000000000001',1),('43000000-0000-4000-8000-000000000002','33000000-0000-4000-8000-000000000001',2),('43000000-0000-4000-8000-000000000003','33000000-0000-4000-8000-000000000001',3),('43000000-0000-4000-8000-000000000004','33000000-0000-4000-8000-000000000001',4);
insert into public.matches(id,matchday_id,competition_id,equipo_local_id,equipo_visitante_id) values
 ('53000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000002'),
 ('53000000-0000-4000-8000-000000000002','43000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000004'),
 ('53000000-0000-4000-8000-000000000003','43000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000005','20000000-0000-4000-8000-000000000006'),
 ('53000000-0000-4000-8000-000000000004','43000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000007','20000000-0000-4000-8000-000000000008');
insert into public.duels(id,matchday_id,player_a_id,player_b_id) values
 ('73000000-0000-4000-8000-000000000001','43000000-0000-4000-8000-000000000001','66000000-0000-4000-8000-000000000001','66000000-0000-4000-8000-000000000002'),('73000000-0000-4000-8000-000000000002','43000000-0000-4000-8000-000000000002','66000000-0000-4000-8000-000000000001','66000000-0000-4000-8000-000000000003'),('73000000-0000-4000-8000-000000000003','43000000-0000-4000-8000-000000000003','66000000-0000-4000-8000-000000000002','66000000-0000-4000-8000-000000000003');
insert into public.predictions(id,match_id,player_id,pronostico) values
 ('82000000-0000-4000-8000-000000000001','53000000-0000-4000-8000-000000000001','66000000-0000-4000-8000-000000000001','1'),('82000000-0000-4000-8000-000000000002','53000000-0000-4000-8000-000000000001','66000000-0000-4000-8000-000000000002','X'),
 ('82000000-0000-4000-8000-000000000003','53000000-0000-4000-8000-000000000002','66000000-0000-4000-8000-000000000001','1'),('82000000-0000-4000-8000-000000000004','53000000-0000-4000-8000-000000000002','66000000-0000-4000-8000-000000000002','X'),('82000000-0000-4000-8000-000000000005','53000000-0000-4000-8000-000000000002','66000000-0000-4000-8000-000000000003','2'),
 ('82000000-0000-4000-8000-000000000006','53000000-0000-4000-8000-000000000003','66000000-0000-4000-8000-000000000002','1'),
 ('82000000-0000-4000-8000-000000000007','53000000-0000-4000-8000-000000000003','66000000-0000-4000-8000-000000000003','X');
update public.matchdays set estado='EN_CURSO',fecha_inicio=clock_timestamp() where id='43000000-0000-4000-8000-000000000002';
update public.matchdays set estado='EN_CURSO',fecha_inicio=clock_timestamp() where id='43000000-0000-4000-8000-000000000003';
update public.matchdays set estado='FINALIZADA' where id='43000000-0000-4000-8000-000000000003';
update public.profiles set activo=false where id='66000000-0000-4000-8000-000000000003';
insert into public.duels(id,matchday_id,player_a_id,player_b_replaced_id)
 values('73000000-0000-4000-8000-000000000004','43000000-0000-4000-8000-000000000004','66000000-0000-4000-8000-000000000001','66000000-0000-4000-8000-000000000003');
grant insert on table pg_temp.tap_results to anon, authenticated;

insert into pg_temp.tap_results select 1, ok((select count(*)::int=9 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relrowsecurity and c.relname in ('profiles','invitation_codes','competitions','teams','seasons','matchdays','matches','predictions','duels')), 'RLS remains enabled on all nine app tables');
insert into pg_temp.tap_results select 2, ok((select has_schema_privilege('authenticated','private','USAGE') and not has_schema_privilege('anon','private','USAGE')), 'Only authenticated requests can use private RLS helper schema');
insert into pg_temp.tap_results select 3, ok((select p.prosecdef and p.proconfig @> array['search_path=""'] and has_function_privilege('authenticated',p.oid,'execute') and not has_function_privilege('anon',p.oid,'execute') from pg_proc p where p.oid='private.is_active_member()'::regprocedure), 'Active-profile helper is SECURITY DEFINER and private');
insert into pg_temp.tap_results select 4, ok(not has_table_privilege('anon','public.teams','SELECT'), 'Anonymous role has no table SELECT grant');
insert into pg_temp.tap_results select 5, ok(not has_table_privilege('authenticated','public.predictions','INSERT') and not has_table_privilege('authenticated','public.duels','INSERT') and not has_table_privilege('authenticated','public.matchdays','INSERT'), 'Atomic schedule/submission writes await RPCs rather than direct grants');
insert into pg_temp.tap_results select 6, ok(not has_table_privilege('anon','public.profiles','SELECT') and not has_table_privilege('anon','public.invitation_codes','SELECT'), 'Anonymous role has no profile or invite SELECT grants');
insert into pg_temp.tap_results select 7, ok(not has_function_privilege('anon','public.get_my_profile()','EXECUTE') and not has_function_privilege('anon','public.admin_list_profiles()','EXECUTE'), 'Anonymous role cannot call profile RPCs');
insert into pg_temp.tap_results select 8, ok(not has_table_privilege('anon','public.matches','SELECT') and not has_table_privilege('anon','public.duels','SELECT'), 'Anonymous role has no game-history grants');
select set_config('request.jwt.claim.sub','66000000-0000-4000-8000-000000000001',true);
set local role authenticated;
insert into pg_temp.tap_results select 9, is((select count(id)::int from public.profiles), 4, 'Active player sees basic group identities including inactive users');
insert into pg_temp.tap_results select 10, is((select count(id)::int from public.profiles where id='66000000-0000-4000-8000-000000000003'), 1, 'Active player can identify a disabled historical participant');
insert into pg_temp.tap_results select 11, ok(not has_column_privilege('authenticated','public.profiles','email','SELECT'), 'Player has no direct email-column privilege');
insert into pg_temp.tap_results select 12, ok(not has_column_privilege('authenticated','public.profiles','role','SELECT') and not has_column_privilege('authenticated','public.profiles','activo','SELECT'), 'Player has no direct role/status-column privilege');
insert into pg_temp.tap_results select 13, ok(not has_column_privilege('authenticated','public.profiles','invitation_code_used','SELECT'), 'Invitation code is hidden even from base self-profile reads');
insert into pg_temp.tap_results select 14, is((select count(*)::int from public.get_my_profile()), 1, 'Active player can load their own private profile by RPC');
insert into pg_temp.tap_results select 15, ok((select profile_id='66000000-0000-4000-8000-000000000001'::uuid and email='rls-a@example.invalid' and role='PLAYER'::public.user_role and activo from public.get_my_profile()), 'Self-profile RPC returns only the signed-in user data');
insert into pg_temp.tap_results select 16, is((select count(*)::int from public.admin_list_profiles()), 0, 'Player cannot enumerate the admin profile projection');
insert into pg_temp.tap_results select 17, is((select count(*)::int from public.admin_list_duels()), 0, 'Player cannot use the admin duel projection');
insert into pg_temp.tap_results select 18, is((select count(*)::int from public.invitation_codes), 0, 'Player sees no invitation codes');
insert into pg_temp.tap_results select 19, is((select count(*)::int from public.teams), 10, 'Active player can read active and historical team catalogue');
insert into pg_temp.tap_results select 20, is((select count(*)::int from public.competitions), 2, 'Active player can read competitions');
insert into pg_temp.tap_results select 21, is((select count(*)::int from public.seasons where id='33000000-0000-4000-8000-000000000001'), 1, 'Active player can read season history');
insert into pg_temp.tap_results select 22, is((select count(*)::int from public.matches), 4, 'Active player can read published matches');
insert into pg_temp.tap_results select 23, is((select count(*)::int from public.matchdays), 4, 'Active player can read matchday history');
insert into pg_temp.tap_results select 24, is((select count(*)::int from public.predictions where match_id='53000000-0000-4000-8000-000000000001'), 1, 'During ABIERTA a player sees only their own prediction');
insert into pg_temp.tap_results select 25, is((select count(*)::int from public.predictions where match_id='53000000-0000-4000-8000-000000000001' and player_id='66000000-0000-4000-8000-000000000002'), 0, 'During ABIERTA a rival prediction is hidden');
insert into pg_temp.tap_results select 26, is((select count(*)::int from public.predictions where match_id='53000000-0000-4000-8000-000000000002'), 3, 'From EN_CURSO all group predictions are visible');
insert into pg_temp.tap_results select 27, is((select count(*)::int from public.predictions where match_id='53000000-0000-4000-8000-000000000002' and player_id='66000000-0000-4000-8000-000000000003'), 1, 'A disabled profile previous in-progress prediction remains visible to active players');
insert into pg_temp.tap_results select 28, is((select count(*)::int from public.predictions where match_id='53000000-0000-4000-8000-000000000003'), 2, 'Finalized history predictions are visible');
insert into pg_temp.tap_results select 29, is((select count(*)::int from public.duels where matchday_id='43000000-0000-4000-8000-000000000004'), 1, 'Active players can read the published virtual duel');
insert into pg_temp.tap_results select 30, ok(not has_column_privilege('authenticated','public.duels','player_b_replaced_id','SELECT'), 'Player API cannot read the replacement profile ID');
insert into pg_temp.tap_results select 31, ok(not has_column_privilege('authenticated','public.profiles','role','UPDATE') and not has_column_privilege('authenticated','public.profiles','activo','UPDATE'), 'Client roles cannot change role or active status by table update');
insert into pg_temp.tap_results select 32, ok(not has_column_privilege('authenticated','public.profiles','email','UPDATE'), 'Profile email changes must use Auth');
DO $body$
declare denied boolean := false;
begin
  begin
    insert into public.invitation_codes(code) values ('PLAYER-FORBIDDEN');
  exception when insufficient_privilege then denied := true;
  end;
  insert into pg_temp.tap_results select 33, extensions.ok(denied, 'Player cannot issue invitations');
end;
$body$;
DO $body$
declare denied boolean := false;
begin
  begin
    insert into public.teams(nombre) values ('Player forbidden team');
  exception when insufficient_privilege then denied := true;
  end;
  insert into pg_temp.tap_results select 34, extensions.ok(denied, 'Player cannot create teams through the admin-only policy');
end;
$body$;
insert into pg_temp.tap_results select 35, ok(not has_table_privilege('authenticated','public.predictions','INSERT'), 'Players cannot bypass the five-pick submission RPC');
reset role;
select set_config('request.jwt.claim.sub','66000000-0000-4000-8000-000000000003',true);
set local role authenticated;
insert into pg_temp.tap_results select 36, is((select count(id)::int from public.profiles), 0, 'A disabled profile stale JWT cannot read the profile identity table');
insert into pg_temp.tap_results select 37, is((select count(*)::int from public.get_my_profile()), 0, 'Disabled user cannot load the private profile RPC');
insert into pg_temp.tap_results select 38, is((select count(*)::int from public.teams), 0, 'Disabled user cannot read game data');
reset role;
select set_config('request.jwt.claim.sub','66000000-0000-4000-8000-000000000004',true);
set local role authenticated;
insert into pg_temp.tap_results select 39, is((select role::text from public.get_my_profile()), 'ADMIN', 'Admin loads their own private profile');
insert into pg_temp.tap_results select 40, is((select count(*)::int from public.admin_list_profiles()), 4, 'Admin can list active and deactivated profiles');
insert into pg_temp.tap_results select 41, throws_ok($sql$select invitation_code_used from public.admin_list_profiles()$sql$, '42703', null::text, 'Admin profile projection never returns invitation-code secret');
insert into pg_temp.tap_results select 42, is((select count(*)::int from public.admin_list_duels()), 4, 'Admin can read every duel');
insert into pg_temp.tap_results select 43, is((select count(*)::int from public.admin_list_duels() where player_b_id is null and player_b_replaced_id='66000000-0000-4000-8000-000000000003'), 1, 'Admin projection includes private replacement provenance');
insert into pg_temp.tap_results select 44, is((select count(*)::int from public.invitation_codes), 5, 'Admin can list the invitation catalogue');
insert into public.invitation_codes(code) values('ADMIN-RLS-CREATED');
insert into pg_temp.tap_results select 45, is((select count(*)::int from public.invitation_codes where code='ADMIN-RLS-CREATED'), 1, 'Admin can create an unused invitation');
insert into pg_temp.tap_results select 46, throws_ok($sql$delete from public.invitation_codes where code='RLS_FIX_A'$sql$, '55000', null::text, 'Admin cannot physically delete a consumed invite');
insert into public.teams(nombre) values('Admin RLS Team');
insert into pg_temp.tap_results select 47, is((select count(*)::int from public.teams where nombre='Admin RLS Team'), 1, 'Admin can create a team');
update public.teams set activo=false where nombre='Admin RLS Team';
insert into pg_temp.tap_results select 48, is((select count(*)::int from public.teams where nombre='Admin RLS Team' and not activo), 1, 'Admin soft-deletes a team');
update public.matches set resultado_real='1' where id='53000000-0000-4000-8000-000000000001';
insert into pg_temp.tap_results select 49, ok(exists(select 1 from public.matches where id='53000000-0000-4000-8000-000000000001' and resultado_real='1'), 'Admin can enter a manual 1X2 match result');
insert into pg_temp.tap_results select 50, ok(not has_column_privilege('authenticated','public.matches','equipo_local_id','UPDATE'), 'Admin result-update grant cannot change match structure');
update public.predictions set pronostico='X' where id='82000000-0000-4000-8000-000000000001';
insert into pg_temp.tap_results select 51, ok(exists(select 1 from public.predictions where id='82000000-0000-4000-8000-000000000001' and pronostico='X'), 'Admin can correct an existing prediction');
insert into pg_temp.tap_results select 52, ok(not has_column_privilege('authenticated','public.predictions','acierto','UPDATE'), 'Admin client cannot write derived prediction scores');
insert into pg_temp.tap_results select 53, ok(not has_column_privilege('authenticated','public.profiles','role','UPDATE'), 'Admin role changes require the future guarded admin operation');
insert into pg_temp.tap_results select 54, ok(not has_table_privilege('authenticated','public.matchdays','INSERT') and not has_table_privilege('authenticated','public.duels','INSERT'), 'Schedule creation awaits the F3 atomic RPC');
reset role;
select set_config('request.jwt.claim.sub','66000000-0000-4000-8000-000000000001',true);
set local role authenticated;
update public.profiles set username='rls_a_updated' where id='66000000-0000-4000-8000-000000000001';
insert into pg_temp.tap_results select 55, is((select username from public.get_my_profile()),'rls_a_updated','Player may update their own username using the column grant');
with updated as (update public.profiles set username='player-hacked' where id='66000000-0000-4000-8000-000000000002' returning id)
insert into pg_temp.tap_results select 56, is((select count(*)::int from updated),0,'RLS filters updates to another player profile');
delete from public.invitation_codes where code='RLS_UNUSED';
reset role;
insert into pg_temp.tap_results select 57, is((select count(*)::int from public.invitation_codes where code='RLS_UNUSED'),1,'RLS filters a player deletion of an unused invitation');
select set_config('request.jwt.claim.sub','66000000-0000-4000-8000-000000000004',true);
set local role authenticated;
delete from public.invitation_codes where code='RLS_UNUSED';
insert into pg_temp.tap_results select 58, is((select count(*)::int from public.invitation_codes where code='RLS_UNUSED'),0,'Admin may delete an unused invitation');
insert into pg_temp.tap_results select 59, ok(not exists(
  select 1 from pg_default_acl d cross join lateral aclexplode(d.defaclacl) a
   where d.defaclrole='postgres'::regrole and d.defaclnamespace='public'::regnamespace
     and a.grantee in (0::oid,'anon'::regrole,'authenticated'::regrole)),
  'Future postgres-created public objects do not inherit API-role grants');
insert into pg_temp.tap_results select 60, ok(not exists(
  select 1 from pg_default_acl d cross join lateral aclexplode(d.defaclacl) a
   where d.defaclrole='postgres'::regrole and d.defaclnamespace='private'::regnamespace
     and a.grantee in (0::oid,'anon'::regrole,'authenticated'::regrole,'service_role'::regrole)),
  'Future private helpers do not inherit public or API-role grants');
reset role;
insert into pg_temp.tap_results select 1000,finish();
select line as tap from pg_temp.tap_results order by position;
rollback;

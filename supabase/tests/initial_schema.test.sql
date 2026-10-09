-- Run through pnpm db:test against the authorized DEVELOPMENT project.
-- The runner embeds seed.sql twice at @fixtures and checks TAP failures/counts.
-- Fixtures, extension creation and temporary grants are ALL rolled back.
begin;
set local statement_timeout = '30s';
set local lock_timeout = '5s';
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
create temporary table baseline_account_counts as
  select (select count(*) from public.profiles)::integer as profiles,
    (select count(*) from public.invitation_codes)::integer as invitations,
    (select count(*) from auth.users)::integer as auth_users;
-- @fixtures
create temporary table tap_results (position integer primary key, line text);
grant insert on table pg_temp.tap_results to anon, authenticated;
insert into pg_temp.tap_results select 0, plan(15);

insert into pg_temp.tap_results select 1, is(
  (select count(*)::integer from pg_tables where schemaname = 'public'
    and tablename in ('profiles', 'invitation_codes', 'competitions', 'teams',
      'seasons', 'matchdays', 'matches', 'predictions', 'duels')),
  9, 'All nine application tables exist'
);
insert into pg_temp.tap_results select 2, is(
  (select count(*)::integer from pg_tables where schemaname = 'public'
    and rowsecurity and tablename in ('profiles', 'invitation_codes', 'competitions',
      'teams', 'seasons', 'matchdays', 'matches', 'predictions', 'duels')),
  9, 'RLS is enabled on all application tables'
);
insert into pg_temp.tap_results select 3, is(
  (select count(*)::integer from pg_type t join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typtype = 'e'
    and t.typname in ('user_role', 'matchday_estado', 'season_estado', 'resultado_1x2', 'duel_resultado')),
  5, 'All five application enums exist'
);
insert into pg_temp.tap_results select 4, is(
  (select count(*)::integer from public.competitions
    where id in ('10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002')),
  2, 'Both demo competitions were seeded'
);
insert into pg_temp.tap_results select 5, is(
  (select count(*)::integer from public.teams
    where id between '20000000-0000-4000-8000-000000000001'::uuid
      and '20000000-0000-4000-8000-000000000010'::uuid),
  10, 'Ten demo teams were seeded'
);
insert into pg_temp.tap_results select 6, is((select count(*)::integer from public.profiles),
  (select profiles from baseline_account_counts), 'Seed does not create profiles');
insert into pg_temp.tap_results select 7, is((select count(*)::integer from public.invitation_codes),
  (select invitations from baseline_account_counts), 'Seed does not create invitations');
insert into pg_temp.tap_results select 8, is((select count(*)::integer from auth.users),
  (select auth_users from baseline_account_counts), 'Seed does not create Auth users');
insert into pg_temp.tap_results select 9, is(
  (select count(*)::integer from pg_indexes where schemaname = 'public'
    and indexname in ('idx_matches_matchday', 'idx_predictions_match', 'idx_predictions_player',
      'idx_duels_matchday', 'idx_duels_player_a', 'idx_duels_player_b', 'idx_matchdays_season')),
  7, 'All seven relationship indexes exist'
);
insert into pg_temp.tap_results select 10, ok(
  exists(select 1 from pg_trigger
    where tgrelid = 'public.profiles'::regclass and tgname = 'trg_profiles_updated_at'
      and not tgisinternal and tgfoid = 'public.set_updated_at()'::regprocedure),
  'Profiles have the updated_at trigger bound to its function'
);

insert into public.seasons (id, nombre, fecha_inicio)
values ('30000000-0000-4000-8000-000000000001', 'SQL smoke test', '2026-01-01');
insert into public.matchdays (id, season_id, numero)
values ('40000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 1);

insert into pg_temp.tap_results select 11, throws_ok(
  $$insert into public.matches (matchday_id, competition_id, equipo_local_id, equipo_visitante_id)
    values ('40000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001')$$,
  '23514', null::text, 'A team cannot play against itself'
);
insert into pg_temp.tap_results select 12, throws_ok(
  $$insert into public.matchdays (season_id, numero)
    values ('30000000-0000-4000-8000-000000000001', 1)$$,
  '23505', null::text, 'Matchday numbers are unique per season'
);
insert into pg_temp.tap_results select 13, throws_ok(
  $$insert into public.matches (matchday_id, competition_id, equipo_local_id, equipo_visitante_id)
    values ('40000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000001', 'ffffffff-ffff-4fff-8fff-ffffffffffff')$$,
  '23503', null::text, 'Matches cannot reference an unknown team'
);

-- Grant only inside this rollback-only test to distinguish RLS from missing grants.
-- Even with SELECT, there are no policies yet, so both API roles must see zero rows.
grant usage on schema public, extensions to anon, authenticated;
grant select on public.teams to anon, authenticated;
set local role anon;
insert into pg_temp.tap_results select 14, is((select count(*)::integer from public.teams), 0, 'Anonymous reads are denied by RLS');
reset role;
set local role authenticated;
insert into pg_temp.tap_results select 15, is((select count(*)::integer from public.teams), 0, 'Authenticated reads are denied until policies exist');
reset role;

insert into pg_temp.tap_results select 100, finish();
-- Management API returns the final SELECT: collect every TAP result in this rowset.
select line as tap from pg_temp.tap_results order by position;
rollback;

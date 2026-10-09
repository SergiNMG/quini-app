-- Counts/privileges only: no personal records are returned.
-- Used before and after rollback-only tests to detect persisted changes.
select jsonb_build_object(
  'row_counts', jsonb_build_object(
    'profiles', (select count(*) from public.profiles),
    'invitation_codes', (select count(*) from public.invitation_codes),
    'competitions', (select count(*) from public.competitions),
    'teams', (select count(*) from public.teams),
    'seasons', (select count(*) from public.seasons),
    'matchdays', (select count(*) from public.matchdays),
    'matches', (select count(*) from public.matches),
    'predictions', (select count(*) from public.predictions),
    'duels', (select count(*) from public.duels)
  ),
  'auth_users', (select count(*) from auth.users),
  'pgtap_installed', exists(select 1 from pg_extension where extname = 'pgtap'),
  'privileges', jsonb_build_object(
    'anon_public_usage', has_schema_privilege('anon', 'public', 'USAGE'),
    'authenticated_public_usage', has_schema_privilege('authenticated', 'public', 'USAGE'),
    'anon_extensions_usage', has_schema_privilege('anon', 'extensions', 'USAGE'),
    'authenticated_extensions_usage', has_schema_privilege('authenticated', 'extensions', 'USAGE'),
    'anon_teams_select', has_table_privilege('anon', 'public.teams', 'SELECT'),
    'authenticated_teams_select', has_table_privilege('authenticated', 'public.teams', 'SELECT')
  )
) as baseline_state;

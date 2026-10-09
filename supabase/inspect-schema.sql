-- Read-only inventory: no application rows, credentials or DDL.
-- Run with: pnpm exec supabase db query --linked --file supabase/inspect-schema.sql
-- An empty migration history alone does NOT prove that the schema is empty.
select jsonb_build_object(
  'postgres_version', current_setting('server_version'),
  'public_relations', coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', c.relname,
      'kind', c.relkind,
      'rls_enabled', c.relrowsecurity
    ) order by c.relname)
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p', 'v', 'm', 'S', 'f')
      and not exists (
        select 1 from pg_depend d
        where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e'
      )
  ), '[]'::jsonb),
  'public_types', coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', t.typname,
      'kind', t.typtype,
      'enum_labels', (
        select jsonb_agg(e.enumlabel order by e.enumsortorder)
        from pg_enum e where e.enumtypid = t.oid
      )
    ) order by t.typname)
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typtype in ('e', 'd', 'r', 'm', 'c')
      and not exists (
        select 1 from pg_depend d
        where d.classid = 'pg_type'::regclass and d.objid = t.oid and d.deptype = 'e'
      )
  ), '[]'::jsonb),
  'public_functions', coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', p.proname,
      'arguments', pg_get_function_identity_arguments(p.oid)
    ) order by p.proname)
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and not exists (
        select 1 from pg_depend d
        where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e'
      )
  ), '[]'::jsonb),
  'policies', coalesce((
    select jsonb_agg(jsonb_build_object(
      'schema', schemaname, 'table', tablename, 'name', policyname
    ) order by schemaname, tablename, policyname)
    from pg_policies where schemaname in ('public', 'auth', 'storage')
  ), '[]'::jsonb),
  'auth_user_triggers', coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', t.tgname,
      'function_schema', fn.nspname,
      'function_name', p.proname
    ) order by t.tgname)
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_proc p on p.oid = t.tgfoid
    join pg_namespace fn on fn.oid = p.pronamespace
    where n.nspname = 'auth' and c.relname = 'users' and not t.tgisinternal
  ), '[]'::jsonb)
) as schema_inventory;

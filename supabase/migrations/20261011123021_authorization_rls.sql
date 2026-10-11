-- F1.8: least-privilege grants, role predicates and row policies.
-- Schedule creation/submission/scoring writes are intentionally reserved for F3/F4/F5 RPCs.
set local lock_timeout = '5s';

create schema private;
revoke all on schema private from public, anon, authenticated, service_role;
grant usage on schema private to authenticated;

-- Keep authorization tied to the current profile row, not stale/user-editable JWT metadata.
-- SECURITY DEFINER avoids recursive profiles RLS; pin search_path and qualify all objects.
create function private.is_active_member()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
     where p.id = (select auth.uid()) and p.activo
  );
$$;

create function private.is_active_admin()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
     where p.id = (select auth.uid())
       and p.activo
       and p.role = 'ADMIN'::public.user_role
  );
$$;

revoke all on function private.is_active_member(), private.is_active_admin()
  from public, anon, authenticated, service_role;
grant execute on function private.is_active_member(), private.is_active_admin()
  to authenticated;

-- These bounded RPCs expose private profile fields only to their owner or an active admin.
-- They intentionally omit profiles.invitation_code_used.
create function public.get_my_profile()
returns table (
  profile_id uuid,
  username text,
  email text,
  avatar_url text,
  role public.user_role,
  activo boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql stable security definer set search_path = ''
as $$
  select p.id, p.username, p.email, p.avatar_url, p.role, p.activo,
         p.created_at, p.updated_at
    from public.profiles p
   where p.id = (select auth.uid()) and p.activo;
$$;

create function public.admin_list_profiles()
returns table (
  profile_id uuid,
  username text,
  email text,
  avatar_url text,
  role public.user_role,
  activo boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql stable security definer set search_path = ''
as $$
  select p.id, p.username, p.email, p.avatar_url, p.role, p.activo,
         p.created_at, p.updated_at
    from public.profiles p
   where (select private.is_active_admin());
$$;

create function public.admin_list_duels()
returns table (
  duel_id uuid,
  matchday_id uuid,
  player_a_id uuid,
  player_a_replaced_id uuid,
  player_b_id uuid,
  player_b_replaced_id uuid,
  aciertos_a integer,
  aciertos_b integer,
  puntos_a integer,
  puntos_b integer,
  resultado public.duel_resultado,
  created_at timestamptz
)
language sql stable security definer set search_path = ''
as $$
  select d.id, d.matchday_id, d.player_a_id, d.player_a_replaced_id,
         d.player_b_id, d.player_b_replaced_id, d.aciertos_a, d.aciertos_b,
         d.puntos_a, d.puntos_b, d.resultado, d.created_at
    from public.duels d
   where (select private.is_active_admin());
$$;

revoke all on function public.get_my_profile(), public.admin_list_profiles(), public.admin_list_duels()
  from public, anon, authenticated, service_role;
grant execute on function public.get_my_profile(), public.admin_list_profiles(), public.admin_list_duels()
  to authenticated;

-- Supabase has broad default grants on public objects. Remove client access first,
-- then grant only the operations/columns required by the confirmed product rules.
revoke all on all tables in schema public from public, anon, authenticated;
revoke all on all sequences in schema public from public, anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;
-- The broad default revocation above also includes these three bounded RPCs.
grant execute on function public.get_my_profile(), public.admin_list_profiles(), public.admin_list_duels()
  to authenticated;
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;

-- Prevent future postgres-owned public objects from silently inheriting client grants.
alter default privileges for role postgres in schema public
  revoke all on tables from public, anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from public, anon, authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;

-- Existing identities can be shown to active group members, but private columns
-- are available only through the guarded profile RPCs above.
grant select (id, username, avatar_url) on public.profiles to authenticated;
grant update (username, avatar_url) on public.profiles to authenticated;

-- Active players and admins may read catalog/history data.
grant select on public.competitions, public.teams, public.seasons,
  public.matchdays, public.matches to authenticated;
grant select (id, matchday_id, player_a_id, player_b_id,
  aciertos_a, aciertos_b, puntos_a, puntos_b, resultado, created_at)
  on public.duels to authenticated;
grant select (id, match_id, player_id, pronostico, acierto, created_at)
  on public.predictions to authenticated;

-- Admin-maintained catalogues use soft-delete; no hard delete is granted.
grant insert (nombre) on public.competitions to authenticated;
grant update (nombre, activo) on public.competitions to authenticated;
grant insert (nombre, escudo_url) on public.teams to authenticated;
grant update (nombre, escudo_url, activo) on public.teams to authenticated;
grant insert (nombre, fecha_inicio, fecha_fin) on public.seasons to authenticated;
grant update (nombre, fecha_inicio, fecha_fin) on public.seasons to authenticated;

-- Invitation rows are entirely admin-only. Consumption/used fields remain writable
-- only to the SECURITY DEFINER Auth trigger, never to clients.
grant select (id, code, usado, usado_por, created_at)
  on public.invitation_codes to authenticated;
grant insert (code) on public.invitation_codes to authenticated;
grant delete on public.invitation_codes to authenticated;

-- Admin may enter real match outcomes and correct an existing prediction.
-- Derived acierto/duel score columns stay unwritable; F5 will replace direct prediction
-- correction with an atomic audited scoring RPC. Player submissions (all five at once)
-- remain unavailable until the F4 transactional RPC exists.
grant update (resultado_real) on public.matches to authenticated;
grant update (pronostico) on public.predictions to authenticated;

-- Current database identity is checked on every statement, so a stale JWT for a
-- deactivated profile receives no application rows or writes.
create policy profiles_read_group_identity
  on public.profiles for select to authenticated
  using ((select private.is_active_member()));
create policy profiles_update_own_identity
  on public.profiles for update to authenticated
  using (id = (select auth.uid()) and (select private.is_active_member()))
  with check (id = (select auth.uid()) and (select private.is_active_member()));
create policy profiles_update_admin_identity
  on public.profiles for update to authenticated
  using ((select private.is_active_admin()))
  with check ((select private.is_active_admin()));

create policy invitations_admin_select
  on public.invitation_codes for select to authenticated
  using ((select private.is_active_admin()));
create policy invitations_admin_insert
  on public.invitation_codes for insert to authenticated
  with check ((select private.is_active_admin()));
create policy invitations_admin_delete_unused
  on public.invitation_codes for delete to authenticated
  using ((select private.is_active_admin()));

create policy competitions_active_read
  on public.competitions for select to authenticated
  using ((select private.is_active_member()));
create policy competitions_admin_insert
  on public.competitions for insert to authenticated
  with check ((select private.is_active_admin()));
create policy competitions_admin_update
  on public.competitions for update to authenticated
  using ((select private.is_active_admin()))
  with check ((select private.is_active_admin()));

create policy teams_active_read
  on public.teams for select to authenticated
  using ((select private.is_active_member()));
create policy teams_admin_insert
  on public.teams for insert to authenticated
  with check ((select private.is_active_admin()));
create policy teams_admin_update
  on public.teams for update to authenticated
  using ((select private.is_active_admin()))
  with check ((select private.is_active_admin()));

create policy seasons_active_read
  on public.seasons for select to authenticated
  using ((select private.is_active_member()));
create policy seasons_admin_insert
  on public.seasons for insert to authenticated
  with check ((select private.is_active_admin()));
create policy seasons_admin_update
  on public.seasons for update to authenticated
  using ((select private.is_active_admin()))
  with check ((select private.is_active_admin()));

create policy matchdays_active_read
  on public.matchdays for select to authenticated
  using ((select private.is_active_member()));

create policy matches_active_read
  on public.matches for select to authenticated
  using ((select private.is_active_member()));
create policy matches_admin_results
  on public.matches for update to authenticated
  using ((select private.is_active_admin()))
  with check ((select private.is_active_admin()));

create policy predictions_group_read
  on public.predictions for select to authenticated
  using (
    (select private.is_active_admin())
    or (
      (select private.is_active_member())
      and (
        player_id = (select auth.uid())
        or exists (
          select 1
            from public.matches m
            join public.matchdays d on d.id = m.matchday_id
           where m.id = predictions.match_id
             and d.estado in ('EN_CURSO'::public.matchday_estado,
                              'FINALIZADA'::public.matchday_estado)
        )
      )
    )
  );
create policy predictions_admin_correction
  on public.predictions for update to authenticated
  using ((select private.is_active_admin()))
  with check ((select private.is_active_admin()));

create policy duels_active_read
  on public.duels for select to authenticated
  using ((select private.is_active_member()));

comment on schema private is
  'Unexposed SECURITY DEFINER authorization helpers used by application RLS policies.';
comment on function public.get_my_profile() is
  'Returns only the current active user profile; intentionally omits invitation_code_used.';
comment on function public.admin_list_profiles() is
  'Returns profile details only to an active ADMIN; intentionally omits invitation_code_used.';
comment on function public.admin_list_duels() is
  'Returns duel replacement IDs only to an active ADMIN; player API reads use the column-limited table grant.';

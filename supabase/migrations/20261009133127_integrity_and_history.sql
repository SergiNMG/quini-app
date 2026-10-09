-- F1.4: preserve identities/history and validate scalar/state invariants.
-- The applied baseline is unchanged. No deletes/resets/data rewriting.
-- Five-match publication, unique participation, complete submissions and scoring
-- remain transactional operations for F3/F4/F5; virtual participants are F1.5.
set local lock_timeout = '5s';

-- Remove cascade/nulling paths, including deletion through Supabase Auth.
alter table public.profiles
  drop constraint profiles_id_fkey,
  add constraint profiles_id_fkey foreign key (id)
    references auth.users(id) on delete restrict on update restrict;

alter table public.invitation_codes
  drop constraint invitation_codes_usado_por_fkey,
  add constraint invitation_codes_usado_por_fkey foreign key (usado_por)
    references public.profiles(id) on delete restrict on update restrict;

alter table public.matchdays
  drop constraint matchdays_season_id_fkey,
  add constraint matchdays_season_id_fkey foreign key (season_id)
    references public.seasons(id) on delete restrict on update restrict;

alter table public.matches
  drop constraint matches_matchday_id_fkey,
  add constraint matches_matchday_id_fkey foreign key (matchday_id)
    references public.matchdays(id) on delete restrict on update restrict;

alter table public.matches
  drop constraint matches_competition_id_fkey,
  add constraint matches_competition_id_fkey foreign key (competition_id)
    references public.competitions(id) on delete restrict on update restrict;

alter table public.matches
  drop constraint matches_equipo_local_id_fkey,
  add constraint matches_equipo_local_id_fkey foreign key (equipo_local_id)
    references public.teams(id) on delete restrict on update restrict;

alter table public.matches
  drop constraint matches_equipo_visitante_id_fkey,
  add constraint matches_equipo_visitante_id_fkey foreign key (equipo_visitante_id)
    references public.teams(id) on delete restrict on update restrict;

alter table public.predictions
  drop constraint predictions_match_id_fkey,
  add constraint predictions_match_id_fkey foreign key (match_id)
    references public.matches(id) on delete restrict on update restrict;

alter table public.predictions
  drop constraint predictions_player_id_fkey,
  add constraint predictions_player_id_fkey foreign key (player_id)
    references public.profiles(id) on delete restrict on update restrict;

alter table public.duels
  drop constraint duels_matchday_id_fkey,
  add constraint duels_matchday_id_fkey foreign key (matchday_id)
    references public.matchdays(id) on delete restrict on update restrict;

alter table public.duels
  drop constraint duels_player_a_id_fkey,
  add constraint duels_player_a_id_fkey foreign key (player_a_id)
    references public.profiles(id) on delete restrict on update restrict;

alter table public.duels
  drop constraint duels_player_b_id_fkey,
  add constraint duels_player_b_id_fkey foreign key (player_b_id)
    references public.profiles(id) on delete restrict on update restrict;

-- CHECK expressions reference only their own row, never cross-table counts.
alter table public.seasons add constraint chk_season_dates
  check (fecha_fin is null or fecha_fin >= fecha_inicio);
alter table public.matchdays
  add constraint chk_matchday_number check (numero > 0),
  add constraint chk_matchday_dates check (fecha_inicio is null or fecha_inicio >= fecha_creacion),
  add constraint chk_matchday_started check (
    (estado = 'ABIERTA' and fecha_inicio is null)
    or (estado in ('EN_CURSO', 'FINALIZADA') and fecha_inicio is not null)
  );
alter table public.duels
  add constraint chk_duel_hits_a check (aciertos_a between 0 and 5),
  add constraint chk_duel_hits_b check (aciertos_b between 0 and 5),
  add constraint chk_duel_points_a check (puntos_a in (0, 1, 3)),
  add constraint chk_duel_points_b check (puntos_b in (0, 1, 3)),
  add constraint chk_duel_calculation_complete check (
    (aciertos_a is null and aciertos_b is null and puntos_a is null
      and puntos_b is null and resultado is null)
    or (aciertos_a is not null and aciertos_b is not null
      and puntos_a is not null and puntos_b is not null and
      case
        when resultado is null then puntos_a = 0 and puntos_b = 0
        when resultado = 'A_GANA' then puntos_a = 3 and puntos_b = 0
        when resultado = 'B_GANA' then puntos_a = 0 and puntos_b = 3
        -- Reserve the asymmetric draw shapes needed by F1.5's virtual opponent.
        when resultado = 'EMPATE' then (puntos_a, puntos_b) in ((1, 1), (1, 0), (0, 1))
        else false
      end)
  );

-- Ordinary application operations retain persisted rows; only unused invitations
-- may be deleted by a future authorized admin flow. Maintenance requires explicit DDL.
create function public.prevent_history_deletion()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' and tg_table_name = 'invitation_codes' then
    if not (to_jsonb(old) ->> 'usado')::boolean
      and (to_jsonb(old) ->> 'usado_por') is null then
      return old;
    end if;
  end if;
  raise exception using errcode = '55000',
    message = 'Physical deletion/truncation is disabled for retained application records';
end;
$$;

create function public.guard_record_identity()
returns trigger language plpgsql set search_path = '' as $$
declare
  column_name text;
begin
  foreach column_name in array tg_argv loop
    if (to_jsonb(new) -> column_name) is distinct from (to_jsonb(old) -> column_name) then
      raise exception using errcode = '55000',
        message = 'Persisted identities and historical assignments cannot be rewritten';
    end if;
  end loop;
  if tg_table_name = 'invitation_codes' then
    if (to_jsonb(old) ->> 'usado')::boolean or (to_jsonb(old) ->> 'usado_por') is not null then
      if (to_jsonb(new) -> 'code') is distinct from (to_jsonb(old) -> 'code')
        or (to_jsonb(new) -> 'usado') is distinct from (to_jsonb(old) -> 'usado')
        or (to_jsonb(new) -> 'usado_por') is distinct from (to_jsonb(old) -> 'usado_por') then
        raise exception using errcode = '55000',
          message = 'A consumed invitation must retain its code and consumption record';
      end if;
    end if;
  end if;
  return new;
end;
$$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles', 'invitation_codes', 'competitions', 'teams', 'seasons',
    'matchdays', 'matches', 'predictions', 'duels'
  ] loop
    execute format('create trigger %I before delete on public.%I
      for each row execute function public.prevent_history_deletion()', 'trg_' || table_name || '_no_delete', table_name);
    execute format('create trigger %I before truncate on public.%I
      for each statement execute function public.prevent_history_deletion()', 'trg_' || table_name || '_no_truncate', table_name);
  end loop;
end;
$$;

create trigger trg_profiles_identity before update on public.profiles
  for each row execute function public.guard_record_identity('id');
create trigger trg_invitations_identity before update on public.invitation_codes
  for each row execute function public.guard_record_identity('id');
create trigger trg_competitions_identity before update on public.competitions
  for each row execute function public.guard_record_identity('id');
create trigger trg_teams_identity before update on public.teams
  for each row execute function public.guard_record_identity('id');
create trigger trg_seasons_identity before update on public.seasons
  for each row execute function public.guard_record_identity('id');
create trigger trg_matchdays_identity before update on public.matchdays
  for each row execute function public.guard_record_identity('id', 'season_id', 'numero');
create trigger trg_matches_identity before update on public.matches
  for each row execute function public.guard_record_identity('id', 'matchday_id');
create trigger trg_predictions_identity before update on public.predictions
  for each row execute function public.guard_record_identity('id', 'match_id', 'player_id');
create trigger trg_duels_identity before update on public.duels
  for each row execute function public.guard_record_identity('id', 'matchday_id', 'player_a_id', 'player_b_id');

create function public.guard_season_lifecycle()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if new.estado <> 'ACTIVA' then
      raise exception using errcode = '23514', message = 'New seasons must start ACTIVA';
    end if;
  elsif new.estado is distinct from old.estado then
    if not (old.estado = 'ACTIVA' and new.estado = 'FINALIZADA') then
      raise exception using errcode = '23514', message = 'Season state cannot move backwards';
    end if;
  end if;
  return new;
end;
$$;
create trigger trg_seasons_lifecycle before insert or update on public.seasons
  for each row execute function public.guard_season_lifecycle();

create function public.guard_matchday_lifecycle()
returns trigger language plpgsql set search_path = '' as $$
declare
  season_state public.season_estado;
begin
  -- A SHARE row lock conflicts with closing the season, not just deleting its key.
  select s.estado into season_state from public.seasons s
    where s.id = new.season_id for share;
  if not found then
    raise exception using errcode = '23503', message = 'Unknown season';
  end if;
  if tg_op = 'INSERT' then
    if season_state <> 'ACTIVA' or new.estado <> 'ABIERTA' then
      raise exception using errcode = '23514', message = 'New matchdays require an active season and ABIERTA state';
    end if;
  elsif new.estado is distinct from old.estado then
    if season_state <> 'ACTIVA' or not (
      (old.estado = 'ABIERTA' and new.estado = 'EN_CURSO')
      or (old.estado = 'EN_CURSO' and new.estado = 'FINALIZADA')
    ) then
      raise exception using errcode = '23514', message = 'Invalid matchday state transition';
    end if;
  end if;
  return new;
end;
$$;
create trigger trg_matchdays_lifecycle before insert or update on public.matchdays
  for each row execute function public.guard_matchday_lifecycle();

create function public.guard_matchday_structure()
returns trigger language plpgsql set search_path = '' as $$
declare
  matchday_state public.matchday_estado;
  season_state public.season_estado;
begin
  if tg_op = 'UPDATE' then
    -- Only matches invoke this trigger on UPDATE; result corrections are not structural.
    if (to_jsonb(new) -> 'competition_id') is not distinct from (to_jsonb(old) -> 'competition_id')
      and (to_jsonb(new) -> 'equipo_local_id') is not distinct from (to_jsonb(old) -> 'equipo_local_id')
      and (to_jsonb(new) -> 'equipo_visitante_id') is not distinct from (to_jsonb(old) -> 'equipo_visitante_id') then
      return new;
    end if;
  end if;
  select m.estado, s.estado into matchday_state, season_state
    from public.matchdays m join public.seasons s on s.id = m.season_id
    where m.id = new.matchday_id for share of m, s;
  if not found then
    raise exception using errcode = '23503', message = 'Unknown matchday';
  end if;
  if season_state <> 'ACTIVA' or matchday_state <> 'ABIERTA' then
    raise exception using errcode = '23514', message = 'New or changed structure requires an open matchday in an active season';
  end if;
  if tg_table_name = 'matches' and tg_op = 'UPDATE' then
    if exists(select 1 from public.predictions p where p.match_id = old.id) then
      raise exception using errcode = '23514', message = 'A predicted match cannot change its teams or competition';
    end if;
  end if;
  return new;
end;
$$;
create trigger trg_matches_structure
  before insert or update of competition_id, equipo_local_id, equipo_visitante_id on public.matches
  for each row execute function public.guard_matchday_structure();
create trigger trg_duels_structure before insert on public.duels
  for each row execute function public.guard_matchday_structure();

create function public.guard_prediction_creation()
returns trigger language plpgsql set search_path = '' as $$
declare
  matchday_state public.matchday_estado;
  season_state public.season_estado;
begin
  select m.estado, s.estado into matchday_state, season_state
    from public.matches f join public.matchdays m on m.id = f.matchday_id
      join public.seasons s on s.id = m.season_id
    where f.id = new.match_id for share of f, m, s;
  if not found then
    raise exception using errcode = '23503', message = 'Unknown match';
  end if;
  if season_state <> 'ACTIVA' or matchday_state <> 'ABIERTA' then
    raise exception using errcode = '23514', message = 'New predictions require an open matchday in an active season';
  end if;
  return new;
end;
$$;
-- UPDATE intentionally remains possible in closed history for admin corrections.
-- Identity and permission checks still apply; authorization/audit/recalculation are F1.8/F5.
create trigger trg_predictions_creation before insert on public.predictions
  for each row execute function public.guard_prediction_creation();

revoke delete, truncate on table public.profiles, public.invitation_codes,
  public.competitions, public.teams, public.seasons, public.matchdays,
  public.matches, public.predictions, public.duels from public, anon, authenticated, service_role;
revoke all on function public.prevent_history_deletion(), public.guard_record_identity(),
  public.guard_season_lifecycle(), public.guard_matchday_lifecycle(),
  public.guard_matchday_structure(), public.guard_prediction_creation()
  from public, anon, authenticated, service_role;

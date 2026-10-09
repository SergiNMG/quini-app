-- F1.5: persist virtual opponents without Auth users or historical rewrites.
-- A NULL player side is virtual; *_replaced_id keeps the retired profile identity.
-- Existing duel rows are untouched. Do not add scoring/statistics logic here.
set local lock_timeout = '5s';

alter table public.duels
  add column player_a_replaced_id uuid,
  add column player_b_replaced_id uuid;

-- Each side is exactly one of: a real profile OR a virtual side replacing
-- the named, retained profile. The virtual side itself is not an Auth account.
alter table public.duels
  alter column player_a_id drop not null,
  alter column player_b_id drop not null,
  drop constraint chk_players_distintos,
  add constraint chk_duel_player_a_kind check (
    (player_a_id is not null and player_a_replaced_id is null)
    or (player_a_id is null and player_a_replaced_id is not null)
  ),
  add constraint chk_duel_player_b_kind check (
    (player_b_id is not null and player_b_replaced_id is null)
    or (player_b_id is null and player_b_replaced_id is not null)
  ),
  add constraint chk_duel_distinct_participants check (
    coalesce(player_a_id, player_a_replaced_id)
      is distinct from coalesce(player_b_id, player_b_replaced_id)
  ),
  add constraint duels_player_a_replaced_id_fkey foreign key (player_a_replaced_id)
    references public.profiles(id) on delete restrict on update restrict,
  add constraint duels_player_b_replaced_id_fkey foreign key (player_b_replaced_id)
    references public.profiles(id) on delete restrict on update restrict,
  add constraint chk_duel_virtual_a_never_scores check (
    player_a_id is not null
    or ((aciertos_a is null or aciertos_a = 0) and (puntos_a is null or puntos_a = 0))
  ),
  add constraint chk_duel_virtual_b_never_scores check (
    player_b_id is not null
    or ((aciertos_b is null or aciertos_b = 0) and (puntos_b is null or puntos_b = 0))
  );

-- Assignment/replacement is part of the duel's immutable historical identity.
drop trigger trg_duels_identity on public.duels;
create trigger trg_duels_identity before update on public.duels
  for each row execute function public.guard_record_identity(
    'id', 'matchday_id', 'player_a_id', 'player_a_replaced_id',
    'player_b_id', 'player_b_replaced_id'
  );

create index idx_duels_player_a_replaced on public.duels(player_a_replaced_id);
create index idx_duels_player_b_replaced on public.duels(player_b_replaced_id);

-- Cross-table active/inactive status cannot be expressed in a CHECK constraint.
-- A narrowly scoped SECURITY DEFINER trigger can inspect profile state even after
-- the application RLS policies are enabled. The function has an empty search_path,
-- is fully schema-qualified, and has no direct EXECUTE grant to API roles.
create function public.guard_duel_participants()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  profile_id uuid;
  profile_active boolean;
begin
  -- Stable order avoids introducing deadlocks for overlapping duels.
  for profile_id in
    select participants.participant_id
    from unnest(array[
      new.player_a_id, new.player_a_replaced_id,
      new.player_b_id, new.player_b_replaced_id
    ]) as participants(participant_id)
    where participants.participant_id is not null
    group by participants.participant_id
    order by participants.participant_id
  loop
    select p.activo into profile_active
      from public.profiles p where p.id = profile_id for share;
    if not found then
      raise exception using errcode = '23503', message = 'Unknown duel participant';
    end if;

    if profile_id = new.player_a_id or profile_id = new.player_b_id then
      if not profile_active then
        raise exception using errcode = '23514', message = 'A newly assigned real player must be active';
      end if;
    elsif profile_active then
      raise exception using errcode = '23514', message = 'A virtual side must reference the inactive profile it replaces';
    end if;
  end loop;
  return new;
end;
$$;
revoke all on function public.guard_duel_participants() from public, anon, authenticated, service_role;
create trigger trg_duels_participant_state before insert on public.duels
  for each row execute function public.guard_duel_participants();

comment on column public.duels.player_a_id is
  'Real participant on side A; NULL means virtual and requires player_a_replaced_id';
comment on column public.duels.player_a_replaced_id is
  'Retained inactive profile replaced by the virtual participant on side A; never an Auth identity for the virtual itself';
comment on column public.duels.player_b_id is
  'Real participant on side B; NULL means virtual and requires player_b_replaced_id';
comment on column public.duels.player_b_replaced_id is
  'Retained inactive profile replaced by the virtual participant on side B; never an Auth identity for the virtual itself';

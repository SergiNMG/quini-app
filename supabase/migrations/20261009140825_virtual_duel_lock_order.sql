-- Keep duel BEFORE INSERT triggers in the same parent -> profiles lock order
-- that the future F3 publication RPC must use. PostgreSQL fires same-event
-- triggers in name order; never rely on their creation order.
drop trigger trg_duels_structure on public.duels;
drop trigger trg_duels_participant_state on public.duels;

create trigger trg_duels_00_structure
  before insert on public.duels
  for each row execute function public.guard_matchday_structure();

create trigger trg_duels_01_participant_state
  before insert on public.duels
  for each row execute function public.guard_duel_participants();

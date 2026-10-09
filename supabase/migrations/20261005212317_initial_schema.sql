-- ============================================================
-- QUINI APP - Esquema de base de datos (Supabase / PostgreSQL)
-- ============================================================
-- Initial baseline for an empty application schema, verified remotely before creation.
-- Apply through Supabase migrations, not by rerunning context/schema.sql.
-- No policies, Auth provisioning or business-rule functions yet (F1.4–F1.8 follow).
-- Keep this migration immutable once applied; add subsequent changes as new migrations.

-- ============================================================
-- TIPOS ENUMERADOS
-- ============================================================
create type public.user_role as enum ('ADMIN', 'PLAYER');
create type public.matchday_estado as enum ('ABIERTA', 'EN_CURSO', 'FINALIZADA');
create type public.season_estado as enum ('ACTIVA', 'FINALIZADA');
create type public.resultado_1x2 as enum ('1', 'X', '2');
create type public.duel_resultado as enum ('A_GANA', 'B_GANA', 'EMPATE');

-- ============================================================
-- PROFILES (extiende auth.users de Supabase Auth)
-- ============================================================
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  email text not null unique,
  avatar_url text,
  role public.user_role not null default 'PLAYER',
  activo boolean not null default true,
  invitation_code_used text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is 'Perfil de cada usuario (admin o player), 1:1 con auth.users';

-- Trigger para mantener updated_at al día
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- ============================================================
-- INVITATION CODES
-- ============================================================
create table public.invitation_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  usado boolean not null default false,
  usado_por uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

comment on table public.invitation_codes is 'Códigos de invitación para controlar el registro';

-- ============================================================
-- COMPETITIONS
-- ============================================================
create table public.competitions (
  id uuid primary key default gen_random_uuid(),
  nombre text not null unique,
  activo boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table public.competitions is 'Catálogo de competiciones: La Liga, Premier League, Champions League, Internacional...';

-- ============================================================
-- TEAMS
-- ============================================================
create table public.teams (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  escudo_url text,
  activo boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table public.teams is 'Equipos y selecciones, gestionados por el admin';

-- ============================================================
-- SEASONS
-- ============================================================
create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  nombre text not null unique,
  estado public.season_estado not null default 'ACTIVA',
  fecha_inicio date not null default current_date,
  fecha_fin date,
  created_at timestamptz not null default now()
);

comment on table public.seasons is 'Temporadas de juego; se conserva el histórico al crear una nueva';

-- ============================================================
-- MATCHDAYS (jornadas)
-- ============================================================
create table public.matchdays (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons(id) on delete cascade,
  numero integer not null,
  estado public.matchday_estado not null default 'ABIERTA',
  fecha_creacion timestamptz not null default now(),
  fecha_inicio timestamptz,
  unique (season_id, numero)
);

comment on table public.matchdays is 'Jornadas dentro de una temporada; ABIERTA = se puede pronosticar';

-- ============================================================
-- MATCHES (los 5 partidos de cada jornada)
-- ============================================================
create table public.matches (
  id uuid primary key default gen_random_uuid(),
  matchday_id uuid not null references public.matchdays(id) on delete cascade,
  competition_id uuid not null references public.competitions(id),
  equipo_local_id uuid not null references public.teams(id),
  equipo_visitante_id uuid not null references public.teams(id),
  resultado_real public.resultado_1x2,
  created_at timestamptz not null default now(),
  constraint chk_equipos_distintos check (equipo_local_id <> equipo_visitante_id)
);

comment on table public.matches is 'Partidos de una jornada; resultado_real lo rellena el admin';

-- ============================================================
-- PREDICTIONS
-- ============================================================
create table public.predictions (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  pronostico public.resultado_1x2 not null,
  acierto boolean,
  created_at timestamptz not null default now(),
  unique (match_id, player_id)
);

comment on table public.predictions is 'Pronóstico 1X2 de cada player por partido; inmutable salvo por el admin (se controla vía RLS, no aquí)';

-- ============================================================
-- DUELS (emparejamientos 1vs1 por jornada)
-- ============================================================
create table public.duels (
  id uuid primary key default gen_random_uuid(),
  matchday_id uuid not null references public.matchdays(id) on delete cascade,
  player_a_id uuid not null references public.profiles(id),
  player_b_id uuid not null references public.profiles(id),
  aciertos_a integer,
  aciertos_b integer,
  puntos_a integer,
  puntos_b integer,
  resultado public.duel_resultado,
  created_at timestamptz not null default now(),
  constraint chk_players_distintos check (player_a_id <> player_b_id)
);

comment on table public.duels is 'Duelo 1vs1 entre dos players en una jornada, con puntos resultantes';

-- ============================================================
-- ÍNDICES
-- ============================================================
create index idx_matches_matchday on public.matches(matchday_id);
create index idx_predictions_match on public.predictions(match_id);
create index idx_predictions_player on public.predictions(player_id);
create index idx_duels_matchday on public.duels(matchday_id);
create index idx_duels_player_a on public.duels(player_a_id);
create index idx_duels_player_b on public.duels(player_b_id);
create index idx_matchdays_season on public.matchdays(season_id);

-- ============================================================
-- ACTIVAR ROW LEVEL SECURITY
-- (sin políticas todavía: hasta que se añadan, las tablas quedan
--  bloqueadas por defecto para cualquier rol que no sea service_role)
-- ============================================================
alter table public.profiles enable row level security;
alter table public.invitation_codes enable row level security;
alter table public.competitions enable row level security;
alter table public.teams enable row level security;
alter table public.seasons enable row level security;
alter table public.matchdays enable row level security;
alter table public.matches enable row level security;
alter table public.predictions enable row level security;
alter table public.duels enable row level security;

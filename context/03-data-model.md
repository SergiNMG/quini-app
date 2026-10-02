# Modelo de datos

El script de creación completo está en `schema.sql` (listo para ejecutar en el SQL Editor de Supabase). Este documento resume las entidades y sus relaciones.

## Entidades principales

| Tabla | Descripción | Relaciones clave |
|---|---|---|
| `profiles` | Perfil de cada usuario (1:1 con `auth.users` de Supabase Auth); incluye `role` (ADMIN/PLAYER) y `activo` (soft delete) | — |
| `invitation_codes` | Códigos de invitación para controlar el registro | `usado_por` → `profiles` |
| `competitions` | Catálogo de competiciones (La Liga, Champions, etc.) | — |
| `teams` | Equipos y selecciones, con nombre y escudo | — |
| `seasons` | Temporadas de juego, con estado ACTIVA/FINALIZADA | — |
| `matchdays` | Jornadas dentro de una temporada | `season_id` → `seasons` |
| `matches` | Los 5 partidos de cada jornada | `matchday_id` → `matchdays`; `competition_id` → `competitions`; `equipo_local_id`/`equipo_visitante_id` → `teams` |
| `predictions` | Pronóstico 1X2 de cada player por partido | `match_id` → `matches`; `player_id` → `profiles` |
| `duels` | Duelo 1vs1 entre dos players en una jornada, con puntos resultantes | `matchday_id` → `matchdays`; `player_a_id`/`player_b_id` → `profiles` |

## Notas de diseño

- **`standings` (clasificación) no es una tabla física**: se calcula mediante una vista o función SQL a partir de `duels`, para no duplicar datos ni arriesgar inconsistencias. Debe soportar el desempate en cascada descrito en `02-business-rules.md`.
- **Soft delete en `profiles` y `teams`/`competitions`** (campo `activo`): nunca se borra físicamente un registro que ya tenga historial asociado (predicciones, duelos, partidos jugados).
- **Inmutabilidad de `predictions`**: se garantiza a nivel de RLS (políticas de Supabase), no con una restricción de base de datos, porque el admin sí debe poder modificarlas.
- **RLS**: activado en todas las tablas desde la creación del esquema; las políticas (quién puede leer/escribir cada tabla según su rol) son el siguiente paso pendiente, no están incluidas en `schema.sql` todavía.

## Pendiente de definir

- Políticas RLS detalladas por tabla y operación (SELECT/INSERT/UPDATE/DELETE).
- Función/vista SQL para calcular `standings` con el desempate en cascada.
- Función/trigger para calcular `acierto` en `predictions` y rellenar `duels` cuando el admin introduce los resultados de una jornada.

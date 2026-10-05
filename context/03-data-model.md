# Modelo de datos

El esquema inicial está en [`schema.sql`](schema.sql). Este documento resume sus entidades y las ampliaciones necesarias. El script todavía no incorpora RLS detallado, rival virtual, trazabilidad ni todas las invariantes de negocio; no representa un backend completo. La implementación deberá versionarse en `supabase/migrations/`, comprobando primero el estado del proyecto remoto.

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
- **RLS**: el script activa RLS en todas las tablas; las políticas por rol y operación todavía no están incluidas. La ejecución del script en el remoto no está verificada desde el repositorio.
- **Campos protegidos**: permitir editar el perfil propio no debe permitir cambiar `role` o `activo`; tampoco se permite al player escribir `acierto`, puntos o resultados calculados. RLS debe complementarse con permisos de columna o funciones de servidor controladas.
- **Envío completo**: las filas de `predictions` representan un envío de 5 partidos que debe guardarse en una sola transacción. La restricción única actual no garantiza este requisito.
- **Fallos por ausencia**: no hace falta crear cinco predicciones falsas; se derivan 0 aciertos y 5 fallos de la participación real en una jornada resuelta. Los lados virtuales no acumulan fallos ni estadísticas, incluido un duelo virtual contra virtual.
- **Rival virtual (diseño pendiente de implementar)**: `duels` necesita representar `jugador_undefined` y conservar el participante sustituido sin crear una cuenta ficticia de Auth. Evaluar un identificador de participante nullable con metadatos de sustitución y restricciones de integridad; no usar el `activo` actual para reinterpretar duelos históricos. Las FK `NOT NULL` actuales no permiten este modelo directamente.
- **Bajas y participantes conservados**: la sustitución virtual solo aplica a jornadas creadas después de la baja; las existentes mantienen participantes reales y envíos, aun estando abiertas/en curso. Registrar el momento efectivo y coordinarlo transaccionalmente con la creación de jornadas.
- **Privacidad de perfiles**: los players solo leen username/avatar ajenos; no basta una política SELECT de toda la fila `profiles`, que también contiene correo, rol, estado y datos de invitación. Separar la proyección de identidad de la consulta privada con permisos de columna o vistas/RPC seguras.
- **Lectura de pronósticos**: propietario o admin activo durante `ABIERTA`; todos los usuarios activos desde `EN_CURSO`. Anónimos y desactivados no consultan datos del juego ni histórico. Comprobar el perfil activo en backend, no solo en el JWT.
- **Posiciones de clasificación**: agrupar primero por puntos y conservar el tamaño inicial del grupo para elegir el desempate; igualdad completa con ranking compartido y saltos (`1, 2, 2, 4`).
- **Correcciones administrativas**: registrar cambios de pronósticos y recalcular los duelos afectados, también en temporadas cerradas, de forma atómica e idempotente. La tabla o mecanismo de auditoría aún no existe.
- **Integridad pendiente**: asegurar cinco partidos por jornada publicada, una participación por jugador y jornada, rangos de aciertos/puntos, transiciones válidas y protección contra borrados físicos del histórico. Los `ON DELETE CASCADE` actuales requieren revisión.

## Pendiente de definir

- Políticas RLS detalladas por tabla y operación (SELECT/INSERT/UPDATE/DELETE), funciones autorizadas y políticas de Storage.
- Flujo de registro con validación y consumo atómico de invitaciones, creación del perfil y sincronización del correo con Auth.
- Representación persistente del rival virtual, momento efectivo de la baja y operación de creación que preserve los participantes reales de jornadas existentes. El comportamiento funcional ya está confirmado.
- Función SQL de `standings` con la cascada de dos jugadores o de tres y más; no usar una comparación pairwise que produzca órdenes inconsistentes.
- Operación de servidor para calcular `acierto`, resolver `duels` y recalcular tras correcciones, sin duplicar puntos.
- Mecanismo mínimo de auditoría y pruebas de integridad. Las tareas y criterios de aceptación se detallan en [`05-roadmap.md`](05-roadmap.md).

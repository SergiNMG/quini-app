# F1.4 — Integridad y preservación del histórico

## Estado y alcance

Migración aplicada a **desarrollo remoto**: [`20261009133127_integrity_and_history.sql`](migrations/20261009133127_integrity_and_history.sql). El baseline anterior no se ha modificado.

Se validaron 62 comprobaciones nuevas y las 15 del baseline, en dos ejecuciones completas sin fixtures persistentes; lint sin errores, 9 tests del runner, 2 de Angular y build correctos. El historial local/remoto coincide y el dry-run final no tiene migraciones pendientes.

Esta tarea aporta invariantes de datos, **no** el motor de puntuación, las políticas de autorización, el rival virtual ni la publicación/envío atómico de cinco partidos. Las pruebas de cambios administrativos se ejecutan como operador SQL de desarrollo: demuestran que la integridad no bloquea la corrección, no que RLS ya autorice al admin desde la app.

## Preservación de registros

- Las **12 FK** tienen `ON DELETE RESTRICT ON UPDATE RESTRICT`. No quedan rutas `CASCADE` o `SET NULL` entre los registros de la aplicación, incluida `profiles.id → auth.users.id`.
- No borrar un usuario de Auth para implementar una baja: si tiene perfil, la FK lo impide. Desactivar mediante `profiles.activo = false`; no borrar perfil ni sus predicciones.
- Triggers bloquean DELETE de perfiles, equipos, competiciones, temporadas, jornadas, partidos, predicciones y duelos. El criterio es conservador: se conservan todos los registros persistidos, no solo aquellos ya puntuados. Equipos/competiciones/perfiles usan soft delete; temporadas usan cierre.
- Invitaciones consumidas conservan código, estado y usuario de consumo. Las no usadas pueden eliminarse mediante una operación de servidor autorizada; no se ha añadido una UI ni permiso de cliente para ello.
- TRUNCATE está bloqueado por trigger en las nueve tablas, incluso con CASCADE. `DELETE` y `TRUNCATE` se revocan a `PUBLIC`, `anon`, `authenticated` y `service_role`.
- Las cuentas Auth sin perfil no quedan bloqueadas por esta FK; esto permite tratar fallos de registro en el flujo de F1.6 sin borrar perfiles existentes.

No es una garantía frente a un propietario que modifique el esquema mediante DDL o desactive triggers explícitamente. Ningún flujo de aplicación debe hacerlo. Los resets remotos siguen prohibidos en el procedimiento normal.

## Identidad y adscripción histórica

No se puede cambiar:

| Entidad | Campos protegidos |
|---|---|
| Todas las tablas de aplicación | `id` |
| Jornadas | `season_id`, `numero` |
| Partidos | `matchday_id` |
| Pronósticos | `match_id`, `player_id` |
| Duelos | `matchday_id`, `player_a_id`, `player_b_id` |
| Invitación consumida | `code`, `usado`, `usado_por` |

Esto evita trasladar un pronóstico a otro jugador, cambiar retrospectivamente un rival o mover una jornada a otra temporada. F1.5 ya representa un lado virtual como `player_*_id IS NULL` y conserva la persona sustituida en `player_*_replaced_id`; se asigna al crear un duelo nuevo, nunca reescribe un duelo publicado. Reactivar luego a ese perfil no convierte el lado virtual en real.

Los nombres, avatares y estado activo del catálogo/perfil pueden mantenerse sin cambiar sus IDs. Cambiar equipos o competición de un partido exige temporada activa, jornada ABIERTA y ausencia de predicciones sobre ese partido; al comenzar la jornada o existir un pronóstico, se bloquea. Este límite de base de datos no introduce un flujo de edición de jornada: la UI y las decisiones de F3.5 siguen pendientes.

## Rangos y datos calculados

- `matchdays.numero > 0`.
- Si existe `seasons.fecha_fin`, no precede a `fecha_inicio`. No se exige una fecha de fin al cerrar ni se impone una única temporada activa: esas decisiones no se inventan en F1.4.
- Jornada ABIERTA: `fecha_inicio` nula. EN_CURSO/FINALIZADA: inicio informado y no anterior a `fecha_creacion`. La acción de comenzar debe guardar el instante efectivo.
- Aciertos por lado: 0–5; puntos por lado: 0, 1 o 3.
- Duelo pendiente: aciertos, puntos y resultado todos nulos.
- Duelo resuelto: ambos aciertos y ambos puntos informados; resultado consistente con la forma de los puntos:
  - `A_GANA`: 3/0; `B_GANA`: 0/3.
  - `EMPATE`: 1/1; también se reservan 1/0 y 0/1 para el futuro rival virtual.
  - Resultado nulo con ambos aciertos/puntos informados y 0/0: duelo resuelto no puntuable, distinto de uno pendiente.

No basta comprobar rangos: la restricción también rechaza cálculos parciales y no deja que `resultado = NULL` eluda la coherencia por la semántica de los CHECK de PostgreSQL. F1.5 concreta qué lado es virtual y restringe sus puntos/aciertos a cero; el motor F5 decide si corresponde 3/0, 1/0, 0/0 y cuándo se finaliza.

## Estados y actividad nueva

- Una temporada nueva comienza ACTIVA y solo puede pasar a FINALIZADA; no se reabre.
- Una jornada nueva comienza ABIERTA y solo avanza `ABIERTA → EN_CURSO → FINALIZADA`, sin saltos ni reapertura.
- No se crean jornadas en una temporada finalizada ni se cambia allí el estado de jornadas existentes.
- Nuevos partidos, duelos o predicciones exigen temporada activa y jornada abierta.
- Actualizar el pronóstico de una fila existente o los datos calculados de su duelo **sigue permitido por estas guardias**, incluso con jornada/temporada finalizada. La autorización, auditoría y recálculo atómico se implementan en F1.8/F5; no se permite cambiar propietario, partido o rivales para simular una corrección.

Finalizar una jornada todavía no comprueba sus cinco resultados ni la resolución de todos los duelos: F5 lo hará. Cerrar una temporada tampoco implementa aún la comprobación completa de jornadas pendientes de F6.5. Estas transiciones son la base, no las operaciones funcionales terminadas.

## Concurrencia: base implementada y plan de operaciones

Las comprobaciones de estado toman **bloqueos de fila `FOR SHARE`** sobre los padres. Estos bloqueos entran en conflicto con un UPDATE de estado, a diferencia de `FOR KEY SHARE`, que solo protege la clave. Crear una predicción bloquea también su partido para serializarse con cambios de equipos/competición.

Esto evita validar un padre como abierto/activo mientras otra transacción lo cambia de estado sin esperar. No demuestra por sí solo que el futuro flujo completo sea correcto bajo cualquier carrera: las pruebas actuales son transaccionales de una sesión; las pruebas de concurrencia de RPC completas corresponden a F3/F4/F5.

### F3 — Publicar e iniciar jornada

1. Una operación de servidor autorizada valida admin activo y temporada, y fija el límite de bajas al crear la jornada.
2. Validar exactamente cinco partidos, equipos distintos/activos y competición activa; insertar jornada, partidos y duelos en **una sola transacción**, todo o nada.
3. Comprobar cobertura del grupo y que cada participante aparece exactamente una vez, incluso entre las columnas A y B. Dos UNIQUE independientes sobre A/B no impiden que un usuario aparezca una vez en cada columna.
4. Serializar modificaciones de una jornada existente mediante bloqueo de su fila antes de validar/escribir; coordinar inicio y envíos sobre el mismo punto de exclusión.
5. Impedir escrituras directas de clientes que eludan esa operación mediante RLS/permisos/RPC. Reintentos de publicación deben ser idempotentes.

### F4 — Enviar los cinco pronósticos

1. Validar usuario activo, participación real, temporada activa, jornada abierta y ausencia de envío anterior.
2. Bloquear la jornada, volver a comprobar el estado y validar que los cinco IDs son exactamente sus cinco partidos, sin duplicados ni partidos ajenos.
3. Insertar las cinco filas de una vez. La unicidad `(match_id, player_id)` existente no garantiza un envío completo.
4. Coordinar el bloqueo con la acción de inicio para que un cierre concurrente no deje un envío parcial/tardío. F1.8 controla quién puede insertar/corregir; no es un permiso implícito de estas guardias.

### F5/F6 — Resolver, corregir y cerrar

Resolver/corregir con bloqueo de jornada/duelos y sobrescritura atómica de derivados, sin sumar puntos otra vez. Comprobar los cinco resultados al finalizar, jornadas pendientes al cerrar temporada y conservar la excepción administrativa sobre pronósticos existentes. La clasificación solo cuenta jornadas resueltas.

La persistencia virtual está en `20261009140144_virtual_duel_participants.sql`: los dos `player_*_id` son nullables y, por lado, exactamente uno entre jugador real y perfil sustituido es no nulo. Los reemplazos tienen FK RESTRICT e índices. `guard_duel_participants()` verifica en INSERT real activo o reemplazo inactivo con un `SECURITY DEFINER` acotado, `search_path` vacío, nombres cualificados, perfiles bloqueados en orden UUID y sin EXECUTE para roles API. El trigger de identidad de F1.4 también hace inmutable el reemplazo. Los CHECKs garantizan que un lado virtual solo pueda tener 0 aciertos/0 puntos; el punto del empate virtual corresponde solo al lado real. Doble virtual se puede guardar y resolver 0/0 sin estadísticas. Las columnas de reemplazo deben ocultarse en vistas/RPC seguras de F1.8: no exponer `SELECT *` de duelos ni el ID privado del perfil para rotular al rival.

Las RPC deben adoptar un orden de bloqueos consistente —primero jornada y luego perfiles en orden UUID, alineado con el trigger— y tratar reintentos por deadlock/serialización. No añadir CHECK con consultas a otras tablas ni triggers ingenuos de `count(*) = 5`: no resuelven por sí solos la atomicidad o los envíos concurrentes. Si se opta por restricciones diferidas o una representación normalizada de participación, añadirla como una migración nueva y probar commits reales/concurrencia en su fase.

## Referencias de PostgreSQL 17

- [CHECK, NULL y FK RESTRICT](https://www.postgresql.org/docs/17/ddl-constraints.html).
- [Bloqueos explícitos y de fila](https://www.postgresql.org/docs/17/explicit-locking.html).
- [Triggers](https://www.postgresql.org/docs/17/sql-createtrigger.html).

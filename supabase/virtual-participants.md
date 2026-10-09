# F1.5 — Persistencia del rival virtual

## Representación

Cada duel side tiene dos columnas:

| Lado | Jugador real | Perfil sustituido |
|---|---|---|
| Real | `player_a_id` / `player_b_id` con FK a perfil activo al publicar | `player_*_replaced_id IS NULL` |
| Virtual (`jugador_undefined`) | `player_*_id IS NULL` | `player_*_replaced_id` con FK al perfil desactivado que ocupaba ese hueco |

Nunca se crea un `auth.users`, perfil con username `jugador_undefined`, UUID sintético o predicción falsa para representar al rival virtual. El `NULL` en la columna del participante es el marcador inequívoco de lado virtual; el perfil sustituido queda como procedencia/historia, no como participante que pronosticará o puntuará en esa jornada.

La migración [20261009140144_virtual_duel_participants.sql](migrations/20261009140144_virtual_duel_participants.sql) implementa:

- Participante real o virtual mutuamente excluyentes por lado; cada lado debe tener su tipo exactamente una vez.
- No enfrentar el mismo perfil contra sí mismo ni con su propia sustitución virtual.
- FK RESTRICT e índices para referencias de reemplazo.
- Trigger de INSERT de duelo que exige que los participantes reales estén activos y los perfiles usados como sustituciones estén inactivos. Bloquea las filas de perfiles en orden UUID para serializarse con cambios concurrentes de `activo`.
- El metadato de participante real/reemplazado se añade al trigger de identidad de F1.4 y no se puede reescribir una vez publicado.
- Un lado virtual solo admite cero aciertos y cero puntos, o null mientras el duelo siga pendiente. El empate asimétrico posible es exclusivamente `EMPATE` con puntos 1/0 o 0/1; el virtual nunca tiene puntos.
- Un duelo virtual-vs-virtual se conserva con dos perfiles reemplazados y dos participantes virtuales. Si ya está resuelto y es no puntuable, se representa con aciertos 0/0, puntos 0/0 y `resultado NULL`; las consultas deben diferenciarlo de pendiente porque ambos aciertos/puntos estarán presentes.

`SECURITY DEFINER` se usa solo en el trigger para consultar `profiles.activo` a pesar de futuras políticas RLS. Tiene `search_path = ''`, referencias de tabla cualificadas y no concede `EXECUTE` a `PUBLIC`, `anon`, `authenticated` ni `service_role`. La función no está disponible como RPC invocable por el cliente.

## Baja y momento efectivo

- Desactivar un jugador no reescribe jornadas existentes, abiertas/en curso/finalizadas, ni convierte sus duelos reales a virtuales.
- El duelo nuevo que reemplaza una plaza solo puede añadirse al crear una jornada posterior a la baja.
- Si un perfil se reactiva tras crear una jornada virtual, el slot continúa virtual; el duel conserva su snapshot de publicación.
- En jornadas existentes, un jugador desactivado conserva lo enviado. Sin envío se aplica ausencia de participante real, no ausencia de virtual.
- Los dos `player_*_replaced_id` son procedencia y no disparan predicciones, fallos, estadísticas o clasificación para esos perfiles en el duelo virtual.

El trigger comprueba la condición observada al insertar, pero la operación transaccional F3 tiene que crear la jornada y todos sus duelos de forma atómica y determinar el corte de bajas. Bloquear primero la jornada/operación de publicación y luego los perfiles en orden UUID; no decidir después de publicar consultando solo el `activo` actual. El trigger no comprueba que cada participante aparezca exactamente una vez entre todos los duelos ni garantiza publicación completa.

## Visibilidad y API

Los campos `player_*_replaced_id` contienen IDs reales de perfiles desactivados y no deben exponerse mediante un `SELECT *` autorizado a players. F1.8 debe diseñar proyección segura (column grants, view `security_invoker`/RPC controlada o consulta equivalente) que permita mostrar `jugador_undefined` sin filtrar los IDs privados, correo o estado de perfiles ajenos. Tampoco se puede confiar únicamente en que el frontend oculte esos campos.

## Puntos, fallos y clasificación aún no implementados

La migración mantiene los rangos y coherencia SQL, y garantiza cero aciertos/puntos virtuales; **no calcula puntos, resultado ni estadísticas**. El motor F5 debe aplicar:

- Real con envío, 1–5 aciertos: 3/0.
- Real con envío y 0 aciertos: 1/0 (`EMPATE`); los cinco fallos cuentan al real.
- Real sin envío: 0/0, cinco fallos y sin empate puntuable.
- Virtual-vs-virtual: resuelto 0/0, sin estadísticas/puntos/fallos/posición para ninguno.

Solo el participante real figura en `standings`. Estos comportamientos son reglas ya confirmadas; migración separada para motor/pruebas F5. La UI, asignación automática/manual al crear jornada (F3) y renderizado visible corresponden a F3/F4/F5.

## Pruebas y cierre

La suite `tests/virtual_duel_participants.test.sql` contiene 27 casos: relaciones, ambos lados/orientaciones, doble virtual, referencias inválidas, perfil activo/inactivo, autocara virtual, puntuación/asimetría, cero puntos del virtual, inmutabilidad del snapshot/reactivación, no reescritura de duelos históricos, orden de triggers y aislamiento/no invocabilidad del trigger `SECURITY DEFINER`.

Se ejecuta por `pnpm db:test` junto con las 62 pruebas F1.4 y las 15 del baseline: 104 en total, en el proyecto de desarrollo autorizado, con fixtures y usuarios Auth ficticios solo dentro de la transacción con rollback. No se resetea ni se puebla la base remota de forma persistente.

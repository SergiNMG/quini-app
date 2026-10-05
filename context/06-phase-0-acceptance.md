# Fase 0 — Decisiones confirmadas y ejemplos de aceptación

Este documento cierra las validaciones F0.4–F0.7 del [roadmap](05-roadmap.md). Las decisiones fueron confirmadas por el desarrollador; las [reglas de negocio](02-business-rules.md) son el contrato funcional. Aquí se conservan ejemplos para convertirlos en pruebas de implementación, **no un segundo backlog**.

La fase 0 valida el comportamiento esperado. No significa que existan ya el motor SQL, las políticas RLS o pruebas automatizadas de esas funcionalidades: se implementan en las fases siguientes.

## F0.4 — Desempates y posiciones

### Decisiones

1. Agrupar por puntos de temporada antes de aplicar cualquier desempate.
2. Dos jugadores: balance de victorias en duelos directos, diferencia aciertos/fallos y victorias totales, en ese orden. Balance igual o ningún enfrentamiento: pasar a diferencia.
3. Tres o más: aciertos totales de temporada, diferencia aciertos/fallos y victorias totales, sin volver al average directo si queda un subgrupo de dos.
4. Igualdad completa: posición compartida con saltos (`1, 2, 2, 4`). Username ascendente solo para presentación; no decide un ganador.
5. El rival virtual no forma parte de los grupos de clasificación.

### Ejemplo A — Dos empatados: prevalece el directo

| Jugador | Puntos de temporada | Aciertos | Fallos | Victorias directas contra el otro |
|---|---:|---:|---:|---:|
| Alba | 12 | 14 | 26 | 2 |
| Bruno | 12 | 18 | 22 | 1 |

**Esperado:** Alba por delante de Bruno. Tener más aciertos globales no sustituye el average directo en un empate inicial de dos.

### Ejemplo B — Sin directo: diferencia aciertos/fallos

| Jugador | Puntos | Aciertos | Fallos | Diferencia | Enfrentamientos entre ellos |
|---|---:|---:|---:|---:|---:|
| Alba | 9 | 18 | 22 | -4 | 0 |
| Bruno | 9 | 16 | 24 | -8 | 0 |

**Esperado:** Alba por delante de Bruno. Se aplica lo mismo si sí jugaron, pero empatan en victorias directas.

### Ejemplo C — Directo y diferencia iguales: victorias totales

| Jugador | Puntos | Aciertos | Fallos | Victorias totales | Empates puntuables | Balance directo |
|---|---:|---:|---:|---:|---:|---|
| Alba | 12 | 18 | 22 | 4 | 0 | Igualado |
| Bruno | 12 | 18 | 22 | 3 | 3 | Igualado |

**Esperado:** Alba por delante de Bruno por más jornadas ganadas. Los 12 puntos son compatibles con ambos balances: `4 × 3` y `3 × 3 + 3 × 1`.

### Ejemplo D — Tres empatados: no reiniciar el directo

| Jugador | Puntos | Aciertos | Fallos | Diferencia | Victorias totales |
|---|---:|---:|---:|---:|---:|
| Alba | 12 | 20 | 20 | 0 | 3 |
| Bruno | 12 | 18 | 22 | -4 | 4 |
| Carla | 12 | 18 | 22 | -4 | 3 |

**Esperado:** Alba → Bruno → Carla. Alba se separa por aciertos; Bruno y Carla siguen con diferencia y victorias. Aunque Carla tenga mejor balance directo contra Bruno, no se usa porque el empate inicial a puntos era de tres.

En estos ejemplos se contabilizan ocho jornadas de cinco partidos por jugador: `aciertos + fallos = 40`. Si todos contabilizan el mismo número de jornadas, igualar aciertos implica igualar diferencia; no se inventan fallos para forzar ese criterio.

### Ejemplo E — Igualdad completa y posición compartida

| Jugador | Puntos | Aciertos | Fallos | Diferencia | Victorias totales | Posición esperada |
|---|---:|---:|---:|---:|---:|---:|
| Alba | 12 | 20 | 20 | 0 | 3 | 1 |
| Bruno | 12 | 18 | 22 | -4 | 3 | 2 |
| Carla | 12 | 18 | 22 | -4 | 3 | 2 |
| Diego | 9 | 16 | 24 | -8 | 2 | 4 |

**Esperado:** posiciones `1, 2, 2, 4`. Bruno aparece antes que Carla por username, pero ambos comparten la segunda posición. Para cuatro o más empatados se aplica la misma cascada de empate múltiple, no comparaciones directas por parejas.

## F0.5 — Momento efectivo de una baja

### Decisión

La baja bloquea inmediatamente nuevos envíos y acceso protegido del jugador, pero la sustitución por virtual se aplica solo en **jornadas creadas después**. Una jornada ya publicada conserva sus participantes reales, independientemente de si está abierta, en curso o finalizada.

### Escenarios esperados

| Situación al desactivar a Bruno | Esperado |
|---|---|
| Jornada finalizada | Duelo, puntos, pronósticos y estadísticas no cambian por la baja |
| Jornada en curso; Bruno envió | Lo enviado se evalúa normalmente, incluso si Bruno termina ganando |
| Jornada abierta; Bruno envió | Se conserva el duelo real y lo enviado; no se transforma en virtual |
| Jornada abierta; Bruno no envió | Bruno no puede enviar; Alba sí: se resuelve como ausencia de rival real |
| Caso anterior; Alba envió pero acertó 0 | Alba obtiene 3 puntos por ausencia real; Bruno 0 puntos y 5 fallos |
| Nueva jornada creada tras la baja | La plaza sustituida es virtual; si Alba envía y acierta 0, obtiene 1 punto |
| Sesión de Bruno emitida antes de la baja | No permite nuevos envíos ni consultar datos protegidos tras desactivarlo |
| Recálculo de una jornada antigua tras la baja | Usa el participante real conservado, no lo convierte en virtual por su estado actual |

El backend debe serializar bajas y creación de jornadas para fijar cuál ocurrió antes. Reactivación y cambios estructurales de jornadas no se añaden como nuevos flujos competitivos en esta validación; su implementación debe respetar los duelos conservados.

## F0.6 — Casos extremos del rival virtual

| Duelo | Envío del real | Aciertos del real | Puntos real/virtual | Fallos del real | Resultado esperado |
|---|---|---:|---|---:|---|
| Real vs virtual | Sí | 2 | 3 / 0 | 3 | Victoria del real |
| Real vs virtual | Sí | 0 | 1 / 0 | 5 | Empate especial; virtual nunca suma |
| Real vs virtual | No | 0 | 0 / 0 | 5 | No puntuable; no empate deportivo |
| Virtual vs virtual | No hay participante real | — | 0 / 0 | — | Conservar registro sin puntos ni estadísticas |

El doble virtual no suma fallos a antiguos jugadores desactivados. Las predicciones de jornadas anteriores siguen vinculadas a esos jugadores y no se borran. Recalcular cualquiera de estos escenarios dos veces debe dar el mismo resultado, sin sumar de nuevo puntos.

## F0.7 — Visibilidad

### Decisión

- Juego, clasificación y temporadas históricas: solo usuarios autenticados activos del grupo.
- Jornada `ABIERTA`: player ve solo sus pronósticos; admin activo ve todos.
- Desde `EN_CURSO`, incluidos estados `FINALIZADA`: todos los usuarios activos ven los pronósticos del grupo.
- Identidad ajena: username/avatar. Correo y perfil privado: propietario/admin; invitaciones y auditoría: admin.
- Un usuario desactivado no recupera acceso al cambiar la contraseña ni por conservar un token antiguo.

### Escenarios esperados de permisos

| Actor y acción | Esperado |
|---|---|
| Anónimo consulta clasificación, jornadas o histórico | Denegado, también por API directa |
| Anónimo intenta listar invitaciones | Denegado; solo puede utilizar la validación limitada del registro |
| Alba consulta lo enviado por Bruno en `ABIERTA` | Denegado |
| Alba consulta su envío en `ABIERTA` | Permitido |
| Admin activo consulta lo enviado por Bruno en `ABIERTA` | Permitido |
| Alba consulta lo enviado por Bruno tras pasar a `EN_CURSO` | Permitido, sin esperar resultados |
| Alba consulta el histórico de otra temporada del grupo | Permitido |
| Alba consulta username/avatar de Bruno, aunque Bruno esté desactivado | Permitido para identificar el histórico |
| Alba solicita email, rol/estado privados, invitaciones o auditoría de Bruno | Denegado |
| Alba consulta su propio correo/perfil | Permitido; role/activo no son editables por ella |
| Usuario desactivado consulta datos del juego con sesión antigua | Denegado |
| Admin desactivado intenta consultar o corregir pronósticos | Denegado |

RLS filtra filas, no oculta por sí solo columnas privadas. La fase 1 debe diseñar permisos de columna, proyecciones/vistas o funciones seguras para separar identidad visible y perfil privado. Las consultas de clasificación y estadísticas no deben saltarse estas restricciones mediante funciones o vistas privilegiadas.

## Cierre de fase 0

F0.4–F0.7 quedan confirmadas y documentadas. Estos escenarios son criterios de aceptación de las fases de implementación, no funcionalidades implementadas. El siguiente paso del roadmap es **F1.3: verificar el estado remoto de Supabase y versionar el esquema**.

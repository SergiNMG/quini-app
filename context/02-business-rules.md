# Reglas de negocio

## Pronósticos y estadísticas por jornada

- Cada jornada contiene exactamente 5 partidos, iguales para todos los participantes.
- El envío del player debe contener los 5 pronósticos 1X2 y guardarse de forma atómica: todos o ninguno. No se considera enviado un formulario parcial.
- Para cada participante real en una jornada resuelta: `fallos = 5 - aciertos`.
- Quien no pronostica tiene **0 aciertos y 5 fallos**. Los fallos penalizan sus estadísticas y los desempates, aunque no existan filas en `predictions`.
- Las estadísticas solo incorporan jornadas resueltas; un resultado aún no introducido no es un fallo.

## Motor de puntuación por duelo entre jugadores reales

Una vez el admin ha introducido el resultado real de los 5 partidos:

1. Si ambos players pronosticaron, se compara su número de aciertos (0 a 5):
   - Más aciertos: **3 puntos** para el ganador y **0 puntos** para el rival.
   - Mismos aciertos: **1 punto** para cada uno.
2. Si solo uno pronosticó, obtiene **3 puntos automáticamente**, incluso con 0 aciertos. El que no pronosticó obtiene 0 puntos, 0 aciertos y 5 fallos.
3. Si ninguno pronosticó, ambos reciben **0 puntos**, 0 aciertos y 5 fallos. No es un empate puntuable.

La ausencia de pronóstico de un jugador real y el rival virtual `jugador_undefined` son casos distintos; no se debe aplicar la victoria automática del punto 2 al rival virtual.

## Desempate en la clasificación

Primero se ordena por puntos totales de la temporada, de mayor a menor. Para un grupo empatado a puntos:

1. **Primer criterio, según el tamaño del grupo original empatado a puntos:**
   - **Dos jugadores:** average directo, según quién ganó su duelo o el balance de victorias en sus enfrentamientos si jugaron más de una vez. Si no se enfrentaron o el balance es igual, se pasa al siguiente criterio.
   - **Tres o más jugadores:** número total de **pronósticos acertados en toda la temporada**, de mayor a menor, sin restar fallos. Este criterio sustituye al average directo; no se calcula una miniliga de enfrentamientos.
2. **Diferencia de pronósticos acertados/fallados:** `total_aciertos - total_fallos`, de mayor a menor.
3. **Número de jornadas ganadas:** duelos ganados durante la temporada, de mayor a menor.

Si el primer criterio de un grupo de tres o más deja a dos jugadores empatados, se continúa con diferencia aciertos/fallos y jornadas ganadas; **no se reinicia la cascada con average directo**. El tamaño del grupo se fija al agrupar inicialmente por puntos, no al comparar cada pareja.

Si todos los criterios siguen empatados, existe igualdad deportiva y se muestra **posición compartida con saltos**: `1, 2, 2, 4`. Dentro del empate, ordenar visualmente por `username` ascendente (y por ID para estabilidad técnica si hiciera falta), sin convertir ese orden en mérito deportivo.

Los ejemplos de aceptación y los datos con resultados esperados están en [validación de fase 0](06-phase-0-acceptance.md). Si dos jugadores tienen los mismos aciertos y el mismo número de jornadas contabilizadas, también tienen la misma diferencia aciertos/fallos; se conserva el criterio de diferencia aunque en ese caso no los separe.

Aciertos, fallos, jornadas ganadas y enfrentamientos directos deben poder consultarse también en estadísticas. `jugador_undefined` nunca aparece en la clasificación.

## Bajas de jugadores y rival virtual

- Un player no puede darse de baja por sí mismo a mitad de temporada.
- Solo el admin puede desactivar un jugador: **soft delete** mediante `activo = false`. No se borra el perfil, sus pronósticos enviados ni su historial.
- Los duelos históricos ya resueltos no se reinterpretan por cambiar el estado actual del perfil.
- En los duelos futuros afectados por una baja, el rival pasa a ser **`jugador_undefined`**, para mantener los emparejamientos aunque haya un número impar de participantes reales.
- `jugador_undefined` es un rival virtual, no una cuenta de Auth ni un usuario que pueda registrarse. Nunca pronostica, siempre tiene 0 aciertos y nunca suma puntos ni estadísticas de clasificación.
- En un duelo publicado, la app conserva una plaza virtual separada de la identidad del perfil desactivado que fue sustituido; reactivar ese perfil no convierte duelos existentes a jugador real. El proyecto no expone un ID ficticio de Auth para `jugador_undefined`.
- El rival real debe enviar los mismos 5 pronósticos que en cualquier otra jornada.

### Puntuación contra `jugador_undefined`

| Situación del jugador real | Aciertos del jugador real | Puntos del jugador real | Puntos del rival virtual |
|---|---:|---:|---:|
| Pronostica | 1 a 5 | 3 | 0 |
| Pronostica | 0 | 1 | 0 |
| No pronostica | 0 | 0 | 0 |

El jugador real acumula `5 - aciertos` fallos; si no pronostica, acumula 5. Solo la victoria de 3 puntos cuenta como jornada ganada. El empate contra el rival virtual da un punto exclusivamente al jugador real.

**Caso confirmado: real sin envío contra virtual.** Recibe 0 puntos, 0 aciertos y 5 fallos; no obtiene el punto del empate reservado a quien sí pronosticó.

**Caso confirmado: virtual contra virtual.** Se conserva el registro como duelo no puntuable con 0/0 puntos. Ninguno suma aciertos, fallos, victorias, empates o posiciones. No se elimina ni se interpreta como empate deportivo.

### Límite temporal de una baja

La sustitución se aplica **solo a jornadas creadas después de la desactivación**, cuando corresponda conservar una plaza virtual. Desactivar no transforma duelos de jornadas que ya existen/publicadas, aunque estén `ABIERTA` o `EN_CURSO`.

| Estado/situación al desactivar | Efecto |
|---|---|
| Jornada existente `FINALIZADA` | Se conserva el duelo real, sus puntos y estadísticas |
| Jornada existente `EN_CURSO` | Se conserva el duelo real; lo enviado se evalúa normalmente al resolver |
| Jornada existente `ABIERTA` | Se conserva el duelo real y lo enviado; el desactivado no puede realizar nuevos envíos propios |
| Jornada creada después de la baja | Rival virtual cuando corresponda; no se aceptan pronósticos del desactivado |

En una jornada existente abierta, si el desactivado no había enviado, se aplican las reglas de **ausencia de un jugador real**, no las del virtual. Si ya había enviado, sus pronósticos siguen contando y puede obtener puntos al resolverse. No se reasignan al virtual ni se borran.

Registrar el momento efectivo de la baja y conservar en cada duelo qué participante era real o virtual. La creación de jornadas y las bajas concurrentes deben fijar ese límite de forma transaccional, sin decidir posteriormente a partir del `activo` actual.

Es un caso excepcional para un grupo de amigos, no un sistema de altas y bajas competitivo avanzado.

## Visibilidad y privacidad

La aplicación es **privada para usuarios autenticados activos**. El histórico completo de temporadas del grupo está disponible para todos ellos; no hay clasificación ni histórico públicos.

| Datos/operación | Anónimo | Player activo | Admin activo | Usuario desactivado |
|---|---|---|---|---|
| Login, registro con invitación y recuperación | Sí | Disponible cuando corresponda | Disponible cuando corresponda | Recuperar credenciales no reactiva la cuenta |
| Jornadas, duelos, resultados, clasificación e histórico | No | Sí | Sí | No |
| Pronósticos en `ABIERTA` | No | Solo los propios | Todos | No |
| Pronósticos en `EN_CURSO` o `FINALIZADA` | No | Todos los del grupo | Todos | No |
| Identidad de otros jugadores | No | Solo username/avatar | Datos necesarios para gestionar perfiles | No |
| Perfil privado y correo | No | Solo el propio | Todos los necesarios para gestión | No |
| Catálogo/gestión de invitaciones | No | No | Sí | No |
| Configuración y acciones administrativas | No | No | Sí | No |

- La revelación de pronósticos ocurre al pasar la jornada a `EN_CURSO`, no al guardar resultados ni al primer envío de un rival. Incluye pronósticos conservados de jugadores desactivados.
- El admin puede revisar pronósticos siempre, incluso durante `ABIERTA`, porque necesita gestionarlos y corregirlos.
- El grupo puede ver username/avatar de participantes desactivados para entender el histórico, pero eso no les concede a estos acceso al juego.
- Correos, rol/estado privados, códigos de invitación y auditoría no se exponen a otros players. Consultar identidad ajena no concede lectura de la fila privada completa de `profiles`.
- Validar el código de invitación al registrarse no permite listar códigos ni consultar quién los utilizó; la validación se realiza mediante un flujo de servidor limitado.
- La condición de usuario activo se comprueba en backend, incluso si la sesión fue emitida antes de la baja.
- Los escudos servidos mediante Storage público siguen siendo archivos no sensibles: conocer su URL no da acceso anónimo a perfiles, jornadas o histórico. La política de almacenamiento de avatares se concreta en F1.12 respetando la privacidad del perfil.

## Inmutabilidad y correcciones de pronósticos

- El player solo puede enviar su formulario mientras la jornada está `ABIERTA`; una vez guardado no puede editarlo ni eliminarlo.
- El **admin puede corregir pronósticos cuando quiera y lo considere necesario**, sin necesitar una solicitud del player ni limitarse al estado `ABIERTA`.
- Si la jornada ya está resuelta, corregir un pronóstico obliga a recalcular aciertos, fallos, puntos, resultado del duelo, clasificación y estadísticas afectadas.
- El recálculo debe ser atómico e idempotente: repetirlo no puede acumular puntos duplicados.
- Las correcciones administrativas deben quedar trazadas con administrador, fecha y valores anteriores/nuevos. Es una salvaguarda técnica, no un flujo de aprobación.

## Estados de jornada

- `ABIERTA`: admite el primer envío de los players.
- `EN_CURSO`: el admin ha comenzado la jornada; no admite envíos ni cambios de players.
- `FINALIZADA`: los 5 resultados están completos y los duelos se han resuelto.
- Empezar una jornada es una acción explícita del admin, no un cierre automático por la hora del primer partido.
- Las comprobaciones de estado y el guardado deben protegerse en servidor contra envíos concurrentes con el inicio de jornada.

## Temporadas e histórico

- Al cerrar una temporada se conserva todo su histórico y se bloquea la actividad ordinaria: nuevas jornadas y envíos de players.
- Crear una nueva temporada no borra la anterior; empieza una clasificación nueva desde cero.
- **Excepción al histórico congelado:** el admin mantiene su permiso de corregir pronósticos incluso en temporadas finalizadas. Estas correcciones son explícitas, quedan registradas y recalculan el histórico afectado sin reabrir la temporada para los players.
- Las bajas actuales no eliminan la clasificación ni las estadísticas previas del jugador desactivado.

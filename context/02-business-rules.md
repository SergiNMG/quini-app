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

Si el primer criterio de un grupo de tres o más deja a dos jugadores empatados, se continúa con diferencia aciertos/fallos y jornadas ganadas; no se reinicia la cascada con average directo. Esta interpretación operativa evita un orden no transitivo y debe validarse con ejemplos antes de implementar la clasificación.

Si todos los criterios siguen empatados, existe igualdad deportiva. La interfaz puede usar un orden estable de presentación, pero no debe inventar otro desempate deportivo.

Aciertos, fallos, jornadas ganadas y enfrentamientos directos deben poder consultarse también en estadísticas. `jugador_undefined` nunca aparece en la clasificación.

## Bajas de jugadores y rival virtual

- Un player no puede darse de baja por sí mismo a mitad de temporada.
- Solo el admin puede desactivar un jugador: **soft delete** mediante `activo = false`. No se borra el perfil, sus pronósticos enviados ni su historial.
- Los duelos históricos ya resueltos no se reinterpretan por cambiar el estado actual del perfil.
- En los duelos futuros afectados por una baja, el rival pasa a ser **`jugador_undefined`**, para mantener los emparejamientos aunque haya un número impar de participantes reales.
- `jugador_undefined` es un rival virtual, no una cuenta de Auth ni un usuario que pueda registrarse. Nunca pronostica, siempre tiene 0 aciertos y nunca suma puntos ni estadísticas de clasificación.
- El rival real debe enviar los mismos 5 pronósticos que en cualquier otra jornada.

### Puntuación contra `jugador_undefined`

| Situación del jugador real | Aciertos del jugador real | Puntos del jugador real | Puntos del rival virtual |
|---|---:|---:|---:|
| Pronostica | 1 a 5 | 3 | 0 |
| Pronostica | 0 | 1 | 0 |
| No pronostica | 0 | 0 | 0 |

El jugador real acumula `5 - aciertos` fallos; si no pronostica, acumula 5. Solo la victoria de 3 puntos cuenta como jornada ganada. El empate contra el rival virtual da un punto exclusivamente al jugador real.

La interpretación operativa para el jugador real que no pronostica es conservar la regla general de no sumar; confirmar este caso en las pruebas de aceptación antes de implementar.

### Límite temporal de una baja

La decisión de producto cubre los **duelos futuros**. Antes de implementar la desactivación se debe concretar el tratamiento de una jornada ya `ABIERTA` o `EN_CURSO`, especialmente si el jugador ya envió pronósticos. No se debe deducir la identidad del rival usando solo el `activo` actual: hay que conservar qué participante era real o virtual en cada duelo y desde cuándo se aplica la baja.

Es un caso excepcional para un grupo de amigos, no un sistema de altas y bajas competitivo avanzado.

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

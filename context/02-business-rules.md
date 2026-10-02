# Reglas de negocio

## Motor de puntuación por duelo

Para cada duelo 1vs1 de una jornada, una vez el admin ha introducido el resultado real de los 5 partidos:

1. Se calcula el nº de aciertos de cada player (0 a 5) sobre los 5 partidos de la jornada.
2. Se compara el nº de aciertos entre los dos players del duelo:
   - Más aciertos → **3 puntos** para ese player, **0 puntos** para el rival.
   - Mismo nº de aciertos → **1 punto** para cada uno (empate).
3. **Caso: un player no pronosticó y el otro sí.** El que no pronosticó cuenta con 0 aciertos y su rival recibe **+3 puntos automáticamente**, aunque el rival también tenga 0 aciertos sobre los partidos.
4. **Caso: ningún player del duelo pronosticó.** Ambos players reciben 0 puntos. Es decir, no suman.

## Desempate en la clasificación

Cuando dos o más players empatan a puntos totales en la temporada, el desempate se resuelve en este orden:

1. **Average directo**: quién ganó el duelo 1vs1 cuando se enfrentaron esa jornada (o el balance de sus enfrentamientos directos si se han enfrentado más de una vez en la temporada).
2. **Diferencia de pronósticos acertados/fallados**: `total_aciertos - total_fallos` acumulado en la temporada.
3. **Número de jornadas ganadas** (duelos ganados) en la temporada.

Estos mismos datos (aciertos, fallos, jornadas ganadas, enfrentamientos directos) deben conservarse también para la sección de estadísticas, no solo para el desempate.

## Bajas de jugadores

- Un player no puede darse de baja por sí mismo a mitad de temporada.
- Solo el admin puede eliminar (desactivar) un jugador. La eliminación es un **soft delete** (`activo = false`), no un borrado físico, para no romper el histórico de jornadas y estadísticas ya jugadas.
- Si tras eliminar un jugador el número de players activos queda impar, el duelo contra el jugador eliminado se resuelve con el mismo comportamiento que el caso "no pronosticó" (punto 3 de esta sección): el rival recibe +3 puntos automáticamente.

## Inmutabilidad de los pronósticos

- Un pronóstico, una vez guardado por el player, no puede ser editado por él.
- Solo el admin tiene permiso para modificar un pronóstico ya enviado, y únicamente a petición del player afectado (flujo manual, no hay UI de "solicitud de cambio" automatizada por ahora).

## Cierre de jornada

- Una jornada solo acepta pronósticos mientras está en estado `ABIERTA`.
- El admin es quien da la jornada por comenzada (cambia su estado), momento a partir del cual ya no se aceptan ni modifican pronósticos de players.

## Temporadas

- Al finalizar o cerrar una temporada, sus datos (jornadas, duelos, clasificación) quedan congelados y consultables como histórico.
- Crear una nueva temporada no borra la anterior; simplemente empieza una clasificación nueva desde cero.

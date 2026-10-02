# Requisitos funcionales

## Autenticación y usuarios

- Registro con correo, nombre de usuario y contraseña.
- El registro es **abierto pero protegido por código de invitación**: no cualquiera que acceda a la web puede registrarse.
- Dos roles: `ADMIN` y `PLAYER`. Puede haber varios admins.
- El primer usuario admin se crea por defecto (no vía flujo de registro normal).
- Los admins pueden cambiar el rol de cualquier usuario desde su pantalla de detalle; para los players ese campo es de solo lectura.
- Un admin puede ser también player (compite en jornadas como cualquier otro).
- Los usuarios pueden editar su perfil (imagen, correo, nombre) y recuperar la contraseña si la olvidan.
- Los players **no pueden darse de baja ellos mismos**; solo el admin puede eliminar (desactivar) un jugador.

## Gestión de equipos (admin)

- CRUD completo de equipos: nombre + escudo (subida de imagen).
- Se pueden dar de alta equipos de cualquier liga, incluidas selecciones nacionales.

## Competiciones (admin)

- Catálogo de competiciones (La Liga, Premier League, Champions League, Internacional, etc.), gestionado por el admin.
- Se asigna una competición a cada partido al crear una jornada.

## Jornadas

- El admin crea la jornada y decide cuándo comienza.
- Cada jornada tiene **exactamente 5 partidos**, cada uno entre 2 equipos, de cualquier competición del catálogo.
- Todos los players pronostican los **mismos 5 partidos** de la jornada.
- El admin empareja a los players en duelos 1 vs 1 al crear la jornada. El número de players es siempre par; nadie descansa.
- Al crear la jornada, el admin puede enviar un correo recordatorio a los players para que pronostiquen.

## Pronósticos (players)

- Cada player pronostica el resultado 1X2 de los 5 partidos antes de que el admin dé la jornada por comenzada.
- Una vez enviado un pronóstico, **el player no puede modificarlo**. Solo el admin puede modificarlo, a petición del player.
- Si un player no pronostica antes de que empiece la jornada, se cuenta como 0 aciertos (ver reglas de puntuación).

## Resultados

- El resultado real (1X2) de cada partido lo introduce el **admin manualmente** una vez jugados los partidos (no se integra una API externa de resultados).

## Puntuación y clasificación

Ver el detalle completo en `02-business-rules.md`. Resumen:

- Cada duelo 1vs1 compara el nº de aciertos de ambos players en los 5 partidos de la jornada.
- Victoria = 3 puntos, derrota = 0 puntos, empate = 1 punto cada uno.
- Clasificación estilo tabla de liga: usuario + puntos acumulados en la temporada.
- Desempate en cascada: average directo → diferencia aciertos/fallos → jornadas ganadas.

## Temporadas

- El juego dura una temporada, que finaliza al acabar la temporada futbolística o cuando el admin decide cerrarla.
- El admin puede crear una nueva temporada para reiniciar el juego.
- Se mantiene el **historial completo de temporadas anteriores**, consultable desde un menú de temporadas con datos y estadísticas.

## Administración

- El admin dispone de un menú de administración para gestionar usuarios, equipos y competiciones (CRUD completo sobre todos los datos).

## No funcionales

- Uso mayoritariamente desde móvil; debe funcionar bien también en PC. Diseño responsive, mobile-first.
- Primera vez del equipo trabajando con Supabase — priorizar simplicidad operativa sobre configuración avanzada.

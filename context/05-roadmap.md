# Roadmap

## Fase 0 — Definición de requisitos ✅ cerrada

Requisitos funcionales, reglas de negocio y ambigüedades resueltas. Ver `01-requirements.md` y `02-business-rules.md`.

## Fase 1 — Modelo de datos y auth ✅ cerrada (parcialmente)

- [x] Diseño del esquema relacional (`03-data-model.md`).
- [x] Script de creación de tablas (`schema.sql`).
- [x] Proyecto de Supabase creado (organización nueva, configuración inicial revisada).
- [ ] Políticas RLS por tabla (pendiente).
- [ ] Función/vista de `standings` con desempate en cascada (pendiente).
- [ ] Función/trigger de cálculo de `acierto` en predicciones y relleno de `duels` al cerrar resultados (pendiente).

## Fase 2 — Gestión de equipos, competiciones y usuarios (admin) — siguiente

- CRUD de equipos con subida de escudo a Storage.
- CRUD de competiciones.
- Pantalla de administración de usuarios (cambio de rol, activar/desactivar).
- Layout reutilizable de tabla + formulario para los tres CRUDs del menú de administración.

## Fase 3 — Creación de jornada (admin)

- Selección de los 5 partidos (equipos + competición).
- Emparejamiento de players en duelos 1vs1.
- Transición de estado de jornada (ABIERTA → EN_CURSO).
- Envío de correo recordatorio (Resend) al crear la jornada.

## Fase 4 — Pronósticos (player)

- Formulario 1X2 por partido, bloqueado fuera del estado ABIERTA y tras el primer envío.

## Fase 5 — Resultados y motor de puntuación

- Pantalla de admin para introducir resultado real de cada partido.
- Cálculo automático de aciertos, resolución de duelos y puntos.

## Fase 6 — Clasificación y temporadas

- Tabla de clasificación con desempate en cascada.
- Cierre de temporada y creación de una nueva, con histórico accesible.

## Fase 7 — Notificaciones

- Integración completa de Resend para recordatorios (y opcionalmente SMTP de Auth).

## Fase 8 — Pulido visual y despliegue

- Revisión responsive mobile-first.
- Despliegue en Vercel.

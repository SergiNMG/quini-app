# Quini App — Visión general

## Qué es

Aplicación web de pronósticos futbolísticos por jornadas, de uso recreativo entre un grupo de amigos. Los usuarios predicen el resultado (1X2) de 5 partidos por jornada y compiten entre sí en duelos 1 vs 1, acumulando puntos a lo largo de una temporada.

## Criterio de producto

La app debe ser **funcional y estética, sin complicaciones**. No se busca la excelencia ni la sobreingeniería, sino una web atractiva e interactiva, con buena experiencia tanto en móvil (uso principal) como en PC (uso de mantenimiento por el admin).

## Roles

- **Admin**: gestiona equipos, competiciones, usuarios, jornadas y resultados. Puede ser, a su vez, player. Puede haber varios admins.
- **Player**: se registra con código de invitación, pronostica los partidos de cada jornada y compite en su duelo 1vs1 asignado.

## Documentos de este directorio

| Archivo | Contenido |
|---|---|
| `00-overview.md` | Este documento |
| `01-requirements.md` | Requisitos funcionales completos |
| `02-business-rules.md` | Reglas de negocio: puntuación, desempates, casos límite |
| `03-data-model.md` | Modelo de datos y su relación con `schema.sql` |
| `04-tech-stack.md` | Stack tecnológico y justificación |
| `05-roadmap.md` | Fases del proyecto y estado actual |
| `schema.sql` | Script SQL de creación de tablas (Supabase/Postgres) |

## Estado actual

Fase 0 (definición de requisitos) y Fase 1 (modelo de datos y auth) cerradas. Proyecto de Supabase creado. Pendiente: políticas RLS, pantallas de administración y flujo de creación de jornada (ver `05-roadmap.md`).

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
| `05-roadmap.md` | Plan único de tareas por fase, dependencias, estado real y criterios de aceptación |
| `schema.sql` | Script SQL de creación de tablas (Supabase/Postgres) |

## Estado actual

Requisitos principales y esquema inicial definidos; quedan validaciones operativas señaladas en el roadmap. Proyecto de Supabase creado según el desarrollador y base Angular/Supabase/Tailwind/Vercel preparada. **La fase 1 está parcialmente realizada, no cerrada**: faltan verificar/versionar el esquema remoto, registro por invitación, perfiles, políticas RLS, flujo de auth y PrimeNG. Las pantallas funcionales y el motor de puntuación están pendientes. Ver el [roadmap detallado](05-roadmap.md) para tareas, dependencias y criterios de aceptación.

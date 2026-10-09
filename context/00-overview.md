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
| `06-phase-0-acceptance.md` | Decisiones confirmadas de fase 0 y ejemplos para las futuras pruebas de aceptación |
| `schema.sql` | Referencia histórica del diseño inicial; el esquema ejecutable está en `supabase/migrations/` |

## Estado actual

**Fase 0 cerrada**: requisitos y decisiones operativas confirmados, con ejemplos de aceptación en `06-phase-0-acceptance.md`. Esquema inicial definido. Proyecto de Supabase creado según el desarrollador y base Angular/Supabase/Tailwind/Vercel preparada. **La fase 1 está parcialmente realizada, no cerrada**: F1.3 completada con baseline versionado y aplicado al Supabase remoto de desarrollo (Postgres 17.6), pruebas SQL y lint correctos. Angular se ejecuta localmente; Docker y el stack local son opcionales. Se creará producción aparte antes del lanzamiento. Siguen pendientes F1.4, registro por invitación, perfiles, políticas RLS, flujo de auth y PrimeNG. El procedimiento de base de datos está en [supabase/README.md](../supabase/README.md). Las pantallas funcionales y el motor de puntuación están pendientes. Ver el [roadmap detallado](05-roadmap.md) para tareas, dependencias y criterios de aceptación.

# Supabase — Desarrollo remoto y migraciones

## Decisión de entorno

**Angular se ejecuta en local; Supabase en remoto.** Docker Desktop está instalado, pero su motor no está operativo en el ordenador corporativo. No se necesita el stack local para el flujo principal ni se intenta eludir restricciones de la empresa.

El proyecto actual se utiliza exclusivamente como **desarrollo**. Antes de incorporar usuarios/datos reales, crear un proyecto separado de **producción** y configurar sus variables independientemente. El plan Free permite dos proyectos, sujeto a los límites compartidos de las organizaciones del propietario.

`development.json` registra el identificador público del proyecto autorizado, no una credencial. Los comandos que despliegan, prueban o hacen lint comprueban que coincide con `supabase/.temp/project-ref` y que el entorno configurado es `development`; si se enlaza otro proyecto, se detienen antes de ejecutar SQL. No cambiar este archivo para apuntar a producción.

## Fuentes de verdad

- `migrations/`: esquema ejecutable versionado. Una migración aplicada no se modifica; los cambios posteriores son migraciones nuevas.
- `seed.sql`: catálogos ficticios, sin usuarios ni secretos. El runner remoto los inserta dos veces dentro de una transacción que se revierte; no los despliega como datos persistentes.
- `tests/*.test.sql`: suites pgTAP con `begin`/`rollback`; 15 comprobaciones de baseline, 62 de integridad/histórico y 27 de jugador virtual (104 en total).
- [`integrity.md`](integrity.md): garantías de F1.4 y plan transaccional para F3/F4/F5.
- [`virtual-participants.md`](virtual-participants.md): modelo persistente F1.5, permisos de lectura pendientes y reglas que se aplicarán en F5/F6.
- `test-support/baseline-state.sql`: conteos y privilegios comparados antes/después de las pruebas, sin exportar registros personales.
- `inspect-schema.sql`: inventario remoto de solo lectura.
- `../scripts/supabase-development.mjs`: runner sin Docker, validación del proyecto de desarrollo y resultados TAP.
- `config.toml`: configuración del stack **local opcional**. No configura automáticamente Auth, Storage ni redirects del proyecto remoto.
- `../context/schema.sql`: diseño histórico de referencia, no el mecanismo de despliegue.

El CLI es la dependencia de desarrollo **2.119.0**, fijada en `package.json`. Usar `pnpm exec supabase`, no una versión variable de `@latest`.

## Preparación

Desde la raíz del repositorio:

```bash
pnpm install --frozen-lockfile
pnpm exec supabase login
pnpm exec supabase link --project-ref TU_PROJECT_REF_DE_DESARROLLO
```

El proyecto enlazado debe coincidir con `supabase/development.json`. Tokens y contraseñas se introducen en el CLI, no se versionan ni se comparten en el chat. `.temp/` está ignorado por Git.

Para Angular, usar la URL y clave **pública** del proyecto de desarrollo en `.env` y ejecutar `pnpm run config:local`. Nunca publicar la clave `service_role`, la contraseña de Postgres o el token personal en `public/env.js`.

Los callbacks de Auth se ajustarán en el Dashboard remoto en F1.10. Cambiar `config.toml` solo afectaría al stack local opcional.

## Flujo de trabajo sin Docker

```bash
# Inspección/plan; no aplican migraciones.
pnpm exec supabase migration list --linked
pnpm db:inspect:remote
pnpm db:plan:remote

# Aplicación explícita, SOLO al desarrollo autorizado.
pnpm run db:deploy:dev

# Validación SQL remota y del runner.
pnpm db:test
pnpm run db:lint:dev
pnpm run test:db-runner
```

- `db:plan:remote` usa `--dry-run --linked --skip-vault`: sin migraciones, seeds, roles o secretos Vault aplicados. No demuestra que el SQL sea válido; solo muestra el plan.
- `db:deploy:dev` comprueba el proyecto y ejecuta `db push --linked --skip-vault`. No aplica seeds/roles/Vault, no resetea datos y no se ejecuta en el build de Vercel. Repetirlo sin migraciones nuevas no reejecuta el baseline.
- `db:test` usa `db query --linked` mediante la API de gestión, **no** el runner `supabase test db`, que requiere un contenedor. Node y el CLI bastan para este flujo.
- `db:lint:dev` usa el lint del CLI contra `public` remoto y falla ante errores. Se ha comprobado que funciona sin Docker con esta versión.

### Seguridad y alcance de las pruebas

El runner descubre y ejecuta en orden todas las suites `tests/*.test.sql`. Para cada una crea un archivo temporal fuera del repositorio, introduce `seed.sql` **dos veces** y ejecuta la suite en una única transacción. Usa timeouts, habilita pgTAP dentro de esa transacción y devuelve el conjunto de resultados TAP antes del `rollback`. La API devuelve el último SELECT, por lo que la suite recoge todas las comprobaciones en una tabla temporal de resultados.

La suite del baseline comprueba:

- Nueve tablas, cinco enums, siete índices y trigger de `updated_at`.
- RLS habilitado en las nueve tablas.
- Dos competiciones y diez equipos ficticios, sin duplicarse por repetir el seed.
- Ninguna cuenta Auth, perfil ni invitación creada por el seed.
- Equipos distintos, número de jornada único por temporada y FK de equipo.
- Denegación de lectura por RLS para `anon` y `authenticated` antes de incorporar políticas.

La suite de F1.4 añade 62 casos de borrados/reasignaciones, FK RESTRICT, rangos y estados, soft delete y correcciones en histórico. Crea identidades Auth/perfiles/invitaciones ficticias solo dentro de su transacción, sin passwords ni cuentas utilizables, para ejercitar las relaciones.

La suite de F1.5 cubre ambos lados virtuales, virtual-vs-virtual, provenance FK, perfiles activos/inactivos, puntos/aciertos siempre cero del virtual, reactivación sin reescribir duelos publicados, e invariancia del duelo real anterior. Todos los perfiles ficticios y pruebas se revierten.

Las escrituras de fixtures, creación temporal de pgTAP y grants de prueba se revierten. Se comparan conteos de las nueve tablas y de `auth.users`, estado de pgTAP y los privilegios afectados antes/después. No se espera que la base esté vacía para comprobar que el seed no crea cuentas. Evitar actividad concurrente al ejecutar la suite: una escritura de otro proceso podría hacer fallar esa comparación.

El runner **no considera suficiente el exit code del SQL**: exige un plan completo, resultados `ok` numerados y ausencia de fallos, SKIP/TODO o bailout. Sus nueve pruebas unitarias cubren el parser y el bloqueo de un proyecto no autorizado.

No ejecutar las pruebas contra producción, no usar `--include-seed` en un push remoto y **nunca ejecutar `db reset --linked` o `db reset --db-url`**. Tampoco se crean credenciales de prueba. Registro/perfiles y primer admin corresponden a F1.6/F1.7.

Estas pruebas cubren baseline e integridad, no la autorización funcional: cuando F1.6 añada aprovisionamiento de perfiles y F1.8 políticas, adaptar las fixtures/casos a esos flujos y añadir pruebas por rol. No validan todavía las reglas de puntuación, cinco partidos atómicos o la privacidad final del grupo.

## Evidencia de cierre de F1.3

Validación realizada en el proyecto de desarrollo autorizado:

| Comprobación | Resultado |
|---|---|
| Inspección previa | PostgreSQL 17.6; `public` sin objetos propios de aplicación ni historial de migraciones |
| Plan previo | Solo `20261005212317_initial_schema.sql`; sin seed/roles |
| Aplicación del baseline | Correcta mediante migraciones; historial local/remoto coincidente |
| pgTAP remoto | 15/15 correctas; repetidas en dos ejecuciones completas |
| Fixtures/permisos tras pruebas | Sin cambios persistentes; pgTAP se revierte al estado previo |
| Lint de `public` | Sin errores |
| Segundo deploy y dry-run final | Sin migraciones pendientes; no-op |
| Pruebas del runner | 9/9 correctas |
| Instalación frozen, build y Angular | Correctos; 2/2 pruebas frontend |

No se ha hecho ningún reset remoto. Esta validación reemplaza el requisito anterior de reconstrucción local con Docker: **F1.3 está cerrada**. No afirma haber reconstruido una base vacía local o haber probado un rollback del despliegue; son comprobaciones diferentes y no obligatorias en el flujo remoto acordado.

El baseline contiene las tablas/enums iniciales con tipos calificados en `public`, índices, función/trigger y RLS. La migración F1.4 protege el histórico y F1.5 persiste los lados virtuales; políticas y operaciones transaccionales completas siguen pendientes. No abrir la aplicación a usuarios reales hasta completar esos permisos y flujos.

## Evidencia de cierre de F1.4/F1.5

`20261009133127_integrity_and_history.sql` protege borrados/reasignaciones y añade integridad; `20261009140144_virtual_duel_participants.sql` permite lados virtuales con procedencia conservada e invariantes. Ambas aplicadas a desarrollo sin modificar migraciones anteriores.

Pasan **104/104 pruebas SQL en tres suites**, repetidas en ejecuciones completas; lint sin errores, 9/9 pruebas del runner, 2/2 Angular y build correctos. Las cuatro migraciones coinciden con el historial remoto y el dry-run final no tiene pendientes. No se ha ejecutado reset remoto ni dejado fixtures/usuarios ficticios persistentes.

Detalles: [integridad y preservación (F1.4)](integrity.md), [persistencia del rival virtual (F1.5)](virtual-participants.md). Atomicidad, seguridad de lectura y cálculo concurrente siguen en F3/F4/F5/F1.8.

## Añadir la siguiente migración

1. Ejecutar `pnpm exec supabase migration new nombre_del_cambio` y escribir el SQL en el archivo generado.
2. Revisar el diff. No modificar migraciones aplicadas ni usar `if not exists` para ocultar discrepancias con el remoto.
3. Confirmar proyecto de desarrollo, historial, inventario y plan. Si aparece estructura manual no versionada, detener el push y reconciliarla antes; no usar `migration repair --status applied` para saltarse SQL que no se ejecutó.
4. Aplicar con `pnpm run db:deploy:dev`, validar inmediatamente con pruebas/lint y revisar el historial final.
5. Ante un error, corregir mediante una nueva migración revisada; no resetear un proyecto con datos ni cambiar el baseline aplicado. Las pruebas transaccionales no sustituyen un plan de recuperación de migraciones destructivas.

Antes del lanzamiento, crear producción aparte, aplicar solo migraciones revisadas y configurar Auth/Storage/variables para ese proyecto. Los scripts de desarrollo se mantienen apuntando al proyecto de desarrollo; los despliegues de producción requieren aprobación y procedimiento propios.

## Stack local opcional

Solo en un equipo donde Docker esté permitido y operativo:

```bash
pnpm run db:start:local
pnpm run db:reset:local  # borra SOLO datos locales y aplica migraciones/seed
pnpm run db:stop:local
```

No son pasos obligatorios del roadmap. Las pruebas actuales se ejecutan mediante `pnpm db:test` en desarrollo remoto, independientemente de que haya un stack local.

## Referencias

- [Supabase CLI](https://supabase.com/docs/reference/cli/introduction).
- [Migraciones y entornos](https://supabase.com/docs/guides/deployment/managing-environments).
- [pgTAP en Supabase](https://supabase.com/docs/guides/database/extensions/pgtap).
- [Límites del plan Free](https://supabase.com/docs/guides/platform/billing-on-supabase).

# Handoff: SUPABASE_RLS
Date: 2026-10-12T01:06:54+02:00 | Branch: `feature/phase-1B` | Status: ready for review

## Summary
Se ha llevado Quini desde requisitos definidos hasta F1.8: esquema versionado en Supabase remoto de desarrollo, alta protegida por invitación, bootstrap seguro del primer admin y RLS/grants aplicados. F1.8 está validada y el commit `3b376d4` ya se subió a `origin/feature/phase-1B`; el árbol estaba limpio antes de crear este handoff. La siguiente tarea recomendada es F1.9 (estado de sesión y guards), todavía sin implementar.

## Work Completed
- [x] Revisados y ampliados requisitos, reglas de negocio, modelo de datos y roadmap. Fase 0 está cerrada; decisiones de desempate, `jugador_undefined`, visibilidad y bajas documentadas en `context/06-phase-0-acceptance.md`.
- [x] pnpm 10.34.6 fijado como package manager por defecto; Angular CLI, VS Code, Vercel, lockfile y documentación usan pnpm.
- [x] Adoptado el flujo **Angular local + Supabase remoto de desarrollo**. Docker Desktop está instalado, pero el daemon corporativo no arranca. No se ha intentado eludir esa restricción. El CLI `supabase@2.119.0` está fijado y el runner remoto transaccional evita Docker.
- [x] F1.3: inspeccionado el remoto vacío (Postgres 17.6), creado/aplicado baseline y seed ficticio; historial de migraciones sincronizado.
- [x] F1.4: constraints/rangos/transiciones y protección del histórico; no se reescriben identidades o filas persistidas.
- [x] F1.5: los lados virtuales se representan con `player_*_id IS NULL` y un `player_*_replaced_id` que conserva el perfil sustituido. No se crea usuario/Auth ficticio; duelos publicados no se reinterpretan al reactivar perfiles.
- [x] F1.6: trigger `AFTER INSERT ON auth.users` valida/consume invitación y crea perfil dentro de la transacción Auth. El cliente solo aporta `username`/`invitation_code`; `role`, `activo` y email del metadata no son fuente de autoridad.
- [x] F1.7: RPC protegida y script local para bootstrap one-time del primer admin. El procedimiento invita con Auth Admin, deja el perfil como PLAYER hasta confirmar el correo y luego promueve bajo advisory lock. **No se ha creado ningún usuario/admin real**.
- [x] F1.8: policies RLS, grants mínimos, helpers `private` ligados al perfil actual, RPCs privados/admin y default privileges endurecidos. Los UUIDs de perfil reemplazado/metadata de invitación no se exponen a players.
- [x] Pruebas en seis suites: 200/200 pgTAP pasan dos ejecuciones completas; lint remoto sin errores; 9 pruebas del runner, build y 2 pruebas Angular correctas.
- [x] Commit `3b376d4 feat: implementar RLS básico y permisos de funciones` empujado a `origin/feature/phase-1B`.

## Files Affected
- Creado: `supabase/migrations/20261011123021_authorization_rls.sql` — policies, funciones de autorización y grants mínimos.
- Creado: `supabase/migrations/20261011130008_private_schema_default_privileges.sql` — evita nuevos grants implícitos a roles API en `private`.
- Creado: `supabase/tests/authorization_rls.test.sql` — 60 pruebas anon/player/admin/desactivado.
- Creado: `supabase/authorization.md` — matriz efectiva de grants, policies y límites.
- Modificado en `3b376d4`: `README.md`, `context/00-overview.md`, `context/03-data-model.md`, `context/05-roadmap.md`, `supabase/README.md`, `supabase/auth-signup.md`, `supabase/integrity.md`, `supabase/virtual-participants.md` y `supabase/tests/integrity_and_history.test.sql`.
- Archivos de fases anteriores ya incluidos en commits anteriores: baseline/migraciones, `supabase/auth-signup.md`, `supabase/bootstrap-first-admin.md`, `scripts/bootstrap-first-admin.mjs`, `scripts/supabase-development.mjs` y suites de test.
- Creado ahora: `.pi/handoffs/HANDOFF_SUPABASE_RLS_10_12_01_06.md` (handoff sin commit todavía).
- Eliminado: ningún archivo del repo en este trabajo.

## Technical Context
- Estado Git antes de escribir este documento: rama `feature/phase-1B`, tracking `origin/feature/phase-1B`, árbol limpio. `origin/develop` está en `0a48b57`; este trabajo está en una feature branch y ya fue pusheado.
- Historial reciente: `3b376d4` (F1.8), `e7ac71a` (F1.7), `23faea5` (F1.6), `0a48b57` (F1.1/phase 1A), `b04266e` (integración de contexto), `de2cf4b` (scaffold).
- Remoto actual: desarrollo, PostgreSQL 17.6. Ocho migraciones locales/remotas, todas sincronizadas; `pnpm db:plan:remote` informa up-to-date. No hay Auth users, perfiles ni filas de aplicación persistidas. Todos los usuarios de suites y fixtures se revierten.
- Docker local no es requisito. El CLI remoto usa `pnpm db:test`, que ejecuta SQL/pgTAP por `supabase db query --linked` dentro de transacciones. No correr `db reset --linked` ni pruebas contra producción.
- Helpers RLS son `SECURITY DEFINER`, `search_path=''`, en schema `private` no expuesto por PostgREST. Se basan en `auth.uid()` + `profiles.activo/role` en DB, evitando metadata/JWT role obsoletos.
- `profiles` da SELECT directo solo de `id`, username y avatar. Email/role/status propios se consultan con `get_my_profile()`; `admin_list_profiles()` y `admin_list_duels()` son RPC de admin. `invitation_code_used` nunca sale por API. Los lados de duelo real/virtual se leen con columnas restringidas para jugadores.
- `anon` no tiene grants a tablas de juego. Perfil desactivado no accede aunque conserve un JWT. Pronósticos propios visibles en ABIERTA; todos los del grupo desde EN_CURSO; admin activo siempre puede verlos.
- Bootstrap es solo para desarrollo y requiere `.env.bootstrap` local (gitignored) con service_role. El script se guarda en `scripts/bootstrap-first-admin.mjs`; redirect/Auth email deben estar configurados. No ejecutar hasta elegir email y decidir crear realmente el admin.
- RLS impide que el jugador escriba directo sus picks, y que el cliente escriba acierto/score o publique jornadas parciales. El admin sí tiene grant para corregir `predictions.pronostico`, pero el recálculo/auditoría completa aún corresponde a F5; no construir aún una UI de corrección que omita ese recálculo.
- Storage/RLS de imágenes no está implementado; corresponde a F1.12.

## Current State
- Working: F0 y F1.1–F1.8 cerradas en roadmap. F1.8 está en `3b376d4` y en remoto de desarrollo.
- Not working / known issues: no hay UI funcional de Auth, rutas/guards, edición de perfil, management CRUD, Storage ni flujo de jornada. No se creó admin real. Los RPC transaccionales F3/F4/F5 siguen pendientes. RLS sobre Storage queda F1.12.
- Tests: `pnpm db:test` — 200 checks/6 suites, repetidos dos veces; `pnpm run db:lint:dev` sin errores; `pnpm run test:db-runner` 9/9; `pnpm run build` correcto; `pnpm test --watch=false` 2/2.
- Git: clean antes del handoff; commit `3b376d4` ya está en origin. El handoff recién creado quedará untracked hasta que se decida añadirlo.

## Next Steps
### Immediate
1. Empezar **F1.9** en `context/05-roadmap.md`: crear estado Auth usando signals, inicializar/restaurar sesión con `supabase.auth.getSession()`, reaccionar a `onAuthStateChange`, y cargar el perfil actual vía `supabase.rpc('get_my_profile')` (no `SELECT * FROM profiles`; email/role privados no tienen grants directos). Añadir rutas/guards para no autenticado, miembro activo y admin activo; el backend/RLS sigue siendo la autoridad.

### Then
- F1.10: formularios sign-up/login/recovery; sign-up metadata exacta `{ username, invitation_code }`, mapear error de trigger a mensaje claro, preparar Auth email confirmation, `localhost:4200`/Vercel redirects.
- F1.11: edición self de username/avatar y sincronización de email mediante Auth.
- F1.12: Storage/buckets y políticas de escudos/avatares.
- F1.13–F1.15: instalar/configurar PrimeNG y layout/shell Angular.
- F2.4: RPC segura admin para cambios de `role/activo` (no existen grants de escritura directos). F3/F4 implementarán RPCs atómicas de jornada y picks.

### Blocked on
- Para crear el admin real, esperar a que el operador elija email, configure redirect/entrega de invitación y rellene su `.env.bootstrap` local. No pedir ni registrar la service_role key en chat o Git.
- No hace falta Docker; la prueba remota requiere CLI login/link válidos.

## Useful Commands & Resources
```bash
pnpm install --frozen-lockfile
pnpm start
pnpm test --watch=false
pnpm run test:db-runner
pnpm db:test
pnpm run db:lint:dev
pnpm db:plan:remote
pnpm exec supabase migration list --linked
```
- Roadmap fuente de verdad: `context/05-roadmap.md`.
- Autorización aplicada y limitaciones: `supabase/authorization.md`.
- Alta invitada: `supabase/auth-signup.md`.
- Procedimiento de bootstrap (no ejecutar sin inputs de operador): `supabase/bootstrap-first-admin.md`.
- Pruebas remotas/migraciones: `supabase/README.md`.

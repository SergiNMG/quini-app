# F1.9 — Estado de sesión y rutas

## Alcance implementado

`AuthService` en `src/app/core/auth/auth.service.ts` mantiene estado con signals de solo lectura (`status`, `session`, `user`, `profile`, `error`, `isAuthenticated`, `isAdmin`). `isAuthenticated` significa **miembro activo verificado**, no solo que exista una sesión Auth. `login(email, password)` y `logout()` devuelven `AuthError | null`; los formularios que los consumen son F1.10.

La app inicializa el servicio sin bloquear el bootstrap para mostrar «Comprobando sesión…». Los guards esperan `whenReady()` y revalidan el perfil mediante `refreshProfile()` antes de autorizar. No se muestra el contenido privado anterior durante una verificación o una pérdida de acceso.

## Cliente y perfil

- `SUPABASE_CLIENT` es un token Angular singleton, creado al inyectar por primera vez. Lee únicamente URL y publishable key de `public/env.js`. No crear clientes por componente ni importar un singleton eager que exija configuración al cargar un módulo de pruebas.
- `AUTH_BACKEND` adapta las APIs de Supabase y permite pruebas sin credenciales/red. `getSession()`, `onAuthStateChange()` y `signInWithPassword()` usan Supabase Auth.
- `get_my_profile()` es la única lectura de campos privados en este flujo. No usar `profiles.select('*')`, metadata editable ni el rol del JWT para decidir permisos.
- La RPC devuelve cero filas tanto para perfil desactivado como inexistente: se muestra «No hay un perfil activo», sin intentar distinguirlos mediante lecturas adicionales.
- La respuesta debe ser una única fila activa de la misma cuenta Auth, con rol ADMIN/PLAYER y campos del contrato F1.8. Respuesta malformada o error deja el acceso bloqueado; nunca se conserva un rol admin antiguo.
- `logout()` usa `signOut({ scope: 'local' })`: cierra el navegador actual, no todas las sesiones de esa cuenta. Un fallo conserva la sesión para reintentar pero retira el perfil verificado y muestra un error.

## Ciclo de vida y concurrencia

Estados: `loading`, `anonymous`, `active`, `inactive`, `error`. No se convierten los errores de red en un perfil inactivo ni en un login exitoso.

La restauración es idempotente. Cada evento Auth invalida inmediatamente el perfil anterior; la consulta RPC se difiere con `setTimeout(0)` fuera del callback para no bloquear el lock interno de Supabase. Una revisión descarta respuestas antiguas tras logout o cambio de cuenta, incluida una restauración anterior al evento. `whenReady()` espera el trabajo más reciente y deja de esperar una RPC obsoleta si otro evento la sustituye. `DestroyRef` cancela la suscripción e invalida las respuestas pendientes.

Los guards revalidan actividad/rol en cada navegación protegida; el root reacciona a cambios de sesión/renovación mientras se permanece en una pantalla. **No hay suscripción Realtime a perfiles**: una baja ajena sin navegación ni evento Auth no se anuncia inmediatamente a la UI. RLS sí corta el acceso en la siguiente petición. La gestión futura de datos debe tratar sus errores y llamar a `refreshProfile()` cuando corresponda; los guards no son una barrera de seguridad.

## Rutas

| Ruta | Comportamiento |
|---|---|
| `/`, rutas desconocidas | Redirección a `/app`, con autorización normal |
| `/app` y futuros hijos | Miembro activo; ADMIN también puede jugar |
| `/admin` y futuros hijos | Solo ADMIN activo; PLAYER vuelve a `/app` |
| `/auth/login` | Invitado; miembro activo vuelve al destino interno; bloqueado/error pasa a access |
| `/auth/access` | Explicación, reintento de verificación y logout; no contiene datos de juego |
| `/auth/callback` | Destino público reservado para F1.10; el SDK detecta sesión del enlace |

Un invitado que pide una ruta privada llega a `/auth/login?returnUrl=...`. Un perfil bloqueado o un error llega a `/auth/access?returnUrl=...`, evitando bucles de login. Solo se conservan destinos `/app` o `/admin` y sus hijos; URLs externas, backslashes, controles o destinos Auth se sustituyen por `/app`. F1.10 debe reutilizar `safeReturnUrl()` al navegar después del login.

Los destinos de login/callback/inicio/admin son **placeholders explícitos**: no son formularios ni CRUD. El encabezado y carga son mínimos para validar F1.9, no el shell PrimeNG definitivo de F1.14. Callback no valida todavía enlaces caducados ni completa PASSWORD_RECOVERY; F1.10 debe implementar esas pantallas antes de abrir el grupo.

## Pruebas y comprobación local

```bash
pnpm run config:local        # .env con URL/publishable key de desarrollo; sin service_role
pnpm start
pnpm test --watch=false     # 72 tests Angular en cuatro suites
pnpm run test:db-runner     # 9 tests del runner SQL
pnpm run build
```

Sin sesión, `/` y `/admin` llevan a la página pública de acceso; `/auth/callback` queda pública. Las pruebas usan cuentas ficticias en memoria y cubren restauración, eventos, login/logout y errores, grants vía contrato RPC, respuesta inválida, revocación de rol/actividad, concurrencia, redirecciones, navegación y carga del root. No crean cuentas reales ni validan todavía SMTP, redirects del Dashboard, login real con email confirmado o una Preview Vercel; esas comprobaciones quedan para F1.10/F8.

F1.9 no necesita migraciones ni nuevas dependencias. Pasan 72 tests Angular, 9 del runner y build; la regresión SQL remota también pasa sus 200 comprobaciones con datos/permisos/pgTAP sin cambios persistentes. Los permisos de backend siguen siendo la autoridad. Ver [autorización](../supabase/authorization.md) y [roadmap](05-roadmap.md).

# F1.8 — Autorización, grants y Row Level Security

## Estado

Migraciones [`20261011123021_authorization_rls.sql`](migrations/20261011123021_authorization_rls.sql) y [`20261011130008_private_schema_default_privileges.sql`](migrations/20261011130008_private_schema_default_privileges.sql) aplicadas al proyecto de desarrollo. Todas las tablas de `public` revocan los grants iniciales de `anon`/`authenticated`, y reciben permisos mínimos con políticas RLS. Se retiene acceso de backend `service_role`; su clave solo puede usarse en servidor.

## Identidad usada por las políticas

- Los helpers están en schema `private`, que no está expuesto en `supabase/config.toml`.
- `private.is_active_member()` consulta `profiles.id = auth.uid()` y el `activo` actual de la base de datos. `private.is_active_admin()` comprueba además `role = ADMIN`.
- Ambos son `SECURITY DEFINER`, `STABLE`, usan `search_path = ''`, cualifican todos los nombres y solo los puede ejecutar `authenticated`. No dependen de `user_metadata` ni de claims `role`/`activo`, que el usuario podría modificar.
- Desactivar un perfil corta el acceso a la siguiente petición aunque el JWT anterior aún no expire. Las identidades de perfiles desactivados permanecen visibles como username/avatar a jugadores activos para el histórico.
- Las migraciones F1.8 restringen los **default privileges de `postgres` en `public` y `private`**: nuevas tablas/secuencias/funciones no heredan grants de API; el helper privado y RPC expuestos tienen EXECUTE concedido de forma explícita. Cada migración futura debe auditar grants/policies explícitamente.

## Matriz aplicada

| Tabla/dato | Anónimo | Miembro activo | Admin activo | Desactivado |
|---|---|---|---|---|
| Perfil directo: `id`, `username`, `avatar_url` | Sin grant | Identidad básica del grupo, incluidos históricos | Identidad básica del grupo | Denegado |
| Email/role/activo de profiles | Denegado | Solo propio mediante `get_my_profile()` | `get_my_profile()` propio y `admin_list_profiles()` de gestión | Denegado |
| `invitation_code_used` | Sin grant | Sin grant | Sin grant; el código se gestiona en `invitation_codes` | Sin acceso |
| Catálogo invitaciones | Sin grant | Sin grant/filas | SELECT/INSERT solo `code`/DELETE; RLS admin | Sin acceso |
| `teams`, `competitions`, seasons, jornadas, partidos | Sin grant | Lectura del grupo/histórico | Lectura + operaciones admin concedidas | Denegado |
| Pronósticos `ABIERTA` | Sin grant | Solo los propios | Todos | Denegado |
| Pronósticos `EN_CURSO`/`FINALIZADA` | Sin grant | Todos los del grupo | Todos | Denegado |
| Duelos | Sin grant | Lectura de columnas públicas sin `player_*_replaced_id` | `admin_list_duels()` incluye reemplazos | Denegado |

### Operaciones admin concedidas ahora

- CRUD lógico de `teams`/`competitions` mediante INSERT/UPDATE y `activo`; el borrado físico está bloqueado.
- SELECT/INSERT sobre invitaciones; DELETE de invitaciones solo mediante RLS admin y el trigger solo acepta códigos no usados. La columna de consumo no tiene permiso UPDATE para cliente.
- Crear y actualizar nombre/fechas de temporada; el estado solo puede transitar mediante el trigger F1.4, pero no se concede UPDATE directo de estado.
- Actualizar `matches.resultado_real`; los equipos/competición del partido son columnas sin grant de UPDATE.
- Corregir `predictions.pronostico` solo como admin; no se concede UPDATE de `acierto` ni de resultados derivados.
- Actualizar `profiles.username`/`avatar_url` (usuario activo propio; admin puede mantener identidades ajenas). No hay permiso directo para INSERT de perfiles, email, ID, role, activo o invitation_code_used.

La administración completa de roles/estados de perfiles se añadirá en F2.4 con una función autorizada. Los UPDATE de resultados/pronósticos directos aquí son el permiso por rol; el recálculo atómico/auditoría se completa en F5 y se moverá a RPC antes de una interfaz de corrección.

## Operaciones que se dejan cerradas hasta sus RPC

No se concede INSERT directo a cliente autenticado para `predictions`, `matches`, `duels` ni `matchdays`; tampoco cambios de estado de jornadas/temporadas o puntuaciones derivadas. F3/F4/F5 implementan las operaciones transaccionales de publicar una jornada completa, enviar los cinco picks juntos, iniciar, resolver y recalcular. No basta el estado de los botones Angular.

Los catálogos de lectura incluyen filas inactivas necesarias para mostrar partidos antiguos; su selector de creación debe filtrarlas en F2/F3. La RLS protege acceso, no sustituye validación de catálogos activos.

## Privacidad de perfiles/duelos

`profiles` solo otorga SELECT directo de las columnas `id`, `username`, `avatar_url`; el permiso de columna restringe una lectura `SELECT *`, incluso si la policy permite ver identities del grupo. `get_my_profile()` devuelve email/role/status solo del usuario autenticado; `admin_list_profiles()` devuelve los campos de gestión a un admin activo, pero nunca `invitation_code_used`.

Las columnas de sustitución virtual contienen IDs de personas desactivadas. No se conceden en la tabla a players; `admin_list_duels()` las entrega únicamente a un admin activo. La UI deberá dibujar el texto fijo `jugador_undefined` en vez de tratar esa referencia como una cuenta Auth.

Los `SECURITY DEFINER` públicos son RPC limitadas: search path vacío y autorización por perfil activo dentro de la función. Los helpers de política están en schema no expuesto. Todo RPC futuro debe probarse con anon, un player activo, admin activo y perfil desactivado.

## Límite explícito de este cierre

F1.8 no implementa la pantalla de registro/login, Admin users CRUD, temporada/jornada, el envío de predicciones o el motor de score. Tampoco define políticas de Supabase Storage (F1.12). Las operaciones aún no implementadas carecen de grant directo en las tablas donde necesitarán atomicidad. Un cliente autenticado no equivale a un jugador activo.

## Pruebas

La suite `tests/authorization_rls.test.sql` crea en una transacción cuatro cuentas Auth ficticias con invitaciones y sus perfiles; prueba miembro activo, admin, JWT de usuario desactivado y anon. Cubre SELECT limitado de perfiles, RPC propias/admin, email/invitaciones/reemplazos privados, pronósticos abiertos/en curso/finalizados, grants y escrituras permitidas/denegadas, y soft-delete de catálogo. Todo dato se revierte.

Ejecutar con `pnpm db:test`; 60 tests de RLS/grants, dentro del conjunto global de 200 comprobaciones pgTAP. `pnpm run db:lint:dev` verifica funciones SQL y `pnpm run db:plan:remote` confirma que no hay migraciones pendientes.

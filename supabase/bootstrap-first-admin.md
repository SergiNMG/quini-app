# F1.7 — Inicializar el primer administrador

## Qué hace y por qué es un flujo separado

F1.6 obliga a que cada `auth.users` insert consuma una invitación y crea un perfil fijo `PLAYER` con email obtenido de Auth. El navegador nunca puede escoger `role=ADMIN`. El primer administrador se establece aparte mediante Supabase Auth Admin API, una invitación única creada por un operador y una RPC que solo el rol interno `service_role` puede ejecutar.

La cuenta se invita fuera del formulario público. El trigger F1.6 la crea inicialmente como PLAYER con una invitación de bootstrap; tras confirmar el email, un script local promueve **exactamente un** perfil PLAYER activo. No se deshabilitan triggers, no se crea un Auth user con SQL ni se desactiva el guard de invitaciones.

## Preparación del operador

1. El repositorio debe estar en una rama que incluya las migraciones F1.6 y F1.7 y el proyecto remoto de desarrollo debe ser el enlazado por `supabase/development.json`.
2. Aplicar migraciones revisadas:

   ```bash
   pnpm db:plan:remote
   pnpm run db:deploy:dev
   pnpm db:test
   ```

3. En Supabase Dashboard → Authentication → URL Configuration, incluir el redirect de bootstrap (por defecto `http://localhost:4200/auth/callback`) en la lista allow-list. F1.10 configurará los redirects finales y el callback de la UI.
4. Verificar el envío de correo de invitación. El SMTP alojado puede tener límites; si el email no llega, configurar SMTP/remitente permitido y resolverlo antes de repetir el bootstrap. No desactivar el trigger como atajo.
5. Copiar `scripts/bootstrap-admin.env.example` a la raíz como `.env.bootstrap`; completar **localmente** URL del proyecto de desarrollo, clave `service_role`, email/username del primer admin y redirect. `.env.bootstrap` está ignorado por Git; comprobar que no aparece en `git status`.
6. El campo `SUPABASE_SERVICE_ROLE_KEY` solo se utiliza por este script ejecutado en Node local. Nunca ponerla en Angular, `public/env.js`, Vercel, commits, logs o chat. Node la lee desde el archivo local.

## Ejecutar

```bash
pnpm run bootstrap:admin:dev
```

El script:

1. Verifica que la URL coincide exactamente con el Project Ref de `supabase/development.json`; rechaza producción/otros proyectos.
2. Comprueba que todavía no existe ningún perfil ADMIN.
3. Si ya existe un perfil PLAYER válido para el email configurado, lo reutiliza para reanudar un intento anterior. En caso contrario, inserta una invitación aleatoria one-time desde el entorno servidor e invita al email con la API Admin de Supabase, adjuntando solo username + código en el metadata necesario para el trigger F1.6.
4. El trigger F1.6 consume la invitación y crea un perfil PLAYER en la misma transacción que Auth.
5. Si el email aún no se confirmó, el script informa que no hizo la promoción. El destinatario acepta el enlace de Auth; el operador ejecuta de nuevo el comando con la misma configuración local.
6. Al estar confirmado, llama a `bootstrap_first_admin` con la clave service-role. La RPC toma un advisory transaction lock, vuelve a comprobar que no hay ningún ADMIN, bloquea y valida que el target sea PLAYER activo, con email confirmado y con invitación efectivamente consumida; recién entonces cambia el rol a ADMIN.
7. Verifica el rol sin imprimir la clave ni el código aleatorio.

La RPC serializa arranques simultáneos: solo una promoción inicial puede ganar. Si alguien más alcanzó a recibir una invitación mientras competía, su perfil seguirá PLAYER; el script no lo eleva automáticamente. Los administradores siguientes se crearán mediante la futura gestión admin (F2.4/F1.8), no por esta RPC de un solo uso.

## Fallos y recuperación

- **Invitación enviada, todavía no aceptada:** volver a ejecutar después de la confirmación. Si el perfil PLAYER existe y cumple las condiciones, el script lo reutiliza; no manda otra invitación.
- **La API Auth falló después de insertar un código sin usar:** el código no se imprime y sigue sin consumirse. Un operador puede identificar y borrar de forma manual únicamente ese código sin usar mediante SQL Editor; F1.4 bloquea borrar invitaciones consumidas. Nunca compartir el código.
- **Perfil/player creado pero RPC falló:** no borrar la cuenta ni cambiar role a mano. Revisar el error y verificar que no haya ADMIN; corregir la causa y volver a ejecutar. El RPC valida que el email esté confirmado y que la invitación pertenezca al perfil.
- **Ya hay un perfil ADMIN:** el script aborta; no intentar volver a bootstrap. Usar la gestión administrativa autenticada cuando F2.4/F1.8 esté disponible.
- **No hay correo Auth operativo:** configurar/verificar SMTP y redirects antes del proceso. No improvisar una alta con trigger desactivado.

No se han creado credenciales de administrador durante la implementación de F1.7. El operador ejecuta el proceso cuando decida el email, y confirma el enlace recibido.

## Implementación y pruebas

- Migración: `supabase/migrations/20261011115749_bootstrap_first_admin.sql`.
- RPC: `public.bootstrap_first_admin(uuid)`, `SECURITY DEFINER`, `search_path=''`, solo `EXECUTE` a `service_role`.
- Script local: `scripts/bootstrap-first-admin.mjs`; no es un endpoint desplegado y no está empaquetado en Angular/Vercel.
- Suite reversible: `supabase/tests/bootstrap_first_admin.test.sql` (13 casos), ejercitada mediante `pnpm db:test` en desarrollo.
- El nombre, email, password, invitation code y clave `service_role` no están codificados en migraciones ni en el repositorio.

La inicialización de producción requiere primero crear el proyecto Supabase de producción y preparar una configuración/bootstrap específica aprobada. El script actual está deliberadamente limitado al Project Ref de desarrollo.

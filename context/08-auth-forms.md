# F1.10 — Registro, login y recuperación

## Estado y alcance

**Frontend implementado y probado; F1.10 no está cerrada.** Por decisión del usuario se prepara/documenta la configuración, sin modificar Auth remoto, crear cuentas ni enviar correos. Faltan el dominio exacto de Vercel de desarrollo, la configuración efectiva de Auth/entrega y las pruebas reales de la lista inferior. `config.toml` no configura Supabase Cloud.

No se instalan dependencias ni se añaden migraciones. Se conserva la autoridad del trigger F1.6 y RLS F1.8. PrimeNG queda para F1.13; los controles actuales son HTML accesible con Reactive Forms y estilos responsive.

## Rutas y contratos

| Ruta | Función |
|---|---|
| `/auth/login` | Correo/contraseña, mensajes Auth, destino validado con `safeReturnUrl()` y guards |
| `/auth/register` | Correo, username, código sensible a mayúsculas, contraseña/repetición |
| `/auth/forgot-password` | Solicitud de recuperación; mensaje de éxito sin confirmar si existe una cuenta |
| `/auth/callback` | Validación explícita de enlace; confirmación o formulario de nueva contraseña |
| `/auth/access` | Perfil inactivo/error, reintento y logout de F1.9 |

Login y registro son para invitados. Recuperación y callback son públicos incluso con una sesión anterior: una sesión ya abierta no convierte un callback vacío/fallido en válido. Un perfil inactivo puede cambiar su contraseña mediante Auth, pero no se reactiva ni obtiene acceso al juego. Confirmar email tampoco crea privilegios.

`AUTH_BACKEND.signUp` construye explícitamente:

```ts
{
  email: input.email.trim(),
  password: input.password, // no alterar espacios de contraseñas
  options: {
    emailRedirectTo: `${location.origin}/auth/callback`,
    data: {
      username: input.username.trim(),
      invitation_code: input.invitationCode.trim(),
    },
  },
}
```

No copia objetos de metadata ni manda role/activo/email dentro de metadata. La UI no consulta ni prevalida invitaciones: el trigger decide y revierte la transacción ante rechazo. Los errores de GoTrue que ocultan detalles SQL se traducen a un mensaje conjunto de invitación/username/administrador, sin afirmar qué condición falló ni mostrar el texto interno.

La invitación se consume al crear `auth.users`, **antes** de confirmar el email. Auth puede devolver éxito neutral para cuentas existentes; por eso no se asegura que se haya creado una cuenta. No se debe repetir el registro con otro código por un correo que no llega: confirmar o reenviar la confirmación de la cuenta existente desde Auth/operación administrativa, revisando el estado real primero. No hay formulario de reenvío de confirmación en esta entrega.

Validaciones: correo requerido/válido, username/código no vacíos, mínimo 8 caracteres para contraseña nueva y repetición. Login no impone longitud mínima para no bloquear contraseñas válidas previas. Auth puede aplicar requisitos más estrictos y sus rechazos se muestran de forma segura. Los botones/fieldset quedan deshabilitados durante el envío y los handlers descartan llamadas duplicadas. Se conservan los campos ante errores y se limpian contraseñas al completar. Hay labels, autocomplete, foco visible y mensajes `alert`/`status`.

## Callback y recuperación

El singleton usa `flowType: 'pkce'` y `detectSessionInUrl: false`. El SDK no consume automáticamente la URL durante el arranque; la pantalla verifica explícitamente y muestra los fallos.

Se aceptan:

1. `?code=...`: `exchangeCodeForSession()`. El propósito de recuperación sale de `data.redirectType` del verifier almacenado por el SDK, no de un `type=recovery` añadido a la URL. **Abrir en el mismo navegador/origen donde se solicitó**; un verifier perdido u otro navegador da error recuperable.
2. `?token_hash=...&type=signup|recovery|invite`: `verifyOtp()` valida en Auth el hash de un solo uso y su tipo. Útil con plantillas personalizadas y para abrir el correo en otro navegador.
3. `#access_token=...&refresh_token=...&type=signup|recovery|invite`: compatibilidad con enlaces implícitos, en particular `inviteUserByEmail` del bootstrap F1.7, que no genera verifier PKCE. `setSession()` valida la sesión con Auth; no se decodifica/confía en un JWT sin validación. En estos enlaces el tipo indica la UI, no concede permisos de servidor. Auth permite cambiar la contraseña de la propia sesión válida, y RLS sigue siendo la barrera de acceso al juego.

Enlace vacío, error del proveedor, combinación ambigua de credenciales, tipo no soportado, rechazo o respuesta sin sesión: estado de enlace inválido/caducado/usado. No se usa una sesión antigua como fallback. La URL del navegador se limpia con `history.replaceState()` antes de verificar, incluso ante fallo; el documento lleva `Referrer-Policy` mediante meta `no-referrer`. No se registran tokens, códigos, passwords ni mensajes SQL.

`AuthService.authenticate()` reutiliza la publicación por revisiones/eventos y espera el perfil RPC; logout o una operación posterior invalidan resultados pendientes. Los callbacks Auth siguen sin ejecutar APIs dentro del lock del SDK.

El formulario de contraseña solo se abre tras un callback aceptado de recovery/invite y se vincula al access token de esa sesión, en memoria. Logout/cambio de token/cuenta bloquea el formulario; recargar la URL ya limpia exige solicitar otro enlace, sin persistir credenciales del enlace. Tras guardar no se admite un segundo envío; se ofrece cerrar la sesión local e iniciar sesión con la contraseña nueva. Un error de logout se puede reintentar sin repetir el cambio de contraseña. La revocación global de otras sesiones no se implementa aquí.

## Configuración remota pendiente (operador)

Proyecto autorizado de desarrollo: el de `supabase/development.json`. No usar el futuro proyecto de producción para estas comprobaciones ni ejecutar resets.

En **Supabase Dashboard → Authentication** del proyecto de desarrollo:

1. **URL Configuration**: establecer Site URL al origen de desarrollo elegido. Añadir **Redirect URLs exactas**:
   - `http://localhost:4200/auth/callback`
   - `https://DOMINIO-VERCEL-DE-DESARROLLO/auth/callback` (sustituir por dominio confirmado).
   - Si se usa otro host local/Preview, añadir únicamente su callback exacto. Evitar comodines amplios de todos los proyectos Vercel.
2. **Providers / Email**: habilitar email/password y confirmación de email. Mantener deshabilitado el acceso anónimo. Revisar mínimo de contraseña (UI: 8) y requisitos de seguridad efectivos.
3. **Correo**: comprobar remitente, cuotas y destinatarios permitidos del servicio de Auth. El SMTP por defecto tiene restricciones; configurar SMTP propio si es necesario para entregar a los correos autorizados. Resend como SMTP Auth es distinto de `api/send-email.mjs`: no habilitar ese endpoint sin protección F7.
4. **Templates**: con el flujo PKCE estándar, conservar `{{ .ConfirmationURL }}` y verificar que el redirect solicitado se respeta. Para enlaces de hash directamente al callback, una alternativa documentada es usar estas plantillas, con `RedirectTo` exactamente al callback permitido:

   ```html
   <!-- Confirm signup -->
   <a href="{{ .RedirectTo }}?token_hash={{ .TokenHash }}&amp;type=signup">Confirmar correo</a>
   <!-- Reset password -->
   <a href="{{ .RedirectTo }}?token_hash={{ .TokenHash }}&amp;type=recovery">Cambiar contraseña</a>
   <!-- Invite user / bootstrap -->
   <a href="{{ .RedirectTo }}?token_hash={{ .TokenHash }}&amp;type=invite">Aceptar invitación</a>
   ```

   Probar cada plantilla antes de abrir el grupo; nunca poner service_role en enlaces o Angular. Si se usan plantillas con `.SiteURL` en vez de `.RedirectTo`, localhost y Vercel no reciben necesariamente el enlace en su propio origen. Algunos escáneres de correo pueden consumir enlaces de un solo uso: revisar si ocurre en el proveedor elegido.
5. **Vercel Preview/desarrollo**: publicar los cambios, usar URL/key públicas del Supabase de desarrollo y comprobar fallback de rutas profundas a la SPA. Production/Supabase de producción queda para F8.5.

El `supabase/config.toml` opcional se ha alineado con localhost:4200/callback, confirmaciones y mínimo 8; este ajuste **no** se ha enviado al Cloud. No ejecutar `supabase config push` sin revisar todos los cambios de configuración.

## Comprobaciones para cerrar F1.10

- [ ] Confirmar dominio de Vercel, redirects remotos, email confirmation y transporte/plantillas de correo efectivos.
- [ ] Con autorización para datos de prueba persistentes, generar una invitación y registrar una cuenta; verificar PLAYER/activo/email, consumo único y login bloqueado hasta confirmar.
- [ ] Probar código inválido/usado y username duplicado por la API pública Auth real; no confundir las pruebas SQL de F1.6 con la traducción real de GoTrue.
- [ ] Confirmar correo en localhost y Vercel; verificar login/logout y destinos player/admin con perfil RPC real.
- [ ] Solicitar recuperación real, cambiar contraseña y comprobar que la anterior falla y la nueva entra. Verificar el mensaje neutral para correo desconocido.
- [ ] Reutilizar/caducar enlace; probar URL incompleta y, con PKCE, otro navegador/verifier perdido. Nunca autorizar por una sesión preexistente ante un enlace fallido.
- [ ] Registrar evidencia sin tokens/emails innecesarios, y definir qué cuentas de prueba se conservarán. No borrar histórico ni reutilizar invitaciones consumidas.

## Evidencia local

- `pnpm test --watch=false`: **120 tests** en 7 suites (72 anteriores + 48 nuevos).
- `pnpm run test:db-runner`: **9 tests**.
- `pnpm run build`: correcto, sin superar budgets.
- Pruebas de adaptador (allowlist metadata), servicio (sesión/propósito, red, revocación/callback obsoleto), parsing y routing/formularios (validación, doble envío, errores y actualización de contraseña).
- No se han reejecutado SQL ni lint remotos en esta entrega: no hay cambios SQL. La evidencia previa de 200 comprobaciones está en F1.8/F1.9, no es una validación real de estos nuevos flujos de correo.

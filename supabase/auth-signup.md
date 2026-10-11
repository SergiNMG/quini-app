# F1.6 — Registro por invitación

## Contrato de registro

El frontend futuro usará `supabase.auth.signUp` (email/password) con este `options.data` mínimo:

```ts
{
  username: username.trim(),
  invitation_code: invitationCode.trim(),
}
```

Estos campos de `user_metadata` **no son de confianza**. Se pueden enviar valores arbitrarios para `role`, `activo`, correo u otros campos; el trigger los ignora. La dirección de perfil sale de `NEW.email` en `auth.users` y el trigger siempre asigna `role = PLAYER`, `activo = true`.

El email de Auth sigue sujeto a la configuración de confirmación del proyecto. El código se consume cuando Auth crea `auth.users`, antes de que el jugador confirme el email; si deja caducar la confirmación, el admin tendrá que generar otra invitación. La activación de confirmación Auth y el tratamiento amable de errores en el formulario pertenecen a F1.10.

## Una única transacción PostgreSQL

`20261009143227_invited_signup_profile.sql` añade un trigger `AFTER INSERT` sobre `auth.users`. Para cada usuario:

1. Exige `invitation_code` y username no vacíos; normaliza espacios exteriores. Los códigos siguen siendo sensibles a mayúsculas/minúsculas.
2. Crea `public.profiles` con ID Auth, username normalizado, `NEW.email`, PLAYER activo y el código utilizado.
3. Ejecuta `UPDATE invitation_codes ... WHERE code = input AND usado = false AND usado_por IS NULL RETURNING ...`.
4. Si el UPDATE no reclama exactamente un código, levanta una excepción. Auth revierte `auth.users` y el perfil creado.

La fila del código queda bloqueada por el UPDATE condicional hasta el fin de la transacción. Dos registros concurrentes con un mismo código no pueden consumirlo ambos: el que pierde encuentra cero filas después de esperar y aborta completamente su inserción Auth/perfil. Si el perfil falla por username/email único u otra restricción, el consumo del código no llega a ocurrir; si falla otro paso después de insertar perfil, todo se revierte junto con el usuario Auth.

La prueba SQL verifica ausencia/invalidez/reuso del código, username en blanco, metadata hostil, conflicto de username con invitación aún libre, perfil-email proveniente de Auth y ausencia de filas huérfanas. Todos los datos Auth ficticios e invitaciones se revierten en la suite.

## Límites de seguridad y próximas tareas

- La validación autoritativa ocurre en PostgreSQL al crear `auth.users`, no en la UI ni en una llamada pública de “prevalidar código”. Las políticas RLS de `invitation_codes` no habilitan por sí mismas el sign-up; la función `SECURITY DEFINER` está aislada con `search_path = ''`, referencias cualificadas y EXECUTE solo para `supabase_auth_admin`.
- Nunca usar `service_role` en Angular. F1.6 no introduce un endpoint frontend con credenciales administrativas ni Edge Function para el alta.
- `profiles.invitation_code_used` guarda el código utilizado por trazabilidad. F1.8 no debe exponer esa columna, email, role o activo a otros jugadores; lectura pública de filas completas de perfiles está prohibida.
- RLS y permisos del resto de tablas, creación/manual-promoción del primer admin y UI de Auth son tareas separadas (F1.7–F1.10). La función no hace admins desde `role` enviado por el cliente.
- F1.6 no modifica ni consume códigos existentes fuera del sign-up. Si Auth falla/username está ocupado, no se pierde la invitación.

## Migración y pruebas

- Migración: `supabase/migrations/20261009143227_invited_signup_profile.sql`.
- Suite: `supabase/tests/invited_signup.test.sql` (23 casos pgTAP).
- Ejecutar únicamente mediante `pnpm db:test` en el proyecto autorizado de desarrollo. No hay fixtures persistentes; nunca usar este flujo de fixtures ni `db reset` en producción.

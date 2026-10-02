# Stack tecnológico

## Contexto del desarrollador

- Perfil frontend (+2 años), especializado en Angular, con poca experiencia real en backend.
- Experiencia reciente con Angular en signals, `computed()`, `rxResource()` y standalone patterns (migración de un proyecto NgModule a Angular 21).
- Primera vez trabajando con Supabase.

## Decisiones

| Capa | Tecnología | Justificación |
|---|---|---|
| Frontend | **Angular** (última versión, standalone components + signals) | Perfil fuerte del desarrollador; al ser proyecto nuevo, se evita la estructura NgModule del proyecto profesional en favor de standalone + signals, más simple de mantener para este alcance |
| Estado | Signals + `rxResource()` | Ya dominado por el desarrollador; NgRx sería sobreingeniería para este alcance |
| Estilos / UI | **Tailwind CSS** + **PrimeNG** (o Angular Material) | Estética cuidada sin escribir CSS a mano; componentes (tablas, formularios, modales) ya interactivos de fábrica — encaja con el criterio "atractiva, sin complicaciones" |
| Backend | **Supabase** (Auth + Postgres + Storage + Edge Functions) | Cubre auth, base de datos relacional, almacenamiento de imágenes y lógica de servidor sin necesidad de escribir un backend propio |
| Autenticación | Supabase Auth (email/contraseña) + código de invitación validado antes de crear el perfil | Registro controlado sin infraestructura extra |
| Almacenamiento de imágenes | Supabase Storage (bucket público para escudos) | Evita gestionar URLs firmadas para contenido no sensible |
| Emails | **Resend** (vía Edge Function) | Buena DX, nivel gratuito suficiente; puede centralizar tanto los recordatorios de jornada como (opcionalmente) el SMTP de Supabase Auth en producción |
| Despliegue frontend | **Vercel** | Angular se despliega como SPA estática; no se necesita SSR para este caso de uso |

## Consideraciones de configuración de Supabase

- Región del proyecto cercana a España (p. ej. West EU).
- Plan Free suficiente para el alcance del MVP.
- RLS activado en todas las tablas desde su creación (ver `03-data-model.md`); las políticas se añaden antes de exponer cualquier tabla a tráfico real.
- `service_role` key solo en Edge Functions/entornos de servidor, nunca en el frontend Angular.
- Redirect URLs de Auth apuntando al dominio de Vercel (+ localhost en desarrollo).

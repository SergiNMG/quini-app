# Stack tecnológico

## Contexto del desarrollador

- Perfil frontend (+2 años), especializado en Angular, con poca experiencia real en backend.
- Experiencia reciente con Angular en signals, `computed()`, `rxResource()` y standalone patterns (migración de un proyecto NgModule a Angular 21).
- Primera vez trabajando con Supabase.

## Decisiones

| Capa | Tecnología | Justificación |
|---|---|---|
| Gestor de paquetes | **pnpm 10.34.6** | Versión fijada en `package.json`, lockfile único `pnpm-lock.yaml` y uso consistente en Angular CLI, VS Code y Vercel |
| Frontend | **Angular** (última versión, standalone components + signals) | Perfil fuerte del desarrollador; al ser proyecto nuevo, se evita la estructura NgModule del proyecto profesional en favor de standalone + signals, más simple de mantener para este alcance |
| Estado | Signals + `rxResource()` | Ya dominado por el desarrollador; NgRx sería sobreingeniería para este alcance |
| Estilos / UI | **Tailwind CSS 4** + **PrimeNG** | Elección de producto: aprender PrimeNG y aprovechar tablas, formularios, diálogos y notificaciones. Usar modo styled y un tema como Aura para evitar construir todos los estilos; Tailwind para layout y responsive. PrimeNG aún no está instalado |
| Backend | **Supabase** (Auth + Postgres + Storage + Edge Functions) | Cubre auth, base de datos relacional, almacenamiento de imágenes y lógica de servidor sin necesidad de escribir un backend propio |
| Autenticación | Supabase Auth (email/contraseña) + código de invitación validado antes de crear el perfil | Registro controlado sin infraestructura extra |
| Almacenamiento de imágenes | Supabase Storage (bucket público para escudos) | Evita gestionar URLs firmadas para contenido no sensible |
| Emails | **Resend** (función serverless de Vercel existente) | Reutilizar `api/send-email.mjs` para evitar duplicar infraestructura; protegerla con autenticación y autorización admin antes de habilitar envíos. SMTP de Supabase Auth opcional en producción. No crear además una Edge Function para el mismo flujo |
| Despliegue frontend | **Vercel** | Angular se despliega como SPA estática; no se necesita SSR para este caso de uso |

## Consideraciones de configuración de Supabase

- Región del proyecto cercana a España (p. ej. West EU).
- Plan Free suficiente para el alcance del MVP.
- RLS activado en todas las tablas desde su creación (ver `03-data-model.md`); las políticas se añaden antes de exponer cualquier tabla a tráfico real.
- `service_role` key solo en Edge Functions/entornos de servidor, nunca en el frontend Angular.
- Redirect URLs de Auth apuntando al dominio de Vercel (+ localhost:4200 en desarrollo); el `config.toml` inicial todavía apunta al puerto 3000.

## Integración de PrimeNG

- Verificar los peer dependencies y elegir una versión compatible con Angular 21 al instalar; no actualizar Angular automáticamente para incorporar la librería.
- Seguir la [guía oficial de instalación](https://primeng.org/installation): configurar `providePrimeNG`, el paquete de temas que corresponda a la versión elegida y un preset como Aura.
- Importar componentes individualmente en cada standalone component; no incorporar toda la librería al bundle.
- Instalar iconos o integración adicional con Tailwind solo si se usan; evitar dependencias y wrappers genéricos innecesarios.
- No se recomienda añadir otra librería de componentes: PrimeNG cubre el alcance y el objetivo de aprendizaje del desarrollador.

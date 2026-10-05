# Quini

Base para una aplicación Angular desplegada en Vercel, con Supabase, Tailwind CSS y Resend.

## Documentación y plan de trabajo

- [Visión general y contexto del producto](context/00-overview.md).
- [Requisitos funcionales](context/01-requirements.md) y [reglas de negocio](context/02-business-rules.md).
- [Modelo de datos](context/03-data-model.md) y [decisiones tecnológicas](context/04-tech-stack.md).
- **[Roadmap detallado por fases](context/05-roadmap.md)**: fuente única de tareas, dependencias, estado real y criterios de aceptación.

La infraestructura inicial no implica que auth o las pantallas funcionales estén terminadas. PrimeNG es la librería de UI elegida y su instalación está planificada en la fase 1.

## Stack

- **Gestor de paquetes:** pnpm 10.34.6 (fijado en `package.json`)
- **Frontend:** Angular 21 (standalone, routing y TypeScript estricto)
- **Estilos:** Tailwind CSS 4
- **Backend:** Supabase (Auth, Postgres y Storage)
- **Correo:** función serverless de Vercel con Resend
- **Hosting:** Vercel con fallback SPA

## Inicio local

1. Usa Node.js compatible con Angular 21 (por ejemplo, Node 22.12 o superior dentro de la rama 22), activa pnpm mediante Corepack e instala dependencias:

   ```bash
   corepack enable
   pnpm install --frozen-lockfile
   ```

   `package.json` fija pnpm 10.34.6 y `pnpm-lock.yaml` es el único lockfile del proyecto. Si Corepack no está disponible, instálalo siguiendo su documentación antes de ejecutar estos comandos. Si `corepack enable` falla por permisos o no hay un comando `pnpm` en el PATH, puedes usar `corepack pnpm` en lugar de `pnpm`.

   No se necesita `--legacy-peer-deps`. `pnpm-workspace.yaml` autoriza únicamente los scripts de instalación de las dependencias nativas usadas por Angular (`@parcel/watcher`, `esbuild`, `lmdb` y `msgpackr-extract`); revisa cualquier nueva solicitud de aprobación antes de permitirla.

2. Copia `.env.example` como `.env` y completa las variables públicas de Supabase desde **Supabase Dashboard → Connect**.

3. Genera el fichero público de configuración:

   ```bash
   pnpm run config:local
   ```

4. Arranca el proyecto:

   ```bash
   pnpm start
   ```

Abre `http://localhost:4200`.

## Supabase

El singleton está en `src/app/core/supabase/supabase.client.ts`:

```ts
import { supabase } from './core/supabase/supabase.client';

const { data, error } = await supabase.auth.getSession();
```

Solo se exponen en el navegador `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`. Configura Row Level Security (RLS) en cada tabla antes de consumirla desde el cliente. Nunca uses una `service_role` en Angular.

La configuración del CLI está en `supabase/config.toml`. La integración Git de Supabase Cloud no enlaza automáticamente el CLI local; ejecuta una vez lo siguiente con el **Project Reference** de tu instancia:

```bash
pnpm dlx supabase@latest login
pnpm dlx supabase@latest link --project-ref TU_PROJECT_REF
```

Crea los cambios de esquema como migraciones versionadas y súbelos al proyecto enlazado:

```bash
pnpm dlx supabase@latest migration new nombre_del_cambio
pnpm dlx supabase@latest db push
```

## Correo con Resend

`api/send-email.mjs` implementa `POST /api/send-email` usando `RESEND_API_KEY` y `RESEND_FROM_EMAIL`. Ambas variables son privadas y solo se deben configurar en Vercel. **El endpoint actual es un scaffold sin autenticación: no debe habilitarse públicamente con credenciales reales hasta protegerlo.** El roadmap prevé verificar sesión y rol admin activo en servidor, limitar el contrato a recordatorios de jornadas y añadir protección de frecuencia/reintentos. No basta con ocultar el botón en Angular.

Ejemplo de payload:

```json
{
  "to": "destinatario@ejemplo.com",
  "subject": "Asunto",
  "html": "<p>Mensaje</p>",
  "text": "Mensaje"
}
```

## Despliegue en Vercel

1. Importa este repositorio Git en Vercel.
2. En **Settings → Environment Variables**, define para Preview y Production:
   - `SUPABASE_URL`
   - `SUPABASE_PUBLISHABLE_KEY`
   - `RESEND_API_KEY`
   - `RESEND_FROM_EMAIL`
3. Despliega. `vercel.json` instala con `corepack pnpm install --frozen-lockfile` y ejecuta `corepack pnpm run build:vercel`, usando la versión fijada en `package.json`. El build genera `public/env.js` con las dos variables públicas y publica `dist/quini-app/browser`. Elimina cualquier override antiguo de instalación/build con npm en el panel de Vercel para que se aplique la configuración del repositorio.

No incluyas secretos de Resend ni la clave `service_role` de Supabase en `public/env.js` ni en variables con prefijos públicos.

## Comandos

```bash
pnpm install --frozen-lockfile  # instala las versiones del lockfile
pnpm start                      # servidor de desarrollo
pnpm run config:local           # crea public/env.js desde .env
pnpm run build                  # build de producción sin regenerar env.js
pnpm run build:vercel            # build de Vercel y generación de env.js
pnpm test --watch=false          # pruebas unitarias sin modo watch
pnpm exec ng generate component # Angular CLI usa pnpm por defecto
```

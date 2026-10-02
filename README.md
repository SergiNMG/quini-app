# Quini

Base para una aplicación Angular desplegada en Vercel, con Supabase, Tailwind CSS y Resend.

## Stack

- **Frontend:** Angular 21 (standalone, routing y TypeScript estricto)
- **Estilos:** Tailwind CSS 4
- **Backend:** Supabase (Auth, Postgres y Storage)
- **Correo:** función serverless de Vercel con Resend
- **Hosting:** Vercel con fallback SPA

## Inicio local

1. Instala dependencias:

   ```bash
   npm install --legacy-peer-deps
   ```

   > La opción es necesaria actualmente por un error de resolución de `npm@10.9.4` en este entorno. Puede omitirse cuando `npm install` funcione normalmente.

2. Copia `.env.example` como `.env` y completa las variables públicas de Supabase desde **Supabase Dashboard → Connect**.

3. Genera el fichero público de configuración:

   ```bash
   npm run config:local
   ```

4. Arranca el proyecto:

   ```bash
   npm start
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
npx supabase@latest login
npx supabase@latest link --project-ref TU_PROJECT_REF
```

Crea los cambios de esquema como migraciones versionadas y súbelos al proyecto enlazado:

```bash
npx supabase@latest migration new nombre_del_cambio
npx supabase@latest db push
```

## Correo con Resend

`api/send-email.mjs` implementa `POST /api/send-email` usando `RESEND_API_KEY` y `RESEND_FROM_EMAIL`. Ambas variables son privadas y solo se deben configurar en Vercel. Antes de conectar un formulario público, añade autenticación y/o protección antiabuso (por ejemplo, Turnstile y rate limiting).

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
3. Despliega. `vercel.json` ejecuta `npm run build:vercel`, que genera `public/env.js` con las dos variables públicas durante la compilación y publica `dist/quini-app/browser`.

No incluyas secretos de Resend ni la clave `service_role` de Supabase en `public/env.js` ni en variables con prefijos públicos.

## Comandos

```bash
npm start             # servidor de desarrollo
npm run config:local  # crea public/env.js desde .env
npm run build          # build de producción sin regenerar env.js
npm run build:vercel   # build de Vercel y generación de env.js
npm test               # pruebas unitarias
```

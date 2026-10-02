import { mkdir, writeFile } from 'node:fs/promises';

const config = {
  SUPABASE_URL: process.env.SUPABASE_URL ?? '',
  SUPABASE_PUBLISHABLE_KEY: process.env.SUPABASE_PUBLISHABLE_KEY ?? '',
};

await mkdir('public', { recursive: true });
await writeFile(
  'public/env.js',
  `// Generated at build time. Values below are public browser configuration.\nwindow.__env = ${JSON.stringify(config, null, 2)};\n`,
);

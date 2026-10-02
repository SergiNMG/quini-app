interface RuntimeConfig {
  SUPABASE_URL?: string;
  SUPABASE_PUBLISHABLE_KEY?: string;
}

declare global {
  interface Window {
    __env?: RuntimeConfig;
  }
}

function requiredConfig(name: keyof RuntimeConfig): string {
  const value = window.__env?.[name];

  if (!value) {
    throw new Error(
      `Falta la configuración ${name}. Define la variable y genera public/env.js.`,
    );
  }

  return value;
}

export const runtimeConfig = {
  get supabaseUrl(): string {
    return requiredConfig('SUPABASE_URL');
  },
  get supabasePublishableKey(): string {
    return requiredConfig('SUPABASE_PUBLISHABLE_KEY');
  },
};

import { InjectionToken } from '@angular/core';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { runtimeConfig } from '../config/runtime-config';

/** Un cliente por aplicación, creado al inyectarlo (no al importar el módulo). */
export const SUPABASE_CLIENT = new InjectionToken<SupabaseClient>('SUPABASE_CLIENT', {
  providedIn: 'root',
  factory: () =>
    createClient(runtimeConfig.supabaseUrl, runtimeConfig.supabasePublishableKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        flowType: 'pkce',
        // Callback explícito: no consumir silenciosamente enlaces fallidos
        // ni confundir una sesión anterior con la sesión del enlace.
        detectSessionInUrl: false,
      },
    }),
});

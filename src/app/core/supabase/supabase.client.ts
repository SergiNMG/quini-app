import { createClient } from '@supabase/supabase-js';
import { runtimeConfig } from '../config/runtime-config';

/** Cliente singleton para Auth, Database y Storage de Supabase. */
export const supabase = createClient(
  runtimeConfig.supabaseUrl,
  runtimeConfig.supabasePublishableKey,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  },
);

import { inject, InjectionToken } from '@angular/core';
import { SUPABASE_CLIENT } from '../supabase/supabase.client';
import type { AuthBackend } from './auth.types';

export const AUTH_BACKEND = new InjectionToken<AuthBackend>('AUTH_BACKEND', {
  providedIn: 'root',
  factory: () => {
    const supabase = inject(SUPABASE_CLIENT);
    return {
      getSession: () => supabase.auth.getSession(),
      onAuthStateChange: (callback) => supabase.auth.onAuthStateChange(callback),
      signInWithPassword: (email, password) =>
        supabase.auth.signInWithPassword({ email, password }),
      signOut: () => supabase.auth.signOut({ scope: 'local' }),
      getMyProfile: async () => supabase.rpc('get_my_profile'),
    };
  },
});

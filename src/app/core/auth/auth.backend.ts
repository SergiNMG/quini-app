import { inject, InjectionToken } from '@angular/core';
import { SUPABASE_CLIENT } from '../supabase/supabase.client';
import type { AuthBackend } from './auth.types';

export const AUTH_BACKEND = new InjectionToken<AuthBackend>('AUTH_BACKEND', {
  providedIn: 'root',
  factory: () => {
    const supabase = inject(SUPABASE_CLIENT);
    return {
      signUp: (input, redirectTo) =>
        supabase.auth.signUp({
          email: input.email.trim(),
          password: input.password,
          options: {
            emailRedirectTo: redirectTo,
            // Lista explícita: nunca copiar metadata arbitraria del formulario.
            data: {
              username: input.username.trim(),
              invitation_code: input.invitationCode.trim(),
            },
          },
        }),
      resetPasswordForEmail: (email, redirectTo) =>
        supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo }),
      updatePassword: (password) => supabase.auth.updateUser({ password }),
      exchangeCode: (code) => supabase.auth.exchangeCodeForSession(code),
      verifyEmailToken: (token_hash, type) => supabase.auth.verifyOtp({ token_hash, type }),
      setSession: (access_token, refresh_token) =>
        supabase.auth.setSession({ access_token, refresh_token }),
      getSession: () => supabase.auth.getSession(),
      onAuthStateChange: (callback) => supabase.auth.onAuthStateChange(callback),
      signInWithPassword: (email, password) =>
        supabase.auth.signInWithPassword({ email, password }),
      signOut: () => supabase.auth.signOut({ scope: 'local' }),
      getMyProfile: async () => supabase.rpc('get_my_profile'),
    };
  },
});

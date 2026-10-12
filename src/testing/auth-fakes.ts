import { AuthError, type AuthChangeEvent, type Session } from '@supabase/supabase-js';
import { vi } from 'vitest';
import type { AuthBackend, UserRole } from '../app/core/auth/auth.types';

export function fakeSession(id = 'player'): Session {
  return {
    access_token: 'fake-access',
    refresh_token: 'fake-refresh',
    token_type: 'bearer',
    expires_in: 3600,
    user: {
      id,
      app_metadata: {},
      user_metadata: { role: 'ADMIN', activo: true },
      aud: 'authenticated',
      created_at: '2026-10-01T00:00:00Z',
    },
  };
}

export function profileRow(id = 'player', role: UserRole = 'PLAYER') {
  return {
    profile_id: id,
    username: 'Jugador',
    email: 'test@example.invalid',
    avatar_url: null,
    role,
    activo: true,
    created_at: '2026-10-01T00:00:00Z',
    updated_at: '2026-10-01T00:00:00Z',
  };
}

export function fakeBackend(session: Session | null = null) {
  let callback: (event: AuthChangeEvent, session: Session | null) => void = () => {};
  const unsubscribe = vi.fn();
  const backend = {
    getSession: vi
      .fn<AuthBackend['getSession']>()
      .mockResolvedValue({ data: { session }, error: null }),
    getMyProfile: vi.fn<AuthBackend['getMyProfile']>().mockResolvedValue({
      data: session ? [profileRow(session.user.id)] : [],
      error: null,
    }),
    onAuthStateChange: vi.fn<AuthBackend['onAuthStateChange']>().mockImplementation((cb) => {
      callback = cb;
      return { data: { subscription: { id: 'fake', callback: cb, unsubscribe } } };
    }),
    signInWithPassword: vi
      .fn<AuthBackend['signInWithPassword']>()
      .mockResolvedValue({ data: { session: fakeSession() }, error: null }),
    signOut: vi.fn<AuthBackend['signOut']>().mockResolvedValue({ error: null }),
  } satisfies AuthBackend;
  return {
    backend,
    unsubscribe,
    emit: (event: AuthChangeEvent, value: Session | null) => callback(event, value),
  };
}

export function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((r) => {
    resolve = r;
  });
  return { promise, resolve };
}

export const authFailure = () => new AuthError('simulated failure');

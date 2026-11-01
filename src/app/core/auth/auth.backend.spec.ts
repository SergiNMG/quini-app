import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { fakeSession } from '../../../testing/auth-fakes';
import { SUPABASE_CLIENT } from '../supabase/supabase.client';
import { AUTH_BACKEND } from './auth.backend';

function setup() {
  const client = {
    auth: {
      signUp: vi.fn().mockResolvedValue({ data: { session: null }, error: null }),
      resetPasswordForEmail: vi.fn().mockResolvedValue({ error: null }),
      updateUser: vi.fn().mockResolvedValue({ error: null }),
      exchangeCodeForSession: vi.fn(),
      verifyOtp: vi.fn(),
      setSession: vi.fn(),
      getSession: vi.fn().mockResolvedValue({ data: { session: null }, error: null }),
      onAuthStateChange: vi.fn(),
      signInWithPassword: vi
        .fn()
        .mockResolvedValue({ data: { session: fakeSession() }, error: null }),
      signOut: vi.fn().mockResolvedValue({ error: null }),
    },
    rpc: vi.fn().mockResolvedValue({ data: [], error: null }),
  };
  TestBed.configureTestingModule({ providers: [{ provide: SUPABASE_CLIENT, useValue: client }] });
  return { client, backend: TestBed.inject(AUTH_BACKEND) };
}

describe('Supabase Auth adapter', () => {
  it('restores the session through Auth without constructing a real client', async () => {
    const { client, backend } = setup();
    await backend.getSession();
    expect(client.auth.getSession).toHaveBeenCalledTimes(1);
  });

  it('subscribes through Auth', () => {
    const { client, backend } = setup();
    const callback = vi.fn();
    backend.onAuthStateChange(callback);
    expect(client.auth.onAuthStateChange).toHaveBeenCalledWith(callback);
  });

  it('passes only email and password to signInWithPassword', async () => {
    const { client, backend } = setup();
    await backend.signInWithPassword('test@example.invalid', 'fake-password');
    expect(client.auth.signInWithPassword).toHaveBeenCalledWith({
      email: 'test@example.invalid',
      password: 'fake-password',
    });
  });

  it('signs out only the current browser session', async () => {
    const { client, backend } = setup();
    await backend.signOut();
    expect(client.auth.signOut).toHaveBeenCalledWith({ scope: 'local' });
  });

  it('sends an explicit metadata allowlist and normalized strings at signup', async () => {
    const { client, backend } = setup();
    const hostile = {
      email: ' test@example.invalid ',
      password: ' password ',
      username: ' Player ',
      invitationCode: ' Code ',
      role: 'ADMIN',
      activo: true,
    };
    await backend.signUp(hostile, 'http://localhost:4200/auth/callback');
    expect(client.auth.signUp).toHaveBeenCalledWith({
      email: 'test@example.invalid',
      password: ' password ',
      options: {
        emailRedirectTo: 'http://localhost:4200/auth/callback',
        data: { username: 'Player', invitation_code: 'Code' },
      },
    });
  });

  it('requests reset with an explicit redirect and updates only the password', async () => {
    const { client, backend } = setup();
    await backend.resetPasswordForEmail(
      ' test@example.invalid ',
      'https://quini.invalid/auth/callback',
    );
    await backend.updatePassword('new-password');
    expect(client.auth.resetPasswordForEmail).toHaveBeenCalledWith('test@example.invalid', {
      redirectTo: 'https://quini.invalid/auth/callback',
    });
    expect(client.auth.updateUser).toHaveBeenCalledWith({ password: 'new-password' });
  });

  it('delegates callback verification to Auth, not JWT decoding', async () => {
    const { client, backend } = setup();
    await backend.exchangeCode('code');
    await backend.verifyEmailToken('hash', 'recovery');
    await backend.setSession('access', 'refresh');
    expect(client.auth.exchangeCodeForSession).toHaveBeenCalledWith('code');
    expect(client.auth.verifyOtp).toHaveBeenCalledWith({ token_hash: 'hash', type: 'recovery' });
    expect(client.auth.setSession).toHaveBeenCalledWith({
      access_token: 'access',
      refresh_token: 'refresh',
    });
  });

  it('reads private profile fields only from get_my_profile', async () => {
    const { client, backend } = setup();
    await backend.getMyProfile();
    expect(client.rpc).toHaveBeenCalledWith('get_my_profile');
  });
});

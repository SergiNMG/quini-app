import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { fakeSession } from '../../../testing/auth-fakes';
import { SUPABASE_CLIENT } from '../supabase/supabase.client';
import { AUTH_BACKEND } from './auth.backend';

function setup() {
  const client = {
    auth: {
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

  it('reads private profile fields only from get_my_profile', async () => {
    const { client, backend } = setup();
    await backend.getMyProfile();
    expect(client.rpc).toHaveBeenCalledWith('get_my_profile');
  });
});

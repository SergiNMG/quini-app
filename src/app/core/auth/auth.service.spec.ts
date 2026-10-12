import { TestBed } from '@angular/core/testing';
import {
  authFailure,
  deferred,
  fakeBackend,
  fakeSession,
  profileRow,
} from '../../../testing/auth-fakes';
import { AUTH_BACKEND } from './auth.backend';
import { AuthService } from './auth.service';
import type { ProfileResult, SessionResult } from './auth.types';

function setup(session = null as ReturnType<typeof fakeSession> | null) {
  const fake = fakeBackend(session);
  TestBed.configureTestingModule({
    providers: [{ provide: AUTH_BACKEND, useValue: fake.backend }],
  });
  return { ...fake, auth: TestBed.inject(AuthService) };
}

describe('AuthService', () => {
  it('starts loading and restores an anonymous session once', async () => {
    const { auth, backend } = setup();
    expect(auth.status()).toBe('loading');
    await Promise.all([auth.whenReady(), auth.whenReady()]);
    expect(auth.status()).toBe('anonymous');
    expect(backend.getSession).toHaveBeenCalledTimes(1);
    expect(backend.onAuthStateChange).toHaveBeenCalledTimes(1);
    expect(backend.getMyProfile).not.toHaveBeenCalled();
  });

  it('loads an active PLAYER via the bounded RPC and ignores metadata role', async () => {
    const { auth } = setup(fakeSession());
    await auth.whenReady();
    expect(auth.isAuthenticated()).toBe(true);
    expect(auth.isAdmin()).toBe(false);
    expect(auth.profile()?.profileId).toBe('player');
    expect(auth.profile()?.email).toBe('test@example.invalid');
  });

  it('recognizes ADMIN only from the current profile', async () => {
    const { auth, backend } = setup(fakeSession());
    backend.getMyProfile.mockResolvedValue({ data: [profileRow('player', 'ADMIN')], error: null });
    await auth.whenReady();
    expect(auth.isAdmin()).toBe(true);
  });

  it('blocks an inactive or missing profile without inventing an identity', async () => {
    const { auth, backend } = setup(fakeSession());
    backend.getMyProfile.mockResolvedValue({ data: [], error: null });
    await auth.whenReady();
    expect(auth.status()).toBe('inactive');
    expect(auth.session()).not.toBeNull();
    expect(auth.profile()).toBeNull();
    expect(auth.isAuthenticated()).toBe(false);
  });

  it.each([
    null,
    {},
    [profileRow('someone-else')],
    [{ ...profileRow(), activo: false }],
    [{ ...profileRow(), role: 'OWNER' }],
    [profileRow(), profileRow()],
  ])('fails closed for invalid RPC response %j', async (data) => {
    const { auth, backend } = setup(fakeSession());
    backend.getMyProfile.mockResolvedValue({ data, error: null });
    await auth.whenReady();
    expect(auth.status()).toBe('error');
    expect(auth.isAdmin()).toBe(false);
    expect(auth.profile()).toBeNull();
  });

  it('handles a failed restoration and permits retry', async () => {
    const { auth, backend } = setup();
    backend.getSession.mockResolvedValueOnce({ data: { session: null }, error: authFailure() });
    await auth.whenReady();
    expect(auth.status()).toBe('error');
    await auth.refreshProfile();
    expect(auth.status()).toBe('anonymous');
  });

  it('handles a thrown restoration error', async () => {
    const { auth, backend } = setup();
    backend.getSession.mockRejectedValueOnce(new Error('network'));
    await auth.whenReady();
    expect(auth.status()).toBe('error');
  });

  it.each(['response', 'throw'])(
    'clears prior admin permissions on a profile failure (%s)',
    async (failure) => {
      const { auth, backend } = setup(fakeSession());
      backend.getMyProfile.mockResolvedValueOnce({
        data: [profileRow('player', 'ADMIN')],
        error: null,
      });
      await auth.whenReady();
      if (failure === 'throw') backend.getMyProfile.mockRejectedValueOnce(new Error('network'));
      else
        backend.getMyProfile.mockResolvedValueOnce({ data: null, error: { message: 'failure' } });
      await auth.refreshProfile();
      expect(auth.status()).toBe('error');
      expect(auth.isAdmin()).toBe(false);
      expect(auth.error()).not.toContain('failure');
    },
  );

  it('reacts to token renewal, account updates and role changes', async () => {
    const { auth, backend, emit } = setup(fakeSession());
    await auth.whenReady();
    backend.getMyProfile.mockResolvedValue({ data: [profileRow('player', 'ADMIN')], error: null });
    emit('TOKEN_REFRESHED', fakeSession());
    expect(auth.profile()).toBeNull();
    await auth.whenReady();
    expect(auth.isAdmin()).toBe(true);
    backend.getMyProfile.mockResolvedValue({ data: [], error: null });
    emit('USER_UPDATED', fakeSession());
    await auth.whenReady();
    expect(auth.status()).toBe('inactive');
  });

  it('logs in with email/password and loads the current profile', async () => {
    const { auth, backend } = setup();
    backend.getMyProfile.mockResolvedValue({ data: [profileRow()], error: null });
    expect(await auth.login('test@example.invalid', 'fake-password')).toBeNull();
    expect(backend.signInWithPassword).toHaveBeenCalledWith(
      'test@example.invalid',
      'fake-password',
    );
    expect(auth.isAuthenticated()).toBe(true);
  });

  it.each(['response', 'throw'])('handles login failure (%s)', async (failure) => {
    const { auth, backend } = setup();
    if (failure === 'throw') backend.signInWithPassword.mockRejectedValueOnce(new Error('network'));
    else
      backend.signInWithPassword.mockResolvedValueOnce({
        data: { session: null },
        error: authFailure(),
      });
    expect(await auth.login('test@example.invalid', 'fake-password')).not.toBeNull();
    expect(auth.isAuthenticated()).toBe(false);
    expect(auth.profile()).toBeNull();
  });

  it('clears all private state on logout', async () => {
    const { auth } = setup(fakeSession());
    await auth.whenReady();
    expect(await auth.logout()).toBeNull();
    expect(auth.status()).toBe('anonymous');
    expect(auth.user()).toBeNull();
    expect(auth.profile()).toBeNull();
  });

  it.each(['response', 'throw'])(
    'reports logout failure rather than pretending it succeeded (%s)',
    async (failure) => {
      const { auth, backend } = setup(fakeSession());
      await auth.whenReady();
      if (failure === 'throw') backend.signOut.mockRejectedValueOnce(new Error('network'));
      else backend.signOut.mockResolvedValueOnce({ error: authFailure() });
      expect(await auth.logout()).not.toBeNull();
      expect(auth.status()).toBe('error');
      expect(auth.session()).not.toBeNull();
      expect(auth.isAuthenticated()).toBe(false);
    },
  );

  it('does not restore a stale session after SIGNED_OUT during getSession', async () => {
    const { auth, backend, emit } = setup();
    const restoration = deferred<SessionResult>();
    backend.getSession.mockReturnValueOnce(restoration.promise);
    const ready = auth.whenReady();
    await Promise.resolve();
    emit('SIGNED_OUT', null);
    restoration.resolve({ data: { session: fakeSession() }, error: null });
    await ready;
    expect(auth.status()).toBe('anonymous');
    expect(backend.getMyProfile).not.toHaveBeenCalled();
  });

  it('ignores an old profile response after SIGNED_OUT', async () => {
    const { auth, backend, emit } = setup();
    await auth.whenReady();
    const oldProfile = deferred<ProfileResult>();
    backend.getMyProfile.mockReturnValueOnce(oldProfile.promise);
    emit('SIGNED_IN', fakeSession());
    await new Promise((r) => setTimeout(r, 1));
    emit('SIGNED_OUT', null);
    await auth.whenReady();
    oldProfile.resolve({ data: [profileRow('player', 'ADMIN')], error: null });
    await Promise.resolve();
    expect(auth.status()).toBe('anonymous');
    expect(auth.isAdmin()).toBe(false);
  });

  it('waits for the latest account change and ignores the old RPC', async () => {
    const { auth, backend, emit } = setup();
    await auth.whenReady();
    const oldProfile = deferred<ProfileResult>();
    backend.getMyProfile.mockReturnValueOnce(oldProfile.promise);
    emit('SIGNED_IN', fakeSession());
    await new Promise((r) => setTimeout(r, 1));
    backend.getMyProfile.mockResolvedValue({ data: [profileRow('new-player')], error: null });
    emit('SIGNED_IN', fakeSession('new-player'));
    await auth.whenReady();
    oldProfile.resolve({ data: [profileRow('player', 'ADMIN')], error: null });
    await Promise.resolve();
    expect(auth.profile()?.profileId).toBe('new-player');
    expect(auth.isAdmin()).toBe(false);
  });

  it('does not allow a late login response to undo logout', async () => {
    const { auth, backend } = setup();
    await auth.whenReady();
    const response = deferred<SessionResult>();
    backend.signInWithPassword.mockReturnValueOnce(response.promise);
    const login = auth.login('test@example.invalid', 'fake-password');
    await new Promise((r) => setTimeout(r, 0));
    await auth.logout();
    response.resolve({ data: { session: fakeSession() }, error: null });
    await login;
    expect(auth.status()).toBe('anonymous');
  });

  it('does not let a synchronous INITIAL_SESSION be overwritten by getSession', async () => {
    const { auth, backend } = setup();
    backend.getMyProfile.mockResolvedValue({ data: [profileRow()], error: null });
    backend.onAuthStateChange.mockImplementationOnce((callback) => {
      callback('INITIAL_SESSION', fakeSession());
      return { data: { subscription: { id: 'initial', callback, unsubscribe: () => {} } } };
    });
    await auth.whenReady();
    expect(auth.isAuthenticated()).toBe(true);
  });

  it('does not call the profile RPC inside the Auth callback', async () => {
    const { auth, backend, emit } = setup();
    await auth.whenReady();
    backend.getMyProfile.mockResolvedValue({ data: [profileRow()], error: null });
    emit('SIGNED_IN', fakeSession());
    expect(backend.getMyProfile).not.toHaveBeenCalled();
    await auth.whenReady();
    expect(backend.getMyProfile).toHaveBeenCalledTimes(1);
  });

  it('releases an already waiting guard when SIGNED_OUT supersedes an unresolved RPC', async () => {
    const { auth, backend, emit } = setup();
    await auth.whenReady();
    const oldProfile = deferred<ProfileResult>();
    backend.getMyProfile.mockReturnValueOnce(oldProfile.promise);
    emit('SIGNED_IN', fakeSession());
    await new Promise((r) => setTimeout(r, 1));
    const waiting = auth.whenReady();
    emit('SIGNED_OUT', null);
    const ready = await Promise.race([
      waiting.then(() => true),
      new Promise<boolean>((r) => setTimeout(() => r(false), 100)),
    ]);
    oldProfile.resolve({ data: [profileRow()], error: null });
    expect(ready).toBe(true);
    expect(auth.status()).toBe('anonymous');
  });

  it('waits for an in-progress login before deciding access', async () => {
    const { auth, backend } = setup();
    await auth.whenReady();
    const response = deferred<SessionResult>();
    backend.signInWithPassword.mockReturnValueOnce(response.promise);
    backend.getMyProfile.mockResolvedValue({ data: [profileRow()], error: null });
    const login = auth.login('test@example.invalid', 'fake-password');
    await new Promise((r) => setTimeout(r, 0));
    let settled = false;
    const waiting = auth.whenReady().then(() => {
      settled = true;
    });
    await Promise.resolve();
    expect(settled).toBe(false);
    response.resolve({ data: { session: fakeSession() }, error: null });
    await Promise.all([login, waiting]);
    expect(auth.isAuthenticated()).toBe(true);
  });

  it('handles a SIGNED_IN event emitted during password login', async () => {
    const { auth, backend, emit } = setup();
    backend.getMyProfile.mockResolvedValue({ data: [profileRow()], error: null });
    backend.signInWithPassword.mockImplementationOnce(async () => {
      emit('SIGNED_IN', fakeSession());
      return { data: { session: fakeSession() }, error: null };
    });
    await auth.login('test@example.invalid', 'fake-password');
    expect(auth.status()).toBe('active');
    expect(backend.getMyProfile).toHaveBeenCalledTimes(1);
  });

  it('a failed logout supersedes an unresolved profile request without hanging', async () => {
    const { auth, backend, emit } = setup();
    await auth.whenReady();
    const oldProfile = deferred<ProfileResult>();
    backend.getMyProfile.mockReturnValueOnce(oldProfile.promise);
    emit('SIGNED_IN', fakeSession());
    await new Promise((r) => setTimeout(r, 1));
    backend.signOut.mockResolvedValueOnce({ error: authFailure() });
    const logout = auth.logout();
    const finished = await Promise.race([
      logout.then(() => true),
      new Promise<boolean>((r) => setTimeout(() => r(false), 100)),
    ]);
    oldProfile.resolve({ data: [profileRow('player', 'ADMIN')], error: null });
    await logout;
    expect(finished).toBe(true);
    expect(auth.status()).toBe('error');
    expect(auth.isAdmin()).toBe(false);
  });

  it('unsubscribes and ignores pending work when the service is destroyed', async () => {
    const { auth, emit, unsubscribe } = setup();
    await auth.whenReady();
    TestBed.resetTestingModule();
    expect(unsubscribe).toHaveBeenCalledTimes(1);
    emit('SIGNED_IN', fakeSession());
    expect(auth.status()).toBe('anonymous');
  });
});

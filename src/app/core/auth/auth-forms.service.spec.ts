import { TestBed } from '@angular/core/testing';
import { AuthError } from '@supabase/supabase-js';
import {
  authFailure,
  deferred,
  fakeBackend,
  fakeSession,
  profileRow,
} from '../../../testing/auth-fakes';
import { AUTH_BACKEND } from './auth.backend';
import { AuthFormsService } from './auth-forms.service';
import { AuthService } from './auth.service';
import type { SessionResult } from './auth.types';

function setup(session: ReturnType<typeof fakeSession> | null = null) {
  const fake = fakeBackend(session);
  fake.backend.getMyProfile.mockResolvedValue({ data: [profileRow()], error: null });
  TestBed.configureTestingModule({
    providers: [{ provide: AUTH_BACKEND, useValue: fake.backend }],
  });
  return { ...fake, forms: TestBed.inject(AuthFormsService), auth: TestBed.inject(AuthService) };
}

describe('Auth forms service', () => {
  it('registers without assuming an unconfirmed account is authenticated', async () => {
    const { forms, auth, backend } = setup();
    await forms.signUp({
      email: 'test@example.invalid',
      password: 'password',
      username: 'Player',
      invitationCode: 'Code',
    });
    expect(auth.status()).toBe('anonymous');
    expect(backend.signUp.mock.calls[0][1]).toBe(
      new URL('/auth/callback', document.location.origin).href,
    );
  });

  it('uses the current origin for reset, never a supplied external redirect', async () => {
    const { forms, backend } = setup();
    await forms.requestReset('test@example.invalid');
    expect(backend.resetPasswordForEmail).toHaveBeenCalledWith(
      'test@example.invalid',
      new URL('/auth/callback', document.location.origin).href,
    );
  });

  it('translates rejected network promises into recoverable errors', async () => {
    const { forms, backend } = setup();
    backend.resetPasswordForEmail.mockRejectedValue(new Error('private details'));
    expect(await forms.requestReset('test@example.invalid')).toBeInstanceOf(AuthError);
  });

  it('does not accept an existing session as proof of an empty callback', async () => {
    const { forms, auth, backend } = setup(fakeSession());
    await auth.whenReady();
    expect(await forms.completeLink({ kind: 'invalid' })).toBe('invalid');
    expect(forms.canSetPassword()).toBe(false);
    expect(backend.exchangeCode).not.toHaveBeenCalled();
  });

  it('fails a rejected or sessionless link without granting password update', async () => {
    const { forms, backend } = setup(fakeSession());
    backend.exchangeCode.mockResolvedValue({ data: { session: null }, error: authFailure() });
    expect(await forms.completeLink({ kind: 'code', code: 'expired' })).toBe('invalid');
    expect(forms.canSetPassword()).toBe(false);
    expect(await forms.setPassword('new-password')).toBeInstanceOf(AuthError);
    expect(backend.updatePassword).not.toHaveBeenCalled();
  });

  it('a normal PKCE confirmation cannot grant password reset', async () => {
    const { forms } = setup();
    expect(await forms.completeLink({ kind: 'code', code: 'confirmation' })).toBe('confirmed');
    expect(forms.canSetPassword()).toBe(false);
  });

  it('grants password update only after a successful recovery exchange', async () => {
    const { forms, backend } = setup();
    backend.exchangeCode.mockResolvedValue({
      data: { session: fakeSession(), redirectType: 'recovery' },
      error: null,
    });
    expect(await forms.completeLink({ kind: 'code', code: 'recovery' })).toBe('password');
    expect(forms.canSetPassword()).toBe(true);
    expect(await forms.setPassword('new-password')).toBeNull();
    expect(backend.updatePassword).toHaveBeenCalledWith('new-password');
    expect(forms.canSetPassword()).toBe(false);
  });

  it('validates token hash on the server before granting recovery', async () => {
    const { forms, backend } = setup();
    expect(await forms.completeLink({ kind: 'token', tokenHash: 'hash', type: 'recovery' })).toBe(
      'password',
    );
    expect(backend.verifyEmailToken).toHaveBeenCalledWith('hash', 'recovery');
  });

  it('supports password creation from a verified Auth Admin invite', async () => {
    const { forms, backend } = setup();
    expect(
      await forms.completeLink({
        kind: 'implicit',
        accessToken: 'access',
        refreshToken: 'refresh',
        type: 'invite',
      }),
    ).toBe('password');
    expect(backend.setSession).toHaveBeenCalledWith('access', 'refresh');
  });

  it('allows retry on password error without exposing details or consuming the UI grant', async () => {
    const { forms, backend } = setup();
    await forms.completeLink({ kind: 'token', tokenHash: 'hash', type: 'recovery' });
    backend.updatePassword.mockResolvedValueOnce({ error: authFailure() });
    expect(await forms.setPassword('new-password')).toBeInstanceOf(AuthError);
    expect(forms.canSetPassword()).toBe(true);
    expect(await forms.setPassword('new-password')).toBeNull();
  });

  it('revokes password form access after logout or account change', async () => {
    const { forms, auth, emit } = setup();
    await forms.completeLink({ kind: 'token', tokenHash: 'hash', type: 'recovery' });
    emit('SIGNED_OUT', null);
    await auth.whenReady();
    expect(forms.canSetPassword()).toBe(false);
    const other = { ...fakeSession('other'), access_token: 'other-access' };
    emit('SIGNED_IN', other);
    await auth.whenReady();
    expect(forms.canSetPassword()).toBe(false);
  });

  it('does not publish a stale callback after logout', async () => {
    const { forms, backend, auth } = setup();
    const response = deferred<SessionResult>();
    backend.verifyEmailToken.mockReturnValueOnce(response.promise);
    const callback = forms.completeLink({ kind: 'token', tokenHash: 'hash', type: 'recovery' });
    await new Promise((r) => setTimeout(r, 0));
    await auth.logout();
    response.resolve({ data: { session: fakeSession() }, error: null });
    expect(await callback).toBe('invalid');
    expect(auth.status()).toBe('anonymous');
    expect(forms.canSetPassword()).toBe(false);
  });
});

import { TestBed } from '@angular/core/testing';
import { AuthApiError } from '@supabase/supabase-js';
import { provideRouter, Router } from '@angular/router';
import { RouterTestingHarness } from '@angular/router/testing';
import { vi } from 'vitest';
import {
  authFailure,
  deferred,
  fakeBackend,
  fakeSession,
  profileRow,
} from '../../../testing/auth-fakes';
import { routes } from '../../app.routes';
import { AUTH_BACKEND } from '../../core/auth/auth.backend';
import type { SessionResult } from '../../core/auth/auth.types';
import { AuthFormPage } from './auth-form-page';
import { AuthCallbackPage } from './auth-callback-page';

async function setup() {
  const fake = fakeBackend();
  fake.backend.getMyProfile.mockResolvedValue({ data: [profileRow()], error: null });
  TestBed.configureTestingModule({
    providers: [provideRouter(routes), { provide: AUTH_BACKEND, useValue: fake.backend }],
  });
  const harness = await RouterTestingHarness.create();
  return { ...fake, harness, router: TestBed.inject(Router) };
}

function fill(page: AuthFormPage) {
  page.form.setValue({
    email: 'test@example.invalid',
    password: 'password123',
    confirmPassword: 'password123',
    username: 'Player',
    invitationCode: 'Code',
  });
}

async function callback(harness: RouterTestingHarness, url: string) {
  const page = await harness.navigateByUrl(url, AuthCallbackPage);
  await vi.waitFor(() => expect(page.state()).not.toBe('loading'));
  harness.detectChanges();
  return page;
}

describe('Auth forms UI', () => {
  it.each(['/auth/login', '/auth/register', '/auth/forgot-password'])(
    'renders labelled responsive forms at %s',
    async (url) => {
      const { harness } = await setup();
      await harness.navigateByUrl(url, AuthFormPage);
      expect(harness.routeNativeElement?.querySelector('label[for="email"]')).toBeTruthy();
      expect(harness.routeNativeElement?.querySelector('form[novalidate]')).toBeTruthy();
      expect(harness.routeNativeElement?.querySelector('button[type="submit"]')).toBeTruthy();
    },
  );

  it('does not submit invalid email or required fields', async () => {
    const { harness, backend } = await setup();
    const page = await harness.navigateByUrl('/auth/register', AuthFormPage);
    page.form.controls.email.setValue('invalid');
    await page.submit();
    expect(page.form.controls.email.touched).toBe(true);
    expect(page.error()).toContain('Revisa');
    expect(backend.signUp).not.toHaveBeenCalled();
  });

  it.each(['short', '        '])('rejects short password or blank username (%j)', async (value) => {
    const { harness, backend } = await setup();
    const page = await harness.navigateByUrl('/auth/register', AuthFormPage);
    fill(page);
    if (value === 'short') page.form.controls.password.setValue(value);
    else page.form.controls.username.setValue(value);
    await page.submit();
    expect(backend.signUp).not.toHaveBeenCalled();
  });

  it('rejects password mismatch without losing entered fields', async () => {
    const { harness, backend } = await setup();
    const page = await harness.navigateByUrl('/auth/register', AuthFormPage);
    fill(page);
    page.form.controls.confirmPassword.setValue('other-password');
    await page.submit();
    expect(page.error()).toContain('no coinciden');
    expect(page.form.controls.invitationCode.value).toBe('Code');
    expect(backend.signUp).not.toHaveBeenCalled();
  });

  it('prevents duplicate signup and shows neutral confirmation without inventing session', async () => {
    const { harness, backend, router } = await setup();
    const pending = deferred<SessionResult>();
    backend.signUp.mockReturnValueOnce(pending.promise);
    const page = await harness.navigateByUrl('/auth/register', AuthFormPage);
    fill(page);
    const first = page.submit();
    await page.submit();
    expect(page.busy()).toBe(true);
    pending.resolve({ data: { session: null }, error: null });
    await first;
    expect(backend.signUp).toHaveBeenCalledTimes(1);
    expect(page.success()).toContain('confirmar');
    expect(page.form.controls.password.value).toBe('');
    expect(router.url).toBe('/auth/register');
    await page.submit();
    expect(backend.signUp).toHaveBeenCalledTimes(1);
  });

  it('shows safe trigger rejection and permits retry', async () => {
    const { harness, backend } = await setup();
    backend.signUp.mockResolvedValueOnce({
      data: { session: null },
      error: new AuthApiError('SQL private trigger details', 500, 'unexpected_failure'),
    });
    const page = await harness.navigateByUrl('/auth/register', AuthFormPage);
    fill(page);
    await page.submit();
    expect(page.error()).toContain('invitación');
    expect(page.error()).not.toContain('SQL');
    expect(page.form.controls.username.value).toBe('Player');
    expect(page.busy()).toBe(false);
    await page.submit();
    expect(page.success()).toBeTruthy();
  });

  it('uses the guarded admin destination after login', async () => {
    const { harness, backend, router } = await setup();
    backend.getMyProfile.mockResolvedValue({ data: [profileRow('player', 'ADMIN')], error: null });
    const page = await harness.navigateByUrl('/auth/login?returnUrl=%2Fadmin', AuthFormPage);
    fill(page);
    await page.submit();
    expect(router.url).toBe('/admin');
  });

  it('rejects external return URLs and sends PLAYER to member home', async () => {
    const { harness, router } = await setup();
    const page = await harness.navigateByUrl(
      '/auth/login?returnUrl=https%3A%2F%2Fevil.invalid',
      AuthFormPage,
    );
    fill(page);
    await page.submit();
    expect(router.url).toBe('/app');
  });

  it('does not turn an inactive login into private access', async () => {
    const { harness, router, backend } = await setup();
    backend.getMyProfile.mockResolvedValue({ data: [], error: null });
    const page = await harness.navigateByUrl('/auth/login', AuthFormPage);
    fill(page);
    await page.submit();
    expect(router.url).toContain('/auth/access');
  });

  it('translates unconfirmed email without navigating', async () => {
    const { harness, backend, router } = await setup();
    backend.signInWithPassword.mockResolvedValue({
      data: { session: null },
      error: new AuthApiError('private', 400, 'email_not_confirmed'),
    });
    const page = await harness.navigateByUrl('/auth/login', AuthFormPage);
    fill(page);
    await page.submit();
    expect(page.error()).toContain('Confirma tu correo');
    expect(router.url).toBe('/auth/login');
  });

  it('reset uses neutral account-existence messaging and prevents double request', async () => {
    const { harness, backend } = await setup();
    const page = await harness.navigateByUrl('/auth/forgot-password', AuthFormPage);
    page.form.controls.email.setValue('test@example.invalid');
    const first = page.submit();
    await page.submit();
    await first;
    expect(backend.resetPasswordForEmail).toHaveBeenCalledTimes(1);
    expect(page.success()).toContain('Si existe una cuenta');
  });

  it('reports reset rate limit and preserves the email for retry', async () => {
    const { harness, backend } = await setup();
    backend.resetPasswordForEmail.mockResolvedValue({
      error: new AuthApiError('private', 429, 'over_email_send_rate_limit'),
    });
    const page = await harness.navigateByUrl('/auth/forgot-password', AuthFormPage);
    page.form.controls.email.setValue('test@example.invalid');
    await page.submit();
    expect(page.error()).toContain('Espera unos minutos');
    expect(page.form.controls.email.value).toBe('test@example.invalid');
  });
});

describe('Auth callback UI', () => {
  it('rejects empty callback even with an existing session and scrubs URL credentials', async () => {
    const { harness, backend } = await setup();
    backend.getSession.mockResolvedValue({ data: { session: fakeSession() }, error: null });
    const page = await callback(
      harness,
      '/auth/callback?error=access_denied&error_description=secret',
    );
    expect(page.state()).toBe('invalid');
    expect(document.location.search).toBe('');
    expect(document.location.hash).toBe('');
    expect(harness.routeNativeElement?.textContent).not.toContain('secret');
    expect(backend.exchangeCode).not.toHaveBeenCalled();
  });

  it('renders an expired link without a password form', async () => {
    const { harness, backend } = await setup();
    backend.verifyEmailToken.mockResolvedValue({ data: { session: null }, error: authFailure() });
    const page = await callback(harness, '/auth/callback?token_hash=expired&type=recovery');
    expect(page.state()).toBe('invalid');
    expect(harness.routeNativeElement?.querySelector('form')).toBeNull();
  });

  it('normal confirmation does not become recovery through query tampering', async () => {
    const { harness, backend } = await setup();
    const page = await callback(harness, '/auth/callback?code=confirmation&type=recovery');
    expect(page.state()).toBe('confirmed');
    expect(backend.exchangeCode).toHaveBeenCalledTimes(1);
    expect(harness.routeNativeElement?.querySelector('form')).toBeNull();
  });

  it('validates, saves once and then closes recovery session', async () => {
    const { harness, backend, router } = await setup();
    const page = await callback(harness, '/auth/callback?token_hash=hash&type=recovery');
    expect(page.state()).toBe('password');
    page.form.setValue({ password: 'short', confirmPassword: 'short' });
    await page.submit();
    expect(backend.updatePassword).not.toHaveBeenCalled();
    page.form.setValue({ password: 'new-password', confirmPassword: 'different-password' });
    await page.submit();
    expect(backend.updatePassword).not.toHaveBeenCalled();
    page.form.setValue({ password: 'new-password', confirmPassword: 'new-password' });
    const first = page.submit();
    await page.submit();
    await first;
    expect(backend.updatePassword).toHaveBeenCalledTimes(1);
    expect(page.state()).toBe('saved');
    await page.submit();
    expect(backend.updatePassword).toHaveBeenCalledTimes(1);
    await page.finish();
    expect(router.url).toBe('/auth/login');
  });

  it('reports password errors without consuming recovery form', async () => {
    const { harness, backend } = await setup();
    backend.updatePassword.mockResolvedValueOnce({
      error: new AuthApiError('private', 422, 'weak_password'),
    });
    const page = await callback(harness, '/auth/callback?token_hash=hash&type=recovery');
    page.form.setValue({ password: 'new-password', confirmPassword: 'new-password' });
    await page.submit();
    expect(page.state()).toBe('password');
    expect(page.error()).toContain('requisitos de seguridad');
    expect(page.form.controls.password.value).toBe('new-password');
  });
});

import { TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { RouterTestingHarness } from '@angular/router/testing';
import {
  authFailure,
  deferred,
  fakeBackend,
  fakeSession,
  profileRow,
} from '../../../testing/auth-fakes';
import { routes } from '../../app.routes';
import { AUTH_BACKEND } from './auth.backend';
import { safeReturnUrl } from './auth.guards';
import { AuthService } from './auth.service';
import type { SessionResult } from './auth.types';

async function setup(session = null as ReturnType<typeof fakeSession> | null, admin = false) {
  const fake = fakeBackend(session);
  if (session)
    fake.backend.getMyProfile.mockResolvedValue({
      data: [profileRow(session.user.id, admin ? 'ADMIN' : 'PLAYER')],
      error: null,
    });
  TestBed.configureTestingModule({
    providers: [provideRouter(routes), { provide: AUTH_BACKEND, useValue: fake.backend }],
  });
  const harness = await RouterTestingHarness.create();
  return { ...fake, harness, router: TestBed.inject(Router), auth: TestBed.inject(AuthService) };
}

describe('Auth routes and guards', () => {
  it('redirects anonymous users to login preserving the protected destination', async () => {
    const { harness, router } = await setup();
    await harness.navigateByUrl('/admin');
    expect(router.url).toContain('/auth/login');
    expect(router.parseUrl(router.url).queryParams['returnUrl']).toBe('/admin');
  });

  it('allows anonymous users to visit the login placeholder', async () => {
    const { harness, router } = await setup();
    await harness.navigateByUrl('/auth/login');
    expect(router.url).toBe('/auth/login');
    expect(harness.routeNativeElement?.textContent).toContain('F1.10');
  });

  it('restores a PLAYER on a direct private URL', async () => {
    const { harness, router } = await setup(fakeSession());
    await harness.navigateByUrl('/app');
    expect(router.url).toBe('/app');
    expect(harness.routeNativeElement?.textContent).toContain('Inicio privado');
  });

  it('redirects PLAYER away from admin', async () => {
    const { harness, router } = await setup(fakeSession());
    await harness.navigateByUrl('/admin');
    expect(router.url).toBe('/app');
  });

  it('allows an active ADMIN into admin and member routes', async () => {
    const { harness, router } = await setup(fakeSession(), true);
    await harness.navigateByUrl('/admin');
    expect(router.url).toBe('/admin');
    await harness.navigateByUrl('/app');
    expect(router.url).toBe('/app');
  });

  it('does not leave a signed-in active user at login', async () => {
    const { harness, router } = await setup(fakeSession(), true);
    await harness.navigateByUrl('/auth/login?returnUrl=%2Fadmin');
    expect(router.url).toBe('/admin');
  });

  it('redirects a blocked profile to an explicit access page rather than a login loop', async () => {
    const { harness, router, backend } = await setup(fakeSession());
    backend.getMyProfile.mockResolvedValue({ data: [], error: null });
    await harness.navigateByUrl('/app');
    expect(router.url).toContain('/auth/access');
    expect(harness.routeNativeElement?.textContent).toContain('No hay un perfil activo');
    await harness.navigateByUrl('/auth/login');
    expect(router.url).toContain('/auth/access');
  });

  it('fails closed when the profile RPC fails', async () => {
    const { harness, router, backend } = await setup(fakeSession(), true);
    backend.getMyProfile.mockResolvedValue({ data: null, error: { message: 'failure' } });
    await harness.navigateByUrl('/admin');
    expect(router.url).toContain('/auth/access');
    expect(harness.routeNativeElement?.textContent).toContain('No se ha podido verificar');
  });

  it('shows restoration failure rather than treating it as anonymous', async () => {
    const { harness, router, backend } = await setup();
    backend.getSession.mockResolvedValue({ data: { session: null }, error: authFailure() });
    await harness.navigateByUrl('/app');
    expect(router.url).toContain('/auth/access');
  });

  it('waits for initial restoration before deciding a protected route', async () => {
    const { harness, router, backend } = await setup();
    const restoration = deferred<SessionResult>();
    backend.getSession.mockReturnValueOnce(restoration.promise);
    backend.getMyProfile.mockResolvedValue({ data: [profileRow()], error: null });
    const navigation = harness.navigateByUrl('/app');
    await new Promise((r) => setTimeout(r, 0));
    expect(router.url).not.toContain('/auth/login');
    restoration.resolve({ data: { session: fakeSession() }, error: null });
    await navigation;
    expect(router.url).toBe('/app');
  });

  it('rechecks revoked activity at the next navigation', async () => {
    const { harness, router, backend } = await setup(fakeSession(), true);
    await harness.navigateByUrl('/app');
    backend.getMyProfile.mockResolvedValue({ data: [], error: null });
    await harness.navigateByUrl('/admin');
    expect(router.url).toContain('/auth/access');
  });

  it('rechecks current role without trusting a previously cached ADMIN', async () => {
    const { harness, router, backend } = await setup(fakeSession(), true);
    await harness.navigateByUrl('/app');
    backend.getMyProfile.mockResolvedValue({ data: [profileRow()], error: null });
    await harness.navigateByUrl('/admin');
    expect(router.url).toBe('/app');
  });

  it('handles root and unknown URLs through protected entry', async () => {
    const { harness, router } = await setup();
    await harness.navigateByUrl('/');
    expect(router.url).toContain('/auth/login');
    await harness.navigateByUrl('/unknown');
    expect(router.url).toContain('/auth/login');
  });

  it('keeps callback routes public for future confirmation/recovery handling', async () => {
    const { harness, router } = await setup();
    await harness.navigateByUrl('/auth/callback');
    expect(router.url).toBe('/auth/callback');
  });

  it('retries the profile from the access screen without reactivating it locally', async () => {
    const { harness, router, backend } = await setup(fakeSession());
    backend.getMyProfile.mockResolvedValue({ data: [], error: null });
    await harness.navigateByUrl('/app');
    backend.getMyProfile.mockResolvedValue({ data: [profileRow()], error: null });
    (harness.routeNativeElement?.querySelector('button') as HTMLButtonElement).click();
    await harness.fixture.whenStable();
    expect(router.url).toBe('/app');
  });

  it('can logout a blocked profile from the access screen', async () => {
    const { harness, router, auth, backend } = await setup(fakeSession());
    backend.getMyProfile.mockResolvedValue({ data: [], error: null });
    await harness.navigateByUrl('/app');
    (harness.routeNativeElement?.querySelectorAll('button')[1] as HTMLButtonElement).click();
    await harness.fixture.whenStable();
    expect(router.url).toBe('/auth/login');
    expect(auth.status()).toBe('anonymous');
  });
});

describe('safeReturnUrl', () => {
  it.each([
    'https://evil.invalid',
    '//evil.invalid',
    '/\\evil',
    '/auth/login',
    '',
    '/application',
    '/administer',
    '/app\n',
    'javascript:alert(1)',
  ])('rejects unsafe or looping returnUrl %j', (url) => {
    expect(safeReturnUrl(url)).toBe('/app');
  });
  it.each(['/app', '/app/history?season=1', '/admin', '/admin/users#detail'])(
    'preserves internal destination %j',
    (url) => {
      expect(safeReturnUrl(url)).toBe(url);
    },
  );
});

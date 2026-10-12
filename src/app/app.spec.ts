import { TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { fakeBackend, fakeSession, profileRow } from '../testing/auth-fakes';
import { App } from './app';
import { routes } from './app.routes';
import { AUTH_BACKEND } from './core/auth/auth.backend';
import { AuthService } from './core/auth/auth.service';

async function setup(admin = false) {
  const fake = fakeBackend(fakeSession());
  fake.backend.getMyProfile.mockResolvedValue({
    data: [profileRow('player', admin ? 'ADMIN' : 'PLAYER')],
    error: null,
  });
  await TestBed.configureTestingModule({
    imports: [App],
    providers: [provideRouter(routes), { provide: AUTH_BACKEND, useValue: fake.backend }],
  }).compileComponents();
  const fixture = TestBed.createComponent(App);
  const auth = TestBed.inject(AuthService);
  const router = TestBed.inject(Router);
  return { ...fake, fixture, auth, router };
}

describe('App', () => {
  it('creates the app and shows initial loading', async () => {
    const { fixture } = await setup();
    fixture.detectChanges();
    expect(fixture.componentInstance).toBeTruthy();
    expect(
      (fixture.nativeElement as HTMLElement).querySelector('[role="status"]')?.textContent,
    ).toContain('Comprobando sesión');
  });

  it('renders the private title and PLAYER navigation without admin links', async () => {
    const { fixture, auth, router } = await setup();
    await auth.whenReady();
    await router.navigateByUrl('/app');
    await fixture.whenStable();
    fixture.detectChanges();
    const html = fixture.nativeElement as HTMLElement;
    expect(html.querySelector('h1')?.textContent).toContain('Quini');
    expect(html.textContent).not.toContain('Administración');
    expect(html.textContent).toContain('Jugador');
  });

  it('lets an ADMIN see the admin navigation and still play', async () => {
    const { fixture, auth, router } = await setup(true);
    await auth.whenReady();
    await router.navigateByUrl('/admin');
    await fixture.whenStable();
    fixture.detectChanges();
    expect((fixture.nativeElement as HTMLElement).textContent).toContain('Administración');
    await router.navigateByUrl('/app');
    fixture.detectChanges();
    expect((fixture.nativeElement as HTMLElement).querySelector('h1')?.textContent).toBe('Quini');
  });

  it('reacts to remote SIGNED_OUT on a private route and hides identity', async () => {
    const { fixture, auth, router, emit } = await setup();
    await auth.whenReady();
    await router.navigateByUrl('/app');
    emit('SIGNED_OUT', null);
    await auth.whenReady();
    await fixture.whenStable();
    fixture.detectChanges();
    expect(router.url).toContain('/auth/login');
    expect((fixture.nativeElement as HTMLElement).textContent).not.toContain('Jugador');
  });

  it('redirects a revoked admin already on the admin page', async () => {
    const { fixture, auth, router, emit, backend } = await setup(true);
    await auth.whenReady();
    await router.navigateByUrl('/admin');
    backend.getMyProfile.mockResolvedValue({ data: [profileRow()], error: null });
    emit('USER_UPDATED', fakeSession());
    await auth.whenReady();
    await fixture.whenStable();
    expect(router.url).toBe('/app');
    fixture.detectChanges();
    expect((fixture.nativeElement as HTMLElement).textContent).not.toContain('Administración');
  });

  it('logs out from the header', async () => {
    const { fixture, auth, router } = await setup();
    await auth.whenReady();
    await router.navigateByUrl('/app');
    await fixture.whenStable();
    fixture.detectChanges();
    (fixture.nativeElement as HTMLElement).querySelector('button')?.click();
    await fixture.whenStable();
    expect(auth.status()).toBe('anonymous');
    expect(router.url).toContain('/auth/login');
  });
});

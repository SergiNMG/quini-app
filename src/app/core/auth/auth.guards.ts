import { inject } from '@angular/core';
import { type CanActivateFn, type CanActivateChildFn, Router, type UrlTree } from '@angular/router';
import { AuthService } from './auth.service';

/** Solo destinos internos del juego. No aceptar URLs externas ni rutas Auth en bucle. */
export function safeReturnUrl(value: string | null | undefined): string {
  if (!value || value.includes('\\') || /[\u0000-\u001f]/.test(value)) return '/app';
  return /^\/(app|admin)(?:[/?#]|$)/.test(value) ? value : '/app';
}

export function deniedUrl(auth: AuthService, router: Router, returnUrl: string): UrlTree {
  return router.createUrlTree([auth.status() === 'anonymous' ? '/auth/login' : '/auth/access'], {
    queryParams: { returnUrl: safeReturnUrl(returnUrl) },
  });
}

async function authorize(admin: boolean, url: string): Promise<boolean | UrlTree> {
  const auth = inject(AuthService);
  const router = inject(Router);
  await auth.refreshProfile();
  if (!auth.isAuthenticated()) return deniedUrl(auth, router, url);
  return !admin || auth.isAdmin() ? true : router.createUrlTree(['/app']);
}

export const memberGuard: CanActivateFn = (_route, state) => authorize(false, state.url);
export const memberChildGuard: CanActivateChildFn = (_route, state) => authorize(false, state.url);
export const adminGuard: CanActivateFn = (_route, state) => authorize(true, state.url);
export const adminChildGuard: CanActivateChildFn = (_route, state) => authorize(true, state.url);

export const guestGuard: CanActivateFn = async (route) => {
  const auth = inject(AuthService);
  const router = inject(Router);
  await auth.refreshProfile();
  if (auth.isAuthenticated()) {
    return router.parseUrl(safeReturnUrl(route.queryParamMap.get('returnUrl')));
  }
  if (auth.status() !== 'anonymous') {
    return deniedUrl(auth, router, route.queryParamMap.get('returnUrl') ?? '/app');
  }
  return true;
};

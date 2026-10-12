import { Component, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { safeReturnUrl } from '../../core/auth/auth.guards';
import { AuthService } from '../../core/auth/auth.service';

@Component({
  selector: 'app-access-page',
  template: `
    <section class="rounded-xl border border-slate-800 bg-slate-900/60 p-6">
      <h1 class="text-3xl font-bold">Acceso no disponible</h1>
      @if (auth.status() === 'inactive') {
        <p class="mt-4 text-slate-300">
          No hay un perfil activo para esta cuenta. Contacta con el administrador.
        </p>
      } @else {
        <p class="mt-4 text-slate-300" role="alert">
          {{ auth.error() ?? 'No se ha podido verificar el acceso.' }}
        </p>
      }
      <button
        type="button"
        (click)="retry()"
        [disabled]="busy()"
        class="mt-6 rounded bg-emerald-700 px-4 py-2 disabled:opacity-50"
      >
        Volver a comprobar
      </button>
      <button
        type="button"
        (click)="logout()"
        [disabled]="busy()"
        class="ml-3 mt-6 rounded border border-slate-600 px-4 py-2 disabled:opacity-50"
      >
        Cerrar sesión
      </button>
    </section>
  `,
})
export class AccessPage {
  readonly auth = inject(AuthService);
  readonly busy = signal(false);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);

  async retry(): Promise<void> {
    this.busy.set(true);
    try {
      await this.auth.refreshProfile();
      if (this.auth.isAuthenticated()) {
        await this.router.navigateByUrl(
          safeReturnUrl(this.route.snapshot.queryParamMap.get('returnUrl')),
        );
      } else if (this.auth.status() === 'anonymous') {
        await this.router.navigate(['/auth/login'], {
          queryParams: { returnUrl: this.route.snapshot.queryParamMap.get('returnUrl') },
        });
      }
    } finally {
      this.busy.set(false);
    }
  }

  async logout(): Promise<void> {
    this.busy.set(true);
    try {
      if (!(await this.auth.logout())) await this.router.navigateByUrl('/auth/login');
    } finally {
      this.busy.set(false);
    }
  }
}

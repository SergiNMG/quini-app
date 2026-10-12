import { Component, computed, effect, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NavigationEnd, Router, RouterLink, RouterOutlet } from '@angular/router';
import { filter, map } from 'rxjs';
import { deniedUrl } from './core/auth/auth.guards';
import { AuthService } from './core/auth/auth.service';

@Component({
  selector: 'app-root',
  imports: [RouterLink, RouterOutlet],
  templateUrl: './app.html',
  styleUrl: './app.css',
})
export class App {
  protected readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  protected readonly signingOut = signal(false);
  private readonly url = toSignal(
    this.router.events.pipe(
      filter((e) => e instanceof NavigationEnd),
      map((e) => e.urlAfterRedirects),
    ),
    { initialValue: this.router.url },
  );
  private readonly protectedRoute = computed(() => /^\/(app|admin)(?:[/?#]|$)/.test(this.url()));
  protected readonly hideContent = computed(
    () =>
      this.auth.status() === 'loading' || (this.protectedRoute() && !this.auth.isAuthenticated()),
  );

  constructor() {
    // No bloquear bootstrap: la plantilla puede mostrar la carga inicial.
    void this.auth.initialize();
    effect(() => {
      const status = this.auth.status();
      const url = this.url();
      if (status === 'loading' || !this.protectedRoute()) return;
      // También reaccionar a cierre en otra pestaña / renovación / cambio de perfil
      // cuando no hay una nueva navegación que ejecute los guards.
      if (!this.auth.isAuthenticated()) {
        void this.router.navigateByUrl(deniedUrl(this.auth, this.router, url));
      } else if (/^\/admin(?:[/?#]|$)/.test(url) && !this.auth.isAdmin()) {
        void this.router.navigateByUrl('/app');
      }
    });
  }

  protected async logout(): Promise<void> {
    this.signingOut.set(true);
    try {
      if (!(await this.auth.logout())) await this.router.navigateByUrl('/auth/login');
    } finally {
      this.signingOut.set(false);
    }
  }
}

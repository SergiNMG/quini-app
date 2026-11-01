import { DOCUMENT } from '@angular/common';
import { Component, inject, OnInit, signal } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { AuthFormsService } from '../../core/auth/auth-forms.service';
import { AuthService } from '../../core/auth/auth.service';
import { authErrorMessage } from '../../core/auth/auth-errors';
import { parseAuthLink } from '../../core/auth/auth-link';
import { deniedUrl, safeReturnUrl } from '../../core/auth/auth.guards';

@Component({
  selector: 'app-auth-callback-page',
  imports: [ReactiveFormsModule, RouterLink],
  styleUrl: './auth-form-page.css',
  template: `
    <section class="auth-card" aria-labelledby="callback-title">
      <h1 id="callback-title" class="text-3xl font-bold">Confirmación de acceso</h1>
      @if (state() === 'loading') {
        <p role="status" class="mt-4">Comprobando enlace…</p>
      }
      @if (state() === 'invalid') {
        <p role="alert" class="mt-4 text-rose-300">
          El enlace no es válido, ha caducado o ya se ha utilizado. Solicita uno nuevo. Los enlaces
          PKCE deben abrirse en el navegador donde los solicitaste.
        </p>
        <p class="mt-4 text-slate-300">
          Si era una confirmación de registro, contacta con el administrador antes de usar otra
          invitación.
        </p>
      }
      @if (state() === 'confirmed') {
        <p role="status" class="mt-4">Correo confirmado. Ya puedes continuar.</p>
        <button type="button" class="mt-4" (click)="continue()">Continuar</button>
      }
      @if (error()) {
        <p role="alert" class="mt-4 text-rose-300">{{ error() }}</p>
      }
      @if (state() === 'password') {
        @if (forms.canSetPassword()) {
          <h2 class="mt-4 text-xl">Elegir nueva contraseña</h2>
          <form
            [formGroup]="form"
            (ngSubmit)="submit()"
            [attr.aria-busy]="busy()"
            novalidate
            class="mt-6 space-y-4"
          >
            <fieldset [disabled]="busy()" class="space-y-4">
              <legend class="sr-only">Nueva contraseña</legend>
              <div>
                <label for="new-password">Nueva contraseña (mínimo 8 caracteres)</label>
                <input
                  id="new-password"
                  type="password"
                  autocomplete="new-password"
                  formControlName="password"
                  required
                  [attr.aria-invalid]="
                    form.controls.password.touched && form.controls.password.invalid
                  "
                />
              </div>
              <div>
                <label for="new-confirm">Repetir nueva contraseña</label>
                <input
                  id="new-confirm"
                  type="password"
                  autocomplete="new-password"
                  formControlName="confirmPassword"
                  required
                />
              </div>
              <button type="submit" [disabled]="busy()">
                {{ busy() ? 'Guardando…' : 'Guardar contraseña' }}
              </button>
            </fieldset>
          </form>
        } @else {
          <p role="alert" class="mt-4">
            La sesión del enlace ha cambiado. Solicita otro enlace de recuperación.
          </p>
        }
      }
      @if (state() === 'saved') {
        <p role="status" class="mt-4 text-emerald-300">
          Contraseña actualizada. Inicia sesión con la nueva contraseña.
        </p>
        <button type="button" class="mt-4" [disabled]="busy()" (click)="finish()">
          Cerrar sesión y continuar
        </button>
      }
      <nav aria-label="Opciones de acceso" class="mt-6 flex flex-wrap gap-4">
        <a routerLink="/auth/forgot-password">Solicitar otro enlace</a>
        <a routerLink="/auth/login">Volver al acceso</a>
      </nav>
    </section>
  `,
})
export class AuthCallbackPage implements OnInit {
  readonly forms = inject(AuthFormsService);
  private readonly auth = inject(AuthService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly document = inject(DOCUMENT);
  readonly state = signal<'loading' | 'invalid' | 'confirmed' | 'password' | 'saved'>('loading');
  readonly busy = signal(false);
  readonly error = signal<string | null>(null);
  readonly form = new FormGroup({
    password: new FormControl('', {
      nonNullable: true,
      validators: [Validators.required, Validators.minLength(8)],
    }),
    confirmPassword: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
  });
  private readonly returnUrl = safeReturnUrl(this.route.snapshot.queryParamMap.get('returnUrl'));

  async ngOnInit(): Promise<void> {
    // Leer desde la ruta también permite navegación Angular y pruebas sin URL global.
    const query = new URLSearchParams(this.route.snapshot.queryParams).toString();
    const link = parseAuthLink(query, this.route.snapshot.fragment ?? '');
    // Quitar credenciales incluso en errores. No registrar códigos/tokens ni llevarlos a otras rutas.
    this.document.defaultView?.history.replaceState(
      this.document.defaultView.history.state,
      '',
      '/auth/callback',
    );
    try {
      this.state.set(await this.forms.completeLink(link));
    } catch {
      this.state.set('invalid');
    }
  }

  async submit(): Promise<void> {
    if (this.busy() || this.state() !== 'password') return;
    this.error.set(null);
    this.form.markAllAsTouched();
    const { password, confirmPassword } = this.form.getRawValue();
    if (this.form.invalid || password !== confirmPassword) {
      this.error.set('Usa al menos 8 caracteres y repite la misma contraseña.');
      return;
    }
    this.busy.set(true);
    try {
      const error = await this.forms.setPassword(password);
      if (error) this.error.set(authErrorMessage(error, 'password'));
      else {
        this.form.reset();
        this.state.set('saved');
      }
    } finally {
      this.busy.set(false);
    }
  }

  async finish(): Promise<void> {
    if (this.busy()) return;
    this.busy.set(true);
    try {
      if (await this.auth.logout())
        this.error.set('La contraseña se guardó, pero no se ha podido cerrar sesión. Reinténtalo.');
      else await this.router.navigateByUrl('/auth/login');
    } finally {
      this.busy.set(false);
    }
  }

  continue() {
    return this.router.navigateByUrl(
      this.auth.isAuthenticated()
        ? this.returnUrl
        : deniedUrl(this.auth, this.router, this.returnUrl),
    );
  }
}

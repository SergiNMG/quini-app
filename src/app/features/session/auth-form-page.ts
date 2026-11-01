import { Component, inject, signal } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { AuthService } from '../../core/auth/auth.service';
import { AuthFormsService } from '../../core/auth/auth-forms.service';
import { authErrorMessage } from '../../core/auth/auth-errors';
import { deniedUrl, safeReturnUrl } from '../../core/auth/auth.guards';

@Component({
  selector: 'app-auth-form-page',
  imports: [ReactiveFormsModule, RouterLink],
  templateUrl: './auth-form-page.html',
  styleUrl: './auth-form-page.css',
})
export class AuthFormPage {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly auth = inject(AuthService);
  private readonly forms = inject(AuthFormsService);
  readonly mode = this.route.snapshot.data['mode'] as 'login' | 'signup' | 'reset';
  readonly title = {
    login: 'Acceso a Quini',
    signup: 'Registro con invitación',
    reset: 'Recuperar contraseña',
  }[this.mode];
  readonly returnUrl = safeReturnUrl(this.route.snapshot.queryParamMap.get('returnUrl'));
  readonly busy = signal(false);
  readonly error = signal<string | null>(null);
  readonly success = signal<string | null>(null);
  readonly form = new FormGroup({
    email: new FormControl('', {
      nonNullable: true,
      validators: [Validators.required, Validators.email],
    }),
    password: new FormControl('', {
      nonNullable: true,
      validators:
        this.mode === 'reset'
          ? []
          : [Validators.required, ...(this.mode === 'signup' ? [Validators.minLength(8)] : [])],
    }),
    confirmPassword: new FormControl('', {
      nonNullable: true,
      validators: this.mode === 'signup' ? [Validators.required] : [],
    }),
    username: new FormControl('', {
      nonNullable: true,
      validators: this.mode === 'signup' ? [Validators.required, Validators.pattern(/\S/)] : [],
    }),
    invitationCode: new FormControl('', {
      nonNullable: true,
      validators: this.mode === 'signup' ? [Validators.required, Validators.pattern(/\S/)] : [],
    }),
  });

  invalid(name: keyof typeof this.form.controls): boolean {
    const control = this.form.controls[name];
    return control.touched && control.invalid;
  }

  async submit(): Promise<void> {
    if (this.busy() || this.success()) return;
    this.error.set(null);
    this.form.controls.email.setValue(this.form.controls.email.value.trim());
    this.form.markAllAsTouched();
    if (this.form.invalid) {
      this.error.set('Revisa los campos señalados.');
      return;
    }
    const value = this.form.getRawValue();
    if (this.mode === 'signup' && value.password !== value.confirmPassword) {
      this.error.set('Las contraseñas no coinciden.');
      return;
    }
    this.busy.set(true);
    try {
      if (this.mode === 'login') {
        const error = await this.auth.login(value.email, value.password);
        if (error) this.error.set(authErrorMessage(error, 'login'));
        else await this.goToDestination();
      } else if (this.mode === 'signup') {
        const { data, error } = await this.forms.signUp(value);
        if (error) this.error.set(authErrorMessage(error, 'signup'));
        else if (data.session) await this.goToDestination();
        else {
          this.form.reset();
          this.success.set(
            'Solicitud de registro recibida. Si el alta es válida, recibirás un correo para confirmar la cuenta. Revisa también spam. La invitación se consume al crear la cuenta, antes de confirmar el correo.',
          );
        }
      } else {
        const error = await this.forms.requestReset(value.email);
        if (error) this.error.set(authErrorMessage(error, 'reset'));
        else {
          this.form.reset();
          this.success.set(
            'Si existe una cuenta con ese correo, recibirás un enlace para cambiar la contraseña. Revisa también spam y abre el enlace en este navegador.',
          );
        }
      }
    } catch {
      this.error.set('No se ha podido completar la operación. Inténtalo de nuevo.');
    } finally {
      this.busy.set(false);
    }
  }

  private goToDestination() {
    return this.router.navigateByUrl(
      this.auth.isAuthenticated()
        ? this.returnUrl
        : deniedUrl(this.auth, this.router, this.returnUrl),
    );
  }
}

import { DOCUMENT } from '@angular/common';
import { computed, inject, Injectable, signal } from '@angular/core';
import { AuthError } from '@supabase/supabase-js';
import { AUTH_BACKEND } from './auth.backend';
import { AuthService } from './auth.service';
import type { AuthLink } from './auth-link';
import type { SignupInput } from './auth.types';

@Injectable({ providedIn: 'root' })
export class AuthFormsService {
  private readonly backend = inject(AUTH_BACKEND);
  private readonly auth = inject(AuthService);
  private readonly document = inject(DOCUMENT);
  private readonly passwordToken = signal<string | null>(null);
  readonly canSetPassword = computed(() => {
    const token = this.passwordToken();
    return !!token && this.auth.session()?.access_token === token;
  });

  private callbackUrl(): string {
    // El origen del navegador, nunca un redirect externo aportado por el usuario.
    return new URL('/auth/callback', this.document.location.origin).href;
  }

  signUp(input: SignupInput) {
    return this.auth.authenticate(() => this.backend.signUp(input, this.callbackUrl()));
  }

  async requestReset(email: string): Promise<AuthError | null> {
    try {
      return (await this.backend.resetPasswordForEmail(email, this.callbackUrl())).error;
    } catch {
      return new AuthError('No se ha podido conectar.');
    }
  }

  async completeLink(link: AuthLink): Promise<'confirmed' | 'password' | 'invalid'> {
    this.passwordToken.set(null);
    if (link.kind === 'invalid') return 'invalid';
    let password = false;
    const result = await this.auth.authenticate(async () => {
      if (link.kind === 'code') {
        const response = await this.backend.exchangeCode(link.code);
        // redirectType procede del verifier local del SDK, no del query string.
        password = response.data.redirectType === 'recovery';
        return response;
      }
      password = link.type === 'recovery' || link.type === 'invite';
      return link.kind === 'token'
        ? this.backend.verifyEmailToken(link.tokenHash, link.type)
        : this.backend.setSession(link.accessToken, link.refreshToken);
    });
    if (
      result.error ||
      !result.data.session ||
      this.auth.session()?.access_token !== result.data.session.access_token
    )
      return 'invalid';
    if (password) {
      this.passwordToken.set(result.data.session.access_token);
      return 'password';
    }
    return 'confirmed';
  }

  async setPassword(password: string): Promise<AuthError | null> {
    if (!this.canSetPassword()) return new AuthError('Solicita un nuevo enlace.');
    try {
      const { error } = await this.backend.updatePassword(password);
      if (!error) this.passwordToken.set(null);
      return error;
    } catch {
      return new AuthError('No se ha podido conectar.');
    }
  }
}

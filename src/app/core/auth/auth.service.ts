import { computed, DestroyRef, inject, Injectable, signal } from '@angular/core';
import { AuthError, type Session } from '@supabase/supabase-js';
import { AUTH_BACKEND } from './auth.backend';
import type { AuthStatus, CurrentProfile } from './auth.types';

interface AuthState {
  status: AuthStatus;
  session: Session | null;
  profile: CurrentProfile | null;
  error: string | null;
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly backend = inject(AUTH_BACKEND);
  private readonly destroyRef = inject(DestroyRef);
  private readonly state = signal<AuthState>({
    status: 'loading',
    session: null,
    profile: null,
    error: null,
  });
  private initialization: Promise<void> | null = null;
  private pending: Promise<void> = Promise.resolve();
  private change = this.newChange();
  private revision = 0;
  private operation = 0;
  private destroyed = false;

  readonly status = computed(() => this.state().status);
  readonly session = computed(() => this.state().session);
  readonly profile = computed(() => this.state().profile);
  readonly error = computed(() => this.state().error);
  readonly user = computed(() => this.session()?.user ?? null);
  readonly isAuthenticated = computed(() => this.status() === 'active');
  readonly isAdmin = computed(() => this.isAuthenticated() && this.profile()?.role === 'ADMIN');

  initialize(): Promise<void> {
    if (!this.initialization) {
      // Asignar antes de suscribir: algunos adaptadores notifican de forma síncrona.
      const revision = this.revision;
      this.initialization = Promise.resolve().then(() => this.restoreSession(revision));
      const { data } = this.backend.onAuthStateChange((_event, session) => {
        // Invalidar inmediatamente la identidad anterior, pero no llamar/esperar
        // otras APIs de Supabase dentro de su callback (lock interno de Auth).
        this.scheduleSession(session, true);
      });
      this.destroyRef.onDestroy(() => {
        this.destroyed = true;
        this.revision++;
        this.operation++;
        this.change.resolve();
        data.subscription.unsubscribe();
      });
    }
    return this.initialization;
  }

  async whenReady(): Promise<void> {
    await this.initialize();
    // Puede llegar otro evento mientras esperamos el perfil del anterior.
    let work: Promise<void>;
    do {
      work = this.pending;
      await Promise.race([work, this.change.promise]);
    } while (!this.destroyed && work !== this.pending);
  }

  /** Los guards revalidan el perfil en DB, nunca el rol de metadata/JWT. */
  async refreshProfile(): Promise<void> {
    await this.whenReady();
    if (this.session()) {
      this.scheduleSession(this.session());
    } else if (this.status() === 'error') {
      await this.restoreSession(++this.revision);
    }
    await this.whenReady();
  }

  async login(email: string, password: string): Promise<AuthError | null> {
    await this.whenReady();
    const operation = ++this.operation;
    const revision = this.invalidate();
    this.setState('loading', null);
    // Publicar el trabajo antes de invocar Auth: el SDK puede emitir eventos
    // durante signIn/signOut, y esos eventos pasan a ser el trabajo más reciente.
    const work = Promise.resolve().then(async () => {
      try {
        const { data, error } = await this.backend.signInWithPassword(email, password);
        if (this.isCurrent(operation, revision)) {
          if (error) {
            this.setState(
              'anonymous',
              null,
              'No se ha podido iniciar sesión. Revisa tus credenciales.',
            );
          } else {
            this.scheduleSession(data.session);
          }
        }
        return error;
      } catch {
        if (this.isCurrent(operation, revision)) {
          this.setState(
            'error',
            null,
            'No se ha podido conectar con el servicio de autenticación.',
          );
        }
        return new AuthError('No se ha podido conectar con el servicio de autenticación.');
      }
    });
    this.pending = work.then(() => {});
    const error = await work;
    await this.whenReady();
    return error;
  }

  async logout(): Promise<AuthError | null> {
    await this.initialize();
    const operation = ++this.operation;
    const revision = this.invalidate();
    const session = this.session();
    this.setState('loading', session);
    const work = Promise.resolve().then(async () => {
      try {
        // Scope local: cerrar este navegador sin expulsar otras sesiones del usuario.
        const { error } = await this.backend.signOut();
        if (this.isCurrent(operation, revision)) {
          if (error) {
            this.setState('error', session, 'No se ha podido cerrar sesión. Inténtalo de nuevo.');
          } else {
            this.scheduleSession(null);
          }
        }
        return error;
      } catch {
        if (this.isCurrent(operation, revision)) {
          this.setState('error', session, 'No se ha podido cerrar sesión. Inténtalo de nuevo.');
        }
        return new AuthError('No se ha podido cerrar sesión.');
      }
    });
    this.pending = work.then(() => {});
    const error = await work;
    await this.whenReady();
    return error;
  }

  private isCurrent(operation: number, revision: number): boolean {
    return !this.destroyed && operation === this.operation && revision === this.revision;
  }

  private async restoreSession(revision: number): Promise<void> {
    try {
      const { data, error } = await this.backend.getSession();
      if (this.destroyed || revision !== this.revision) return;
      if (error) {
        this.setState('error', null, 'No se ha podido restaurar la sesión. Inténtalo de nuevo.');
      } else {
        this.scheduleSession(data.session);
      }
    } catch {
      if (!this.destroyed && revision === this.revision) {
        this.setState('error', null, 'No se ha podido restaurar la sesión. Inténtalo de nuevo.');
      }
    }
  }

  private scheduleSession(session: Session | null, defer = false): void {
    if (this.destroyed) return;
    const revision = this.invalidate();
    this.setState(session ? 'loading' : 'anonymous', session);
    this.pending = (async () => {
      if (defer) await new Promise<void>((resolve) => setTimeout(resolve, 0));
      if (!session || this.destroyed || revision !== this.revision) return;
      try {
        const { data, error } = await this.backend.getMyProfile();
        if (this.destroyed || revision !== this.revision) return;
        if (error) {
          this.setState(
            'error',
            session,
            'No se ha podido verificar tu perfil. Inténtalo de nuevo.',
          );
          return;
        }
        if (Array.isArray(data) && data.length === 0) {
          // La RPC omite tanto perfiles desactivados como inexistentes.
          this.setState('inactive', session);
          return;
        }
        const profile = this.parseProfile(data, session.user.id);
        if (!profile) {
          this.setState('error', session, 'La respuesta del perfil no es válida.');
          return;
        }
        this.state.set({ status: 'active', session, profile, error: null });
      } catch {
        if (!this.destroyed && revision === this.revision) {
          this.setState(
            'error',
            session,
            'No se ha podido verificar tu perfil. Inténtalo de nuevo.',
          );
        }
      }
    })();
  }

  private invalidate(): number {
    this.change.resolve();
    this.change = this.newChange();
    return ++this.revision;
  }

  private newChange(): { promise: Promise<void>; resolve: () => void } {
    let resolve!: () => void;
    const promise = new Promise<void>((done) => {
      resolve = done;
    });
    return { promise, resolve };
  }

  private setState(status: AuthStatus, session: Session | null, error: string | null = null): void {
    this.state.set({ status, session, profile: null, error });
  }

  private parseProfile(data: unknown, userId: string): CurrentProfile | null {
    if (!Array.isArray(data) || data.length !== 1) return null;
    const row: unknown = data[0];
    if (typeof row !== 'object' || row === null) return null;
    const p = row as Record<string, unknown>;
    if (
      p['profile_id'] !== userId ||
      p['activo'] !== true ||
      (p['role'] !== 'ADMIN' && p['role'] !== 'PLAYER') ||
      typeof p['username'] !== 'string' ||
      typeof p['email'] !== 'string' ||
      (p['avatar_url'] !== null && typeof p['avatar_url'] !== 'string') ||
      typeof p['created_at'] !== 'string' ||
      typeof p['updated_at'] !== 'string'
    )
      return null;
    return {
      profileId: userId,
      username: p['username'],
      email: p['email'],
      avatarUrl: p['avatar_url'],
      role: p['role'],
      activo: true,
      createdAt: p['created_at'],
      updatedAt: p['updated_at'],
    };
  }
}

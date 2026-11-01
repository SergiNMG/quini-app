import type { AuthChangeEvent, AuthError, Session, Subscription } from '@supabase/supabase-js';

export type UserRole = 'ADMIN' | 'PLAYER';

export interface CurrentProfile {
  profileId: string;
  username: string;
  email: string;
  avatarUrl: string | null;
  role: UserRole;
  activo: boolean;
  createdAt: string;
  updatedAt: string;
}

export type AuthStatus = 'loading' | 'anonymous' | 'active' | 'inactive' | 'error';

export interface SessionResult {
  data: { session: Session | null };
  error: AuthError | null;
}

export interface PasswordResult {
  data: { session: Session | null };
  error: AuthError | null;
}

export interface ProfileResult {
  data: unknown;
  error: { message: string } | null;
}

export interface SignupInput {
  email: string;
  password: string;
  username: string;
  invitationCode: string;
}

export type EmailLinkType = 'signup' | 'recovery' | 'invite';

export interface AuthBackend {
  signUp(input: SignupInput, redirectTo: string): Promise<SessionResult>;
  resetPasswordForEmail(email: string, redirectTo: string): Promise<{ error: AuthError | null }>;
  updatePassword(password: string): Promise<{ error: AuthError | null }>;
  exchangeCode(
    code: string,
  ): Promise<SessionResult & { data: { session: Session | null; redirectType?: string | null } }>;
  verifyEmailToken(tokenHash: string, type: EmailLinkType): Promise<SessionResult>;
  setSession(accessToken: string, refreshToken: string): Promise<SessionResult>;
  getSession(): Promise<SessionResult>;
  onAuthStateChange(callback: (event: AuthChangeEvent, session: Session | null) => void): {
    data: { subscription: Subscription };
  };
  signInWithPassword(email: string, password: string): Promise<PasswordResult>;
  signOut(): Promise<{ error: AuthError | null }>;
  getMyProfile(): Promise<ProfileResult>;
}

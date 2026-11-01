import type { EmailLinkType } from './auth.types';

export type AuthLink =
  | { kind: 'code'; code: string }
  | { kind: 'token'; tokenHash: string; type: EmailLinkType }
  | { kind: 'implicit'; accessToken: string; refreshToken: string; type: EmailLinkType }
  | { kind: 'invalid' };

/** No interpretar errores del proveedor como HTML ni aceptar tipos ajenos a estos flujos. */
export function parseAuthLink(search: string, hash: string): AuthLink {
  const query = new URLSearchParams(search);
  const fragment = new URLSearchParams(hash.replace(/^#/, ''));
  if (
    query.has('error') ||
    fragment.has('error') ||
    query.has('error_code') ||
    fragment.has('error_code')
  ) {
    return { kind: 'invalid' };
  }
  const code = query.get('code');
  const tokenHash = query.get('token_hash');
  const accessToken = fragment.get('access_token');
  const refreshToken = fragment.get('refresh_token');
  const type = query.get('type') ?? fragment.get('type');
  if ([code, tokenHash, accessToken].filter(Boolean).length !== 1) return { kind: 'invalid' };
  if (code) return { kind: 'code', code };
  if (type !== 'signup' && type !== 'recovery' && type !== 'invite') return { kind: 'invalid' };
  if (tokenHash) return { kind: 'token', tokenHash, type };
  // Compatibilidad con correos de invitación Auth Admin (no generan verifier PKCE).
  if (accessToken && refreshToken) return { kind: 'implicit', accessToken, refreshToken, type };
  return { kind: 'invalid' };
}

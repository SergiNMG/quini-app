import { parseAuthLink } from './auth-link';

describe('Auth link parsing', () => {
  it.each([
    ['', ''],
    ['type=recovery', ''],
    ['code=code&error=access_denied', ''],
    ['token_hash=hash&type=email_change', ''],
    ['code=code&token_hash=hash&type=recovery', ''],
    ['', '#access_token=access&type=recovery'],
    ['', '#access_token=access&refresh_token=refresh&type=unknown'],
    ['', '#error_code=otp_expired&error_description=private'],
  ])('rejects missing, expired, conflicting or unsupported credentials (%s, %s)', (query, hash) => {
    expect(parseAuthLink(query, hash)).toEqual({ kind: 'invalid' });
  });

  it('accepts PKCE without trusting a recovery query parameter', () => {
    expect(parseAuthLink('code=code&type=recovery', '')).toEqual({ kind: 'code', code: 'code' });
  });

  it.each(['signup', 'recovery', 'invite'])('accepts token hash with allowed type %s', (type) => {
    expect(parseAuthLink('token_hash=hash&type=' + type, '')).toEqual({
      kind: 'token',
      tokenHash: 'hash',
      type,
    });
  });

  it('accepts Auth Admin invitation tokens for server validation', () => {
    expect(parseAuthLink('', '#access_token=access&refresh_token=refresh&type=invite')).toEqual({
      kind: 'implicit',
      accessToken: 'access',
      refreshToken: 'refresh',
      type: 'invite',
    });
  });
});

import {
  decodeJwtPayload,
  getAccessToken,
  getCurrentUserId,
  getCurrentUserRole,
  hasValidAccessToken,
  isAdminAccessToken,
  isTokenExpired,
} from './auth-session';

function tokenWithPayload(payload: Record<string, unknown>): string {
  const json = JSON.stringify(payload);
  const base64 = btoa(json).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
  return `header.${base64}.signature`;
}

describe('auth-session helpers', () => {
  afterEach(() => {
    localStorage.removeItem('access_token');
  });

  it('treats missing, malformed, and expired tokens as invalid sessions', () => {
    expect(getAccessToken()).toBeNull();
    expect(hasValidAccessToken()).toBeFalse();
    expect(isTokenExpired(null)).toBeTrue();
    expect(decodeJwtPayload('not-a-jwt')).toBeNull();

    localStorage.setItem('access_token', 'not-a-jwt');
    expect(hasValidAccessToken()).toBeFalse();

    const expiredToken = tokenWithPayload({ exp: Math.floor(Date.now() / 1000) - 60, role: 'Admin' });
    localStorage.setItem('access_token', expiredToken);
    expect(isTokenExpired(expiredToken)).toBeTrue();
    expect(hasValidAccessToken()).toBeFalse();
  });

  it('extracts user id and role from a valid access token', () => {
    const validToken = tokenWithPayload({
      exp: Math.floor(Date.now() / 1000) + 3600,
      user_id: 42,
      role: 'Admin',
    });
    localStorage.setItem('access_token', validToken);

    expect(getAccessToken()).toBe(validToken);
    expect(hasValidAccessToken()).toBeTrue();
    expect(getCurrentUserId()).toBe(42);
    expect(getCurrentUserRole()).toBe('Admin');
    expect(isAdminAccessToken()).toBeTrue();
  });

  it('does not grant admin access when role or expiry is missing', () => {
    localStorage.setItem('access_token', tokenWithPayload({ exp: Math.floor(Date.now() / 1000) + 3600 }));
    expect(getCurrentUserRole()).toBeNull();
    expect(isAdminAccessToken()).toBeFalse();

    localStorage.setItem('access_token', tokenWithPayload({ role: 'Admin' }));
    expect(hasValidAccessToken()).toBeFalse();
    expect(isAdminAccessToken()).toBeFalse();
  });
});

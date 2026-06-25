export interface JwtPayload {
  exp?: number;
  role?: string;
  user_id?: number;
  [key: string]: unknown;
}

const ACCESS_TOKEN_KEY = 'access_token';

export function getAccessToken(): string | null {
  return localStorage.getItem(ACCESS_TOKEN_KEY);
}

export function decodeJwtPayload(token: string | null): JwtPayload | null {
  if (!token) return null;

  const payloadSegment = token.split('.')[1];
  if (!payloadSegment) return null;

  try {
    const base64 = payloadSegment.replace(/-/g, '+').replace(/_/g, '/');
    const paddedBase64 = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), '=');
    return JSON.parse(atob(paddedBase64));
  } catch {
    return null;
  }
}

export function isTokenExpired(token: string | null): boolean {
  const payload = decodeJwtPayload(token);
  if (typeof payload?.exp !== 'number') return true;
  return payload.exp * 1000 < Date.now();
}

export function hasValidAccessToken(): boolean {
  return !isTokenExpired(getAccessToken());
}

export function getCurrentAccessTokenPayload(): JwtPayload | null {
  return decodeJwtPayload(getAccessToken());
}

export function getCurrentUserId(): number | null {
  const userId = getCurrentAccessTokenPayload()?.user_id;
  return typeof userId === 'number' ? userId : null;
}

export function getCurrentUserRole(): string | null {
  const role = getCurrentAccessTokenPayload()?.role;
  return typeof role === 'string' ? role : null;
}

export function isAdminAccessToken(): boolean {
  return hasValidAccessToken() && getCurrentUserRole() === 'Admin';
}

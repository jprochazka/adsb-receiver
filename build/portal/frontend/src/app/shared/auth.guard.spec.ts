import { TestBed } from '@angular/core/testing';
import { ActivatedRouteSnapshot, Router, RouterStateSnapshot, UrlTree, provideRouter } from '@angular/router';
import { authGuard } from './auth.guard';

function tokenWithExpiry(exp: number): string {
  const payload = btoa(JSON.stringify({ exp })).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
  return `header.${payload}.signature`;
}

describe('authGuard', () => {
  let router: Router;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideRouter([])] });
    router = TestBed.inject(Router);
  });

  afterEach(() => localStorage.removeItem('access_token'));

  function runGuard(url = '/account'): boolean | UrlTree {
    return TestBed.runInInjectionContext(() => authGuard(
      {} as ActivatedRouteSnapshot,
      { url } as RouterStateSnapshot,
    )) as boolean | UrlTree;
  }

  it('redirects anonymous and expired sessions with a return URL', () => {
    const anonymous = runGuard() as UrlTree;
    expect(router.serializeUrl(anonymous)).toBe('/login?returnUrl=%2Faccount');

    localStorage.setItem('access_token', tokenWithExpiry(Math.floor(Date.now() / 1000) - 60));
    expect(router.serializeUrl(runGuard() as UrlTree)).toBe('/login?returnUrl=%2Faccount');
  });

  it('allows a valid authenticated session', () => {
    localStorage.setItem('access_token', tokenWithExpiry(Math.floor(Date.now() / 1000) + 3600));
    expect(runGuard()).toBeTrue();
  });
});
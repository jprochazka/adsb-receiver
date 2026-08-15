import { TestBed } from '@angular/core/testing';
import { ActivatedRouteSnapshot, Route, Router, RouterStateSnapshot, UrlTree, provideRouter } from '@angular/router';
import { routes } from '../app.routes';
import { adminGuard } from './admin.guard';

function tokenWithPayload(payload: Record<string, unknown>): string {
  const json = JSON.stringify(payload);
  const base64 = btoa(json).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
  return `header.${base64}.signature`;
}

describe('adminGuard', () => {
  let router: Router;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideRouter([])] });
    router = TestBed.inject(Router);
  });

  afterEach(() => {
    localStorage.removeItem('access_token');
  });

  function runGuard(): boolean | UrlTree {
    return TestBed.runInInjectionContext(() =>
      adminGuard({} as ActivatedRouteSnapshot, {} as RouterStateSnapshot),
    ) as boolean | UrlTree;
  }

  it('protects every Admin dropdown route', () => {
    const adminRoute = routes.find(route => route.path === 'admin') as Route | undefined;

    expect(adminRoute?.canActivateChild).toEqual([adminGuard]);
    expect(adminRoute?.children?.map(route => route.path).sort()).toEqual([
      '',
      '**',
      'acars',
      'ais',
      'blog',
      'devices',
      'feeders',
      'flights',
      'links',
      'live',
      'scheduler',
      'users',
      'x-alert',
    ]);
  });

  it('redirects users without an admin token to login', () => {
    expect(router.serializeUrl(runGuard() as UrlTree)).toBe('/login');

    localStorage.setItem('access_token', tokenWithPayload({
      exp: Math.floor(Date.now() / 1000) + 3600,
      role: 'User',
    }));
    expect(router.serializeUrl(runGuard() as UrlTree)).toBe('/login');
  });

  it('redirects users with an expired admin token to login', () => {
    localStorage.setItem('access_token', tokenWithPayload({
      exp: Math.floor(Date.now() / 1000) - 60,
      role: 'Admin',
    }));

    expect(router.serializeUrl(runGuard() as UrlTree)).toBe('/login');
  });

  it('allows users with a valid admin token', () => {
    localStorage.setItem('access_token', tokenWithPayload({
      exp: Math.floor(Date.now() / 1000) + 3600,
      role: 'Admin',
    }));

    expect(runGuard()).toBeTrue();
  });
});

import { HttpClient, HttpHeaders } from '@angular/common/http';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';

import { authInterceptor } from './auth.interceptor';

describe('authInterceptor', () => {
  let http: HttpClient;
  let httpMock: HttpTestingController;
  const routerMock = {
    url: '/devices',
    navigate: jasmine.createSpy('navigate'),
  };

  beforeEach(() => {
    localStorage.clear();
    routerMock.navigate.calls.reset();
    routerMock.url = '/devices';

    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(withInterceptors([authInterceptor])),
        provideHttpClientTesting(),
        { provide: Router, useValue: routerMock },
      ],
    });

    http = TestBed.inject(HttpClient);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
    localStorage.clear();
  });

  it('does not redirect for unauthenticated public 401 responses', () => {
    http.get('/public-endpoint').subscribe({
      next: fail,
      error: () => {
        expect(routerMock.navigate).not.toHaveBeenCalled();
      },
    });

    const req = httpMock.expectOne('/public-endpoint');
    expect(req.request.headers.has('Authorization')).toBeFalse();
    req.flush({ msg: 'Unauthorized' }, { status: 401, statusText: 'Unauthorized' });

    expect(localStorage.getItem('access_token')).toBeNull();
  });

  it('clears session and redirects for authenticated 401 responses', () => {
    const validPayload = btoa(JSON.stringify({ exp: 4102444800, role: 'User' }));
    localStorage.setItem('access_token', `header.${validPayload}.sig`);
    localStorage.setItem('refresh_token', 'refresh-token');

    http
      .get('/admin-endpoint', {
        headers: new HttpHeaders({ Authorization: 'Bearer test-token' }),
      })
      .subscribe({
        next: fail,
        error: () => {
          expect(routerMock.navigate).toHaveBeenCalledWith(['/login'], {
            queryParams: { returnUrl: '/devices' },
          });
        },
      });

    const req = httpMock.expectOne('/admin-endpoint');
    expect(req.request.headers.get('Authorization')).toBe('Bearer test-token');
    req.flush({ msg: 'Unauthorized' }, { status: 401, statusText: 'Unauthorized' });

    expect(localStorage.getItem('access_token')).toBeNull();
    expect(localStorage.getItem('refresh_token')).toBeNull();
  });

  it('clears a stale admin session on an admin-role 403', () => {
    const validPayload = btoa(JSON.stringify({ exp: 4102444800, role: 'Admin' }));
    localStorage.setItem('access_token', `header.${validPayload}.sig`);
    routerMock.url = '/admin/users';

    http.get('/admin-endpoint', {
      headers: new HttpHeaders({ Authorization: 'Bearer test-token' }),
    }).subscribe({ next: fail, error: () => {} });

    httpMock.expectOne('/admin-endpoint').flush(
      { msg: 'Admin access required' },
      { status: 403, statusText: 'Forbidden' },
    );

    expect(localStorage.getItem('access_token')).toBeNull();
    expect(routerMock.navigate).toHaveBeenCalled();
  });
});

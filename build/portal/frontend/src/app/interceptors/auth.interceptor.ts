import { HttpInterceptorFn, HttpErrorResponse } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';
import { isTokenExpired } from '../shared/auth-session';

function clearSession(router: Router): void {
  localStorage.removeItem('access_token');
  localStorage.removeItem('refresh_token');
  router.navigate(['/login'], { queryParams: { returnUrl: router.url } });
}

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const router = inject(Router);
  const token = localStorage.getItem('access_token');
  const hasAuthHeader = req.headers.has('Authorization');

  if (hasAuthHeader && token && isTokenExpired(token)) {
    clearSession(router);
    return throwError(() => new Error('Session expired. Please log in again.'));
  }

  return next(req).pipe(
    catchError((error) => {
      if (error instanceof HttpErrorResponse && error.status === 401 && hasAuthHeader) {
        clearSession(router);
      }
      if (error instanceof HttpErrorResponse && error.status === 403 && hasAuthHeader) {
        const message = error.error?.msg;
        if (message === 'Account is locked' || (router.url.startsWith('/admin') && message === 'Admin access required')) {
          clearSession(router);
        }
      }
      return throwError(() => error);
    })
  );
};

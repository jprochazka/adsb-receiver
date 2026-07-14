import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { hasValidAccessToken } from './auth-session';

export const authGuard: CanActivateFn = (_route, state) => {
  return hasValidAccessToken()
    || inject(Router).createUrlTree(['/login'], { queryParams: { returnUrl: state.url } });
};
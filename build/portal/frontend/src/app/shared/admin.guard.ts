import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { isAdminAccessToken } from './auth-session';

export const adminGuard: CanActivateFn = () => {
  return isAdminAccessToken() || inject(Router).createUrlTree(['/login']);
};

import { Component, ChangeDetectionStrategy } from '@angular/core';
import { Router } from '@angular/router';

@Component({
  selector: 'app-logout',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `<a class="nav-link" style="cursor:pointer" (click)="logout()">Logout</a>`
})
export class LogoutComponent {
  constructor(private router: Router) {}

  logout() {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    this.router.navigate(['/login']);
  }
}

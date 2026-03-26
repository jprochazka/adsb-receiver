import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';

import { Router, RouterLink } from '@angular/router';
import { DataService } from '../service/data.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [FormsModule, RouterLink],
  templateUrl: './login.component.html',
  styleUrl: './login.component.scss'
})
export class LoginComponent {
  email = '';
  password = '';
  errorMessage = '';
  loading = false;

  private router = inject(Router);

  constructor(private dataService: DataService) {}

  login() {
    this.errorMessage = '';
    this.loading = true;
    this.dataService.login(this.email, this.password).subscribe({
      next: (response) => {
        localStorage.setItem('access_token', response.access_token);
        localStorage.setItem('refresh_token', response.refresh_token);
        this.router.navigate(['/account']);
      },
      error: () => {
        this.errorMessage = 'Invalid email or password.';
        this.loading = false;
      }
    });
  }
}

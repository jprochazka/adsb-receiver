import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';

import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { DataService } from '../service/data.service';

@Component({
  selector: 'app-register',
  standalone: true,
  imports: [FormsModule, RouterLink],
  templateUrl: './register.component.html',
  styleUrl: './register.component.scss'
})
export class RegisterComponent {
  name = '';
  email = '';
  password = '';
  confirmPassword = '';

  loading = false;
  errorMessage = '';
  successMessage = '';

  private router = inject(Router);
  private route = inject(ActivatedRoute);

  constructor(private dataService: DataService) {}

  register() {
    this.errorMessage = '';
    this.successMessage = '';

    if (!this.name.trim() || !this.email.trim() || !this.password) {
      this.errorMessage = 'All fields are required.';
      return;
    }
    if (this.password.length < 8) {
      this.errorMessage = 'Password must be at least 8 characters.';
      return;
    }
    if (this.password !== this.confirmPassword) {
      this.errorMessage = 'Passwords do not match.';
      return;
    }

    this.loading = true;
    this.dataService.register(this.name.trim(), this.email.trim(), this.password).subscribe({
      next: () => {
        this.loading = false;
        this.successMessage = 'Account created! Redirecting to login\u2026';
        const returnUrl = this.route.snapshot.queryParamMap.get('returnUrl');
        setTimeout(() => {
          if (returnUrl && returnUrl.startsWith('/')) {
            this.router.navigate(['/login'], { queryParams: { returnUrl } });
            return;
          }
          this.router.navigate(['/login']);
        }, 1500);
      },
      error: (err) => {
        this.loading = false;
        const msg = err?.error?.msg;
        this.errorMessage = msg && typeof msg === 'string' ? msg : 'Registration failed. Please try again.';
      }
    });
  }

  get loginQueryParams(): { returnUrl: string } | {} {
    const returnUrl = this.route.snapshot.queryParamMap.get('returnUrl');
    if (returnUrl && returnUrl.startsWith('/')) {
      return { returnUrl };
    }
    return {};
  }
}

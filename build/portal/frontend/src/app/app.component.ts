import { CommonModule } from '@angular/common';
import { Component, OnInit, OnDestroy } from '@angular/core';
import { Router, RouterLink, RouterOutlet, RouterLinkActive } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { LinksComponent } from './links/links.component';
import { LogoutComponent } from './logout/logout.component';
import { DataService } from './service/data.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterOutlet, RouterLink, RouterLinkActive, LinksComponent, LogoutComponent],
  templateUrl: './app.component.html',
  styleUrl: './app.component.scss'
})
export class AppComponent implements OnInit, OnDestroy {
  title = 'frontend';
  searchQuery = '';
  trackedFlights: any[] = [];
  private pollInterval: any;

  constructor(private router: Router, private dataService: DataService) {}

  ngOnInit(): void {
    this.pollRecentNotifications();
    this.pollInterval = setInterval(() => this.pollRecentNotifications(), 60000);
  }

  ngOnDestroy(): void {
    clearInterval(this.pollInterval);
  }

  private pollRecentNotifications(): void {
    this.dataService.getRecentNotifications().subscribe({
      next: (result) => this.trackedFlights = result.flights ?? [],
      error: () => {}
    });
  }

  get isLoggedIn(): boolean {
    return !!localStorage.getItem('access_token');
  }

  get isAdmin(): boolean {
    const token = localStorage.getItem('access_token');
    if (!token) return false;
    try {
      const base64 = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
      const payload = JSON.parse(atob(base64));
      return payload.role === 'Admin';
    } catch {
      return false;
    }
  }

  search() {
    const q = this.searchQuery.trim();
    if (!q) return;
    this.dataService.searchFlights(q).subscribe({
      next: (result) => {
        if (result.count === 1) {
          this.router.navigate(['/flight-history', result.flights[0].flight]);
        } else {
          this.router.navigate(['/flights'], { queryParams: { q } });
        }
      }
    });
  }
}

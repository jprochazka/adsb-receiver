import { CommonModule } from '@angular/common';
import { Component, OnInit, OnDestroy } from '@angular/core';
import { NavigationEnd, Router, RouterLink, RouterOutlet, RouterLinkActive } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { forkJoin } from 'rxjs';
import { catchError, filter, of } from 'rxjs';
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

  flightsNavEnabled = true;
  acarsNavEnabled   = true;
  blogNavEnabled    = true;
  linksNavEnabled   = true;

  infoNavEnabled    = true;
  infoSystemEnabled = true;
  infoGraphsEnabled = true;

  mapNavEnabled      = true;
  mapDump1090Enabled = true;
  mapDump978Enabled  = true;
  mapAdsbxEnabled    = true;
  mapPfclientEnabled = false;
  pfclientUrl        = '';

  constructor(private router: Router, private dataService: DataService) {}

  ngOnInit(): void {
    this.pollRecentNotifications();
    this.pollInterval = setInterval(() => this.pollRecentNotifications(), 60000);
    this.loadFlightsSettings();
    this.loadInfoSettings();
    this.loadMapSettings();
    this.router.events.pipe(filter(e => e instanceof NavigationEnd)).subscribe(() => {
      document.getElementById('navbarMain')?.classList.remove('show');
    });
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

  private loadFlightsSettings(): void {
    this.dataService.getSetting('flights_nav_enabled').pipe(catchError(() => of({ value: 'true' }))).subscribe(res => {
      this.flightsNavEnabled = res?.value !== 'false';
    });
    this.dataService.getSetting('acars_nav_enabled').pipe(catchError(() => of({ value: 'true' }))).subscribe(res => {
      this.acarsNavEnabled = res?.value !== 'false';
    });
    this.dataService.getSetting('blog_nav_enabled').pipe(catchError(() => of({ value: 'true' }))).subscribe(res => {
      this.blogNavEnabled = res?.value !== 'false';
    });
    this.dataService.getSetting('links_nav_enabled').pipe(catchError(() => of({ value: 'true' }))).subscribe(res => {
      this.linksNavEnabled = res?.value !== 'false';
    });
  }

  private loadInfoSettings(): void {
    forkJoin({
      nav:    this.dataService.getSetting('info_nav_enabled').pipe(catchError(() => of({ value: 'true' }))),
      system: this.dataService.getSetting('info_system_enabled').pipe(catchError(() => of({ value: 'true' }))),
      graphs: this.dataService.getSetting('info_graphs_enabled').pipe(catchError(() => of({ value: 'true' }))),
    }).subscribe(({ nav, system, graphs }) => {
      this.infoNavEnabled    = nav?.value    !== 'false';
      this.infoSystemEnabled = system?.value !== 'false';
      this.infoGraphsEnabled = graphs?.value !== 'false';
    });
  }

  private loadMapSettings(): void {
    forkJoin({
      nav:      this.dataService.getSetting('map_nav_enabled').pipe(catchError(() => of({ value: 'true' }))),
      d1090:    this.dataService.getSetting('map_dump1090_enabled').pipe(catchError(() => of({ value: 'true' }))),
      d978:     this.dataService.getSetting('map_dump978_enabled').pipe(catchError(() => of({ value: 'true' }))),
      adsbx:    this.dataService.getSetting('map_adsbx_enabled').pipe(catchError(() => of({ value: 'true' }))),
      pfclient: this.dataService.getSetting('map_pfclient_enabled').pipe(catchError(() => of({ value: 'false' }))),
    }).subscribe(({ nav, d1090, d978, adsbx, pfclient }) => {
      this.mapNavEnabled      = nav?.value      !== 'false';
      this.mapDump1090Enabled = d1090?.value    !== 'false';
      this.mapDump978Enabled  = d978?.value     !== 'false';
      this.mapAdsbxEnabled    = adsbx?.value    !== 'false';
      this.mapPfclientEnabled = pfclient?.value === 'true';
      this.pfclientUrl = `${window.location.protocol}//${window.location.hostname}:30053`;
    });
  }

  get isLoggedIn(): boolean {
    const token = localStorage.getItem('access_token');
    if (!token) return false;
    try {
      const base64 = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
      const payload = JSON.parse(atob(base64));
      return payload.exp * 1000 > Date.now();
    } catch {
      return false;
    }
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

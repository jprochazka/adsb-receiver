
import { Component, OnInit, OnDestroy, ChangeDetectionStrategy } from '@angular/core';
import { NavigationEnd, Router, RouterLink, RouterOutlet, RouterLinkActive } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { forkJoin } from 'rxjs';
import { catchError, filter, of } from 'rxjs';
import { LinksComponent } from './links/links.component';
import { LogoutComponent } from './logout/logout.component';
import { DataService } from './service/data.service';
import { environment } from '../environments/environment';
import { hasValidAccessToken, isAdminAccessToken } from './shared/auth-session';

const MAP_LINK_DEFS: Record<string, { label: string; href: string; external: boolean }> = {
  dump1090: { label: 'Dump1090',            href: '/dump1090', external: false },
  dump978:  { label: 'Dump978',             href: '/dump978',  external: false },
  adsbx:    { label: 'ADS-B Exchange',      href: '/adbsx',    external: false },
  pfclient: { label: 'Plane Finder Client', href: '',          external: true  },
};
const DEFAULT_MAP_ORDER = 'dump1090,dump978,adsbx,pfclient';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [FormsModule, RouterOutlet, RouterLink, RouterLinkActive, LinksComponent, LogoutComponent],
  templateUrl: './app.component.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './app.component.scss'
})
export class AppComponent implements OnInit, OnDestroy {
  title = 'frontend';
  frontendVersion = environment.frontendVersion;
  backendVersion = environment.backendVersion;
  currentYear = new Date().getFullYear();
  searchQuery = '';
  trackedFlights: any[] = [];
  alertBarDismissed = false;
  private dismissedFlights = new Set<string>();
  private pollInterval: any;

  flightsNavEnabled = true;
  acarsNavEnabled   = true;
  blogNavEnabled    = true;
  linksNavEnabled   = true;

  infoNavEnabled    = true;
  infoSystemEnabled = true;
  infoGraphsEnabled = true;

  mapNavEnabled = true;
  liveMapEnabled = true;
  mapLinks: { key: string; label: string; href: string; enabled: boolean; external: boolean }[] = [];

  get enabledMapLinks() {
    return this.mapLinks.filter(l => l.enabled);
  }

  get anyMapEnabled(): boolean {
    return this.mapLinks.some(l => l.enabled);
  }

  constructor(private router: Router, private dataService: DataService) {}

  ngOnInit(): void {
    this.pollRecentNotifications();
    this.pollInterval = setInterval(() => this.pollRecentNotifications(), 60000);
    this.loadBackendVersion();
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

  private loadBackendVersion(): void {
    this.dataService.getApiVersion().pipe(catchError(() => of(null))).subscribe((result) => {
      if (result?.version) {
        this.backendVersion = result.version;
      }
    });
  }

  private pollRecentNotifications(): void {
    if (!this.isLoggedIn) {
      this.trackedFlights = [];
      return;
    }
    this.dataService.getRecentNotifications().subscribe({
      next: (result) => {
        const flights = result.flights ?? [];
        if (this.alertBarDismissed) {
          const hasNewFlight = flights.some((f: any) => !this.dismissedFlights.has(f.flight));
          if (hasNewFlight) {
            this.alertBarDismissed = false;
            this.dismissedFlights.clear();
          }
        }
        this.trackedFlights = flights;
      },
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
    const pfclientUrl = `${window.location.protocol}//${window.location.hostname}:30053`;
    forkJoin({
      liveMap:  this.dataService.getSetting('live_map_enabled').pipe(catchError(() => of({ value: 'true' }))),
      nav:      this.dataService.getSetting('map_nav_enabled').pipe(catchError(() => of({ value: 'true' }))),
      d1090:    this.dataService.getSetting('map_dump1090_enabled').pipe(catchError(() => of({ value: 'true' }))),
      d978:     this.dataService.getSetting('map_dump978_enabled').pipe(catchError(() => of({ value: 'true' }))),
      adsbx:    this.dataService.getSetting('map_adsbx_enabled').pipe(catchError(() => of({ value: 'true' }))),
      pfclient: this.dataService.getSetting('map_pfclient_enabled').pipe(catchError(() => of({ value: 'false' }))),
      order:    this.dataService.getSetting('map_links_order').pipe(catchError(() => of({ value: DEFAULT_MAP_ORDER }))),
    }).subscribe(({ liveMap, nav, d1090, d978, adsbx, pfclient, order }) => {
      this.liveMapEnabled = liveMap?.value !== 'false';
      this.mapNavEnabled = nav?.value !== 'false';

      const enabledMap: Record<string, boolean> = {
        dump1090: d1090?.value    !== 'false',
        dump978:  d978?.value     !== 'false',
        adsbx:    adsbx?.value    !== 'false',
        pfclient: pfclient?.value === 'true',
      };

      const orderKeys = (order?.value || DEFAULT_MAP_ORDER)
        .split(',').map((k: string) => k.trim()).filter((k: string) => k in MAP_LINK_DEFS);
      for (const key of Object.keys(MAP_LINK_DEFS)) {
        if (!orderKeys.includes(key)) orderKeys.push(key);
      }

      this.mapLinks = orderKeys.map((key: string) => ({
        key,
        label:    MAP_LINK_DEFS[key].label,
        href:     key === 'pfclient' ? pfclientUrl : MAP_LINK_DEFS[key].href,
        enabled:  enabledMap[key] ?? false,
        external: MAP_LINK_DEFS[key].external,
      }));
    });
  }

  get isLoggedIn(): boolean {
    return hasValidAccessToken();
  }

  get isAdmin(): boolean {
    return isAdminAccessToken();
  }

  dismissAlert(): void {
    this.dismissedFlights = new Set(this.trackedFlights.map(f => f.flight));
    this.alertBarDismissed = true;
  }

  search() {
    const q = this.searchQuery.trim();
    if (!q) return;
    this.dataService.searchFlights(q).subscribe({
      next: (result) => {
        if (result.count === 1) {
          this.router.navigate(['/flight-history', 'adsb', result.flights[0].flight]);
        } else {
          this.router.navigate(['/flights'], { queryParams: { q } });
        }
      }
    });
  }
}

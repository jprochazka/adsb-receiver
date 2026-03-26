import { Component, OnInit, inject } from '@angular/core';

import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';
import { forkJoin, combineLatest } from 'rxjs';
import { catchError, of } from 'rxjs';

const PAGE_SIZE = 50;

@Component({
  selector: 'app-flights',
  standalone: true,
  imports: [SpinnerComponent, RouterLink],
  templateUrl: './flights.component.html',
  styleUrl: './flights.component.scss'
})
export class FlightsComponent implements OnInit {
  // ADS-B
  adsbData: any;
  adsbCurrentPage = 1;
  adsbTotalPages = 1;
  adsbTotalFlights = 0;
  adsbPageNumbers: number[] = [];

  // UAT
  uatData: any;
  uatCurrentPage = 1;
  uatTotalPages = 1;
  uatTotalFlights = 0;
  uatPageNumbers: number[] = [];

  // Tab visibility settings
  allTabEnabled  = true;
  adsbTabEnabled = true;
  uatTabEnabled  = true;

  // Combined list (both sources merged, sorted by last_seen desc)
  combinedFlights: any[] = [];

  loading = true;
  searchQuery = '';
  activeTab: 'all' | 'adsb' | 'uat' = 'all';

  private route = inject(ActivatedRoute);
  private router = inject(Router);

  constructor(private data_service: DataService) {}

  ngOnInit() {
    forkJoin({
      allTab:  this.data_service.getSetting('all_tab_enabled').pipe(catchError(() => of({ value: 'true' }))),
      adsbTab: this.data_service.getSetting('adsb_tab_enabled').pipe(catchError(() => of({ value: 'true' }))),
      uatTab:  this.data_service.getSetting('uat_tab_enabled').pipe(catchError(() => of({ value: 'true' }))),
    }).subscribe(({ allTab, adsbTab, uatTab }) => {
      this.allTabEnabled  = allTab?.value  !== 'false';
      this.adsbTabEnabled = adsbTab?.value !== 'false';
      this.uatTabEnabled  = uatTab?.value  !== 'false';
      if (this.allTabEnabled && this.adsbTabEnabled && this.uatTabEnabled) {
        this.activeTab = 'all';
      } else if (!this.adsbTabEnabled && this.uatTabEnabled) {
        this.activeTab = 'uat';
      } else if (this.adsbTabEnabled && !this.uatTabEnabled) {
        this.activeTab = 'adsb';
      } else {
        this.activeTab = 'all';
      }
      this.subscribeToRoute();
    });
  }

  private subscribeToRoute() {
    combineLatest([
      this.route.paramMap,
      this.route.queryParamMap
    ]).subscribe(([params, queryParams]) => {
      const q = queryParams.get('q') || '';
      this.searchQuery = q;
      this.loading = true;

      if (q) {
        forkJoin({
          adsb: this.data_service.searchFlights(q).pipe(catchError(() => of(null))),
          uat:  this.data_service.searchUatFlights(q).pipe(catchError(() => of(null))),
        }).subscribe(({ adsb, uat }) => {
          this.adsbData = adsb;
          this.uatData  = uat;
          this.adsbTotalFlights = adsb?.count ?? 0;
          this.uatTotalFlights  = uat?.count  ?? 0;
          this.adsbTotalPages = 1;
          this.uatTotalPages  = 1;
          this.adsbPageNumbers = [];
          this.uatPageNumbers  = [];
          const adsbMapped = (adsb?.flights || []).map((f: any) => ({ ...f, _type: 'adsb' }));
          const uatMapped  = (uat?.flights  || []).map((f: any) => ({ ...f, _type: 'uat'  }));
          this.combinedFlights = [...adsbMapped, ...uatMapped]
            .sort((a, b) => (b.last_seen > a.last_seen ? 1 : -1));
          this.loading = false;
        });
      } else {
        const adsbPage = Math.max(1, parseInt(params.get('page') || '1', 10) || 1);
        const uatPage  = Math.max(1, parseInt(params.get('uatPage') || '1', 10) || 1);
        this.adsbCurrentPage = adsbPage;
        this.uatCurrentPage  = uatPage;

        forkJoin({
          adsbCount: this.data_service.GetFlightsCount(),
          adsbFlights: this.data_service.getFlights((adsbPage - 1) * PAGE_SIZE, PAGE_SIZE),
          uatCount: this.data_service.getUatFlightsCount().pipe(catchError(() => of({ flights: 0 }))),
          uatFlights: this.data_service.getUatFlights((uatPage - 1) * PAGE_SIZE, PAGE_SIZE).pipe(catchError(() => of(null))),
        }).subscribe(({ adsbCount, adsbFlights, uatCount, uatFlights }) => {
          this.adsbTotalFlights = adsbCount.flights;
          this.adsbTotalPages   = Math.max(1, Math.ceil(adsbCount.flights / PAGE_SIZE));
          this.adsbCurrentPage  = Math.min(adsbPage, this.adsbTotalPages);
          this.adsbPageNumbers  = this.buildPageNumbers(this.adsbCurrentPage, this.adsbTotalPages);
          this.adsbData = adsbFlights;

          this.uatTotalFlights = uatCount.flights;
          this.uatTotalPages   = Math.max(1, Math.ceil(uatCount.flights / PAGE_SIZE));
          this.uatCurrentPage  = Math.min(uatPage, this.uatTotalPages);
          this.uatPageNumbers  = this.buildPageNumbers(this.uatCurrentPage, this.uatTotalPages);
          this.uatData = uatFlights;

          const adsbMapped = (adsbFlights?.flights || []).map((f: any) => ({ ...f, _type: 'adsb' }));
          const uatMapped  = (uatFlights?.flights  || []).map((f: any) => ({ ...f, _type: 'uat'  }));
          this.combinedFlights = [...adsbMapped, ...uatMapped]
            .sort((a, b) => (b.last_seen > a.last_seen ? 1 : -1));

          this.loading = false;
        });
      }
    });
  }

  setTab(tab: 'all' | 'adsb' | 'uat') {
    this.activeTab = tab;
  }

  goToAdsbPage(page: number) {
    if (page < 1 || page > this.adsbTotalPages || page === this.adsbCurrentPage) return;
    this.router.navigate(['/flights', page]);
  }

  goToUatPage(page: number) {
    if (page < 1 || page > this.uatTotalPages || page === this.uatCurrentPage) return;
    this.router.navigate(['/flights'], { queryParams: { uatPage: page } });
  }

  private buildPageNumbers(current: number, total: number): number[] {
    if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1);
    const pages = new Set<number>();
    pages.add(1);
    pages.add(total);
    for (let i = Math.max(1, current - 2); i <= Math.min(total, current + 2); i++) pages.add(i);
    return Array.from(pages).sort((a, b) => a - b);
  }
}

import { Component, OnInit, inject, ChangeDetectionStrategy } from '@angular/core';

import { ActivatedRoute, Router } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { combineLatest, forkJoin } from 'rxjs';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

const DEFAULT_PAGE_SIZE = 50;
const MSG_PAGE_SIZE = 25;

@Component({
  selector: 'app-acars',
  standalone: true,
  imports: [FormsModule, SpinnerComponent],
  templateUrl: './acars.component.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './acars.component.scss'
})
export class AcarsComponent implements OnInit {
  flights: any[] = [];
  loading = true;
  readonly pageSizeOptions = [10, 25, 50, 100];
  perPage = DEFAULT_PAGE_SIZE;
  private _filterQuery = '';
  get filterQuery(): string {
    return this._filterQuery;
  }
  set filterQuery(val: string) {
    this._filterQuery = val;
  }

  // Flight pagination
  currentPage = 1;
  totalPages = 1;
  totalFlights = 0;
  pageNumbers: number[] = [];

  // Expanded flight messages
  expandedFlightId: number | null = null;
  messages: any[] = [];
  messagesLoading = false;
  msgCurrentPage = 1;
  msgTotalPages = 1;
  msgTotal = 0;
  msgPageNumbers: number[] = [];

  // Message text modal
  modalText = '';
  modalMsgNo = '';
  modalLabel = '';
  modalTime = '';

  private route = inject(ActivatedRoute);
  private router = inject(Router);

  constructor(private dataService: DataService) {}

  ngOnInit(): void {
    combineLatest([this.route.paramMap, this.route.queryParamMap]).subscribe(([params, queryParams]) => {
      this.loading = true;
      this.collapseMessages();

      const page = Math.max(1, parseInt(params.get('page') || '1', 10) || 1);
      const requestedPerPage = Number(queryParams.get('perPage') || DEFAULT_PAGE_SIZE);
      this.perPage = this.pageSizeOptions.includes(requestedPerPage) ? requestedPerPage : DEFAULT_PAGE_SIZE;
      this.currentPage = page;
      const offset = (page - 1) * this.perPage;

      forkJoin({
        count: this.dataService.getAcarsFlightsCount(),
        flights: this.dataService.getAcarsFlights(offset, this.perPage),
      }).subscribe({
        next: ({ count, flights }) => {
          this.totalFlights = count.flights;
          this.totalPages = Math.max(1, Math.ceil(count.flights / this.perPage));
          this.currentPage = Math.min(page, this.totalPages);
          this.pageNumbers = this.buildPageNumbers(this.currentPage, this.totalPages);
          this.flights = flights.flights ?? [];
          this.loading = false;
        },
        error: () => { this.loading = false; }
      });
    });
  }

  toggleMessages(flight: any): void {
    if (this.expandedFlightId === flight.id) {
      this.collapseMessages();
      return;
    }
    this.expandedFlightId = flight.id;
    this.msgCurrentPage = 1;
    this.loadMessages(flight.id, 0);
  }

  private loadMessages(flightId: number, offset: number): void {
    this.messagesLoading = true;
    this.messages = [];
    forkJoin({
      page: this.dataService.getAcarsFlightMessages(flightId, offset, MSG_PAGE_SIZE),
    }).subscribe({
      next: ({ page }) => {
        this.messages = page.messages ?? [];
        this.msgTotal = page.total;
        this.msgTotalPages = Math.max(1, Math.ceil(page.total / MSG_PAGE_SIZE));
        this.msgPageNumbers = this.buildPageNumbers(this.msgCurrentPage, this.msgTotalPages);
        this.messagesLoading = false;
      },
      error: () => { this.messagesLoading = false; }
    });
  }

  collapseMessages(): void {
    this.expandedFlightId = null;
    this.messages = [];
    this.msgCurrentPage = 1;
    this.msgTotalPages = 1;
    this.msgTotal = 0;
    this.msgPageNumbers = [];
  }

  goToMsgPage(flightId: number, page: number): void {
    if (page < 1 || page > this.msgTotalPages || page === this.msgCurrentPage) return;
    this.msgCurrentPage = page;
    this.loadMessages(flightId, (page - 1) * MSG_PAGE_SIZE);
  }

  goToPage(page: number): void {
    if (page < 1 || page > this.totalPages || page === this.currentPage) return;

    const commands = page === 1 ? ['/acars'] : ['/acars', page];
    this.router.navigate(commands, {
      queryParams: this.buildAcarsListQueryParams(),
    });
  }

  updatePerPage(perPage: number): void {
    if (!this.pageSizeOptions.includes(perPage)) return;

    this.perPage = perPage;
    this.currentPage = 1;

    this.router.navigate(['/acars'], {
      queryParams: this.buildAcarsListQueryParams(),
    });
  }

  openTextModal(msg: any, event: Event): void {
    event.stopPropagation();
    this.modalText   = msg.text || '';
    this.modalMsgNo  = msg.message_no || '';
    this.modalLabel  = msg.label || '';
    this.modalTime   = msg.time || '';
  }

  truncate(text: string, max = 50): string {
    if (!text) return '—';
    return text.length > max ? text.slice(0, max) + '…' : text;
  }

  get filteredFlights(): any[] {
    const q = this.filterQuery.trim().toLowerCase();
    if (!q) return this.flights;
    return this.flights.filter((f: any) =>
      (f.flight_number || '').toLowerCase().includes(q) ||
      (f.registration || '').toLowerCase().includes(q)
    );
  }

  aircraftTypeIconDataUrl(flight: any): string {
    const klass = this.aircraftClassForFlight(flight);
    const svg = this.svgForAircraftClass(klass, '#f8fafc', '#0f172a');
    return `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
  }

  aircraftTypeLabelForFlight(flight: any): string {
    switch (this.aircraftClassForFlight(flight)) {
      case 'airliner':
        return 'Airliner';
      case 'general_aviation':
        return 'General Aviation';
      case 'helicopter':
        return 'Helicopter';
      case 'military':
        return 'Military';
      case 'glider':
        return 'Glider';
      case 'balloon':
        return 'Balloon';
      case 'uav':
        return 'UAV';
      case 'ground':
        return 'Ground Vehicle';
      case 'space':
        return 'Space Vehicle';
      default:
        return 'Unknown';
    }
  }

  private aircraftClassForFlight(flight: any): string {
    const provided = String(flight?.aircraft_class || '').trim().toLowerCase();
    if (provided && provided !== 'unknown') {
      return provided;
    }

    const callsign = String(flight?.flight_number || '').trim().toUpperCase();
    if (
      callsign.startsWith('RCH') || callsign.startsWith('NAVY') || callsign.startsWith('ARMY') ||
      callsign.startsWith('MC') || callsign.startsWith('VM') || callsign.startsWith('KING')
    ) {
      return 'military';
    }
    if (callsign) {
      return 'airliner';
    }
    return 'unknown';
  }

  private svgForAircraftClass(aircraftClass: string, fill: string, outline: string): string {
    switch (aircraftClass) {
      case 'helicopter':
        return this.helicopterSvg(fill, outline);
      case 'military':
        return this.militaryJetSvg(fill, outline);
      case 'glider':
        return this.gliderSvg(fill, outline);
      case 'balloon':
        return this.balloonSvg(fill, outline);
      case 'uav':
        return this.uavSvg(fill, outline);
      case 'ground':
        return this.groundVehicleSvg(fill, outline);
      case 'general_aviation':
        return this.generalAviationSvg(fill, outline);
      case 'unknown':
        return this.unknownAircraftSvg(fill, outline);
      default:
        return this.airlinerSvg(fill, outline);
    }
  }

  private generalAviationSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 50" width="36" height="36">` +
      `<path d="M25,3.8 L27.6,11.6 L40.8,16.4 L40.2,19.6 L30,18.7 L27.7,24.2 L27.4,35.9 L31.9,41.8 L29.8,43.6 L25,39.8 L20.2,43.6 L18.1,41.8 L22.6,35.9 L22.3,24.2 L20,18.7 L9.8,19.6 L9.2,16.4 L22.4,11.6 Z"` +
      ` fill="${fill}" stroke="${outline}" stroke-width="1" stroke-linejoin="round"/>` +
      `<circle cx="25" cy="4.8" r="1.1" fill="${fill}" stroke="${outline}" stroke-width="0.8"/>` +
      `</svg>`;
  }

  private airlinerSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 50" width="40" height="40">` +
      `<path d="M25,2 L29,16 L46,24 L44,27 L29,21 L28,36 L34,43 L32,45 L25,40 L18,45 L16,43 L22,36 L21,21 L6,27 L4,24 L21,16 Z"` +
      ` fill="${fill}" stroke="${outline}" stroke-width="1" stroke-linejoin="round"/>` +
      `</svg>`;
  }

  private militaryJetSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 50" width="40" height="40">` +
      `<path d="M25,2 L28,14 L28,24 L47,34 L45,37 L28,28 L27,44 L29,47 L25,48 L21,47 L23,44 L22,28 L5,37 L3,34 L22,24 L22,14 Z"` +
      ` fill="${fill}" stroke="${outline}" stroke-width="1" stroke-linejoin="round"/>` +
      `</svg>`;
  }

  private helicopterSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 54" width="42" height="46">` +
      `<ellipse cx="25" cy="29" rx="7" ry="11" fill="${fill}" stroke="${outline}" stroke-width="1"/>` +
      `<rect x="23.5" y="39" width="3" height="11" rx="1" fill="${fill}"/>` +
      `<rect x="18" y="47" width="14" height="3" rx="1.5" fill="${fill}"/>` +
      `<g transform="rotate(45 25 23)">` +
      `<rect x="3" y="21" width="44" height="4" rx="2" fill="${fill}" stroke="${outline}" stroke-width="0.5"/>` +
      `<rect x="23" y="3" width="4" height="40" rx="2" fill="${fill}" stroke="${outline}" stroke-width="0.5"/>` +
      `</g>` +
      `<circle cx="25" cy="23" r="4.5" fill="${fill}" stroke="${outline}" stroke-width="1"/>` +
      `</svg>`;
  }

  private gliderSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 46" width="52" height="40">` +
      `<ellipse cx="30" cy="24" rx="2.5" ry="18" fill="${fill}" stroke="${outline}" stroke-width="0.5"/>` +
      `<path d="M30,22 L2,26 L2,29 L30,25 L58,29 L58,26 Z" fill="${fill}" stroke="${outline}" stroke-width="0.5" stroke-linejoin="round"/>` +
      `<rect x="20" y="38" width="20" height="3.5" rx="1.75" fill="${fill}" stroke="${outline}" stroke-width="0.5"/>` +
      `</svg>`;
  }

  private balloonSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 50" width="36" height="36">` +
      `<circle cx="25" cy="25" r="22" fill="${fill}" stroke="${outline}" stroke-width="1"/>` +
      `</svg>`;
  }

  private uavSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 50" width="40" height="40">` +
      `<line x1="25" y1="25" x2="10" y2="10" stroke="${fill}" stroke-width="3.5" stroke-linecap="round"/>` +
      `<line x1="25" y1="25" x2="40" y2="10" stroke="${fill}" stroke-width="3.5" stroke-linecap="round"/>` +
      `<line x1="25" y1="25" x2="10" y2="40" stroke="${fill}" stroke-width="3.5" stroke-linecap="round"/>` +
      `<line x1="25" y1="25" x2="40" y2="40" stroke="${fill}" stroke-width="3.5" stroke-linecap="round"/>` +
      `<circle cx="10" cy="10" r="6.5" fill="${fill}" stroke="${outline}" stroke-width="1"/>` +
      `<circle cx="40" cy="10" r="6.5" fill="${fill}" stroke="${outline}" stroke-width="1"/>` +
      `<circle cx="10" cy="40" r="6.5" fill="${fill}" stroke="${outline}" stroke-width="1"/>` +
      `<circle cx="40" cy="40" r="6.5" fill="${fill}" stroke="${outline}" stroke-width="1"/>` +
      `<rect x="19" y="19" width="12" height="12" rx="3" fill="${fill}" stroke="${outline}" stroke-width="1"/>` +
      `</svg>`;
  }

  private groundVehicleSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 50" width="36" height="36">` +
      `<rect x="13" y="7" width="24" height="36" rx="4" fill="${fill}" stroke="${outline}" stroke-width="1"/>` +
      `<rect x="8" y="10" width="6" height="11" rx="3" fill="${fill}" stroke="${outline}" stroke-width="0.5"/>` +
      `<rect x="36" y="10" width="6" height="11" rx="3" fill="${fill}" stroke="${outline}" stroke-width="0.5"/>` +
      `<rect x="8" y="29" width="6" height="11" rx="3" fill="${fill}" stroke="${outline}" stroke-width="0.5"/>` +
      `<rect x="36" y="29" width="6" height="11" rx="3" fill="${fill}" stroke="${outline}" stroke-width="0.5"/>` +
      `</svg>`;
  }

  private unknownAircraftSvg(fill: string, outline: string): string {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 50 50" width="36" height="36">` +
      `<g fill="${fill}" stroke="${outline}" stroke-width="1" stroke-linejoin="round">` +
      `<path d="M25,4 C26.5,4 28,14 28,24 C28,36 26.5,45 25,48 C23.5,45 22,36 22,24 C22,14 23.5,4 25,4 Z"/>` +
      `<path d="M28,22 L42,32 L40,36 L25,26 L10,36 L8,32 L22,22 Z"/>` +
      `<path d="M25,44 L32,48 L31,49 L25,46 L19,49 L18,48 Z"/>` +
      `</g>` +
      `</svg>`;
  }

  private buildPageNumbers(current: number, total: number): number[] {
    if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1);
    const pages = new Set<number>();
    pages.add(1);
    pages.add(total);
    for (let i = Math.max(1, current - 2); i <= Math.min(total, current + 2); i++) pages.add(i);
    return Array.from(pages).sort((a, b) => a - b);
  }

  private buildAcarsListQueryParams(): { perPage?: number } {
    const queryParams: { perPage?: number } = {};
    if (this.perPage !== DEFAULT_PAGE_SIZE) {
      queryParams.perPage = this.perPage;
    }
    return queryParams;
  }
}

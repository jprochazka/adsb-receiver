import { Component, OnInit, inject } from '@angular/core';

import { ActivatedRoute, Router } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { forkJoin } from 'rxjs';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

const PAGE_SIZE = 50;
const MSG_PAGE_SIZE = 25;

@Component({
  selector: 'app-acars',
  standalone: true,
  imports: [FormsModule, SpinnerComponent],
  templateUrl: './acars.component.html',
  styleUrl: './acars.component.scss'
})
export class AcarsComponent implements OnInit {
  flights: any[] = [];
  loading = true;
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
    this.route.paramMap.subscribe((params) => {
      this.loading = true;
      this.collapseMessages();

      const page = Math.max(1, parseInt(params.get('page') || '1', 10) || 1);
      this.currentPage = page;
      const offset = (page - 1) * PAGE_SIZE;

      forkJoin({
        count: this.dataService.getAcarsFlightsCount(),
        flights: this.dataService.getAcarsFlights(offset, PAGE_SIZE),
      }).subscribe({
        next: ({ count, flights }) => {
          this.totalFlights = count.flights;
          this.totalPages = Math.max(1, Math.ceil(count.flights / PAGE_SIZE));
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
    this.router.navigate(['/acars', page]);
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

  private buildPageNumbers(current: number, total: number): number[] {
    if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1);
    const pages = new Set<number>();
    pages.add(1);
    pages.add(total);
    for (let i = Math.max(1, current - 2); i <= Math.min(total, current + 2); i++) pages.add(i);
    return Array.from(pages).sort((a, b) => a - b);
  }
}

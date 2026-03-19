import { Component, OnInit, inject } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';
import { forkJoin, combineLatest } from 'rxjs';

const PAGE_SIZE = 50;

@Component({
  selector: 'app-flights',
  standalone: true,
  imports: [NgFor, NgIf, SpinnerComponent, RouterLink],
  templateUrl: './flights.component.html',
  styleUrl: './flights.component.scss'
})
export class FlightsComponent implements OnInit {
  data: any;
  loading = true;
  searchQuery = '';

  // Pagination state
  currentPage = 1;
  totalPages = 1;
  totalFlights = 0;
  pageSize = PAGE_SIZE;
  pageNumbers: number[] = [];

  private route = inject(ActivatedRoute);
  private router = inject(Router);

  constructor(private data_service: DataService) {}

  ngOnInit() {
    combineLatest([
      this.route.paramMap,
      this.route.queryParamMap
    ]).subscribe(([params, queryParams]) => {
      const q = queryParams.get('q') || '';
      this.searchQuery = q;
      this.loading = true;

      if (q) {
        this.data_service.searchFlights(q).subscribe({
          next: (flights) => {
            this.data = flights;
            this.totalFlights = flights.count;
            this.totalPages = 1;
            this.currentPage = 1;
            this.pageNumbers = [];
            this.loading = false;
          },
          error: () => { this.loading = false; }
        });
      } else {
        const page = Math.max(1, parseInt(params.get('page') || '1', 10) || 1);
        this.currentPage = page;
        const offset = (page - 1) * PAGE_SIZE;

        forkJoin({
          count: this.data_service.GetFlightsCount(),
          flights: this.data_service.getFlights(offset, PAGE_SIZE)
        }).subscribe({
          next: ({ count, flights }) => {
            this.totalFlights = count.flights;
            this.totalPages = Math.max(1, Math.ceil(count.flights / PAGE_SIZE));
            this.currentPage = Math.min(page, this.totalPages);
            this.pageNumbers = this.buildPageNumbers(this.currentPage, this.totalPages);
            this.data = flights;
            this.loading = false;
          },
          error: () => { this.loading = false; }
        });
      }
    });
  }

  goToPage(page: number) {
    if (page < 1 || page > this.totalPages || page === this.currentPage) return;
    this.router.navigate(['/flights', page]);
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

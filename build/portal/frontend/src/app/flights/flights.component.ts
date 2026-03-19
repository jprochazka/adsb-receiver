import { Component, OnInit, inject } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';
import { forkJoin } from 'rxjs';

@Component({
  selector: 'app-flights',
  standalone: true,
  imports: [NgFor, NgIf, SpinnerComponent],
  templateUrl: './flights.component.html',
  styleUrl: './flights.component.scss'
})
export class FlightsComponent implements OnInit  {
  count: any;
  data: any;
  loading = true;
  searchQuery = '';

  private route = inject(ActivatedRoute);

  constructor(private data_service: DataService) {}

  ngOnInit() {
    this.route.queryParamMap.subscribe(params => {
      const q = params.get('q') || '';
      this.searchQuery = q;
      this.loading = true;

      if (q) {
        this.data_service.searchFlights(q).subscribe({
          next: (flights) => {
            this.data = flights;
            this.count = null;
            this.loading = false;
          },
          error: () => { this.loading = false; }
        });
      } else {
        forkJoin({
          count: this.data_service.GetFlightsCount(),
          flights: this.data_service.getFlights()
        }).subscribe({
          next: ({ count, flights }) => {
            this.count = count;
            this.data = flights;
            this.loading = false;
          },
          error: () => { this.loading = false; }
        });
      }
    });
  }
}

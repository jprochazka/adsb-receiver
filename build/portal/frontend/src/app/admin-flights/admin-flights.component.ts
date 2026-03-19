import { Component, OnInit } from '@angular/core';
import { NgIf } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

@Component({
  selector: 'app-admin-flights',
  standalone: true,
  imports: [NgIf, FormsModule, SpinnerComponent],
  templateUrl: './admin-flights.component.html',
  styleUrl: './admin-flights.component.scss'
})
export class AdminFlightsComponent implements OnInit {
  totalFlights = 0;
  loading = true;
  errorMessage = '';
  successMessage = '';

  purgeDays = 30;
  purging = false;
  purgeConfirm = false;

  constructor(private dataService: DataService) {}

  ngOnInit() {
    this.loadStats();
  }

  loadStats() {
    this.loading = true;
    this.errorMessage = '';
    this.dataService.GetFlightsCount().subscribe({
      next: (data) => {
        this.totalFlights = data.flights;
        this.loading = false;
      },
      error: () => {
        this.errorMessage = 'Failed to load flight statistics.';
        this.loading = false;
      }
    });
  }

  requestPurge() {
    this.purgeConfirm = true;
    this.successMessage = '';
    this.errorMessage = '';
  }

  cancelPurge() {
    this.purgeConfirm = false;
  }

  confirmPurge() {
    this.purging = true;
    this.purgeConfirm = false;
    this.dataService.purgeFlights(this.purgeDays).subscribe({
      next: (result) => {
        this.purging = false;
        this.successMessage = `Purge complete: ${result.deleted_flights} flight(s) and ${result.deleted_positions} position(s) deleted (cutoff: ${result.cutoff_date}).`;
        this.loadStats();
      },
      error: () => {
        this.purging = false;
        this.errorMessage = 'Failed to purge flights. Ensure you are logged in as an Admin.';
      }
    });
  }
}

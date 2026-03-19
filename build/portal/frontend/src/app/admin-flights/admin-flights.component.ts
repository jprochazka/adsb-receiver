import { Component, OnInit } from '@angular/core';
import { NgIf } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { catchError, of } from 'rxjs';
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

  flightsNavEnabled = true;
  blogNavEnabled    = true;
  savingNav = false;
  navSuccessMessage = '';
  navErrorMessage = '';

  purgeDays = 30;
  purging = false;
  purgeConfirm = false;

  constructor(private dataService: DataService) {}

  ngOnInit() {
    this.loadNavSetting();
    this.loadStats();
  }

  loadNavSetting() {
    this.dataService.getSetting('flights_nav_enabled').pipe(catchError(() => of({ value: 'true' }))).subscribe(res => {
      this.flightsNavEnabled = res?.value !== 'false';
    });
    this.dataService.getSetting('blog_nav_enabled').pipe(catchError(() => of({ value: 'true' }))).subscribe(res => {
      this.blogNavEnabled = res?.value !== 'false';
    });
  }

  saveNavSetting() {
    this.savingNav = true;
    this.navSuccessMessage = '';
    this.navErrorMessage = '';
    Promise.all([
      this.dataService.updateSetting('flights_nav_enabled', String(this.flightsNavEnabled)).toPromise(),
      this.dataService.updateSetting('blog_nav_enabled',    String(this.blogNavEnabled)).toPromise(),
    ]).then(() => {
      this.savingNav = false;
      this.navSuccessMessage = 'Flights management settings saved successfully.';
    }).catch(() => {
      this.savingNav = false;
      this.navErrorMessage = 'Failed to save settings.';
    });
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

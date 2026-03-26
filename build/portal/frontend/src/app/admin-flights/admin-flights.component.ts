import { Component, OnInit } from '@angular/core';

import { FormsModule } from '@angular/forms';
import { catchError, of } from 'rxjs';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

@Component({
  selector: 'app-admin-flights',
  standalone: true,
  imports: [FormsModule, SpinnerComponent],
  templateUrl: './admin-flights.component.html',
  styleUrl: './admin-flights.component.scss'
})
export class AdminFlightsComponent implements OnInit {
  totalFlights = 0;
  totalUatFlights = 0;
  dbSize = '';
  diskUsage = '';
  diskPercent = 0;
  loading = true;
  errorMessage = '';
  successMessage = '';

  flightsNavEnabled = true;
  allTabEnabled  = true;
  adsbTabEnabled = true;
  uatTabEnabled  = true;

  purgeDays = 30;
  purging = false;
  purgeConfirm = false;

  uatPurgeDays = 30;
  uatPurging = false;
  uatPurgeConfirm = false;
  uatSuccessMessage = '';
  uatErrorMessage = '';

  constructor(private dataService: DataService) {}

  ngOnInit() {
    this.loadNavSetting();
    this.loadStats();
  }

  loadNavSetting() {
    this.dataService.getSetting('flights_nav_enabled').pipe(catchError(() => of({ value: 'true' }))).subscribe(res => {
      this.flightsNavEnabled = res?.value !== 'false';
    });
    this.dataService.getSetting('all_tab_enabled').pipe(catchError(() => of({ value: 'true' }))).subscribe(res => {
      this.allTabEnabled = res?.value !== 'false';
    });
    this.dataService.getSetting('adsb_tab_enabled').pipe(catchError(() => of({ value: 'true' }))).subscribe(res => {
      this.adsbTabEnabled = res?.value !== 'false';
    });
    this.dataService.getSetting('uat_tab_enabled').pipe(catchError(() => of({ value: 'true' }))).subscribe(res => {
      this.uatTabEnabled = res?.value !== 'false';
    });
  }

  saveFlightsNavEnabled() {
    this.dataService.updateSetting('flights_nav_enabled', String(this.flightsNavEnabled)).subscribe();
  }

  saveAllTabEnabled() {
    this.dataService.updateSetting('all_tab_enabled', String(this.allTabEnabled)).subscribe();
  }

  saveAdsbTabEnabled() {
    this.dataService.updateSetting('adsb_tab_enabled', String(this.adsbTabEnabled)).subscribe();
  }

  saveUatTabEnabled() {
    this.dataService.updateSetting('uat_tab_enabled', String(this.uatTabEnabled)).subscribe();
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
    this.dataService.getUatFlightsCount().pipe(catchError(() => of(null))).subscribe(data => {
      this.totalUatFlights = data?.flights ?? 0;
    });
    this.dataService.getSystemDatabase().pipe(catchError(() => of(null))).subscribe(data => {
      const bytes = data?.size ?? 0;
      if (bytes >= 1073741824) {
        this.dbSize = (bytes / 1073741824).toFixed(2) + ' GB';
      } else if (bytes >= 1048576) {
        this.dbSize = (bytes / 1048576).toFixed(2) + ' MB';
      } else if (bytes >= 1024) {
        this.dbSize = (bytes / 1024).toFixed(2) + ' KB';
      } else {
        this.dbSize = bytes + ' B';
      }
    });
    this.dataService.getSystemDisk().pipe(catchError(() => of(null))).subscribe(data => {
      if (data) {
        const fmt = (b: number) => b >= 1073741824 ? (b / 1073741824).toFixed(1) + ' GB'
          : b >= 1048576 ? (b / 1048576).toFixed(1) + ' MB'
          : b >= 1024 ? (b / 1024).toFixed(1) + ' KB' : b + ' B';
        this.diskUsage = fmt(data.disk_usage_used) + ' / ' + fmt(data.disk_usage_total);
        this.diskPercent = Math.round(data.disk_usage_percent ?? 0);
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

  requestUatPurge() {
    this.uatPurgeConfirm = true;
    this.uatSuccessMessage = '';
    this.uatErrorMessage = '';
  }

  cancelUatPurge() {
    this.uatPurgeConfirm = false;
  }

  confirmUatPurge() {
    this.uatPurging = true;
    this.uatPurgeConfirm = false;
    this.dataService.purgeUatFlights(this.uatPurgeDays).subscribe({
      next: (result) => {
        this.uatPurging = false;
        this.uatSuccessMessage = `Purge complete: ${result.deleted_flights} flight(s) and ${result.deleted_positions} position(s) deleted (cutoff: ${result.cutoff_date}).`;
        this.loadStats();
      },
      error: () => {
        this.uatPurging = false;
        this.uatErrorMessage = 'Failed to purge UAT flights. Ensure you are logged in as an Admin.';
      }
    });
  }
}

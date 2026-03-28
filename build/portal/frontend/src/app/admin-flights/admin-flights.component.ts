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
  flightsTableSize = '';
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

  ignoredPageSize = 10;

  ignoredAdsbFlights: any[] = [];
  ignoredAdsbOffset = 0;
  ignoredAdsbTotal = 0;
  ignoredAdsbLoading = false;
  ignoredAdsbError = '';
  private ignoredAdsbSaving = new Set<string>();

  ignoredUatFlights: any[] = [];
  ignoredUatOffset = 0;
  ignoredUatTotal = 0;
  ignoredUatLoading = false;
  ignoredUatError = '';
  private ignoredUatSaving = new Set<string>();

  constructor(private dataService: DataService) {}

  ngOnInit() {
    this.loadNavSetting();
    this.loadStats();
    this.loadIgnoredAdsbFlights();
    this.loadIgnoredUatFlights();
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
    this.dataService.getSystemFlightsTables().pipe(catchError(() => of(null))).subscribe(data => {
      const bytes = data?.size ?? 0;
      if (bytes >= 1073741824) {
        this.flightsTableSize = (bytes / 1073741824).toFixed(2) + ' GB';
      } else if (bytes >= 1048576) {
        this.flightsTableSize = (bytes / 1048576).toFixed(2) + ' MB';
      } else if (bytes >= 1024) {
        this.flightsTableSize = (bytes / 1024).toFixed(2) + ' KB';
      } else {
        this.flightsTableSize = bytes + ' B';
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

  loadIgnoredAdsbFlights() {
    this.ignoredAdsbLoading = true;
    this.ignoredAdsbError = '';

    this.dataService.getIgnoredFlights(this.ignoredAdsbOffset, this.ignoredPageSize).subscribe({
      next: (res) => {
        this.ignoredAdsbFlights = res?.flights ?? [];
        this.ignoredAdsbTotal = res?.total ?? this.ignoredAdsbFlights.length;
        this.ignoredAdsbLoading = false;

        if (this.ignoredAdsbTotal > 0 && this.ignoredAdsbOffset >= this.ignoredAdsbTotal) {
          this.ignoredAdsbOffset = Math.max(0, this.ignoredAdsbOffset - this.ignoredPageSize);
          this.loadIgnoredAdsbFlights();
        }
      },
      error: () => {
        this.ignoredAdsbLoading = false;
        this.ignoredAdsbError = 'Failed to load ADS-B ignored flights.';
      }
    });
  }

  loadIgnoredUatFlights() {
    this.ignoredUatLoading = true;
    this.ignoredUatError = '';

    this.dataService.getIgnoredUatFlights(this.ignoredUatOffset, this.ignoredPageSize).subscribe({
      next: (res) => {
        this.ignoredUatFlights = res?.flights ?? [];
        this.ignoredUatTotal = res?.total ?? this.ignoredUatFlights.length;
        this.ignoredUatLoading = false;

        if (this.ignoredUatTotal > 0 && this.ignoredUatOffset >= this.ignoredUatTotal) {
          this.ignoredUatOffset = Math.max(0, this.ignoredUatOffset - this.ignoredPageSize);
          this.loadIgnoredUatFlights();
        }
      },
      error: () => {
        this.ignoredUatLoading = false;
        this.ignoredUatError = 'Failed to load UAT ignored flights.';
      }
    });
  }

  adsbIgnoredStart() {
    return this.ignoredAdsbTotal === 0 ? 0 : this.ignoredAdsbOffset + 1;
  }

  adsbIgnoredEnd() {
    return Math.min(this.ignoredAdsbOffset + this.ignoredPageSize, this.ignoredAdsbTotal);
  }

  uatIgnoredStart() {
    return this.ignoredUatTotal === 0 ? 0 : this.ignoredUatOffset + 1;
  }

  uatIgnoredEnd() {
    return Math.min(this.ignoredUatOffset + this.ignoredPageSize, this.ignoredUatTotal);
  }

  prevIgnoredAdsbPage() {
    if (this.ignoredAdsbOffset === 0 || this.ignoredAdsbLoading) {
      return;
    }
    this.ignoredAdsbOffset = Math.max(0, this.ignoredAdsbOffset - this.ignoredPageSize);
    this.loadIgnoredAdsbFlights();
  }

  nextIgnoredAdsbPage() {
    if (this.ignoredAdsbLoading || this.ignoredAdsbOffset + this.ignoredPageSize >= this.ignoredAdsbTotal) {
      return;
    }
    this.ignoredAdsbOffset += this.ignoredPageSize;
    this.loadIgnoredAdsbFlights();
  }

  prevIgnoredUatPage() {
    if (this.ignoredUatOffset === 0 || this.ignoredUatLoading) {
      return;
    }
    this.ignoredUatOffset = Math.max(0, this.ignoredUatOffset - this.ignoredPageSize);
    this.loadIgnoredUatFlights();
  }

  nextIgnoredUatPage() {
    if (this.ignoredUatLoading || this.ignoredUatOffset + this.ignoredPageSize >= this.ignoredUatTotal) {
      return;
    }
    this.ignoredUatOffset += this.ignoredPageSize;
    this.loadIgnoredUatFlights();
  }

  isSavingIgnoredAdsb(flight: string) {
    return this.ignoredAdsbSaving.has(flight);
  }

  isSavingIgnoredUat(flight: string) {
    return this.ignoredUatSaving.has(flight);
  }

  updateIgnoredAdsbFlight(flight: any, event: Event) {
    const target = event.target as HTMLInputElement | null;
    if (!target) {
      return;
    }

    const ignoreOnPurge = target.checked;
    this.ignoredAdsbSaving.add(flight.flight);
    this.ignoredAdsbError = '';

    this.dataService.updateFlightPurgePreference(flight.flight, ignoreOnPurge).subscribe({
      next: () => {
        this.ignoredAdsbSaving.delete(flight.flight);
        this.loadIgnoredAdsbFlights();
      },
      error: () => {
        this.ignoredAdsbSaving.delete(flight.flight);
        this.ignoredAdsbError = `Failed to update purge preference for ADS-B flight ${flight.flight}.`;
        this.loadIgnoredAdsbFlights();
      }
    });
  }

  updateIgnoredUatFlight(flight: any, event: Event) {
    const target = event.target as HTMLInputElement | null;
    if (!target) {
      return;
    }

    const ignoreOnPurge = target.checked;
    this.ignoredUatSaving.add(flight.flight);
    this.ignoredUatError = '';

    this.dataService.updateUatFlightPurgePreference(flight.flight, ignoreOnPurge).subscribe({
      next: () => {
        this.ignoredUatSaving.delete(flight.flight);
        this.loadIgnoredUatFlights();
      },
      error: () => {
        this.ignoredUatSaving.delete(flight.flight);
        this.ignoredUatError = `Failed to update purge preference for UAT flight ${flight.flight}.`;
        this.loadIgnoredUatFlights();
      }
    });
  }
}

import { Component, OnInit } from '@angular/core';

import { FormsModule } from '@angular/forms';
import { HttpErrorResponse } from '@angular/common/http';
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

  readonly pageSizeOptions = [10, 25, 50, 100];
  ignoredAdsbPageSize = 10;
  ignoredUatPageSize = 10;

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

  openSkyStatus: any = null;
  openSkyLoading = false;
  openSkyUpdating = false;
  openSkyError = '';
  openSkySuccess = '';

  constructor(private dataService: DataService) {}

  ngOnInit() {
    this.loadNavSetting();
    this.loadStats();
    this.loadIgnoredAdsbFlights();
    this.loadIgnoredUatFlights();
    this.loadOpenSkyAircraftDatabaseStatus();
  }

  loadOpenSkyAircraftDatabaseStatus() {
    this.openSkyLoading = true;
    this.openSkyError = '';

    this.dataService.getOpenSkyAircraftDatabaseStatus().subscribe({
      next: (status) => {
        this.openSkyStatus = status;
        this.openSkyLoading = false;
      },
      error: (err: HttpErrorResponse) => {
        this.openSkyLoading = false;
        if (err.status === 404 && err.error) {
          this.openSkyStatus = err.error;
          return;
        }
        this.openSkyError = this.buildOpenSkyErrorMessage(err, 'load OpenSky aircraft database status');
      }
    });
  }

  updateOpenSkyAircraftDatabase() {
    this.openSkyUpdating = true;
    this.openSkyError = '';
    this.openSkySuccess = '';

    this.dataService.updateOpenSkyAircraftDatabase().subscribe({
      next: (status) => {
        this.openSkyStatus = status;
        this.openSkyUpdating = false;
        this.openSkySuccess = 'OpenSky aircraft database updated successfully.';
      },
      error: (err: HttpErrorResponse) => {
        this.openSkyUpdating = false;
        this.openSkyError = this.buildOpenSkyErrorMessage(err, 'update OpenSky aircraft database');
      }
    });
  }

  private buildOpenSkyErrorMessage(err: HttpErrorResponse, action: string): string {
    const backendMessage = typeof err.error?.msg === 'string' ? err.error.msg.trim() : '';
    if (backendMessage) {
      return `Failed to ${action}: ${backendMessage}.`;
    }

    if (err.status === 401) {
      return `Failed to ${action}: authentication required.`;
    }

    if (err.status === 403) {
      return `Failed to ${action}: admin access required.`;
    }

    return `Failed to ${action}: unexpected server error.`;
  }

  formatByteSize(bytes: number | null | undefined): string {
    if (bytes == null || Number.isNaN(bytes)) {
      return 'Unknown';
    }
    if (bytes >= 1073741824) {
      return `${(bytes / 1073741824).toFixed(2)} GB`;
    }
    if (bytes >= 1048576) {
      return `${(bytes / 1048576).toFixed(2)} MB`;
    }
    if (bytes >= 1024) {
      return `${(bytes / 1024).toFixed(2)} KB`;
    }
    return `${bytes} B`;
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
    this.saveSetting('flights_nav_enabled', String(this.flightsNavEnabled));
  }

  saveAllTabEnabled() {
    this.saveSetting('all_tab_enabled', String(this.allTabEnabled));
  }

  saveAdsbTabEnabled() {
    this.saveSetting('adsb_tab_enabled', String(this.adsbTabEnabled));
  }

  saveUatTabEnabled() {
    this.saveSetting('uat_tab_enabled', String(this.uatTabEnabled));
  }

  private saveSetting(key: string, value: string): void {
    this.errorMessage = '';
    this.successMessage = '';

    this.dataService.updateSetting(key, value).subscribe({
      next: () => { this.successMessage = 'Setting saved.'; },
      error: () => { this.errorMessage = 'Failed to save setting.'; },
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

    this.dataService.getIgnoredFlights(this.ignoredAdsbOffset, this.ignoredAdsbPageSize).subscribe({
      next: (res) => {
        this.ignoredAdsbFlights = res?.flights ?? [];
        this.ignoredAdsbTotal = res?.total ?? this.ignoredAdsbFlights.length;
        this.ignoredAdsbLoading = false;

        if (this.ignoredAdsbTotal > 0 && this.ignoredAdsbOffset >= this.ignoredAdsbTotal) {
          this.ignoredAdsbOffset = Math.max(0, this.ignoredAdsbOffset - this.ignoredAdsbPageSize);
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

    this.dataService.getIgnoredUatFlights(this.ignoredUatOffset, this.ignoredUatPageSize).subscribe({
      next: (res) => {
        this.ignoredUatFlights = res?.flights ?? [];
        this.ignoredUatTotal = res?.total ?? this.ignoredUatFlights.length;
        this.ignoredUatLoading = false;

        if (this.ignoredUatTotal > 0 && this.ignoredUatOffset >= this.ignoredUatTotal) {
          this.ignoredUatOffset = Math.max(0, this.ignoredUatOffset - this.ignoredUatPageSize);
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
    return Math.min(this.ignoredAdsbOffset + this.ignoredAdsbPageSize, this.ignoredAdsbTotal);
  }

  uatIgnoredStart() {
    return this.ignoredUatTotal === 0 ? 0 : this.ignoredUatOffset + 1;
  }

  uatIgnoredEnd() {
    return Math.min(this.ignoredUatOffset + this.ignoredUatPageSize, this.ignoredUatTotal);
  }

  prevIgnoredAdsbPage() {
    if (this.ignoredAdsbOffset === 0 || this.ignoredAdsbLoading) {
      return;
    }
    this.ignoredAdsbOffset = Math.max(0, this.ignoredAdsbOffset - this.ignoredAdsbPageSize);
    this.loadIgnoredAdsbFlights();
  }

  nextIgnoredAdsbPage() {
    if (this.ignoredAdsbLoading || this.ignoredAdsbOffset + this.ignoredAdsbPageSize >= this.ignoredAdsbTotal) {
      return;
    }
    this.ignoredAdsbOffset += this.ignoredAdsbPageSize;
    this.loadIgnoredAdsbFlights();
  }

  prevIgnoredUatPage() {
    if (this.ignoredUatOffset === 0 || this.ignoredUatLoading) {
      return;
    }
    this.ignoredUatOffset = Math.max(0, this.ignoredUatOffset - this.ignoredUatPageSize);
    this.loadIgnoredUatFlights();
  }

  nextIgnoredUatPage() {
    if (this.ignoredUatLoading || this.ignoredUatOffset + this.ignoredUatPageSize >= this.ignoredUatTotal) {
      return;
    }
    this.ignoredUatOffset += this.ignoredUatPageSize;
    this.loadIgnoredUatFlights();
  }

  updateIgnoredAdsbPageSize(pageSize: number) {
    this.ignoredAdsbPageSize = pageSize;
    this.ignoredAdsbOffset = 0;
    this.loadIgnoredAdsbFlights();
  }

  updateIgnoredUatPageSize(pageSize: number) {
    this.ignoredUatPageSize = pageSize;
    this.ignoredUatOffset = 0;
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

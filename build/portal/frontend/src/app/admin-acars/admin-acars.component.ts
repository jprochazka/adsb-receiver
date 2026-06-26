import { Component, OnInit, ChangeDetectionStrategy } from '@angular/core';

import { FormsModule } from '@angular/forms';
import { catchError, of } from 'rxjs';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

@Component({
  selector: 'app-admin-acars',
  standalone: true,
  imports: [FormsModule, SpinnerComponent],
  templateUrl: './admin-acars.component.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './admin-acars.component.scss'
})
export class AdminAcarsComponent implements OnInit {
  acarsNavEnabled = true;

  totalFlights = 0;
  totalMessages = 0;
  dbSize = '';
  acarsDbSize = '';
  diskUsage = '';
  diskPercent = 0;
  loading = true;
  errorMessage = '';
  successMessage = '';

  purgeDays = 30;
  purging = false;
  purgeConfirm = false;

  constructor(private dataService: DataService) {}

  ngOnInit(): void {
    this.dataService.getSetting('acars_nav_enabled').pipe(catchError(() => of({ value: 'true' }))).subscribe(res => {
      this.acarsNavEnabled = res?.value !== 'false';
    });
    this.loadStats();
  }

  saveAcarsNavEnabled(): void {
    this.saveSetting('acars_nav_enabled', String(this.acarsNavEnabled));
  }

  private saveSetting(key: string, value: string): void {
    this.errorMessage = '';
    this.successMessage = '';

    this.dataService.updateSetting(key, value).subscribe({
      next: () => { this.successMessage = 'Setting saved.'; },
      error: () => { this.errorMessage = 'Failed to save setting.'; },
    });
  }

  loadStats(): void {
    this.loading = true;
    this.dataService.getAcarsFlightsCount().pipe(catchError(() => of(null))).subscribe(data => {
      this.totalFlights = data?.flights ?? 0;
      this.loading = false;
    });
    this.dataService.getAcarsMessagesCount().pipe(catchError(() => of(null))).subscribe(data => {
      this.totalMessages = data?.messages ?? 0;
    });
    const fmtBytes = (bytes: number) => {
      if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(2) + ' GB';
      if (bytes >= 1048576) return (bytes / 1048576).toFixed(2) + ' MB';
      if (bytes >= 1024) return (bytes / 1024).toFixed(2) + ' KB';
      return bytes + ' B';
    };
    this.dataService.getSystemDatabase().pipe(catchError(() => of(null))).subscribe(data => {
      this.dbSize = fmtBytes(data?.size ?? 0);
    });
    this.dataService.getAcarsDatabase().pipe(catchError(() => of(null))).subscribe(data => {
      this.acarsDbSize = data ? fmtBytes(data.size) : 'Unavailable';
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

  requestPurge(): void {
    this.purgeConfirm = true;
    this.successMessage = '';
    this.errorMessage = '';
  }

  cancelPurge(): void {
    this.purgeConfirm = false;
  }

  confirmPurge(): void {
    this.purging = true;
    this.purgeConfirm = false;
    this.dataService.purgeAcarsFlights(this.purgeDays).subscribe({
      next: (result) => {
        this.purging = false;
        this.successMessage = `Purge complete: ${result.deleted_flights} flight(s) and ${result.deleted_messages} message(s) deleted (cutoff: ${result.cutoff_date}).`;
        this.loadStats();
      },
      error: () => {
        this.purging = false;
        this.errorMessage = 'Failed to purge ACARS flights. Ensure you are logged in as an Admin.';
      }
    });
  }
}

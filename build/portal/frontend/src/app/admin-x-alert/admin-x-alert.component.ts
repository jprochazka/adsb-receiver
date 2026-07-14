import { ChangeDetectionStrategy, Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { forkJoin } from 'rxjs';

import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

interface XAlertConfig {
  [key: string]: string;
}

interface XAlertStatus {
  last_run: string | null;
  last_result: string;
  last_error: string | null;
  posted_since_start: number;
  dump1090_status: string;
  dump978_status: string;
  last_image_result: string;
  last_image_at: string | null;
}

const DEFAULT_CONFIG: XAlertConfig = {
  x_alert_enabled: 'false',
  x_alert_poll_seconds: '15',
  x_alert_receiver_lat: '',
  x_alert_receiver_lon: '',
  x_alert_radius_nm: '3.0',
  x_alert_min_altitude_ft: '500',
  x_alert_max_altitude_ft: '15000',
  x_alert_min_speed_kt: '80',
  x_alert_cooldown_minutes: '30',
  x_alert_ignore_no_callsign: 'false',
  x_alert_post_mode: 'log-only',
  x_alert_x_api_key: '',
  x_alert_x_api_secret: '',
  x_alert_x_access_token: '',
  x_alert_x_access_secret: '',
  x_alert_image_enabled: 'false',
  x_alert_image_lookback_minutes: '10',
  x_alert_image_width: '1024',
  x_alert_image_height: '768',
  x_alert_image_track_points_max: '150',
  x_alert_image_fallback_text_only: 'true',
};

const EMPTY_STATUS: XAlertStatus = {
  last_run: null,
  last_result: 'never',
  last_error: null,
  posted_since_start: 0,
  dump1090_status: 'unknown',
  dump978_status: 'unknown',
  last_image_result: 'never',
  last_image_at: null,
};

@Component({
  selector: 'app-admin-x-alert',
  standalone: true,
  imports: [FormsModule, SpinnerComponent],
  templateUrl: './admin-x-alert.component.html',
  styleUrl: './admin-x-alert.component.scss',
  changeDetection: ChangeDetectionStrategy.Eager,
})
export class AdminXAlertComponent implements OnInit {
  loading = true;
  busy = false;
  successMessage = '';
  errorMessage = '';
  config: XAlertConfig = { ...DEFAULT_CONFIG };
  savedConfig: XAlertConfig = { ...DEFAULT_CONFIG };
  status: XAlertStatus = { ...EMPTY_STATUS };
  credentials = { api_key: false, api_secret: false, access_token: false, access_secret: false };

  constructor(private dataService: DataService) {}

  ngOnInit(): void {
    this.refresh();
  }

  refresh(): void {
    this.loading = true;
    this.errorMessage = '';
    forkJoin({
      config: this.dataService.getXAlertConfig(),
      status: this.dataService.getXAlertStatus(),
    }).subscribe({
      next: ({ config, status }) => {
        this.credentials = config.credentials ?? this.credentials;
        const { credentials, ...values } = config;
        this.config = { ...DEFAULT_CONFIG, ...values };
        this.savedConfig = { ...this.config };
        this.status = { ...EMPTY_STATUS, ...status };
        this.loading = false;
      },
      error: () => {
        this.errorMessage = 'Failed to load X alert configuration.';
        this.loading = false;
      },
    });
  }

  enabled(): boolean {
    return this.config['x_alert_enabled'] === 'true';
  }

  setEnabled(enabled: boolean): void {
    this.config['x_alert_enabled'] = String(enabled);
  }

  imageEnabled(): boolean {
    return this.config['x_alert_image_enabled'] === 'true';
  }

  setImageEnabled(enabled: boolean): void {
    this.config['x_alert_image_enabled'] = String(enabled);
  }

  ignoreNoCallsign(): boolean {
    return this.config['x_alert_ignore_no_callsign'] === 'true';
  }

  setIgnoreNoCallsign(enabled: boolean): void {
    this.config['x_alert_ignore_no_callsign'] = String(enabled);
  }

  save(): void {
    this.perform(() => this.dataService.updateXAlertConfig(this.config), 'X alert settings saved.', true);
  }

  reset(): void {
    this.config = { ...this.savedConfig };
    this.successMessage = '';
    this.errorMessage = '';
  }

  dryRun(): void {
    this.perform(() => this.dataService.dryRunXAlert(), 'Dry run completed.');
  }

  sendNow(): void {
    this.perform(() => this.dataService.sendXAlert(), 'Manual alert cycle completed.');
  }

  lastRunLabel(): string {
    if (!this.status.last_run) return 'Never';
    const parsed = new Date(this.status.last_run);
    return Number.isNaN(parsed.getTime()) ? this.status.last_run : parsed.toLocaleString();
  }

  lastImageLabel(): string {
    if (!this.status.last_image_at) return 'Never generated';
    const parsed = new Date(this.status.last_image_at);
    const timestamp = Number.isNaN(parsed.getTime()) ? this.status.last_image_at : parsed.toLocaleString();
    return `${this.status.last_image_result} at ${timestamp}`;
  }

  private perform(action: () => any, successMessage: string, reloadConfig = false): void {
    this.busy = true;
    this.successMessage = '';
    this.errorMessage = '';
    action().subscribe({
      next: (response: any) => {
        this.busy = false;
        this.successMessage = successMessage;
        if (reloadConfig) {
          this.credentials = response.credentials ?? this.credentials;
          const { credentials, ...values } = response;
          this.config = { ...DEFAULT_CONFIG, ...values };
          this.savedConfig = { ...this.config };
        }
        this.dataService.getXAlertStatus().subscribe(status => this.status = { ...EMPTY_STATUS, ...status });
      },
      error: (error: any) => {
        this.busy = false;
        this.errorMessage = error?.error?.msg ?? error?.error?.error ?? 'X alert action failed.';
      },
    });
  }
}
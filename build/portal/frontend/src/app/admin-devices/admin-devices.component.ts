import { Component, OnInit } from '@angular/core';

import { FormsModule } from '@angular/forms';
import { forkJoin } from 'rxjs';
import { catchError, of } from 'rxjs';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

@Component({
  selector: 'app-admin-devices',
  standalone: true,
  imports: [FormsModule, SpinnerComponent],
  templateUrl: './admin-devices.component.html',
  styleUrl: './admin-devices.component.scss'
})
export class AdminDevicesComponent implements OnInit {
  loading = true;
  errorMessage = '';
  successMessage = '';

  // Navigation visibility
  infoNavEnabled    = true;
  infoSystemEnabled = true;
  infoGraphsEnabled = true;
  infoStatsEnabled  = true;

  // Graph settings
  dump1090GraphsEnabled  = true;
  dump978GraphsEnabled   = false;
  measurementRange       = 'imperialNautical';
  measurementTemperature = 'imperial';
  networkInterface       = 'eth0';
  graphRefreshIntervalSeconds = 15;

  rangeOptions = [
    { value: 'imperialNautical', label: 'Imperial — Nautical Miles' },
    { value: 'imperialStatute',  label: 'Imperial — Statute Miles'  },
    { value: 'metric',           label: 'Metric — Kilometres'        },
  ];

  temperatureOptions = [
    { value: 'imperial', label: 'Imperial (°F)' },
    { value: 'metric',   label: 'Metric (°C)'   },
  ];

  interfaceOptions = [
    { value: 'eth0',  label: 'eth0  (Ethernet)' },
    { value: 'wlan0', label: 'wlan0 (Wi-Fi)'    },
  ];

  constructor(private dataService: DataService) {}

  ngOnInit(): void {
    forkJoin({
      nav:    this.dataService.getSetting('info_nav_enabled').pipe(catchError(() => of({ value: 'true' }))),
      system: this.dataService.getSetting('info_system_enabled').pipe(catchError(() => of({ value: 'true' }))),
      graphs: this.dataService.getSetting('info_graphs_enabled').pipe(catchError(() => of({ value: 'true' }))),
      stats: this.dataService.getSetting('info_stats_enabled').pipe(catchError(() => of({ value: 'true' }))),
      d1090:  this.dataService.getSetting('graphs_dump1090_enabled').pipe(catchError(() => of({ value: 'true' }))),
      d978:   this.dataService.getSetting('graphs_dump978_enabled').pipe(catchError(() => of({ value: 'false' }))),
      range:  this.dataService.getSetting('graphs_measurement_range').pipe(catchError(() => of({ value: 'imperialNautical' }))),
      temp:   this.dataService.getSetting('graphs_measurement_temperature').pipe(catchError(() => of({ value: 'imperial' }))),
      iface:  this.dataService.getSetting('graphs_network_interface').pipe(catchError(() => of({ value: 'eth0' }))),
      refresh: this.dataService.getSetting('graphs_refresh_interval_ms').pipe(catchError(() => of({ value: '15000' }))),
    }).subscribe({
      next: ({ nav, system, graphs, stats, d1090, d978, range, temp, iface, refresh }) => {
        this.infoNavEnabled    = nav?.value    !== 'false';
        this.infoSystemEnabled = system?.value !== 'false';
        this.infoGraphsEnabled = graphs?.value !== 'false';
        this.infoStatsEnabled  = stats?.value  !== 'false';
        this.dump1090GraphsEnabled  = d1090?.value !== 'false';
        this.dump978GraphsEnabled   = d978?.value  !== 'false';
        this.measurementRange       = range?.value ?? 'imperialNautical';
        this.measurementTemperature = temp?.value  ?? 'imperial';
        this.networkInterface       = iface?.value ?? 'eth0';
        this.graphRefreshIntervalSeconds = this.msToSeconds(this.normalizeRefreshMs(refresh?.value));
        this.loading = false;
      },
      error: () => {
        this.loading = false;
      }
    });
  }

  saveInfoNavEnabled(): void {
    this.saveSetting('info_nav_enabled', String(this.infoNavEnabled));
  }

  saveInfoSystemEnabled(): void {
    this.saveSetting('info_system_enabled', String(this.infoSystemEnabled));
  }

  saveInfoGraphsEnabled(): void {
    this.saveSetting('info_graphs_enabled', String(this.infoGraphsEnabled));
  }

  saveInfoStatsEnabled(): void {
    this.saveSetting('info_stats_enabled', String(this.infoStatsEnabled));
  }

  saveDump1090GraphsEnabled(): void {
    this.saveSetting('graphs_dump1090_enabled', String(this.dump1090GraphsEnabled));
  }

  saveDump978GraphsEnabled(): void {
    this.saveSetting('graphs_dump978_enabled', String(this.dump978GraphsEnabled));
  }

  saveMeasurementRange(): void {
    this.saveSetting('graphs_measurement_range', this.measurementRange);
  }

  saveMeasurementTemperature(): void {
    this.saveSetting('graphs_measurement_temperature', this.measurementTemperature);
  }

  saveNetworkInterface(): void {
    this.saveSetting('graphs_network_interface', this.networkInterface);
  }

  saveGraphRefreshIntervalSeconds(): void {
    this.graphRefreshIntervalSeconds = this.normalizeRefreshSeconds(this.graphRefreshIntervalSeconds);
    const refreshMs = this.secondsToMs(this.graphRefreshIntervalSeconds);
    this.saveSetting('graphs_refresh_interval_ms', String(refreshMs));
  }

  private saveSetting(key: string, value: string): void {
    this.errorMessage = '';
    this.successMessage = '';

    this.dataService.updateSetting(key, value).subscribe({
      next: () => { this.successMessage = 'Setting saved.'; },
      error: () => { this.errorMessage = 'Failed to save setting.'; },
    });
  }

  private secondsToMs(value: number): number {
    return value * 1000;
  }

  private msToSeconds(value: number): number {
    return Math.round(value / 1000);
  }

  private normalizeRefreshSeconds(value: string | number | null | undefined): number {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) {
      return 15;
    }
    return Math.min(120, Math.max(3, Math.round(parsed)));
  }

  private normalizeRefreshMs(value: string | number | null | undefined): number {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) {
      return 15000;
    }
    return Math.min(120000, Math.max(3000, Math.round(parsed)));
  }
}

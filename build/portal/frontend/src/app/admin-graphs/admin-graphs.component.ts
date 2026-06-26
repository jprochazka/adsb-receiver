import { Component, OnInit, ChangeDetectionStrategy } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

@Component({
  selector: 'app-admin-graphs',
  standalone: true,
  imports: [NgFor, NgIf, FormsModule, SpinnerComponent],
  templateUrl: './admin-graphs.component.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './admin-graphs.component.scss'
})
export class AdminGraphsComponent implements OnInit {
  loading = true;
  saving = false;
  errorMessage = '';
  successMessage = '';

  measurementRange = 'imperialNautical';
  measurementTemperature = 'imperial';
  networkInterface = 'eth0';
  dump978GraphsEnabled = false;

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
      range: this.dataService.getSetting('graphs_measurement_range'),
      temp:  this.dataService.getSetting('graphs_measurement_temperature'),
      iface: this.dataService.getSetting('graphs_network_interface'),
      d978:  this.dataService.getSetting('graphs_dump978_enabled').pipe(catchError(() => of({ value: 'false' }))),
    }).subscribe({
      next: ({ range, temp, iface, d978 }) => {
        this.measurementRange       = range?.value  ?? 'imperialNautical';
        this.measurementTemperature = temp?.value   ?? 'imperial';
        this.networkInterface       = iface?.value  ?? 'eth0';
        this.dump978GraphsEnabled   = d978?.value   !== 'false';
        this.loading = false;
      },
      error: () => {
        this.errorMessage = 'Failed to load settings.';
        this.loading = false;
      }
    });
  }

  save(): void {
    this.saving = true;
    this.errorMessage = '';
    this.successMessage = '';

    forkJoin([
      this.dataService.updateSetting('graphs_measurement_range',       this.measurementRange),
      this.dataService.updateSetting('graphs_measurement_temperature',  this.measurementTemperature),
      this.dataService.updateSetting('graphs_network_interface',        this.networkInterface),
      this.dataService.updateSetting('graphs_dump978_enabled',          String(this.dump978GraphsEnabled)),
    ]).subscribe({
      next: () => {
        this.saving = false;
        this.successMessage = 'Graph settings saved successfully.';
      },
      error: () => {
        this.saving = false;
        this.errorMessage = 'Failed to save settings.';
      }
    });
  }
}

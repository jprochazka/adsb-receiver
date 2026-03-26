import { Component, OnInit } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { forkJoin } from 'rxjs';
import { catchError, of } from 'rxjs';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

@Component({
  selector: 'app-admin-information',
  standalone: true,
  imports: [NgFor, NgIf, FormsModule, SpinnerComponent],
  templateUrl: './admin-information.component.html',
  styleUrl: './admin-information.component.scss'
})
export class AdminInformationComponent implements OnInit {
  loading = true;

  // Navigation visibility
  infoNavEnabled    = true;
  infoSystemEnabled = true;
  infoGraphsEnabled = true;

  // Graph settings
  dump1090GraphsEnabled  = true;
  dump978GraphsEnabled   = false;
  measurementRange       = 'imperialNautical';
  measurementTemperature = 'imperial';
  networkInterface       = 'eth0';

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
      d1090:  this.dataService.getSetting('graphs_dump1090_enabled').pipe(catchError(() => of({ value: 'true' }))),
      d978:   this.dataService.getSetting('graphs_dump978_enabled').pipe(catchError(() => of({ value: 'false' }))),
      range:  this.dataService.getSetting('graphs_measurement_range').pipe(catchError(() => of({ value: 'imperialNautical' }))),
      temp:   this.dataService.getSetting('graphs_measurement_temperature').pipe(catchError(() => of({ value: 'imperial' }))),
      iface:  this.dataService.getSetting('graphs_network_interface').pipe(catchError(() => of({ value: 'eth0' }))),
    }).subscribe({
      next: ({ nav, system, graphs, d1090, d978, range, temp, iface }) => {
        this.infoNavEnabled    = nav?.value    !== 'false';
        this.infoSystemEnabled = system?.value !== 'false';
        this.infoGraphsEnabled = graphs?.value !== 'false';
        this.dump1090GraphsEnabled  = d1090?.value !== 'false';
        this.dump978GraphsEnabled   = d978?.value  !== 'false';
        this.measurementRange       = range?.value ?? 'imperialNautical';
        this.measurementTemperature = temp?.value  ?? 'imperial';
        this.networkInterface       = iface?.value ?? 'eth0';
        this.loading = false;
      },
      error: () => {
        this.loading = false;
      }
    });
  }

  saveInfoNavEnabled(): void {
    this.dataService.updateSetting('info_nav_enabled', String(this.infoNavEnabled)).subscribe();
  }

  saveInfoSystemEnabled(): void {
    this.dataService.updateSetting('info_system_enabled', String(this.infoSystemEnabled)).subscribe();
  }

  saveInfoGraphsEnabled(): void {
    this.dataService.updateSetting('info_graphs_enabled', String(this.infoGraphsEnabled)).subscribe();
  }

  saveDump1090GraphsEnabled(): void {
    this.dataService.updateSetting('graphs_dump1090_enabled', String(this.dump1090GraphsEnabled)).subscribe();
  }

  saveDump978GraphsEnabled(): void {
    this.dataService.updateSetting('graphs_dump978_enabled', String(this.dump978GraphsEnabled)).subscribe();
  }

  saveMeasurementRange(): void {
    this.dataService.updateSetting('graphs_measurement_range', this.measurementRange).subscribe();
  }

  saveMeasurementTemperature(): void {
    this.dataService.updateSetting('graphs_measurement_temperature', this.measurementTemperature).subscribe();
  }

  saveNetworkInterface(): void {
    this.dataService.updateSetting('graphs_network_interface', this.networkInterface).subscribe();
  }
}

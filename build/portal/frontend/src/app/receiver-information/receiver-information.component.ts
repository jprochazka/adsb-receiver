import { Component, OnInit } from '@angular/core';

import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

const PERIODS = [
  { label: 'Hourly',     value: '1h'   },
  { label: 'Six Hours',  value: '6h'   },
  { label: 'Daily',      value: '24h'  },
  { label: 'Weekly',     value: '7d'   },
  { label: 'Monthly',    value: '30d'  },
  { label: 'Yearly',     value: '365d' },
];

@Component({
  selector: 'app-receiver-information',
  standalone: true,
  imports: [SpinnerComponent],
  templateUrl: './receiver-information.component.html',
  styleUrl: './receiver-information.component.scss'
})
export class ReceiverInformationComponent implements OnInit {
  periods = PERIODS;
  activePeriod = '1h';
  loading = true;
  errorMessage = '';

  measurementRange = 'imperialNautical';
  measurementAltitude = 'imperial';
  measurementTemperature = 'imperial';
  networkInterface = 'eth0';
  dump1090GraphsEnabled = true;
  dump978GraphsEnabled = false;

  constructor(private dataService: DataService) {}

  ngOnInit(): void {
    forkJoin({
      range: this.dataService.getSetting('graphs_measurement_range'),
      temp:  this.dataService.getSetting('graphs_measurement_temperature'),
      iface: this.dataService.getSetting('graphs_network_interface'),
      d1090: this.dataService.getSetting('graphs_dump1090_enabled').pipe(catchError(() => of({ value: 'true' }))),
      d978:  this.dataService.getSetting('graphs_dump978_enabled').pipe(catchError(() => of({ value: 'false' }))),
    }).subscribe({
      next: ({ range, temp, iface, d1090, d978 }) => {
        this.measurementRange        = range?.value  ?? 'imperialNautical';
        this.measurementAltitude     = this.measurementRange === 'metric' ? 'metric' : 'imperial';
        this.measurementTemperature  = temp?.value   ?? 'imperial';
        this.networkInterface        = iface?.value  ?? 'eth0';
        this.dump1090GraphsEnabled   = d1090?.value  !== 'false';
        this.dump978GraphsEnabled    = d978?.value   !== 'false';
        this.loading = false;
      },
      error: () => {
        this.errorMessage = 'Failed to load graph settings.';
        this.loading = false;
      }
    });
  }

  setPeriod(period: string): void {
    this.activePeriod = period;
  }

  imgUrl(name: string): string {
    return `/graphs/${name}-${this.activePeriod}.png`;
  }
}

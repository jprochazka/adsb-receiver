import { Component, OnInit } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { forkJoin } from 'rxjs';
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
  selector: 'app-performance-graphs',
  standalone: true,
  imports: [NgFor, NgIf, SpinnerComponent],
  templateUrl: './performance-graphs.component.html',
  styleUrl: './performance-graphs.component.scss'
})
export class PerformanceGraphsComponent implements OnInit {
  periods = PERIODS;
  activePeriod = '1h';
  loading = true;
  errorMessage = '';

  measurementRange = 'imperialNautical';
  measurementTemperature = 'imperial';
  networkInterface = 'eth0';

  constructor(private dataService: DataService) {}

  ngOnInit(): void {
    forkJoin({
      range: this.dataService.getSetting('graphs_measurement_range'),
      temp:  this.dataService.getSetting('graphs_measurement_temperature'),
      iface: this.dataService.getSetting('graphs_network_interface'),
    }).subscribe({
      next: ({ range, temp, iface }) => {
        this.measurementRange        = range?.value  ?? 'imperialNautical';
        this.measurementTemperature  = temp?.value   ?? 'imperial';
        this.networkInterface        = iface?.value  ?? 'eth0';
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

  /** Build the URL for a named graph image at the current period. */
  imgUrl(name: string): string {
    return `/graphs/${name}-${this.activePeriod}.png`;
  }
}

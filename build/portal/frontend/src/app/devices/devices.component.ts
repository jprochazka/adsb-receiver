import { Component, OnInit } from '@angular/core';
import { CommonModule, DecimalPipe, DatePipe } from '@angular/common';
import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';
import { RrdChartComponent, RrdChartConfig } from '../shared/rrd-chart/rrd-chart.component';

const PERIODS = [
  { label: 'Hourly',    value: '1h'  },
  { label: 'Six Hours', value: '6h'  },
  { label: 'Daily',     value: '24h' },
  { label: 'Two Days',  value: '2d'  },
  { label: 'Weekly',    value: '7d'  },
  { label: 'Monthly',   value: '30d' },
];

@Component({
  selector: 'app-devices',
  standalone: true,
  imports: [CommonModule, DecimalPipe, DatePipe, SpinnerComponent, RrdChartComponent],
  templateUrl: './devices.component.html',
  styleUrl: './devices.component.scss'
})
export class DevicesComponent implements OnInit {
  infoSystemEnabled = true;
  infoGraphsEnabled = true;

  // ---- Receiver Information ----
  periods = PERIODS;
  activePeriod = '24h';
  receiverLoading = true;
  errorMessage = '';

  measurementRange = 'imperialNautical';
  measurementAltitude = 'imperial';
  measurementTemperature = 'imperial';
  networkInterface = 'eth0';
  dump1090GraphsEnabled = true;
  dump978GraphsEnabled = false;
  graphRefreshIntervalMs = 15000;

  // Chart configs (built after settings load)
  d1090MessageRate!: RrdChartConfig;
  d1090Aircraft!: RrdChartConfig;
  d1090Tracks!: RrdChartConfig;
  d1090Range!: RrdChartConfig;
  d1090Signal!: RrdChartConfig;
  d1090LocalRate!: RrdChartConfig;
  d1090Positions!: RrdChartConfig;
  d1090StrongSignals!: RrdChartConfig;
  d1090DfTypes!: RrdChartConfig;
  d1090Cpu!: RrdChartConfig;

  d978Aircraft!: RrdChartConfig;
  d978Signal!: RrdChartConfig;
  d978Messages!: RrdChartConfig;
  d978Range!: RrdChartConfig;
  d978Altitude!: RrdChartConfig;

  sysCpu!: RrdChartConfig;
  sysTemperature!: RrdChartConfig;
  sysMemory!: RrdChartConfig;
  sysNetwork!: RrdChartConfig;
  sysDiskUsage!: RrdChartConfig;
  sysDiskIops!: RrdChartConfig;
  sysDiskBandwidth!: RrdChartConfig;

  // ---- System Information ----
  systemLoading = true;
  cpu: any;
  memory: any;
  disk: any;
  network: any;
  other: any;
  database: any;

  // Tab control
  activeTab = 'receiver';

  constructor(private dataService: DataService) {}

  ngOnInit(): void {
    this.loadVisibilitySettings();
  }

  get showTabNavigation(): boolean {
    return this.infoGraphsEnabled && this.infoSystemEnabled;
  }

  get hasVisibleTab(): boolean {
    return this.infoGraphsEnabled || this.infoSystemEnabled;
  }

  private loadVisibilitySettings(): void {
    forkJoin({
      system: this.dataService.getSetting('info_system_enabled').pipe(catchError(() => of({ value: 'true' }))),
      graphs: this.dataService.getSetting('info_graphs_enabled').pipe(catchError(() => of({ value: 'true' }))),
    }).subscribe({
      next: ({ system, graphs }) => {
        this.infoSystemEnabled = system?.value !== 'false';
        this.infoGraphsEnabled = graphs?.value !== 'false';
        this.syncActiveTab();

        if (this.infoGraphsEnabled) {
          this.loadReceiverData();
        } else {
          this.receiverLoading = false;
        }

        if (this.infoSystemEnabled) {
          this.loadSystemData();
        } else {
          this.systemLoading = false;
        }
      },
      error: () => {
        this.syncActiveTab();
        this.loadReceiverData();
        this.loadSystemData();
      }
    });
  }

  private loadReceiverData(): void {
    forkJoin({
      range: this.dataService.getSetting('graphs_measurement_range'),
      temp:  this.dataService.getSetting('graphs_measurement_temperature'),
      iface: this.dataService.getSetting('graphs_network_interface'),
      refresh: this.dataService.getSetting('graphs_refresh_interval_ms').pipe(catchError(() => of({ value: '15000' }))),
      d1090: this.dataService.getSetting('graphs_dump1090_enabled').pipe(catchError(() => of({ value: 'true' }))),
      d978:  this.dataService.getSetting('graphs_dump978_enabled').pipe(catchError(() => of({ value: 'false' }))),
    }).subscribe({
      next: ({ range, temp, iface, refresh, d1090, d978 }) => {
        this.measurementRange       = range?.value ?? 'imperialNautical';
        this.measurementAltitude    = this.measurementRange === 'metric' ? 'metric' : 'imperial';
        this.measurementTemperature = temp?.value  ?? 'imperial';
        this.networkInterface       = iface?.value ?? 'eth0';
        this.graphRefreshIntervalMs = this.normalizeRefreshMs(refresh?.value);
        this.dump1090GraphsEnabled  = d1090?.value !== 'false';
        this.dump978GraphsEnabled   = d978?.value  !== 'false';
        this.buildChartConfigs();
        this.receiverLoading = false;
      },
      error: () => {
        this.errorMessage = 'Failed to load graph settings.';
        this.receiverLoading = false;
      }
    });
  }

  private loadSystemData(): void {
    forkJoin({
      cpu: this.dataService.getSystemCpu(),
      memory: this.dataService.getSystemMemory(),
      disk: this.dataService.getSystemDisk(),
      network: this.dataService.getSystemNetwork(),
      other: this.dataService.getSystemOther(),
      database: this.dataService.getSystemDatabase()
    }).subscribe({
      next: ({ cpu, memory, disk, network, other, database }) => {
        this.cpu = cpu;
        this.memory = memory;
        this.disk = disk;
        this.network = network;
        this.other = other;
        this.database = database;
        this.systemLoading = false;
      },
      error: () => { this.systemLoading = false; }
    });
  }

  private normalizeRefreshMs(value: string | number | null | undefined): number {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) {
      return 15000;
    }
    return Math.min(120000, Math.max(3000, Math.round(parsed)));
  }

  setPeriod(period: string): void {
    this.activePeriod = period;
  }

  setActiveTab(tab: string): void {
    if ((tab === 'receiver' && !this.infoGraphsEnabled) || (tab === 'system' && !this.infoSystemEnabled)) {
      this.syncActiveTab();
      return;
    }

    this.activeTab = tab;
  }

  private syncActiveTab(): void {
    if (this.infoGraphsEnabled) {
      this.activeTab = 'receiver';
      return;
    }

    if (this.infoSystemEnabled) {
      this.activeTab = 'system';
      return;
    }

    this.activeTab = '';
  }

  formatBytes(bytes: number): string {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return (bytes / Math.pow(k, i)).toFixed(2) + ' ' + sizes[i];
  }

  bootTime(): Date {
    return new Date(this.other.other_boot_time * 1000);
  }

  private buildChartConfigs(): void {
    const rangeLabel = this.measurementRange === 'metric'
      ? 'Max Range (km)'
      : this.measurementRange === 'imperialStatute'
        ? 'Max Range (mi)'
        : 'Max Range (nm)';

    const rangeTransform = this.measurementRange === 'metric'
      ? (ds: any[]) => ds.map(d => ({ ...d, data: d.data.map((v: number | null) => v != null ? v * 0.001 : null) }))
      : this.measurementRange === 'imperialStatute'
        ? (ds: any[]) => ds.map(d => ({ ...d, data: d.data.map((v: number | null) => v != null ? v * 0.000621371 : null) }))
        : (ds: any[]) => ds.map(d => ({ ...d, data: d.data.map((v: number | null) => v != null ? v * 0.000539957 : null) }));

    const tempLabel = this.measurementTemperature === 'imperial' ? 'Temperature (°F)' : 'Temperature (°C)';
    const tempTransform = this.measurementTemperature === 'imperial'
      ? (ds: any[]) => ds.map(d => ({
          ...d,
          label: 'Temperature',
          data: d.data.map((v: number | null) => v != null ? (v / 1000) * 1.8 + 32 : null)
        }))
      : (ds: any[]) => ds.map(d => ({
          ...d,
          label: 'Temperature',
          data: d.data.map((v: number | null) => v != null ? v / 1000 : null)
        }));

    const altLabel = this.measurementAltitude === 'metric' ? 'Avg Altitude (m)' : 'Avg Altitude (ft)';
    const altTransform = this.measurementAltitude === 'metric'
      ? (ds: any[]) => ds.map(d => ({ ...d, data: d.data.map((v: number | null) => v != null ? v * 0.3048 : null) }))
      : undefined;

    // dump1090
    this.d1090MessageRate = {
      decoder: 'dump1090', metric: 'message-rate', title: 'Message Rate',
      yLabel: 'Messages/sec',
    };
    this.d1090Aircraft = {
      decoder: 'dump1090', metric: 'aircraft', title: 'Aircraft Seen / Tracked',
      yLabel: 'Aircraft',
    };
    this.d1090Tracks = {
      decoder: 'dump1090', metric: 'tracks', title: 'Tracks Seen',
      yLabel: 'Tracks/Hour',
      transform: (ds) => ds.map(d => ({
        ...d,
        data: d.data.map(v => v != null ? v * 3600 : null)
      })),
    };
    this.d1090Range = {
      decoder: 'dump1090', metric: 'range', title: rangeLabel,
      yLabel: rangeLabel, transform: rangeTransform,
    };
    this.d1090Signal = {
      decoder: 'dump1090', metric: 'signal', title: 'Signal Level',
      yLabel: 'dBFS',
    };
    this.d1090LocalRate = {
      decoder: 'dump1090', metric: 'message-rate', title: 'Message Rate (Local)',
      yLabel: 'Messages/sec',
    };
    this.d1090Positions = {
      decoder: 'dump1090', metric: 'positions', title: 'Positions Decoded',
      yLabel: 'Positions/Hour',
      transform: (ds) => ds.map(d => ({
        ...d,
        data: d.data.map(v => v != null ? v * 3600 : null)
      })),
    };
    this.d1090StrongSignals = {
      decoder: 'dump1090', metric: 'strong-signals', title: 'Strong Signals (>-3 dBFS)',
      yLabel: '% of Messages',
      transform: (ds) => {
        const strong = ds.find(d => d.label === 'strong');
        const total  = ds.find(d => d.label === 'total');
        if (!strong || !total) return ds;
        return [{
          label: 'Strong Signals %',
          data: strong.data.map((v, i) => {
            const t = total.data[i];
            return (v != null && t != null && t > 0) ? (v * 100) / t : null;
          })
        }];
      },
    };
    this.d1090DfTypes = {
      decoder: 'dump1090', metric: 'df-types', title: 'Message Types',
      yLabel: 'Messages/sec',
    };
    this.d1090Cpu = {
      decoder: 'dump1090', metric: 'cpu', title: 'dump1090 CPU Utilization',
      yLabel: 'CPU %',
      transform: (ds) => ds.map(d => ({
        ...d,
        data: d.data.map(v => v != null ? v / 10 : null)
      })),
    };

    // dump978
    this.d978Aircraft = {
      decoder: 'dump978', metric: 'aircraft', title: 'Aircraft Seen / Tracked',
      yLabel: 'Aircraft',
    };
    this.d978Signal = {
      decoder: 'dump978', metric: 'signal', title: 'Signal Strength',
      yLabel: 'dBFS',
    };
    this.d978Messages = {
      decoder: 'dump978', metric: 'messages', title: 'Message Rate',
      yLabel: 'Messages/sec',
    };
    this.d978Range = {
      decoder: 'dump978', metric: 'range', title: rangeLabel,
      yLabel: rangeLabel, transform: rangeTransform,
    };
    this.d978Altitude = {
      decoder: 'dump978', metric: 'altitude', title: altLabel,
      yLabel: altLabel, transform: altTransform,
    };

    // system
    this.sysCpu = {
      decoder: 'devices', metric: 'cpu', title: 'Overall CPU Utilization',
      yLabel: 'CPU %',
    };
    this.sysTemperature = {
      decoder: 'devices', metric: 'temperature', title: tempLabel,
      yLabel: tempLabel, transform: tempTransform,
    };
    this.sysMemory = {
      decoder: 'devices', metric: 'memory', title: 'Memory Utilization',
      yLabel: 'Bytes', type: 'bar',
    };
    this.sysNetwork = {
      decoder: 'devices', metric: 'network', title: `Network Bandwidth (${this.networkInterface})`,
      yLabel: 'Bytes/sec',
    };
    this.sysDiskUsage = {
      decoder: 'devices', metric: 'disk-usage', title: 'Disk Usage (/)',
      yLabel: 'Bytes', type: 'bar',
    };
    this.sysDiskIops = {
      decoder: 'devices', metric: 'disk-io-iops', title: 'Disk I/O — IOPS',
      yLabel: 'IOPS',
    };
    this.sysDiskBandwidth = {
      decoder: 'devices', metric: 'disk-io-bandwidth', title: 'Disk I/O — Bandwidth',
      yLabel: 'Bytes/sec',
    };
  }
}

import { Component, OnInit } from '@angular/core';
import { CommonModule, DecimalPipe, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';
import { RrdChartComponent, RrdChartConfig } from '../shared/rrd-chart/rrd-chart.component';
import {
  aircraftTypeLabel,
  convertRangeFromMeters,
  DEVICE_GRAPH_PERIODS,
  extractDatasetAverage,
  formatBytes as formatDeviceBytes,
  formatDuration as formatDeviceDuration,
  normalizeRefreshMs,
} from './devices-display.helpers';

type GraphResolution = 'auto' | 'fine' | 'balanced' | 'compact';

type ReceiverKpis = {
  adsbMsgRate: number | null;
  adsbAircraft: number | null;
  adsbRange: number | null;
  adsbStrongPct: number | null;
  adsbPosPerMsgPct: number | null;
  uatMsgRate: number | null;
  uatAircraft: number | null;
};

@Component({
  selector: 'app-devices',
  standalone: true,
  imports: [CommonModule, FormsModule, DecimalPipe, DatePipe, SpinnerComponent, RrdChartComponent],
  templateUrl: './devices.component.html',
  styleUrl: './devices.component.scss'
})
export class DevicesComponent implements OnInit {
  infoSystemEnabled = true;
  infoGraphsEnabled = true;
  infoStatsEnabled = true;

  // ---- Receiver Information ----
  periods = DEVICE_GRAPH_PERIODS;
  activePeriod = '24h';
  periodIndex = DEVICE_GRAPH_PERIODS.findIndex((p) => p.value === this.activePeriod);
  rangeStart = '';
  rangeEnd = '';
  resolution: GraphResolution = 'auto';
  customRangeActive = false;
  customStartEpoch: number | null = null;
  customEndEpoch: number | null = null;
  brushStartPct = 0;
  brushEndPct = 100;
  brushSnapOptions = [1, 5, 15];
  brushSnapMinutes = 5;
  receiverLoading = true;
  errorMessage = '';

  measurementRange = 'imperialNautical';
  measurementAltitude = 'imperial';
  measurementTemperature = 'imperial';
  networkInterface = 'eth0';
  dump1090GraphsEnabled = true;
  dump978GraphsEnabled = false;
  graphRefreshIntervalMs = 15000;
  compareEnabled = false;
  currentKpis: ReceiverKpis | null = null;
  baselineKpis: ReceiverKpis | null = null;
  baselineLabel = '';
  baselineStartEpoch: number | null = null;
  baselineEndEpoch: number | null = null;

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

  // ---- Public Stats Tab ----
  statsLoading = true;
  statsError = '';
  publicStats: {
    adsbFlights: number | null;
    uatFlights: number | null;
    acarsFlights: number | null;
    acarsMessages: number | null;
    liveAircraft: number | null;
    liveAdsbAircraft: number | null;
    liveUatAircraft: number | null;
    liveMessages: number | null;
    databaseSize: number | null;
    uptimeSeconds: number | null;
    snapshotTime: Date | null;
    topAircraftTypes: Array<{ label: string; count: number }>;
    classifiedOpenSky: number | null;
    classifiedHeuristic: number | null;
    unknownClassified: number | null;
    classifiedOpenSkyPct: number | null;
    classifiedHeuristicPct: number | null;
    unknownClassifiedPct: number | null;
    openskyDbEntries: number | null;
    openskyDbInstalled: boolean;
    openskyDbDownloadedAt: Date | null;
    cpuTemperature: number | null;
    flightTablesSize: number | null;
    receiverVersion: string | null;
    receiverLat: number | null;
    receiverLon: number | null;
    signalLevel: number | null;
    peakSignal: number | null;
    noiseLevel: number | null;
    dump978Available: boolean;
    avgRssi: number | null;
    mlatAircraft: number | null;
    updatedAt: Date;
  } | null = null;

  // Tab control
  activeTab = 'receiver';

  constructor(private dataService: DataService) {}

  ngOnInit(): void {
    this.syncCustomRangeFromActivePeriod();
    this.loadVisibilitySettings();
  }

  get showTabNavigation(): boolean {
    return this.visibleTabCount > 1;
  }

  get hasVisibleTab(): boolean {
    return this.visibleTabCount > 0;
  }

  get visibleTabCount(): number {
    return Number(this.infoGraphsEnabled) + Number(this.infoSystemEnabled) + Number(this.infoStatsEnabled);
  }

  private loadVisibilitySettings(): void {
    forkJoin({
      system: this.dataService.getSetting('info_system_enabled').pipe(catchError(() => of({ value: 'true' }))),
      graphs: this.dataService.getSetting('info_graphs_enabled').pipe(catchError(() => of({ value: 'true' }))),
      stats: this.dataService.getSetting('info_stats_enabled').pipe(catchError(() => of({ value: 'true' }))),
    }).subscribe({
      next: ({ system, graphs, stats }) => {
        this.infoSystemEnabled = system?.value !== 'false';
        this.infoGraphsEnabled = graphs?.value !== 'false';
        this.infoStatsEnabled = stats?.value !== 'false';
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

        if (this.infoStatsEnabled) {
          this.loadStatsData();
        } else {
          this.statsLoading = false;
        }
      },
      error: () => {
        this.syncActiveTab();
        this.loadReceiverData();
        this.loadSystemData();
        this.loadStatsData();
      }
    });
  }

  private loadStatsData(): void {
    this.statsLoading = true;
    this.statsError = '';

    forkJoin({
      adsb: this.dataService.GetFlightsCount().pipe(catchError(() => of(null))),
      uat: this.dataService.getUatFlightsCount().pipe(catchError(() => of(null))),
      acarsFlights: this.dataService.getAcarsFlightsCount().pipe(catchError(() => of(null))),
      acarsMessages: this.dataService.getAcarsMessagesCount().pipe(catchError(() => of(null))),
      live: this.dataService.getLiveAircraft().pipe(catchError(() => of(null))),
      opensky: this.dataService.getOpenSkyAircraftDatabaseStatus().pipe(catchError(() => of(null))),
      database: this.dataService.getSystemDatabase().pipe(catchError(() => of(null))),
      other: this.dataService.getSystemOther().pipe(catchError(() => of(null))),
      cpu: this.dataService.getSystemCpu().pipe(catchError(() => of(null))),
      receiver: this.dataService.getReceiverInfo().pipe(catchError(() => of(null))),
    }).subscribe({
      next: ({ adsb, uat, acarsFlights, acarsMessages, live, opensky, database, other, cpu, receiver }) => {
        const now = Date.now();
        const bootSeconds = typeof other?.other_boot_time === 'number' ? other.other_boot_time : null;
        const uptimeSeconds = bootSeconds != null ? Math.max(0, Math.floor(now / 1000) - Math.floor(bootSeconds)) : null;
        const classificationStats = live?.classification_stats ?? {};
        const liveAircraft = Array.isArray(live?.aircraft) ? live.aircraft : [];
        const liveAdsbAircraft = liveAircraft.filter((a: any) => a?.source === 'dump1090').length;
        const liveUatAircraft = liveAircraft.filter((a: any) => a?.source === 'dump978').length;

        const typeCounts = new Map<string, number>();
        for (const aircraft of liveAircraft) {
          const label = aircraftTypeLabel(String(aircraft?.aircraft_class ?? 'unknown').toLowerCase());
          typeCounts.set(label, (typeCounts.get(label) ?? 0) + 1);
        }

        const topAircraftTypes = Array.from(typeCounts.entries())
          .map(([label, count]) => ({ label, count }))
          .sort((a, b) => b.count - a.count)
          .slice(0, 5);

        const totalLiveClassified = liveAircraft.length;
        const openskyCount = typeof classificationStats?.opensky_count === 'number' ? classificationStats.opensky_count : null;
        const heuristicCount = typeof classificationStats?.heuristic_count === 'number' ? classificationStats.heuristic_count : null;
        const unknownCount = typeof classificationStats?.unknown_count === 'number' ? classificationStats.unknown_count : null;
        const ratio = (count: number | null): number | null => {
          if (count == null || totalLiveClassified <= 0) {
            return null;
          }
          return (count / totalLiveClassified) * 100;
        };

        // Aggregate RSSI from live aircraft
        const rssiValues = liveAircraft
          .map((a: any) => a?.rssi)
          .filter((v: any): v is number => typeof v === 'number' && Number.isFinite(v));
        const avgRssi = rssiValues.length > 0
          ? rssiValues.reduce((sum: number, v: number) => sum + v, 0) / rssiValues.length
          : null;

        // Count MLAT aircraft (those with classification_source containing 'mlat' in their lat source)
        const mlatAircraft = liveAircraft.filter((a: any) => a?.type === 'mlat' || a?.mlat_lat === true).length || null;

        // Receiver info
        const d1090 = receiver?.dump1090;
        const d978 = receiver?.dump978;

        this.publicStats = {
          adsbFlights: typeof adsb?.flights === 'number' ? adsb.flights : null,
          uatFlights: typeof uat?.flights === 'number' ? uat.flights : null,
          acarsFlights: typeof acarsFlights?.flights === 'number' ? acarsFlights.flights : null,
          acarsMessages: typeof acarsMessages?.messages === 'number' ? acarsMessages.messages : null,
          liveAircraft: liveAircraft.length,
          liveAdsbAircraft,
          liveUatAircraft,
          liveMessages: typeof live?.messages === 'number' ? live.messages : null,
          databaseSize: typeof database?.size === 'number' ? database.size : null,
          uptimeSeconds,
          snapshotTime: typeof live?.now === 'number' ? new Date(live.now * 1000) : null,
          topAircraftTypes,
          classifiedOpenSky: openskyCount,
          classifiedHeuristic: heuristicCount,
          unknownClassified: unknownCount,
          classifiedOpenSkyPct: ratio(openskyCount),
          classifiedHeuristicPct: ratio(heuristicCount),
          unknownClassifiedPct: ratio(unknownCount),
          openskyDbEntries: typeof classificationStats?.opensky_cache_entries === 'number' ? classificationStats.opensky_cache_entries : null,
          openskyDbInstalled: !!opensky?.installed,
          openskyDbDownloadedAt: opensky?.downloaded_at ? new Date(opensky.downloaded_at) : null,
          cpuTemperature: typeof cpu?.cpu_temperature === 'number' ? cpu.cpu_temperature : null,
          flightTablesSize: null,
          receiverVersion: d1090?.version ?? d978?.version ?? null,
          receiverLat: d1090?.lat ?? d978?.lat ?? null,
          receiverLon: d1090?.lon ?? d978?.lon ?? null,
          signalLevel: typeof d1090?.signal === 'number' ? d1090.signal : null,
          peakSignal: typeof d1090?.peak_signal === 'number' ? d1090.peak_signal : null,
          noiseLevel: typeof d1090?.noise === 'number' ? d1090.noise : null,
          dump978Available: d978 != null,
          avgRssi,
          mlatAircraft,
          updatedAt: new Date(now),
        };
        this.statsLoading = false;
      },
      error: () => {
        this.statsError = 'Failed to load public stats.';
        this.statsLoading = false;
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
        this.graphRefreshIntervalMs = normalizeRefreshMs(refresh?.value);
        this.dump1090GraphsEnabled  = d1090?.value !== 'false';
        this.dump978GraphsEnabled   = d978?.value  !== 'false';
        this.buildChartConfigs();
        this.refreshReceiverInsights();
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


  setPeriod(period: string): void {
    this.activePeriod = period;
    this.periodIndex = this.periods.findIndex((p) => p.value === period);
    this.customRangeActive = false;
    this.customStartEpoch = null;
    this.customEndEpoch = null;
    this.brushStartPct = 0;
    this.brushEndPct = 100;
    this.syncCustomRangeFromActivePeriod();
    if (!this.receiverLoading) {
      this.refreshReceiverInsights();
    }
  }

  setPeriodByIndex(index: number): void {
    const bounded = Math.max(0, Math.min(this.periods.length - 1, index));
    this.periodIndex = bounded;
    this.setPeriod(this.periods[bounded].value);
  }

  stepPeriod(delta: number): void {
    this.setPeriodByIndex(this.periodIndex + delta);
  }

  applyCustomRange(): void {
    if (!this.rangeStart || !this.rangeEnd) {
      this.errorMessage = 'Select both start and end date/time to apply a custom range.';
      return;
    }

    const start = new Date(this.rangeStart);
    const end = new Date(this.rangeEnd);
    if (!Number.isFinite(start.getTime()) || !Number.isFinite(end.getTime())) {
      this.errorMessage = 'Invalid custom date range.';
      return;
    }
    if (end <= start) {
      this.errorMessage = 'End date/time must be after start date/time.';
      return;
    }

    this.errorMessage = '';
    this.customRangeActive = true;
    this.customStartEpoch = Math.floor(start.getTime() / 1000);
    this.customEndEpoch = Math.floor(end.getTime() / 1000);
    this.refreshReceiverInsights();
  }

  setBaselineFromCurrent(): void {
    if (!this.currentKpis) {
      return;
    }

    this.baselineKpis = { ...this.currentKpis };
    const window = this.getActiveWindowEpochs();
    this.baselineStartEpoch = window?.start ?? null;
    this.baselineEndEpoch = window?.end ?? null;
    this.baselineLabel = this.rangeSummary;
    this.compareEnabled = true;
  }

  clearBaseline(): void {
    this.baselineKpis = null;
    this.baselineLabel = '';
    this.compareEnabled = false;
    this.baselineStartEpoch = null;
    this.baselineEndEpoch = null;
  }

  formatDelta(current: number | null, baseline: number | null, suffix = ''): string {
    if (current == null || baseline == null) {
      return '';
    }

    const diff = current - baseline;
    const sign = diff >= 0 ? '+' : '';
    return `${sign}${diff.toFixed(1)}${suffix}`;
  }

  hasDelta(current: number | null, baseline: number | null): boolean {
    return this.compareEnabled && current != null && baseline != null;
  }

  onBrushStartInput(value: number): void {
    this.brushStartPct = Math.max(0, Math.min(value, this.brushEndPct - 0.1));
    this.syncRangeFromBrush();
  }

  onBrushEndInput(value: number): void {
    this.brushEndPct = Math.min(100, Math.max(value, this.brushStartPct + 0.1));
    this.syncRangeFromBrush();
  }

  setBrushSnap(minutes: number): void {
    if (!this.brushSnapOptions.includes(minutes)) {
      return;
    }

    this.brushSnapMinutes = minutes;
    this.syncRangeFromBrush();
  }

  nudgeBrushStart(direction: -1 | 1): void {
    const deltaPct = this.getBrushDeltaPct() * direction;
    this.onBrushStartInput(this.brushStartPct + deltaPct);
  }

  nudgeBrushEnd(direction: -1 | 1): void {
    const deltaPct = this.getBrushDeltaPct() * direction;
    this.onBrushEndInput(this.brushEndPct + deltaPct);
  }

  get brushSelectionStyle(): string {
    const left = Math.max(0, Math.min(100, this.brushStartPct));
    const width = Math.max(1, Math.min(100 - left, this.brushEndPct - this.brushStartPct));
    return `left:${left}%;width:${width}%`;
  }

  get activePeriodLabel(): string {
    return this.periods.find((p) => p.value === this.activePeriod)?.label ?? this.activePeriod;
  }

  get brushStartLabel(): string {
    return this.formatBrushDateLabel(this.rangeStart);
  }

  get brushEndLabel(): string {
    return this.formatBrushDateLabel(this.rangeEnd);
  }

  get maxGraphPoints(): number {
    if (this.resolution === 'fine') return 480;
    if (this.resolution === 'balanced') return 240;
    if (this.resolution === 'compact') return 120;

    // Auto: adapt density to current period for readability.
    const option = this.periods.find((p) => p.value === this.activePeriod);
    if (!option) return 240;
    if (option.durationHours <= 6) return 480;
    if (option.durationHours <= 48) return 300;
    if (option.durationHours <= 168) return 220;
    return 160;
  }

  get chartStepSeconds(): number {
    return this.getKpiStepSeconds();
  }

  get rangeSummary(): string {
    if (this.customRangeActive && this.customStartEpoch && this.customEndEpoch) {
      const start = new Date(this.customStartEpoch * 1000).toLocaleString();
      const end = new Date(this.customEndEpoch * 1000).toLocaleString();
      return `${start} to ${end}`;
    }

    const option = this.periods.find((p) => p.value === this.activePeriod);
    if (!option) return this.activePeriod;
    return `${option.label} (${option.value})`;
  }

  setActiveTab(tab: string): void {
    if (
      (tab === 'receiver' && !this.infoGraphsEnabled) ||
      (tab === 'system' && !this.infoSystemEnabled) ||
      (tab === 'stats' && !this.infoStatsEnabled)
    ) {
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

    if (this.infoStatsEnabled) {
      this.activeTab = 'stats';
      return;
    }

    this.activeTab = '';
  }

  private syncCustomRangeFromActivePeriod(): void {
    const option = this.periods.find((p) => p.value === this.activePeriod);
    if (!option) return;

    const end = new Date();
    const start = new Date(end.getTime() - option.durationHours * 3_600_000);
    this.rangeStart = this.toDatetimeLocalValue(start);
    this.rangeEnd = this.toDatetimeLocalValue(end);
  }

  private syncRangeFromBrush(): void {
    const option = this.periods.find((p) => p.value === this.activePeriod);
    if (!option) return;

    const now = Date.now();
    const windowMs = option.durationHours * 3_600_000;
    const baseStart = now - windowMs;

    const startMs = baseStart + (windowMs * (this.brushStartPct / 100));
    const endMs = baseStart + (windowMs * (this.brushEndPct / 100));
    const snapMs = this.brushSnapMinutes * 60_000;

    let snappedStartMs = Math.floor(startMs / snapMs) * snapMs;
    let snappedEndMs = Math.ceil(endMs / snapMs) * snapMs;

    snappedStartMs = Math.max(baseStart, snappedStartMs);
    snappedEndMs = Math.min(now, snappedEndMs);
    if (snappedEndMs <= snappedStartMs) {
      snappedEndMs = Math.min(now, snappedStartMs + snapMs);
    }

    this.rangeStart = this.toDatetimeLocalValue(new Date(snappedStartMs));
    this.rangeEnd = this.toDatetimeLocalValue(new Date(snappedEndMs));
  }

  private refreshReceiverInsights(): void {
    const options = this.buildGraphQueryOptions();
    forkJoin({
      d1090Rate: this.dataService.getGraphData('dump1090', 'message-rate', options).pipe(catchError(() => of(null))),
      d1090Aircraft: this.dataService.getGraphData('dump1090', 'aircraft', options).pipe(catchError(() => of(null))),
      d1090Range: this.dataService.getGraphData('dump1090', 'range', options).pipe(catchError(() => of(null))),
      d978Messages: this.dataService.getGraphData('dump978', 'messages', options).pipe(catchError(() => of(null))),
      d978Aircraft: this.dataService.getGraphData('dump978', 'aircraft', options).pipe(catchError(() => of(null))),
    }).subscribe(({ d1090Rate, d1090Aircraft, d1090Range, d978Messages, d978Aircraft }) => {
      const msgRate = extractDatasetAverage(d1090Rate, 'messages');
      const positions = extractDatasetAverage(d1090Rate, 'positions');
      const strongSignals = extractDatasetAverage(d1090Rate, 'strong_signals');
      const rangeMeters = extractDatasetAverage(d1090Range, 'max_range');

      this.currentKpis = {
        adsbMsgRate: msgRate,
        adsbAircraft: extractDatasetAverage(d1090Aircraft, 'total'),
        adsbRange: rangeMeters != null ? convertRangeFromMeters(rangeMeters, this.measurementRange) : null,
        adsbStrongPct: (strongSignals != null && msgRate != null && msgRate > 0) ? (strongSignals * 100) / msgRate : null,
        adsbPosPerMsgPct: (positions != null && msgRate != null && msgRate > 0) ? (positions * 100) / msgRate : null,
        uatMsgRate: extractDatasetAverage(d978Messages, 'messages'),
        uatAircraft: extractDatasetAverage(d978Aircraft, 'total'),
      };
    });
  }

  private buildGraphQueryOptions(): { period?: string; start?: number; end?: number; step?: number } {
    const step = this.chartStepSeconds;
    const window = this.getActiveWindowEpochs();
    if (window) {
      return {
        start: window.start,
        end: window.end,
        step,
      };
    }

    return {
      period: this.activePeriod,
      step,
    };
  }

  private getActiveWindowEpochs(): { start: number; end: number } | null {
    if (this.customRangeActive && this.customStartEpoch != null && this.customEndEpoch != null) {
      return {
        start: this.customStartEpoch,
        end: this.customEndEpoch,
      };
    }

    const option = this.periods.find((p) => p.value === this.activePeriod);
    if (!option) {
      return null;
    }

    const end = Math.floor(Date.now() / 1000);
    const start = end - Math.floor(option.durationHours * 3600);
    return { start, end };
  }

  private getKpiStepSeconds(): number {
    if (this.resolution === 'fine') return 60;
    if (this.resolution === 'balanced') return 300;
    if (this.resolution === 'compact') return 900;

    const option = this.periods.find((p) => p.value === this.activePeriod);
    if (!option) return 300;
    if (option.durationHours <= 1) return 60;
    if (option.durationHours <= 24) return 300;
    return 900;
  }


  private getBrushDeltaPct(): number {
    const option = this.periods.find((p) => p.value === this.activePeriod);
    if (!option) return 0.1;

    const windowMs = option.durationHours * 3_600_000;
    const deltaPct = (this.brushSnapMinutes * 60_000 * 100) / windowMs;
    return Math.max(0.1, deltaPct);
  }

  private formatBrushDateLabel(datetimeLocal: string): string {
    const date = new Date(datetimeLocal);
    if (!Number.isFinite(date.getTime())) {
      return datetimeLocal;
    }

    return date.toLocaleString(undefined, {
      month: 'short',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    });
  }

  private toDatetimeLocalValue(date: Date): string {
    const pad = (n: number) => String(n).padStart(2, '0');
    const y = date.getFullYear();
    const m = pad(date.getMonth() + 1);
    const d = pad(date.getDate());
    const h = pad(date.getHours());
    const min = pad(date.getMinutes());
    return `${y}-${m}-${d}T${h}:${min}`;
  }

  formatBytes(bytes: number): string {
    return formatDeviceBytes(bytes);
  }

  formatDuration(seconds: number | null): string {
    return formatDeviceDuration(seconds);
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

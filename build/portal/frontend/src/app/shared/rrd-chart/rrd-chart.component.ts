import {
  Component,
  ElementRef,
  Input,
  OnChanges,
  OnDestroy,
  SimpleChanges,
  ViewChild,
  AfterViewInit,
} from '@angular/core';
import { Chart, ChartType, registerables } from 'chart.js';
import { forkJoin } from 'rxjs';
import { DataService } from '../../service/data.service';

Chart.register(...registerables);

// Palette used for datasets in order
const PALETTE = [
  '#4e79a7', '#f28e2b', '#e15759', '#76b7b2',
  '#59a14f', '#edc948', '#b07aa1', '#ff9da7',
  '#9c755f', '#bab0ac',
];

export interface RrdChartConfig {
  decoder: string;   // 'dump1090' | 'dump978' | 'system'
  metric: string;    // matches backend route segment
  type?: ChartType;  // defaults to 'line'
  title: string;
  yLabel?: string;
  /** Optional post-processing applied to each dataset's data array. */
  transform?: (datasets: { label: string; data: (number | null)[] }[]) =>
    { label: string; data: (number | null)[] }[];
}

@Component({
  selector: 'app-rrd-chart',
  standalone: true,
  template: `
    <div class="rrd-chart-wrapper">
      <h6 class="chart-title">{{ config.title }}</h6>
      @if (compareLegendVisible) {
        <div class="chart-compare-hint" aria-label="Compare legend">
          <span class="hint-line hint-line--solid"></span>
          <span>Current</span>
          <span class="hint-sep">|</span>
          <span class="hint-line hint-line--dashed"></span>
          <span>{{ compareLabel }}</span>
        </div>
      }
      @if (loading) {
        <div class="chart-placeholder d-flex align-items-center justify-content-center text-muted small">
          Loading…
        </div>
      }
      @if (error) {
        <div class="chart-placeholder chart-placeholder--warn d-flex align-items-center justify-content-center text-muted small">
          No data available
        </div>
      }
      <canvas #chartCanvas [class.d-none]="loading || error"></canvas>
    </div>
  `,
  styleUrl: './rrd-chart.component.scss',
})
export class RrdChartComponent implements AfterViewInit, OnChanges, OnDestroy {
  @Input({ required: true }) config!: RrdChartConfig;
  @Input({ required: true }) period!: string;
  @Input() refreshMs = 15000;
  @Input() maxPoints: number | null = null;
  @Input() startEpoch: number | null = null;
  @Input() endEpoch: number | null = null;
  @Input() compareStartEpoch: number | null = null;
  @Input() compareEndEpoch: number | null = null;
  @Input() compareLabel = 'Baseline';
  @Input() stepSeconds: number | null = null;

  @ViewChild('chartCanvas') canvasRef!: ElementRef<HTMLCanvasElement>;

  loading = true;
  error = false;

  private chart: Chart | null = null;
  private refreshTimer: ReturnType<typeof setInterval> | null = null;

  constructor(private dataService: DataService) {}

  ngAfterViewInit(): void {
    this.startAutoRefresh();
    this.loadData(true);
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['period'] && !changes['period'].firstChange) {
      this.loadData(true);
    }

    if ((changes['startEpoch'] && !changes['startEpoch'].firstChange) ||
        (changes['endEpoch'] && !changes['endEpoch'].firstChange)) {
      this.loadData(true);
    }

    if ((changes['compareStartEpoch'] && !changes['compareStartEpoch'].firstChange) ||
        (changes['compareEndEpoch'] && !changes['compareEndEpoch'].firstChange) ||
        (changes['compareLabel'] && !changes['compareLabel'].firstChange)) {
      this.loadData(true);
    }

    if (changes['stepSeconds'] && !changes['stepSeconds'].firstChange) {
      this.loadData(true);
    }

    if (changes['maxPoints'] && !changes['maxPoints'].firstChange) {
      this.loadData(false);
    }

    if (changes['refreshMs'] && !changes['refreshMs'].firstChange) {
      this.startAutoRefresh();
    }
  }

  ngOnDestroy(): void {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = null;
    }
    this.chart?.destroy();
  }

  get compareLegendVisible(): boolean {
    return this.compareStartEpoch != null && this.compareEndEpoch != null;
  }

  private startAutoRefresh(): void {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = null;
    }

    if (!Number.isFinite(this.refreshMs) || this.refreshMs < 3000) {
      return;
    }

    this.refreshTimer = setInterval(() => {
      if (document.visibilityState === 'hidden') {
        return;
      }
      this.loadData(false);
    }, this.refreshMs);
  }

  private loadData(showLoader: boolean): void {
    if (showLoader) {
      this.loading = true;
      this.error = false;
    }

    const currentRequest = this.dataService.getGraphData(this.config.decoder, this.config.metric, {
      period: this.period,
      start: this.startEpoch ?? undefined,
      end: this.endEpoch ?? undefined,
      step: this.stepSeconds ?? undefined,
    });

    const compareEnabled = this.compareStartEpoch != null && this.compareEndEpoch != null;
    if (!compareEnabled) {
      currentRequest.subscribe({
        next: (response) => {
          this.loading = false;
          const hasData = this.responseHasData(response);
          if (!hasData) {
            this.error = true;
            return;
          }
          this.error = false;
          this.renderChart(response);
        },
        error: () => {
          this.loading = false;
          this.error = true;
        },
      });
      return;
    }

    const compareRequest = this.dataService.getGraphData(this.config.decoder, this.config.metric, {
      start: this.compareStartEpoch ?? undefined,
      end: this.compareEndEpoch ?? undefined,
      step: this.stepSeconds ?? undefined,
    });

    forkJoin({ current: currentRequest, compare: compareRequest }).subscribe({
      next: ({ current, compare }) => {
        this.loading = false;
        const hasData = this.responseHasData(current);
        if (!hasData) {
          this.error = true;
          return;
        }

        this.error = false;
        this.renderChart(current, compare);
      },
      error: () => {
        this.loading = false;
        this.error = true;
      },
    });
  }

  private renderChart(response: any, compareResponse: any | null = null): void {
    const labels: number[] = response.labels ?? [];
    let datasets: { label: string; data: (number | null)[] }[] = response.datasets ?? [];

    if (this.config.transform) {
      datasets = this.config.transform(datasets);
    }

    // Convert Unix timestamps to locale time strings for display
    const labelStrings = labels.map((ts) =>
      new Date(ts * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    );

    let chartDatasets: any[] = datasets.map((ds, i) => ({
      label: ds.label,
      data: ds.data,
      borderColor: PALETTE[i % PALETTE.length],
      backgroundColor: PALETTE[i % PALETTE.length] + '33',
      borderWidth: 1.5,
      pointRadius: 0,
      spanGaps: true,
      fill: this.config.type === 'bar',
    }));

    if (compareResponse?.datasets?.length) {
      let compareDatasets: { label: string; data: (number | null)[] }[] = compareResponse.datasets;
      if (this.config.transform) {
        compareDatasets = this.config.transform(compareDatasets);
      }

      const targetLength = labelStrings.length;
      const mapped = compareDatasets.map((ds, i) => ({
        label: `${ds.label} (${this.compareLabel})`,
        data: this.alignSeriesLength(ds.data, targetLength),
        borderColor: PALETTE[i % PALETTE.length],
        backgroundColor: 'transparent',
        borderWidth: 1.5,
        borderDash: [6, 4],
        pointRadius: 0,
        spanGaps: true,
        fill: false,
      }));

      chartDatasets = [...chartDatasets, ...mapped];
    }

    const downsampled = this.downsampleForDisplay(labelStrings, chartDatasets);
    const sampledLabels = downsampled.labels;
    chartDatasets = downsampled.datasets;

    if (this.chart) {
      this.chart.data.labels = sampledLabels;
      this.chart.data.datasets = chartDatasets as any;
      this.chart.update('none');
      return;
    }

    this.chart = new Chart(this.canvasRef.nativeElement, {
      type: this.config.type ?? 'line',
      data: {
        labels: sampledLabels,
        datasets: chartDatasets as any,
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        animation: false,
        interaction: { mode: 'index', intersect: false },
        plugins: {
          legend: { position: 'bottom', labels: { boxWidth: 12, font: { size: 11 } } },
          tooltip: { mode: 'index', intersect: false },
        },
        scales: {
          x: {
            ticks: { maxTicksLimit: 8, font: { size: 10 } },
            grid: {
              color: 'rgba(0,0,0,0.22)',
              lineWidth: 1.25,
            },
          },
          y: {
            title: {
              display: !!this.config.yLabel,
              text: this.config.yLabel ?? '',
              font: { size: 11 },
            },
            ticks: { font: { size: 10 } },
            grid: {
              color: 'rgba(0,0,0,0.22)',
              lineWidth: 1.25,
            },
          },
        },
      },
    });
  }

  private downsampleForDisplay(
    labels: string[],
    datasets: { label: string; data: (number | null)[]; [key: string]: any }[]
  ): { labels: string[]; datasets: { label: string; data: (number | null)[]; [key: string]: any }[] } {
    const max = this.maxPoints ?? 0;
    if (!Number.isFinite(max) || max <= 0 || labels.length <= max) {
      return { labels, datasets };
    }

    const target = Math.max(2, Math.floor(max));
    const lastIndex = labels.length - 1;
    const indexSet = new Set<number>();

    for (let i = 0; i < target; i++) {
      const idx = Math.round((i * lastIndex) / (target - 1));
      indexSet.add(idx);
    }

    const indices = Array.from(indexSet).sort((a, b) => a - b);
    return {
      labels: indices.map((idx) => labels[idx]),
      datasets: datasets.map((ds) => ({
        ...ds,
        data: indices.map((idx) => ds.data[idx]),
      })),
    };
  }

  private responseHasData(response: any): boolean {
    return (response?.labels?.length ?? 0) > 0 &&
      (response?.datasets ?? []).some((ds: any) =>
        ds?.data?.some((v: any) => v !== null && v !== undefined)
      );
  }

  private alignSeriesLength(data: (number | null)[], targetLength: number): (number | null)[] {
    if (targetLength <= 0) {
      return [];
    }

    if (!Array.isArray(data) || data.length === 0) {
      return Array(targetLength).fill(null);
    }

    if (data.length === targetLength) {
      return data;
    }

    if (targetLength === 1) {
      return [data[0] ?? null];
    }

    const lastSourceIndex = data.length - 1;
    const mapped: (number | null)[] = [];
    for (let i = 0; i < targetLength; i++) {
      const idx = Math.round((i * lastSourceIndex) / (targetLength - 1));
      mapped.push(data[idx] ?? null);
    }
    return mapped;
  }
}

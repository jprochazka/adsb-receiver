export type PeriodOption = { label: string; value: string; durationHours: number };

export const DEVICE_GRAPH_PERIODS: PeriodOption[] = [
  { label: 'Hourly', value: '1h', durationHours: 1 },
  { label: 'Six Hours', value: '6h', durationHours: 6 },
  { label: 'Daily', value: '24h', durationHours: 24 },
  { label: 'Two Days', value: '2d', durationHours: 48 },
  { label: 'Weekly', value: '7d', durationHours: 168 },
  { label: 'Monthly', value: '30d', durationHours: 720 },
];

const AIRCRAFT_TYPE_LABELS: Record<string, string> = {
  airliner: 'Airliner',
  general_aviation: 'General Aviation',
  helicopter: 'Helicopter',
  military: 'Military',
  glider: 'Glider',
  balloon: 'Balloon',
  uav: 'UAV',
  ground: 'Ground Vehicle',
  space: 'Space Vehicle',
};

export function normalizeRefreshMs(value: string | number | null | undefined): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return 15000;
  }
  return Math.min(120000, Math.max(3000, Math.round(parsed)));
}

export function formatBytes(bytes: number): string {
  if (bytes === 0) {
    return '0 B';
  }

  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${(bytes / Math.pow(k, i)).toFixed(2)} ${sizes[i]}`;
}

export function formatDuration(seconds: number | null): string {
  if (seconds == null || !Number.isFinite(seconds) || seconds < 0) {
    return 'N/A';
  }

  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);

  if (days > 0) {
    return `${days}d ${hours}h ${minutes}m`;
  }
  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  }
  return `${minutes}m`;
}

export type MeasurementRange = 'metric' | 'imperialStatute' | 'imperialNautical' | string;

export function extractDatasetAverage(response: any, label: string): number | null {
  if (!response?.datasets || !Array.isArray(response.datasets)) {
    return null;
  }

  const dataset = response.datasets.find((d: any) => d?.label === label);
  if (!dataset || !Array.isArray(dataset.data)) {
    return null;
  }

  const values = dataset.data.filter((v: number | null) => typeof v === 'number') as number[];
  if (!values.length) {
    return null;
  }

  const sum = values.reduce((acc, v) => acc + v, 0);
  return sum / values.length;
}

export function convertRangeFromMeters(value: number, measurementRange: MeasurementRange): number {
  if (measurementRange === 'metric') {
    return value * 0.001;
  }
  if (measurementRange === 'imperialStatute') {
    return value * 0.000621371;
  }
  return value * 0.000539957;
}

export function aircraftTypeLabel(typeCode: string): string {
  return AIRCRAFT_TYPE_LABELS[typeCode] ?? 'Unknown';
}

import {
  aircraftTypeLabel,
  convertRangeFromMeters,
  extractDatasetAverage,
  formatBytes,
  formatDuration,
  normalizeRefreshMs,
} from './devices-display.helpers';

describe('devices display helpers', () => {
  it('formats byte counts with binary units', () => {
    expect(formatBytes(0)).toBe('0 B');
    expect(formatBytes(1024)).toBe('1.00 KB');
    expect(formatBytes(1048576)).toBe('1.00 MB');
  });

  it('formats durations and rejects invalid uptime values', () => {
    expect(formatDuration(null)).toBe('N/A');
    expect(formatDuration(Number.NaN)).toBe('N/A');
    expect(formatDuration(-1)).toBe('N/A');
    expect(formatDuration(59)).toBe('0m');
    expect(formatDuration(3600 + 120)).toBe('1h 2m');
    expect(formatDuration(2 * 86400 + 3 * 3600 + 4 * 60)).toBe('2d 3h 4m');
  });

  it('normalizes graph refresh intervals to supported bounds', () => {
    expect(normalizeRefreshMs(undefined)).toBe(15000);
    expect(normalizeRefreshMs('bad')).toBe(15000);
    expect(normalizeRefreshMs('2000')).toBe(3000);
    expect(normalizeRefreshMs('12345.6')).toBe(12346);
    expect(normalizeRefreshMs(200000)).toBe(120000);
  });

  it('maps aircraft class codes to portal labels', () => {
    expect(aircraftTypeLabel('airliner')).toBe('Airliner');
    expect(aircraftTypeLabel('general_aviation')).toBe('General Aviation');
    expect(aircraftTypeLabel('ground')).toBe('Ground Vehicle');
    expect(aircraftTypeLabel('missing')).toBe('Unknown');
  });

  it('averages numeric dataset values by label', () => {
    expect(extractDatasetAverage({ datasets: [{ label: 'messages', data: [100, null, 140] }] }, 'messages')).toBe(120);
    expect(extractDatasetAverage({ datasets: [{ label: 'positions', data: [1, 2] }] }, 'messages')).toBeNull();
    expect(extractDatasetAverage({ datasets: [{ label: 'messages', data: [null, undefined] }] }, 'messages')).toBeNull();
    expect(extractDatasetAverage(null, 'messages')).toBeNull();
  });

  it('converts range meters using selected graph units', () => {
    expect(convertRangeFromMeters(1000, 'metric')).toBeCloseTo(1, 5);
    expect(convertRangeFromMeters(1609.344, 'imperialStatute')).toBeCloseTo(1, 5);
    expect(convertRangeFromMeters(1852, 'imperialNautical')).toBeCloseTo(1, 5);
  });
});

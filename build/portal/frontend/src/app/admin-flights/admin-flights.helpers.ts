export interface PurgeResultLike {
  deleted_flights: number;
  deleted_positions: number;
  cutoff_date: string;
}

export type FlightSourceLabel = 'ADS-B' | 'UAT';

export function buildPurgeCompleteMessage(result: PurgeResultLike): string {
  return `Purge complete: ${result.deleted_flights} flight(s) and ${result.deleted_positions} position(s) deleted (cutoff: ${result.cutoff_date}).`;
}

export function getIgnoredRangeStart(total: number, offset: number): number {
  return total === 0 ? 0 : offset + 1;
}

export function getIgnoredRangeEnd(offset: number, pageSize: number, total: number): number {
  return Math.min(offset + pageSize, total);
}

export function getPreviousIgnoredOffset(offset: number, pageSize: number): number {
  return Math.max(0, offset - pageSize);
}

export function canGoToNextIgnoredPage(loading: boolean, offset: number, pageSize: number, total: number): boolean {
  return !loading && offset + pageSize < total;
}

export function getNextIgnoredOffset(offset: number, pageSize: number): number {
  return offset + pageSize;
}

export function normalizeIgnoredOffsetAfterLoad(offset: number, pageSize: number, total: number): number {
  if (total > 0 && offset >= total) {
    return getPreviousIgnoredOffset(offset, pageSize);
  }

  return offset;
}

export function readIgnoreOnPurgeChecked(event: Event): boolean | null {
  const target = event.target as HTMLInputElement | null;
  return target ? target.checked : null;
}

export function buildPurgePreferenceError(source: FlightSourceLabel, flight: string): string {
  return `Failed to update purge preference for ${source} flight ${flight}.`;
}

export interface FlightLike {
  aircraft_class?: unknown;
  emitter_category?: unknown;
  flight?: unknown;
}

export function buildPageNumbers(current: number, total: number): number[] {
  const start = Math.max(1, current - 2);
  const end = Math.min(total, current + 2);
  const range: number[] = [];
  for (let i = start; i <= end; i++) range.push(i);
  return range;
}

export function normalizeSightingsCount(value: unknown, fallback: number): number {
  const parsed = Number(value);
  if (Number.isFinite(parsed) && parsed >= 1) {
    return Math.floor(parsed);
  }
  return fallback;
}

export function normalizeCount(value: unknown, fallback: number): number {
  const parsed = Number(value);
  if (Number.isFinite(parsed) && parsed >= 0) {
    return Math.floor(parsed);
  }
  return fallback;
}

export function inferAircraftClass(flight: FlightLike | null | undefined): string {
  const provided = String(flight?.aircraft_class || '').trim().toLowerCase();
  if (provided && provided !== 'unknown') return provided;

  const category = String(flight?.emitter_category || '').trim().toUpperCase();
  const callsign = String(flight?.flight || '').trim().toUpperCase();

  if (callsign.startsWith('RCH') || callsign.startsWith('NAVY') || callsign.startsWith('ARMY')) return 'military';
  if (category === 'A7') return 'helicopter';
  if (category === 'A5' || category === 'A6' || category === 'A4') return 'airliner';
  if (category === 'B1') return 'glider';
  if (category === 'B2') return 'balloon';
  if (category === 'B5') return 'uav';
  if (category.startsWith('C')) return 'ground';
  if (category.startsWith('D')) return 'military';
  if (category.startsWith('A') || category.startsWith('B')) return 'general_aviation';

  return 'unknown';
}

export function aircraftTypeLabelForFlight(flight: FlightLike | null | undefined): string {
  switch (inferAircraftClass(flight)) {
    case 'airliner':
      return 'Airliner';
    case 'general_aviation':
      return 'General Aviation';
    case 'helicopter':
      return 'Helicopter';
    case 'military':
      return 'Military';
    case 'glider':
      return 'Glider';
    case 'balloon':
      return 'Balloon';
    case 'uav':
      return 'UAV';
    case 'ground':
      return 'Ground Vehicle';
    case 'space':
      return 'Space Vehicle';
    default:
      return 'Unknown';
  }
}

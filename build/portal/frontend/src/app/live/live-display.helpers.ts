export interface LiveAircraftDisplayLike {
  source?: string | null;
  flight?: string | null;
  aircraft_class?: string | null;
  category?: string | null;
  classification_source?: string | null;
  classification_confidence?: string | null;
}

export type AircraftTypeLegendItem = {
  key: string;
  label: string;
};

const ALTITUDE_TIERS = [
  { max: -1,     color: '#64748b' },
  { max: 5_000,  color: '#38bdf8' },
  { max: 15_000, color: '#22c55e' },
  { max: 30_000, color: '#f59e0b' },
  { max: 45_000, color: '#f97316' },
  { max: Infinity, color: '#ef4444' },
] as const;

export const AIRCRAFT_TYPE_LEGEND: AircraftTypeLegendItem[] = [
  { key: 'airliner', label: 'Airliner' },
  { key: 'general_aviation', label: 'General Aviation' },
  { key: 'helicopter', label: 'Helicopter' },
  { key: 'military', label: 'Military' },
  { key: 'glider', label: 'Glider' },
  { key: 'balloon', label: 'Balloon' },
  { key: 'uav', label: 'UAV' },
  { key: 'ground', label: 'Ground Vehicle' },
  { key: 'unknown', label: 'Unknown' },
];

export function altitudeColor(alt: number | null | undefined): string {
  if (alt == null) return '#64748b';
  for (const tier of ALTITUDE_TIERS) {
    if (alt <= tier.max) return tier.color;
  }
  return '#ef4444';
}

export function sourceColor(source: string | null | undefined): string {
  return source === 'dump978' ? '#f59e0b' : '#22d3ee';
}

export function classifyAircraftForIcon(ac: LiveAircraftDisplayLike | null | undefined): string {
  const provided = (ac?.aircraft_class || '').trim().toLowerCase();
  if (provided) return provided;

  const category = (ac?.category || '').trim().toUpperCase();
  const callsign = (ac?.flight || '').trim().toUpperCase();

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

export function aircraftTypeLabel(ac: LiveAircraftDisplayLike | null | undefined): string {
  const klass = (ac?.aircraft_class || '').trim().toLowerCase();
  switch (klass) {
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

export function aircraftTypeSourceLabel(ac: LiveAircraftDisplayLike | null | undefined): string {
  const source = (ac?.classification_source || '').trim().toLowerCase();
  const confidence = (ac?.classification_confidence || '').trim().toLowerCase();
  const confidenceLabel = confidence ? ` (${confidence})` : '';

  if (source === 'opensky') {
    return `OpenSky${confidenceLabel}`;
  }
  return `Heuristic${confidenceLabel}`;
}

export function flightHistoryLink(ac: LiveAircraftDisplayLike): string | null {
  if (!ac.flight) return null;
  const flightType = ac.source === 'dump978' ? 'uat' : 'adsb';
  return `/flight-history/${flightType}/${encodeURIComponent(ac.flight)}`;
}

export function sourceLabel(ac: LiveAircraftDisplayLike): string {
  return ac.source === 'dump978' ? 'Dump978 (UAT)' : 'Dump1090 (ADS-B)';
}

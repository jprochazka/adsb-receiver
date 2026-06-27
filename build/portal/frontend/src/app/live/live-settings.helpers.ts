export interface LiveMapSettingsInput {
  enabled?: string;
  refreshMs?: string;
  centerLat?: string;
  centerLon?: string;
  zoom?: string;
  trailPoints?: string;
  showAllSeen?: string;
  spiderOverlayEnabled?: string;
  centerIconEnabled?: string;
  distanceRingsEnabled?: string;
  distanceRingCompassLinesEnabled?: string;
  distanceRingCount?: string;
  distanceRingIntervalMiles?: string;
  theoreticalRangeEnabled?: string;
  theoreticalRangeJson?: string;
  heyWhatsThatRingsEnabled?: string;
  heyWhatsThatRingsJson?: string;
}

export interface LiveMapSettings {
  liveMapEnabled: boolean;
  refreshMs: number;
  defaultCenterLon: number;
  defaultCenterLat: number;
  defaultZoom: number;
  trailPoints: number;
  showAllSeen: boolean;
  liveMapSpiderOverlayEnabled: boolean;
  liveMapCenterIconEnabled: boolean;
  liveMapDistanceRingsEnabled: boolean;
  liveMapDistanceRingCompassLinesEnabled: boolean;
  liveMapDistanceRingCount: number;
  liveMapDistanceRingIntervalMiles: number;
  liveMapTheoreticalRangeEnabled: boolean;
  liveMapTheoreticalRangeJson: string;
  liveMapHeyWhatsThatRingsEnabled: boolean;
  liveMapHeyWhatsThatRingsJson: string;
}

export const DEFAULT_LIVE_MAP_SETTINGS: LiveMapSettings = {
  liveMapEnabled: true,
  refreshMs: 5_000,
  defaultCenterLon: 0,
  defaultCenterLat: 20,
  defaultZoom: 3,
  trailPoints: 20,
  showAllSeen: true,
  liveMapSpiderOverlayEnabled: true,
  liveMapCenterIconEnabled: true,
  liveMapDistanceRingsEnabled: false,
  liveMapDistanceRingCompassLinesEnabled: true,
  liveMapDistanceRingCount: 4,
  liveMapDistanceRingIntervalMiles: 25,
  liveMapTheoreticalRangeEnabled: false,
  liveMapTheoreticalRangeJson: '',
  liveMapHeyWhatsThatRingsEnabled: false,
  liveMapHeyWhatsThatRingsJson: '',
};

export const MIN_FLYOUT_WIDTH = 240;
export const MAX_FLYOUT_WIDTH = 560;
export const DEFAULT_FLYOUT_WIDTH = 280;

export function parseLiveMapSettings(input: LiveMapSettingsInput): LiveMapSettings {
  return {
    liveMapEnabled: input.enabled !== 'false',
    refreshMs: clampInt(input.refreshMs, 1_000, 60_000, DEFAULT_LIVE_MAP_SETTINGS.refreshMs),
    defaultCenterLat: clampFloat(input.centerLat, -85, 85, DEFAULT_LIVE_MAP_SETTINGS.defaultCenterLat),
    defaultCenterLon: clampFloat(input.centerLon, -180, 180, DEFAULT_LIVE_MAP_SETTINGS.defaultCenterLon),
    defaultZoom: clampInt(input.zoom, 1, 18, DEFAULT_LIVE_MAP_SETTINGS.defaultZoom),
    trailPoints: clampInt(input.trailPoints, 0, 200, DEFAULT_LIVE_MAP_SETTINGS.trailPoints),
    showAllSeen: input.showAllSeen !== 'false',
    liveMapSpiderOverlayEnabled: input.spiderOverlayEnabled !== 'false',
    liveMapCenterIconEnabled: input.centerIconEnabled !== 'false',
    liveMapDistanceRingsEnabled: input.distanceRingsEnabled === 'true',
    liveMapDistanceRingCompassLinesEnabled: input.distanceRingCompassLinesEnabled !== 'false',
    liveMapDistanceRingCount: clampInt(input.distanceRingCount, 1, 12, DEFAULT_LIVE_MAP_SETTINGS.liveMapDistanceRingCount),
    liveMapDistanceRingIntervalMiles: clampInt(input.distanceRingIntervalMiles, 1, 250, DEFAULT_LIVE_MAP_SETTINGS.liveMapDistanceRingIntervalMiles),
    liveMapTheoreticalRangeEnabled: input.theoreticalRangeEnabled === 'true',
    liveMapTheoreticalRangeJson: String(input.theoreticalRangeJson ?? '').trim(),
    liveMapHeyWhatsThatRingsEnabled: input.heyWhatsThatRingsEnabled === 'true',
    liveMapHeyWhatsThatRingsJson: String(input.heyWhatsThatRingsJson ?? '').trim(),
  };
}

export function clampFlyoutWidth(
  width: number,
  viewportWidth: number,
  minWidth = MIN_FLYOUT_WIDTH,
  maxWidth = MAX_FLYOUT_WIDTH,
): number {
  const viewportMax = Math.max(minWidth, viewportWidth - 80);
  const max = Math.min(maxWidth, viewportMax);
  return Math.max(minWidth, Math.min(max, width));
}

function clampInt(raw: string | undefined, min: number, max: number, fallback: number): number {
  const parsed = Number.parseInt(String(raw ?? ''), 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(min, Math.min(max, parsed));
}

function clampFloat(raw: string | undefined, min: number, max: number, fallback: number): number {
  const parsed = Number.parseFloat(String(raw ?? ''));
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(min, Math.min(max, parsed));
}

import { DEFAULT_LIVE_MAP_SETTINGS, clampFlyoutWidth, parseLiveMapSettings } from './live-settings.helpers';

describe('live settings helpers', () => {
  it('parses bounded numeric settings and trims overlay JSON values', () => {
    const settings = parseLiveMapSettings({
      enabled: 'true',
      refreshMs: '999',
      centerLat: '95',
      centerLon: '-200',
      zoom: '22',
      trailPoints: '250',
      distanceRingCount: '20',
      distanceRingIntervalMiles: '999',
      theoreticalRangeJson: '  {"type":"FeatureCollection"}  ',
      heyWhatsThatRingsJson: '  [[1,2],[3,4],[5,6]]  ',
    });

    expect(settings.liveMapEnabled).toBeTrue();
    expect(settings.refreshMs).toBe(1_000);
    expect(settings.defaultCenterLat).toBe(85);
    expect(settings.defaultCenterLon).toBe(-180);
    expect(settings.defaultZoom).toBe(18);
    expect(settings.trailPoints).toBe(200);
    expect(settings.liveMapDistanceRingCount).toBe(12);
    expect(settings.liveMapDistanceRingIntervalMiles).toBe(250);
    expect(settings.liveMapTheoreticalRangeJson).toBe('{"type":"FeatureCollection"}');
    expect(settings.liveMapHeyWhatsThatRingsJson).toBe('[[1,2],[3,4],[5,6]]');
  });

  it('preserves existing boolean defaults and true-only flags', () => {
    const settings = parseLiveMapSettings({
      enabled: 'false',
      showAllSeen: 'false',
      spiderOverlayEnabled: 'false',
      centerIconEnabled: 'false',
      distanceRingsEnabled: 'true',
      distanceRingCompassLinesEnabled: 'false',
      theoreticalRangeEnabled: 'true',
      heyWhatsThatRingsEnabled: 'true',
    });

    expect(settings.liveMapEnabled).toBeFalse();
    expect(settings.showAllSeen).toBeFalse();
    expect(settings.liveMapSpiderOverlayEnabled).toBeFalse();
    expect(settings.liveMapCenterIconEnabled).toBeFalse();
    expect(settings.liveMapDistanceRingsEnabled).toBeTrue();
    expect(settings.liveMapDistanceRingCompassLinesEnabled).toBeFalse();
    expect(settings.liveMapTheoreticalRangeEnabled).toBeTrue();
    expect(settings.liveMapHeyWhatsThatRingsEnabled).toBeTrue();
  });

  it('falls back to defaults for invalid numeric values', () => {
    const settings = parseLiveMapSettings({
      refreshMs: 'not-a-number',
      centerLat: undefined,
      centerLon: '',
      zoom: 'NaN',
      trailPoints: 'bad',
      distanceRingCount: 'bad',
      distanceRingIntervalMiles: 'bad',
    });

    expect(settings.refreshMs).toBe(DEFAULT_LIVE_MAP_SETTINGS.refreshMs);
    expect(settings.defaultCenterLat).toBe(DEFAULT_LIVE_MAP_SETTINGS.defaultCenterLat);
    expect(settings.defaultCenterLon).toBe(DEFAULT_LIVE_MAP_SETTINGS.defaultCenterLon);
    expect(settings.defaultZoom).toBe(DEFAULT_LIVE_MAP_SETTINGS.defaultZoom);
    expect(settings.trailPoints).toBe(DEFAULT_LIVE_MAP_SETTINGS.trailPoints);
    expect(settings.liveMapDistanceRingCount).toBe(DEFAULT_LIVE_MAP_SETTINGS.liveMapDistanceRingCount);
    expect(settings.liveMapDistanceRingIntervalMiles).toBe(DEFAULT_LIVE_MAP_SETTINGS.liveMapDistanceRingIntervalMiles);
  });

  it('clamps flyout width using configured bounds and viewport width', () => {
    expect(clampFlyoutWidth(100, 1200)).toBe(240);
    expect(clampFlyoutWidth(600, 1200)).toBe(560);
    expect(clampFlyoutWidth(500, 520)).toBe(440);
    expect(clampFlyoutWidth(260, 300)).toBe(240);
  });
});

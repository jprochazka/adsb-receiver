import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { of } from 'rxjs';

import { LiveComponent } from './live.component';
import { extractOverlayRings } from './live-overlay.helpers';
import { DataService } from '../service/data.service';

describe('LiveComponent', () => {
  let component: LiveComponent;
  let fixture: ComponentFixture<LiveComponent>;

  const livePayload = {
    now: 1700000000,
    messages: 42,
    aircraft: [
      {
        source: 'dump1090',
        hex: 'abc123',
        flight: 'AAL123',
        lat: 41.0,
        lon: -87.0,
        altitude: 10000,
        speed: 250,
        track: 90,
        vertical_rate: 0,
        squawk: '1200',
        category: 'A3',
        seen: 1,
        rssi: -12,
        type: 'adsb_icao',
        aircraft_class: 'airliner',
        classification_source: 'opensky',
        classification_confidence: 'high',
      },
      {
        source: 'dump1090',
        hex: 'def456',
        flight: 'NOFIX1',
        lat: null,
        lon: null,
        altitude: null,
        speed: null,
        track: null,
        vertical_rate: null,
        squawk: null,
        category: null,
        seen: 9,
        rssi: -18,
        type: 'adsb_icao',
        aircraft_class: 'unknown',
        classification_source: 'heuristic',
        classification_confidence: 'low',
      },
    ],
  };

  const dataServiceMock = {
    getSetting: jasmine.createSpy('getSetting').and.callFake((name: string) => {
      const values: Record<string, string> = {
        live_map_enabled: 'true',
        live_map_refresh_ms: '3000',
        live_map_center_lat: '40',
        live_map_center_lon: '-90',
        live_map_default_zoom: '5',
        live_map_trail_points: '3',
        live_map_show_all_seen: 'true',
        live_map_spider_overlay_enabled: 'true',
        live_map_center_icon_enabled: 'true',
        live_map_distance_rings_enabled: 'false',
        live_map_distance_ring_compass_lines_enabled: 'true',
        live_map_distance_ring_count: '4',
        live_map_distance_ring_interval_miles: '25',
        live_map_theoretical_range_enabled: 'false',
        live_map_theoretical_range_json: '',
        live_map_heywhatsthat_rings_enabled: 'false',
        live_map_heywhatsthat_rings_json: '',
      };
      return of({ value: values[name] ?? 'true' });
    }),
    getLiveAircraft: jasmine.createSpy('getLiveAircraft').and.returnValue(of(livePayload)),
    getAircraftPhoto: jasmine.createSpy('getAircraftPhoto').and.returnValue(of({ photos: [] })),
  };

  const defaultGetSetting = (name: string) => {
    const values: Record<string, string> = {
      live_map_enabled: 'true',
      live_map_refresh_ms: '3000',
      live_map_center_lat: '40',
      live_map_center_lon: '-90',
      live_map_default_zoom: '5',
      live_map_trail_points: '3',
      live_map_show_all_seen: 'true',
      live_map_spider_overlay_enabled: 'true',
      live_map_center_icon_enabled: 'true',
      live_map_distance_rings_enabled: 'false',
      live_map_distance_ring_compass_lines_enabled: 'true',
      live_map_distance_ring_count: '4',
      live_map_distance_ring_interval_miles: '25',
      live_map_theoretical_range_enabled: 'false',
      live_map_theoretical_range_json: '',
      live_map_heywhatsthat_rings_enabled: 'false',
      live_map_heywhatsthat_rings_json: '',
    };
    return of({ value: values[name] ?? 'true' });
  };

  function stubMap(): void {
    spyOn<any>(component, 'initMap').and.callFake(() => {
      (component as any).olMap = {
        setTarget: () => {},
        on: () => {},
        addControl: () => {},
        hasFeatureAtPixel: () => false,
        forEachFeatureAtPixel: () => null,
        getTargetElement: () => document.createElement('div'),
        getView: () => ({ animate: () => {} }),
      };
    });
  }

  beforeEach(async () => {
    dataServiceMock.getSetting.and.callFake(defaultGetSetting);
    dataServiceMock.getLiveAircraft.and.returnValue(of(livePayload));
    dataServiceMock.getAircraftPhoto.and.returnValue(of({ photos: [] }));
    dataServiceMock.getSetting.calls.reset();
    dataServiceMock.getLiveAircraft.calls.reset();
    dataServiceMock.getAircraftPhoto.calls.reset();

    await TestBed.configureTestingModule({
      imports: [LiveComponent],
      providers: [
        provideRouter([]),
        { provide: DataService, useValue: dataServiceMock },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(LiveComponent);
    component = fixture.componentInstance;
    stubMap();
  });

  it('should create', () => {
    fixture.detectChanges();
    expect(component).toBeTruthy();
  });

  it('should load settings and poll live aircraft data', () => {
    fixture.detectChanges();

    expect(component.liveMapEnabled).toBeTrue();
    expect(component.refreshMs).toBe(3000);
    expect(component.defaultCenterLat).toBe(40);
    expect(component.defaultCenterLon).toBe(-90);
    expect(component.defaultZoom).toBe(5);
    expect(component.trailPoints).toBe(3);
    expect(component.showAllSeen).toBeTrue();
    expect(component.liveMapCenterIconEnabled).toBeTrue();
    expect(component.liveMapDistanceRingsEnabled).toBeFalse();
    expect(component.liveMapDistanceRingCompassLinesEnabled).toBeTrue();
    expect(component.liveMapDistanceRingCount).toBe(4);
    expect(component.liveMapDistanceRingIntervalMiles).toBe(25);
    expect(component.liveMapTheoreticalRangeEnabled).toBeFalse();
    expect(component.liveMapTheoreticalRangeJson).toBe('');
    expect(component.liveMapHeyWhatsThatRingsEnabled).toBeFalse();
    expect(component.liveMapHeyWhatsThatRingsJson).toBe('');

    expect(dataServiceMock.getLiveAircraft).toHaveBeenCalled();
    expect(component.loading).toBeFalse();
    expect(component.aircraft.length).toBe(2);
    expect(component.filteredAircraft.length).toBe(2);
  });

  it('should hide non-positioned aircraft when show-all-seen is disabled', () => {
    dataServiceMock.getSetting.and.callFake((name: string) => {
      if (name === 'live_map_show_all_seen') return of({ value: 'false' });
      return defaultGetSetting(name);
    });

    fixture = TestBed.createComponent(LiveComponent);
    component = fixture.componentInstance;
    stubMap();

    fixture.detectChanges();

    expect(component.showAllSeen).toBeFalse();
    expect(component.aircraft.length).toBe(2);
    expect(component.filteredAircraft.length).toBe(1);
    expect(component.filteredAircraft[0].hex).toBe('abc123');
  });

  it('should not poll live aircraft when map is disabled', () => {
    dataServiceMock.getSetting.and.callFake((name: string) => {
      if (name === 'live_map_enabled') return of({ value: 'false' });
      return of({ value: 'true' });
    });

    fixture = TestBed.createComponent(LiveComponent);
    component = fixture.componentInstance;
    stubMap();

    fixture.detectChanges();

    expect(component.liveMapEnabled).toBeFalse();
    expect(dataServiceMock.getLiveAircraft).not.toHaveBeenCalled();
    expect(component.errorMessage).toContain('disabled');
  });

  it('should retain short trails for moving aircraft', () => {
    fixture.detectChanges();

    const secondPayload = {
      ...livePayload,
      aircraft: [
        {
          ...livePayload.aircraft[0],
          lat: 41.001,
          lon: -87.001,
        },
      ],
    };

    (component as any).handleData(secondPayload);

    const trailHistory = (component as any).trailHistory['abc123'];
    expect(trailHistory).toBeDefined();
    expect(trailHistory.length).toBeGreaterThan(1);
  });

  it('should interpolate live trail points when updates are sparse', () => {
    fixture.detectChanges();

    const history: any[] = [{ coord: [0, 0], ts: 0 }];
    (component as any).appendTrailPoint(history, [6000, 0], 30_000);

    expect(history.length).toBeGreaterThan(2);
    expect(history[history.length - 1].coord).toEqual([6000, 0]);
  });

  it('should smooth interior trail coordinates while preserving endpoints', () => {
    fixture.detectChanges();

    const coords = [
      [0, 0],
      [10, 20],
      [20, 0],
      [30, 20],
    ];

    const smoothed = (component as any).smoothTrailCoordinates(coords) as number[][];

    expect(smoothed.length).toBe(coords.length);
    expect(smoothed[0]).toEqual(coords[0]);
    expect(smoothed[smoothed.length - 1]).toEqual(coords[coords.length - 1]);
    expect(smoothed[1][1]).toBeLessThan(coords[1][1]);
  });

  it('should filter aircraft by callsign and hex', () => {
    fixture.detectChanges();

    component.filterQuery = 'aal';
    component.applyFilter();
    expect(component.filteredAircraft.length).toBe(1);

    component.filterQuery = 'zzz';
    component.applyFilter();
    expect(component.filteredAircraft.length).toBe(0);
  });

  it('should build a UAT history link for dump978 aircraft', () => {
    fixture.detectChanges();

    const link = component.flightHistoryLink({
      ...livePayload.aircraft[0],
      source: 'dump978',
    });

    expect(link).toBe('/flight-history/uat/AAL123');
  });

  it('should add compass rays only when enabled on distance rings', () => {
    fixture.detectChanges();

    (component as any).liveMapDistanceRingsEnabled = true;
    (component as any).liveMapDistanceRingCount = 3;
    (component as any).liveMapDistanceRingIntervalMiles = 10;
    (component as any).liveMapDistanceRingCompassLinesEnabled = true;
    (component as any).initDistanceRings();

    const withRays = (component as any).distanceRingSource.getFeatures() as Array<{ get: (k: string) => string | undefined }>;
    const ringCount = withRays.filter(f => f.get('distanceRingKind') === 'ring').length;
    const rayCount = withRays.filter(f => f.get('distanceRingKind') === 'ray').length;

    expect(ringCount).toBe(3);
    expect(rayCount).toBe(16);

    (component as any).liveMapDistanceRingCompassLinesEnabled = false;
    (component as any).initDistanceRings();
    const withoutRays = (component as any).distanceRingSource.getFeatures() as Array<{ get: (k: string) => string | undefined }>;
    const rayCountDisabled = withoutRays.filter(f => f.get('distanceRingKind') === 'ray').length;

    expect(rayCountDisabled).toBe(0);
  });

  it('should render a dedicated unknown icon for unknown aircraft class', () => {
    fixture.detectChanges();

    const svg = (component as any).svgForAircraftClass('unknown', '#000000', '#ffffff') as string;

    expect(svg).toContain('M25,4 C26.5,4 28,14 28,24');
    expect(svg).toContain('M28,22 L42,32 L40,36');
    expect(svg).toContain('M25,44 L32,48');
  });

  it('should rotate helicopter rotors by 45 degrees', () => {
    fixture.detectChanges();

    const svg = (component as any).svgForAircraftClass('helicopter', '#000000', '#ffffff') as string;

    expect(svg).toContain('transform="rotate(45 25 23)"');
  });

  it('should render general aviation as a single-engine light-aircraft silhouette', () => {
    fixture.detectChanges();

    const svg = (component as any).svgForAircraftClass('general_aviation', '#000000', '#ffffff') as string;

    expect(svg).toContain('<path d="M25,3.8 L27.6,11.6 L40.8,16.4');
    expect(svg).toContain('<circle cx="25" cy="4.8" r="1.1"');
  });

  it('should parse coordinate-array theoretical range json into rings', () => {
    fixture.detectChanges();

    const parsed = extractOverlayRings(
      JSON.stringify([
        [-90.0, 40.0],
        [-90.1, 40.0],
        [-90.1, 40.1],
        [-90.0, 40.0]
      ])
    ) as number[][][];

    expect(parsed.length).toBeGreaterThan(0);
    expect(parsed[0].length).toBeGreaterThan(3);
  });

  it('should ignore invalid theoretical range json', () => {
    fixture.detectChanges();

    const parsed = extractOverlayRings('{not-json') as number[][][];
    expect(parsed.length).toBe(0);
  });

  it('should render heywhatsthat overlay rings when enabled', () => {
    fixture.detectChanges();

    (component as any).liveMapHeyWhatsThatRingsEnabled = true;
    (component as any).liveMapHeyWhatsThatRingsJson = JSON.stringify([
      [-90.0, 40.0],
      [-90.2, 40.0],
      [-90.1, 40.2],
      [-90.0, 40.0]
    ]);

    (component as any).initHeyWhatsThatRingsOverlay();

    const features = (component as any).heyWhatsThatRingsSource.getFeatures();
    expect(features.length).toBe(1);
  });

  it('should format aircraft type and source labels', () => {
    fixture.detectChanges();

    const typeLabel = component.aircraftTypeLabel(livePayload.aircraft[0] as any);
    const sourceLabel = component.aircraftTypeSourceLabel(livePayload.aircraft[0] as any);

    expect(typeLabel).toBe('Airliner');
    expect(sourceLabel).toBe('OpenSky (high)');
  });

  it('should render aircraft type legend on map', () => {
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent as string;
    expect(text).toContain('Aircraft Types');
    expect(text).toContain('General Aviation');
    expect(text).toContain('Unknown');
  });

  it('should include OpenSky attribution in map source attributions', () => {
    ((component as any).initMap as jasmine.Spy).and.callThrough();
    fixture.detectChanges();

    const source = (component as any).olMap.getLayers().item(0).getSource();
    const attributionLike = source.getAttributions();
    const attributions = typeof attributionLike === 'function'
      ? String(attributionLike(undefined as any))
      : String(attributionLike ?? '');

    expect(attributions).toContain('OpenSky Network Aircraft Database (ODbL v1.0)');
    expect(attributions).toContain('openstreetmap.org/copyright');
  });

  it('should keep map container rendered', () => {
    fixture.detectChanges();

    const mapContainer = fixture.nativeElement.querySelector('#live');
    expect(mapContainer).withContext('OpenLayers map target element missing').not.toBeNull();
  });

  it('should generate data-url legend icon markup for aircraft types', () => {
    fixture.detectChanges();

    const icon = component.aircraftTypeLegendIconDataUrl('helicopter');

    expect(icon.startsWith('data:image/svg+xml;utf8,')).toBeTrue();
    expect(icon).toContain('%3Csvg');
  });
});

import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { of } from 'rxjs';

import { LiveComponent } from './live.component';
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
});

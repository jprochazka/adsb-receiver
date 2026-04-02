import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of } from 'rxjs';

import { AdminLiveComponent } from './admin-live.component';
import { DataService } from '../service/data.service';

describe('AdminLiveComponent', () => {
  let component: AdminLiveComponent;
  let fixture: ComponentFixture<AdminLiveComponent>;

  const defaultSettings: Record<string, string> = {
    live_map_enabled: 'true',
    live_map_refresh_ms: '4000',
    live_map_center_lat: '41.50',
    live_map_center_lon: '-87.75',
    live_map_default_zoom: '6',
    live_map_trail_points: '33',
    live_map_show_all_seen: 'true',
    live_map_spider_overlay_enabled: 'true',
    live_map_center_icon_enabled: 'true',
    live_map_distance_rings_enabled: 'false',
    live_map_distance_ring_compass_lines_enabled: 'true',
    live_map_distance_ring_count: '4',
    live_map_distance_ring_interval_miles: '25',
    live_map_theoretical_range_enabled: 'false',
    live_map_theoretical_range_json: '',
    live_map_json_url: 'http://192.168.1.25/dump1090/data/aircraft.json',
    live_map_json_url_dump978: 'http://192.168.1.25/dump978/data/aircraft.json',
    live_map_custom_presets: '[{"label":"Home","refreshMs":2500,"centerLat":39,"centerLon":-95,"zoom":7,"trailPoints":40},{"label":"Summer","refreshMs":5000,"centerLat":20,"centerLon":0,"zoom":3,"trailPoints":20},{"label":"Winter","refreshMs":7000,"centerLat":50,"centerLon":10,"zoom":4,"trailPoints":15}]',
  };

  const dataServiceMock = {
    getSetting: jasmine.createSpy('getSetting').and.callFake((name: string) => {
      return of({ value: defaultSettings[name] ?? 'true' });
    }),
    updateSetting: jasmine.createSpy('updateSetting').and.returnValue(of({})),
  };

  beforeEach(async () => {
    dataServiceMock.getSetting.and.callFake((name: string) => of({ value: defaultSettings[name] ?? 'true' }));
    dataServiceMock.getSetting.calls.reset();
    dataServiceMock.updateSetting.calls.reset();

    await TestBed.configureTestingModule({
      imports: [AdminLiveComponent],
      providers: [{ provide: DataService, useValue: dataServiceMock }],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminLiveComponent);
    component = fixture.componentInstance;
  });

  it('should create', () => {
    fixture.detectChanges();
    expect(component).toBeTruthy();
  });

  it('should load saved settings', () => {
    fixture.detectChanges();

    expect(component.loading).toBeFalse();
    expect(component.liveMapEnabled).toBeTrue();
    expect(component.liveMapRefreshMs).toBe(4000);
    expect(component.liveMapCenterLat).toBe(41.5);
    expect(component.liveMapCenterLon).toBe(-87.75);
    expect(component.liveMapDefaultZoom).toBe(6);
    expect(component.liveMapTrailPoints).toBe(33);
    expect(component.liveMapShowAllSeen).toBeTrue();
    expect(component.liveMapSpiderOverlayEnabled).toBeTrue();
    expect(component.liveMapCenterIconEnabled).toBeTrue();
    expect(component.liveMapDistanceRingsEnabled).toBeFalse();
    expect(component.liveMapDistanceRingCompassLinesEnabled).toBeTrue();
    expect(component.liveMapDistanceRingCount).toBe(4);
    expect(component.liveMapDistanceRingIntervalMiles).toBe(25);
    expect(component.liveMapTheoreticalRangeEnabled).toBeFalse();
    expect(component.liveMapTheoreticalRangeJson).toBe('');
    expect(component.dump1090JsonUrl).toBe('http://192.168.1.25/dump1090/data/aircraft.json');
    expect(component.dump978JsonUrl).toBe('http://192.168.1.25/dump978/data/aircraft.json');
    expect(component.customPresetSlots.length).toBe(3);
    expect(component.customPresetSlots[0].label).toBe('Home');
  });

  it('should save live map settings', () => {
    fixture.detectChanges();

    component.liveMapEnabled = false;
    component.saveLiveMapEnabled();
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_enabled', 'false');

    component.liveMapRefreshMs = 700;
    component.saveLiveMapRefreshMs();
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_refresh_ms', '1000');

    component.liveMapTrailPoints = 250;
    component.saveLiveMapTrailPoints();
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_trail_points', '200');

    component.liveMapShowAllSeen = false;
    component.saveLiveMapShowAllSeen();
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_show_all_seen', 'false');

    component.liveMapSpiderOverlayEnabled = false;
    component.saveLiveMapSpiderOverlayEnabled();
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_spider_overlay_enabled', 'false');

    component.liveMapCenterIconEnabled = false;
    component.saveLiveMapCenterIconEnabled();
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_center_icon_enabled', 'false');

    component.liveMapDistanceRingsEnabled = true;
    component.saveLiveMapDistanceRingsEnabled();
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_distance_rings_enabled', 'true');

    component.liveMapDistanceRingCompassLinesEnabled = false;
    component.saveLiveMapDistanceRingCompassLinesEnabled();
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_distance_ring_compass_lines_enabled', 'false');

    component.liveMapDistanceRingCount = 20;
    component.saveLiveMapDistanceRingCount();
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_distance_ring_count', '12');

    component.liveMapDistanceRingIntervalMiles = 0;
    component.saveLiveMapDistanceRingIntervalMiles();
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_distance_ring_interval_miles', '1');

    component.liveMapTheoreticalRangeEnabled = true;
    component.saveLiveMapTheoreticalRangeEnabled();
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_theoretical_range_enabled', 'true');

    component.dump1090JsonUrl = 'http://localhost:8080/custom-1090.json';
    component.saveDump1090JsonUrl();
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_json_url', 'http://localhost:8080/custom-1090.json');

    component.dump978JsonUrl = 'http://localhost:8080/custom-978.json';
    component.saveDump978JsonUrl();
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_json_url_dump978', 'http://localhost:8080/custom-978.json');
  });

  it('should reject invalid theoretical range json', () => {
    fixture.detectChanges();

    component.liveMapTheoreticalRangeJson = '{invalid json';
    component.saveLiveMapTheoreticalRangeJson();

    expect(component.errorMessage).toContain('not valid JSON');
    expect(dataServiceMock.updateSetting).not.toHaveBeenCalledWith('live_map_theoretical_range_json', jasmine.any(String));
  });

  it('should save valid theoretical range json', () => {
    fixture.detectChanges();

    component.liveMapTheoreticalRangeJson = '{"type":"FeatureCollection","features":[]}';
    component.saveLiveMapTheoreticalRangeJson();

    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith(
      'live_map_theoretical_range_json',
      '{"type":"FeatureCollection","features":[]}'
    );
  });

  it('should apply preset and persist all fields', () => {
    fixture.detectChanges();

    component.applyLiveMapPreset('local');

    expect(component.liveMapEnabled).toBeTrue();
    expect(component.liveMapRefreshMs).toBe(2000);
    expect(component.liveMapCenterLat).toBe(39);
    expect(component.liveMapCenterLon).toBe(-95);
    expect(component.liveMapDefaultZoom).toBe(7);
    expect(component.liveMapTrailPoints).toBe(30);

    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_enabled', 'true');
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_refresh_ms', '2000');
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_center_lat', '39');
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_center_lon', '-95');
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_default_zoom', '7');
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_trail_points', '30');
  });

  it('should save current values into custom preset slot', () => {
    fixture.detectChanges();

    component.liveMapRefreshMs = 2100;
    component.liveMapCenterLat = 44.4;
    component.liveMapCenterLon = -88.8;
    component.liveMapDefaultZoom = 8;
    component.liveMapTrailPoints = 26;
    component.customPresetSlots[0].label = 'My Home';

    component.saveCurrentAsCustomPreset(0);

    expect(component.customPresetSlots[0].refreshMs).toBe(2100);
    expect(component.customPresetSlots[0].centerLat).toBe(44.4);
    expect(component.customPresetSlots[0].centerLon).toBe(-88.8);
    expect(component.customPresetSlots[0].zoom).toBe(8);
    expect(component.customPresetSlots[0].trailPoints).toBe(26);
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_custom_presets', jasmine.any(String));
  });

  it('should apply custom preset to live settings', () => {
    fixture.detectChanges();

    component.applyCustomPreset(2);

    expect(component.liveMapEnabled).toBeTrue();
    expect(component.liveMapRefreshMs).toBe(7000);
    expect(component.liveMapCenterLat).toBe(50);
    expect(component.liveMapCenterLon).toBe(10);
    expect(component.liveMapDefaultZoom).toBe(4);
    expect(component.liveMapTrailPoints).toBe(15);
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_enabled', 'true');
  });

  it('should delete a custom preset and persist the updated list', () => {
    fixture.detectChanges();

    component.deleteCustomPreset(1);

    expect(component.customPresetSlots.length).toBe(2);
    expect(component.customPresetSlots.some((slot) => slot.label === 'Summer')).toBeFalse();
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_custom_presets', jasmine.any(String));
  });

  it('should add a custom preset and persist the updated list', () => {
    fixture.detectChanges();

    component.addCustomPreset();

    expect(component.customPresetSlots.length).toBe(4);
    expect(component.customPresetSlots[3].label).toBe('Preset 4');
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('live_map_custom_presets', jasmine.any(String));
  });

  it('should load an empty custom preset list from settings', () => {
    dataServiceMock.getSetting.and.callFake((name: string) => {
      if (name === 'live_map_custom_presets') return of({ value: '[]' });

      const values: Record<string, string> = {
        live_map_enabled: 'true',
        live_map_refresh_ms: '4000',
        live_map_center_lat: '41.50',
        live_map_center_lon: '-87.75',
        live_map_default_zoom: '6',
        live_map_trail_points: '33',
        live_map_show_all_seen: 'true',
        live_map_spider_overlay_enabled: 'true',
        live_map_center_icon_enabled: 'true',
        live_map_distance_rings_enabled: 'false',
        live_map_distance_ring_compass_lines_enabled: 'true',
        live_map_distance_ring_count: '4',
        live_map_distance_ring_interval_miles: '25',
        live_map_theoretical_range_enabled: 'false',
        live_map_theoretical_range_json: '',
        live_map_json_url: 'http://192.168.1.25/dump1090/data/aircraft.json',
        live_map_json_url_dump978: 'http://192.168.1.25/dump978/data/aircraft.json',
      };
      return of({ value: values[name] ?? 'true' });
    });

    fixture = TestBed.createComponent(AdminLiveComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();

    expect(component.customPresetSlots.length).toBe(0);
  });

  it('should prevent adding more than ten custom presets', () => {
    fixture.detectChanges();

    for (let i = 0; i < 10; i++) {
      component.addCustomPreset();
    }

    expect(component.customPresetSlots.length).toBe(10);
    expect(component.errorMessage).toContain('Maximum of 10 custom presets reached');
  });
});

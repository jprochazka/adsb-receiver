import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { AdminDevicesComponent } from './admin-devices.component';
import { DataService } from '../service/data.service';

describe('AdminDevicesComponent', () => {
  let component: AdminDevicesComponent;
  let fixture: ComponentFixture<AdminDevicesComponent>;

  const dataServiceMock = {
    getSetting: jasmine.createSpy('getSetting').and.callFake((name: string) => {
      const values: Record<string, string> = {
        info_nav_enabled: 'true',
        info_system_enabled: 'true',
        info_graphs_enabled: 'false',
        info_stats_enabled: 'true',
        graphs_dump1090_enabled: 'true',
        graphs_dump978_enabled: 'false',
        graphs_measurement_range: 'metric',
        graphs_measurement_temperature: 'metric',
        graphs_network_interface: 'wlan0',
        graphs_refresh_interval_ms: '2000',
      };
      return of({ value: values[name] ?? 'true' });
    }),
    updateSetting: jasmine.createSpy('updateSetting').and.returnValue(of({})),
  };

  beforeEach(async () => {
    dataServiceMock.getSetting.calls.reset();
    dataServiceMock.updateSetting.calls.reset();
    dataServiceMock.updateSetting.and.returnValue(of({}));

    await TestBed.configureTestingModule({
      imports: [AdminDevicesComponent],
      providers: [{ provide: DataService, useValue: dataServiceMock }],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminDevicesComponent);
    component = fixture.componentInstance;
  });

  it('should create', () => {
    fixture.detectChanges();
    expect(component).toBeTruthy();
  });

  it('should load information settings on init', () => {
    fixture.detectChanges();

    expect(component.infoNavEnabled).toBeTrue();
    expect(component.infoGraphsEnabled).toBeFalse();
    expect(component.infoStatsEnabled).toBeTrue();
    expect(component.measurementRange).toBe('metric');
    expect(component.networkInterface).toBe('wlan0');
    expect(component.graphRefreshIntervalSeconds).toBe(3);
    expect(component.loading).toBeFalse();
  });

  it('should save graph refresh interval in milliseconds', () => {
    fixture.detectChanges();
    component.graphRefreshIntervalSeconds = 121;

    component.saveGraphRefreshIntervalSeconds();

    expect(component.graphRefreshIntervalSeconds).toBe(120);
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('graphs_refresh_interval_ms', '120000');
  });

  it('should save nav and graph toggles', () => {
    fixture.detectChanges();
    component.infoNavEnabled = false;
    component.dump978GraphsEnabled = true;
    component.infoStatsEnabled = false;

    component.saveInfoNavEnabled();
    component.saveDump978GraphsEnabled();
    component.saveInfoStatsEnabled();

    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('info_nav_enabled', 'false');
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('graphs_dump978_enabled', 'true');
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('info_stats_enabled', 'false');
    expect(component.successMessage).toBe('Setting saved.');
    expect(component.errorMessage).toBe('');
  });

  it('should surface save failures for autosaved settings', () => {
    fixture.detectChanges();
    dataServiceMock.updateSetting.and.returnValue(throwError(() => new Error('failed')));
    component.successMessage = 'Previous success';

    component.saveInfoGraphsEnabled();

    expect(component.successMessage).toBe('');
    expect(component.errorMessage).toBe('Failed to save setting.');
  });
});

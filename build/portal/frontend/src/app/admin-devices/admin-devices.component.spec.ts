import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, Subject, throwError } from 'rxjs';

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
    getDumpVdl2Config: jasmine.createSpy('getDumpVdl2Config').and.returnValue(of({
      installed: true,
      active: true,
      ingest_active: false,
      frequencies: [136.975, 136.1, 136.1],
    })),
    updateDumpVdl2Config: jasmine.createSpy('updateDumpVdl2Config').and.returnValue(of({
      installed: true,
      active: true,
      ingest_active: true,
      frequencies: [136.1, 136.975],
    })),
  };

  beforeEach(async () => {
    dataServiceMock.getSetting.calls.reset();
    dataServiceMock.updateSetting.calls.reset();
    dataServiceMock.updateSetting.and.returnValue(of({}));
    dataServiceMock.getDumpVdl2Config.calls.reset();
    dataServiceMock.getDumpVdl2Config.and.returnValue(of({
      installed: true,
      active: true,
      ingest_active: false,
      frequencies: [136.975, 136.1, 136.1],
    }));
    dataServiceMock.updateDumpVdl2Config.calls.reset();
    dataServiceMock.updateDumpVdl2Config.and.returnValue(of({
      installed: true,
      active: true,
      ingest_active: true,
      frequencies: [136.1, 136.975],
    }));

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

  it('should remain loading until the decoder configuration loads', () => {
    const config$ = new Subject<{
      installed: boolean;
      active: boolean;
      ingest_active: boolean;
      frequencies: number[];
    }>();
    dataServiceMock.getDumpVdl2Config.and.returnValue(config$);

    fixture.detectChanges();
    expect(component.loading).toBeTrue();

    config$.next({
      installed: true,
      active: false,
      ingest_active: true,
      frequencies: [136.975, 136.1, 136.1],
    });
    config$.complete();

    expect(component.loading).toBeFalse();
    expect(component.dumpVdl2Config.frequencies).toEqual([136.1, 136.975]);
    expect(component.dumpVdl2Config.ingest_active).toBeTrue();
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

  it('should validate, normalize, and add decoder frequencies', () => {
    fixture.detectChanges();
    component.dumpVdl2Frequency = 117.995;

    component.addDumpVdl2Frequency();

    expect(component.errorMessage).toContain('between 118.0 and 137.0');
    component.dumpVdl2Frequency = 136.5;
    component.addDumpVdl2Frequency();
    component.dumpVdl2Frequency = 136.1;
    component.addDumpVdl2Frequency();

    expect(component.dumpVdl2Config.frequencies).toEqual([136.1, 136.5, 136.975]);
    expect(component.dumpVdl2Frequency).toBeNull();
    expect(component.errorMessage).toBe('');
  });

  it('should remove frequencies but require at least one', () => {
    fixture.detectChanges();

    component.removeDumpVdl2Frequency(136.1);
    expect(component.dumpVdl2Config.frequencies).toEqual([136.975]);

    component.removeDumpVdl2Frequency(136.975);
    expect(component.dumpVdl2Config.frequencies).toEqual([136.975]);
    expect(component.errorMessage).toContain('At least one');
  });

  it('should save decoder frequencies and apply the returned status', () => {
    fixture.detectChanges();
    component.dumpVdl2Config.frequencies = [136.975, 136.1, 136.1];

    component.saveDumpVdl2Config();

    expect(dataServiceMock.updateDumpVdl2Config).toHaveBeenCalledWith({
      frequencies: [136.1, 136.975],
    });
    expect(component.dumpVdl2Config.ingest_active).toBeTrue();
    expect(component.successMessage).toContain('configuration saved');
    expect(component.savingDumpVdl2).toBeFalse();
  });

  it('should surface decoder save failures', () => {
    fixture.detectChanges();
    dataServiceMock.updateDumpVdl2Config.and.returnValue(throwError(() => new Error('failed')));

    component.saveDumpVdl2Config();

    expect(component.successMessage).toBe('');
    expect(component.errorMessage).toContain('Failed to save VDL Mode 2');
    expect(component.savingDumpVdl2).toBeFalse();
  });

  it('should disable decoder editing when dumpvdl2 is not installed', () => {
    dataServiceMock.getDumpVdl2Config.and.returnValue(of({
      installed: false,
      active: false,
      ingest_active: false,
      frequencies: [136.975],
    }));
    fixture.detectChanges();

    const element: HTMLElement = fixture.nativeElement;
    const frequencyInput = element.querySelector<HTMLInputElement>('#dumpvdl2-frequency');
    const fieldset = element.querySelector<HTMLFieldSetElement>('#dumpvdl2-config fieldset');
    expect(frequencyInput).not.toBeNull();
    expect(fieldset!.disabled).toBeTrue();
    expect(frequencyInput!.matches(':disabled')).toBeTrue();
    expect(element.querySelectorAll<HTMLButtonElement>('#dumpvdl2-config button:disabled').length).toBeGreaterThan(0);
    expect(element.textContent).toContain('Install dumpvdl2 to enable frequency configuration.');

    component.saveDumpVdl2Config();
    expect(dataServiceMock.updateDumpVdl2Config).not.toHaveBeenCalled();
    expect(component.errorMessage).toContain('not installed');
  });
});

import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { AdminGraphsComponent } from './admin-graphs.component';
import { DataService } from '../service/data.service';

describe('AdminGraphsComponent', () => {
  let component: AdminGraphsComponent;
  let fixture: ComponentFixture<AdminGraphsComponent>;

  const dataServiceMock = {
    getSetting: jasmine.createSpy('getSetting').and.callFake((name: string) => {
      const values: Record<string, string> = {
        graphs_measurement_range: 'metric',
        graphs_measurement_temperature: 'metric',
        graphs_network_interface: 'wlan0',
        graphs_dump978_enabled: 'true',
      };
      return of({ value: values[name] ?? 'true' });
    }),
    updateSetting: jasmine.createSpy('updateSetting').and.returnValue(of({})),
  };

  beforeEach(async () => {
    dataServiceMock.getSetting.calls.reset();
    dataServiceMock.getSetting.and.callFake((name: string) => {
      const values: Record<string, string> = {
        graphs_measurement_range: 'metric',
        graphs_measurement_temperature: 'metric',
        graphs_network_interface: 'wlan0',
        graphs_dump978_enabled: 'true',
      };
      return of({ value: values[name] ?? 'true' });
    });
    dataServiceMock.updateSetting.calls.reset();

    await TestBed.configureTestingModule({
      imports: [AdminGraphsComponent],
      providers: [{ provide: DataService, useValue: dataServiceMock }],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminGraphsComponent);
    component = fixture.componentInstance;
  });

  it('should create', () => {
    fixture.detectChanges();
    expect(component).toBeTruthy();
  });

  it('should load settings on init', () => {
    fixture.detectChanges();

    expect(component.measurementRange).toBe('metric');
    expect(component.measurementTemperature).toBe('metric');
    expect(component.networkInterface).toBe('wlan0');
    expect(component.dump978GraphsEnabled).toBeTrue();
    expect(component.loading).toBeFalse();
  });

  it('should handle settings load failure', () => {
    dataServiceMock.getSetting.and.returnValue(throwError(() => new Error('failed')));

    fixture.detectChanges();

    expect(component.loading).toBeFalse();
    expect(component.errorMessage).toBe('Failed to load settings.');
  });

  it('should save graph settings', () => {
    fixture.detectChanges();
    component.measurementRange = 'imperialNautical';
    component.measurementTemperature = 'imperial';
    component.networkInterface = 'eth0';
    component.dump978GraphsEnabled = false;

    component.save();

    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('graphs_measurement_range', 'imperialNautical');
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('graphs_measurement_temperature', 'imperial');
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('graphs_network_interface', 'eth0');
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('graphs_dump978_enabled', 'false');
    expect(component.saving).toBeFalse();
    expect(component.successMessage).toBe('Graph settings saved successfully.');
  });
});

import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Component, Input } from '@angular/core';
import { of, throwError } from 'rxjs';

import { DevicesComponent } from './devices.component';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';
import { RrdChartComponent } from '../shared/rrd-chart/rrd-chart.component';

@Component({
  selector: 'app-spinner',
  standalone: true,
  template: '',
})
class SpinnerStubComponent {}

@Component({
  selector: 'app-rrd-chart',
  standalone: true,
  template: '',
})
class RrdChartStubComponent {
  @Input() config: unknown;
  @Input() period = '';
  @Input() refreshMs = 15000;
}

describe('DevicesComponent', () => {
  let component: DevicesComponent;
  let fixture: ComponentFixture<DevicesComponent>;

  const dataServiceMock = {
    getGraphData: jasmine.createSpy('getGraphData').and.returnValue(of({ labels: [], datasets: [] })),
    getSetting: jasmine.createSpy('getSetting').and.callFake((name: string) => {
      switch (name) {
        case 'info_system_enabled':
          return of({ value: 'true' });
        case 'info_graphs_enabled':
          return of({ value: 'true' });
        case 'graphs_measurement_range':
          return of({ value: 'metric' });
        case 'graphs_measurement_temperature':
          return of({ value: 'metric' });
        case 'graphs_network_interface':
          return of({ value: 'wlan0' });
        case 'graphs_refresh_interval_ms':
          return of({ value: '2000' });
        case 'graphs_dump1090_enabled':
          return of({ value: 'true' });
        case 'graphs_dump978_enabled':
          return of({ value: 'false' });
        default:
          return of({ value: '' });
      }
    }),
    getSystemCpu: jasmine.createSpy('getSystemCpu').and.returnValue(of({ cpu_percent: 15.2 })),
    getSystemMemory: jasmine.createSpy('getSystemMemory').and.returnValue(of({ memory_percent: 45.6 })),
    getSystemDisk: jasmine.createSpy('getSystemDisk').and.returnValue(of({ disk_usage_percent: 62.1 })),
    getSystemNetwork: jasmine.createSpy('getSystemNetwork').and.returnValue(of({ network_interface: 'eth0' })),
    getSystemOther: jasmine.createSpy('getSystemOther').and.returnValue(of({ other_boot_time: 1700000000 })),
    getSystemDatabase: jasmine.createSpy('getSystemDatabase').and.returnValue(of({ size: 1024 })),
  };

  beforeEach(async () => {
    dataServiceMock.getGraphData.calls.reset();
    dataServiceMock.getGraphData.and.returnValue(of({ labels: [], datasets: [] }));
    dataServiceMock.getSetting.calls.reset();
    dataServiceMock.getSetting.and.callFake((name: string) => {
      switch (name) {
        case 'info_system_enabled':
          return of({ value: 'true' });
        case 'info_graphs_enabled':
          return of({ value: 'true' });
        case 'graphs_measurement_range':
          return of({ value: 'metric' });
        case 'graphs_measurement_temperature':
          return of({ value: 'metric' });
        case 'graphs_network_interface':
          return of({ value: 'wlan0' });
        case 'graphs_refresh_interval_ms':
          return of({ value: '2000' });
        case 'graphs_dump1090_enabled':
          return of({ value: 'true' });
        case 'graphs_dump978_enabled':
          return of({ value: 'false' });
        default:
          return of({ value: '' });
      }
    });

    Object.values(dataServiceMock).forEach((spy) => {
      if (spy && typeof spy.calls !== 'undefined') {
        spy.calls.reset();
      }
    });
    dataServiceMock.getSystemCpu.and.returnValue(of({ cpu_percent: 15.2 }));
    dataServiceMock.getSystemMemory.and.returnValue(of({ memory_percent: 45.6 }));
    dataServiceMock.getSystemDisk.and.returnValue(of({ disk_usage_percent: 62.1 }));
    dataServiceMock.getSystemNetwork.and.returnValue(of({ network_interface: 'eth0' }));
    dataServiceMock.getSystemOther.and.returnValue(of({ other_boot_time: 1700000000 }));
    dataServiceMock.getSystemDatabase.and.returnValue(of({ size: 1024 }));

    TestBed.overrideComponent(DevicesComponent, {
      remove: {
        imports: [SpinnerComponent, RrdChartComponent],
      },
      add: {
        imports: [SpinnerStubComponent, RrdChartStubComponent],
      },
    });

    await TestBed.configureTestingModule({
      imports: [DevicesComponent],
      providers: [{ provide: DataService, useValue: dataServiceMock }],
    }).compileComponents();

    fixture = TestBed.createComponent(DevicesComponent);
    component = fixture.componentInstance;
  });

  it('should create', () => {
    fixture.detectChanges();
    expect(component).toBeTruthy();
  });

  // Receiver Information Tests
  it('should load graph settings and build chart configs', () => {
    fixture.detectChanges();

    expect(dataServiceMock.getSetting).toHaveBeenCalledWith('info_graphs_enabled');
    expect(dataServiceMock.getSetting).toHaveBeenCalledWith('info_system_enabled');
    expect(dataServiceMock.getSetting).toHaveBeenCalledWith('graphs_measurement_range');
    expect(component.measurementRange).toBe('metric');
    expect(component.measurementAltitude).toBe('metric');
    expect(component.measurementTemperature).toBe('metric');
    expect(component.networkInterface).toBe('wlan0');
    expect(component.graphRefreshIntervalMs).toBe(3000);
    expect(component.dump1090GraphsEnabled).toBeTrue();
    expect(component.dump978GraphsEnabled).toBeFalse();
    expect(component.d1090Range).toBeDefined();
    expect(component.sysNetwork.title).toContain('wlan0');
    expect(component.receiverLoading).toBeFalse();
  });

  it('should handle receiver settings load failure', () => {
    dataServiceMock.getSetting.and.callFake((name: string) => {
      if (name === 'graphs_measurement_range') {
        return throwError(() => new Error('failed'));
      }
      return of({ value: 'true' });
    });

    fixture.detectChanges();

    expect(component.receiverLoading).toBeFalse();
    expect(component.errorMessage).toBe('Failed to load graph settings.');
  });

  it('should update active period', () => {
    component.setPeriod('7d');
    expect(component.activePeriod).toBe('7d');
  });

  // System Information Tests
  it('should load system data on init', () => {
    fixture.detectChanges();

    expect(dataServiceMock.getSystemCpu).toHaveBeenCalled();
    expect(dataServiceMock.getSystemMemory).toHaveBeenCalled();
    expect(dataServiceMock.getSystemDisk).toHaveBeenCalled();
    expect(dataServiceMock.getSystemNetwork).toHaveBeenCalled();
    expect(dataServiceMock.getSystemOther).toHaveBeenCalled();
    expect(dataServiceMock.getSystemDatabase).toHaveBeenCalled();

    expect(component.cpu).toEqual({ cpu_percent: 15.2 });
    expect(component.memory).toEqual({ memory_percent: 45.6 });
    expect(component.systemLoading).toBeFalse();
  });

  it('should set system loading false when a request fails', () => {
    dataServiceMock.getSystemCpu.and.returnValue(throwError(() => new Error('failed')));

    fixture.detectChanges();

    expect(component.systemLoading).toBeFalse();
  });

  it('should format bytes correctly', () => {
    expect(component.formatBytes(0)).toBe('0 B');
    expect(component.formatBytes(1024)).toBe('1.00 KB');
    expect(component.formatBytes(1048576)).toBe('1.00 MB');
  });

  it('should return boot time as date', () => {
    component.other = { other_boot_time: 1700000000 };

    const boot = component.bootTime();

    expect(boot instanceof Date).toBeTrue();
    expect(boot.getTime()).toBe(1700000000 * 1000);
  });

  // Tab Navigation Tests
  it('should switch active tab', () => {
    component.setActiveTab('system');
    expect(component.activeTab).toBe('system');

    component.setActiveTab('receiver');
    expect(component.activeTab).toBe('receiver');
  });

  it('should start with receiver tab active', () => {
    expect(component.activeTab).toBe('receiver');
  });

  it('should hide the system tab and skip system requests when system information is disabled', () => {
    dataServiceMock.getSetting.and.callFake((name: string) => {
      switch (name) {
        case 'info_system_enabled':
          return of({ value: 'false' });
        case 'info_graphs_enabled':
          return of({ value: 'true' });
        case 'graphs_measurement_range':
          return of({ value: 'metric' });
        case 'graphs_measurement_temperature':
          return of({ value: 'metric' });
        case 'graphs_network_interface':
          return of({ value: 'wlan0' });
        case 'graphs_refresh_interval_ms':
          return of({ value: '2000' });
        case 'graphs_dump1090_enabled':
          return of({ value: 'true' });
        case 'graphs_dump978_enabled':
          return of({ value: 'false' });
        default:
          return of({ value: '' });
      }
    });

    fixture.detectChanges();

    const navButtons = Array.from(
      fixture.nativeElement.querySelectorAll('.nav-tabs .nav-link') as NodeListOf<HTMLButtonElement>
    ).map((button) => button.textContent?.trim());

    expect(component.infoSystemEnabled).toBeFalse();
    expect(component.activeTab).toBe('receiver');
    expect(dataServiceMock.getSystemCpu).not.toHaveBeenCalled();
    expect(navButtons).not.toContain('System');
  });

  it('should hide the receiver tab and default to system when receiver information is disabled', () => {
    dataServiceMock.getSetting.and.callFake((name: string) => {
      switch (name) {
        case 'info_system_enabled':
          return of({ value: 'true' });
        case 'info_graphs_enabled':
          return of({ value: 'false' });
        default:
          return of({ value: 'true' });
      }
    });

    fixture.detectChanges();

    const navButtons = Array.from(
      fixture.nativeElement.querySelectorAll('.nav-tabs .nav-link') as NodeListOf<HTMLButtonElement>
    ).map((button) => button.textContent?.trim());

    expect(component.infoGraphsEnabled).toBeFalse();
    expect(component.activeTab).toBe('system');
    expect(dataServiceMock.getSystemCpu).toHaveBeenCalled();
    expect(navButtons).not.toContain('Receiver');
  });

  it('should show a disabled message when both information sections are turned off', () => {
    dataServiceMock.getSetting.and.callFake((name: string) => {
      switch (name) {
        case 'info_system_enabled':
        case 'info_graphs_enabled':
          return of({ value: 'false' });
        default:
          return of({ value: 'true' });
      }
    });

    fixture.detectChanges();

    expect(component.activeTab).toBe('');
    expect(fixture.nativeElement.textContent).toContain('No device sections are currently enabled.');
    expect(dataServiceMock.getSystemCpu).not.toHaveBeenCalled();
    expect(dataServiceMock.getSetting).not.toHaveBeenCalledWith('graphs_measurement_range');
  });

  it('should ignore attempts to switch to a disabled tab', () => {
    component.infoGraphsEnabled = false;
    component.infoSystemEnabled = true;
    component.activeTab = 'system';

    component.setActiveTab('receiver');

    expect(component.activeTab).toBe('system');
  });
});

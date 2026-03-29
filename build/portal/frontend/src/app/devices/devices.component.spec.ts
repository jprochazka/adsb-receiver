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
  @Input() maxPoints: number | null = null;
  @Input() startEpoch: number | null = null;
  @Input() endEpoch: number | null = null;
  @Input() compareStartEpoch: number | null = null;
  @Input() compareEndEpoch: number | null = null;
  @Input() compareLabel = '';
  @Input() stepSeconds: number | null = null;
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

  it('should expose brush snap and fine-adjust controls in the template', () => {
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent as string;
    expect(text).toContain('Snap');
    expect(text).toContain('Start -');
    expect(text).toContain('Start +');
    expect(text).toContain('End -');
    expect(text).toContain('End +');
  });

  it('should snap brush-derived range to selected increment', () => {
    fixture.detectChanges();
    spyOn(Date, 'now').and.returnValue(new Date('2026-03-28T12:00:00Z').getTime());

    component.setPeriod('24h');
    component.setBrushSnap(15);
    component.onBrushStartInput(10.2);
    component.onBrushEndInput(90.2);

    const start = new Date(component.rangeStart);
    const end = new Date(component.rangeEnd);

    expect(Number.isNaN(start.getTime())).toBeFalse();
    expect(Number.isNaN(end.getTime())).toBeFalse();
    expect(start.getMinutes() % 15).toBe(0);
    expect(end.getMinutes() % 15).toBe(0);
    expect(end.getTime()).toBeGreaterThan(start.getTime());
  });

  it('should nudge brush handles using selected snap increment', () => {
    fixture.detectChanges();

    component.setPeriod('24h');
    component.setBrushSnap(15);
    const startBefore = component.brushStartPct;
    const endBefore = component.brushEndPct;

    component.nudgeBrushStart(1);
    component.nudgeBrushEnd(-1);

    expect(component.brushStartPct).toBeGreaterThan(startBefore);
    expect(component.brushEndPct).toBeLessThan(endBefore);
  });

  it('should format brush labels from range inputs', () => {
    fixture.detectChanges();

    component.rangeStart = '2026-03-28T10:30';
    component.rangeEnd = '2026-03-28T11:45';

    expect(component.brushStartLabel).toBeTruthy();
    expect(component.brushEndLabel).toBeTruthy();
    expect(component.brushStartLabel).not.toContain('T');
    expect(component.brushEndLabel).not.toContain('T');
  });

  it('should compute SDR tuning KPIs from graph responses', () => {
    dataServiceMock.getGraphData.and.callFake((_decoder: string, metric: string) => {
      if (metric === 'message-rate') {
        return of({
          labels: [1, 2],
          datasets: [
            { label: 'messages', data: [100, 120] },
            { label: 'positions', data: [45, 55] },
            { label: 'strong_signals', data: [20, 18] },
          ],
        });
      }

      if (metric === 'aircraft') {
        return of({ labels: [1, 2], datasets: [{ label: 'total', data: [30, 35] }] });
      }

      if (metric === 'range') {
        return of({ labels: [1, 2], datasets: [{ label: 'max_range', data: [100000, 120000] }] });
      }

      if (metric === 'messages') {
        return of({ labels: [1, 2], datasets: [{ label: 'messages', data: [14, 16] }] });
      }

      return of({ labels: [], datasets: [] });
    });

    fixture.detectChanges();

    expect(component.currentKpis).toBeTruthy();
    expect(component.currentKpis?.adsbMsgRate).toBeCloseTo(110, 5);
    expect(component.currentKpis?.adsbAircraft).toBeCloseTo(32.5, 5);
    expect(component.currentKpis?.adsbPosPerMsgPct).toBeGreaterThan(40);
    expect(component.currentKpis?.adsbStrongPct).toBeGreaterThan(10);
    expect(component.currentKpis?.uatMsgRate).toBeCloseTo(15, 5);
  });

  it('should set and clear baseline from current KPI snapshot', () => {
    fixture.detectChanges();
    component.currentKpis = {
      adsbMsgRate: 50,
      adsbAircraft: 20,
      adsbRange: 80,
      adsbStrongPct: 12,
      adsbPosPerMsgPct: 40,
      uatMsgRate: 8,
      uatAircraft: 4,
    };

    component.setBaselineFromCurrent();

    expect(component.baselineKpis).toEqual(component.currentKpis);
    expect(component.compareEnabled).toBeTrue();
    expect(component.baselineLabel).toContain(component.activePeriod);

    component.clearBaseline();

    expect(component.baselineKpis).toBeNull();
    expect(component.compareEnabled).toBeFalse();
    expect(component.baselineLabel).toBe('');
  });

  it('should format deltas with sign and suffix', () => {
    expect(component.formatDelta(12, 10)).toBe('+2.0');
    expect(component.formatDelta(8, 10, '%')).toBe('-2.0%');
    expect(component.formatDelta(null, 10)).toBe('');
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

import { ComponentFixture, TestBed, fakeAsync, tick } from '@angular/core/testing';
import { defer, of } from 'rxjs';
import { delay } from 'rxjs/operators';

import { RrdChartComponent } from './rrd-chart.component';
import { DataService } from '../../service/data.service';

describe('RrdChartComponent', () => {
  let component: RrdChartComponent;
  let fixture: ComponentFixture<RrdChartComponent>;

  const dataServiceMock = {
    getGraphData: jasmine.createSpy('getGraphData').and.returnValue(of({ labels: [], datasets: [] }).pipe(delay(0))),
  };

  beforeEach(async () => {
    dataServiceMock.getGraphData.calls.reset();

    await TestBed.configureTestingModule({
      imports: [RrdChartComponent],
      providers: [{ provide: DataService, useValue: dataServiceMock }],
    }).compileComponents();

    fixture = TestBed.createComponent(RrdChartComponent);
    component = fixture.componentInstance;
    component.config = {
      decoder: 'system',
      metric: 'cpu',
      title: 'CPU',
      yLabel: 'CPU %',
    };
    component.period = '24h';
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should clear timer and destroy chart on destroy', () => {
    const timerId = setInterval(() => undefined, 1000);
    const clearSpy = spyOn(globalThis, 'clearInterval').and.callThrough();
    const destroySpy = jasmine.createSpy('destroy');

    (component as any).refreshTimer = timerId;
    (component as any).chart = { destroy: destroySpy };

    component.ngOnDestroy();

    expect(clearSpy).toHaveBeenCalled();
    expect(destroySpy).toHaveBeenCalled();
  });

  it('should show no-data state when response has empty labels and datasets', fakeAsync(() => {
    dataServiceMock.getGraphData.and.returnValue(of({ labels: [], datasets: [] }).pipe(delay(0)));
    fixture.detectChanges();
    tick(0);
    fixture.detectChanges();

    expect(component.error).toBeTrue();
    expect(component.loading).toBeFalse();
  }));

  it('should show no-data state when all dataset values are null', fakeAsync(() => {
    dataServiceMock.getGraphData.and.returnValue(of({
      labels: [1000, 1030],
      datasets: [
        { label: 'idle', data: [null, null] },
        { label: 'user', data: [null, null] },
      ],
    }).pipe(delay(0)));
    fixture.detectChanges();
    tick(0);
    fixture.detectChanges();

    expect(component.error).toBeTrue();
    expect(component.loading).toBeFalse();
  }));

  it('should show no-data state on HTTP error (e.g. 503)', fakeAsync(() => {
    dataServiceMock.getGraphData.and.returnValue(defer(() => Promise.reject({ status: 503 })));
    fixture.detectChanges();
    tick(0);
    fixture.detectChanges();

    expect(component.error).toBeTrue();
    expect(component.loading).toBeFalse();
  }));

  it('should not be in error state when response contains at least one non-null value', fakeAsync(() => {
    dataServiceMock.getGraphData.and.returnValue(of({
      labels: [1000, 1030],
      datasets: [
        { label: 'idle', data: [null, 42.5] },
      ],
    }).pipe(delay(0)));
    fixture.detectChanges();
    tick(0);
    fixture.detectChanges();

    expect(component.error).toBeFalse();
    expect(component.loading).toBeFalse();
  }));

  it('should request current and baseline datasets when compare window is provided', fakeAsync(() => {
    dataServiceMock.getGraphData.and.callFake((_decoder: string, _metric: string, options: any) => {
      if (options?.start === 1700000000 && options?.end === 1700003600) {
        return of({ labels: [1000, 1030], datasets: [{ label: 'idle', data: [30, 35] }] }).pipe(delay(0));
      }
      return of({ labels: [1100, 1130], datasets: [{ label: 'idle', data: [40, 45] }] }).pipe(delay(0));
    });

    component.compareStartEpoch = 1700000000;
    component.compareEndEpoch = 1700003600;
    component.stepSeconds = 60;

    fixture.detectChanges();
    tick(0);
    fixture.detectChanges();

    expect(dataServiceMock.getGraphData.calls.count()).toBe(2);
    const secondCallArgs = dataServiceMock.getGraphData.calls.argsFor(1);
    expect(secondCallArgs[2].start).toBe(1700000000);
    expect(secondCallArgs[2].end).toBe(1700003600);
    expect(secondCallArgs[2].step).toBe(60);
    expect(component.error).toBeFalse();
  }));

  it('should render compare legend when baseline window is active', fakeAsync(() => {
    dataServiceMock.getGraphData.and.returnValue(of({
      labels: [1000, 1030],
      datasets: [{ label: 'idle', data: [30, 35] }],
    }).pipe(delay(0)));

    component.compareStartEpoch = 1700000000;
    component.compareEndEpoch = 1700003600;
    component.compareLabel = 'Baseline';

    fixture.detectChanges();
    tick(0);
    fixture.detectChanges();

    const hint = fixture.nativeElement.querySelector('.chart-compare-hint') as HTMLElement | null;
    expect(hint).not.toBeNull();
    expect(hint?.textContent).toContain('Current');
    expect(hint?.textContent).toContain('Baseline');
  }));
});

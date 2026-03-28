import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { RrdChartComponent } from './rrd-chart.component';
import { DataService } from '../../service/data.service';

describe('RrdChartComponent', () => {
  let component: RrdChartComponent;
  let fixture: ComponentFixture<RrdChartComponent>;

  const dataServiceMock = {
    getGraphData: jasmine.createSpy('getGraphData').and.returnValue(of({ labels: [], datasets: [] })),
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

  it('should show no-data state when response has empty labels and datasets', () => {
    dataServiceMock.getGraphData.and.returnValue(of({ labels: [], datasets: [] }));
    fixture.detectChanges();

    expect(component.error).toBeTrue();
    expect(component.loading).toBeFalse();
  });

  it('should show no-data state when all dataset values are null', () => {
    dataServiceMock.getGraphData.and.returnValue(of({
      labels: [1000, 1030],
      datasets: [
        { label: 'idle', data: [null, null] },
        { label: 'user', data: [null, null] },
      ],
    }));
    fixture.detectChanges();

    expect(component.error).toBeTrue();
    expect(component.loading).toBeFalse();
  });

  it('should show no-data state on HTTP error (e.g. 503)', () => {
    dataServiceMock.getGraphData.and.returnValue(throwError(() => ({ status: 503 })));
    fixture.detectChanges();

    expect(component.error).toBeTrue();
    expect(component.loading).toBeFalse();
  });

  it('should not be in error state when response contains at least one non-null value', () => {
    dataServiceMock.getGraphData.and.returnValue(of({
      labels: [1000, 1030],
      datasets: [
        { label: 'idle', data: [null, 42.5] },
      ],
    }));
    fixture.detectChanges();

    expect(component.error).toBeFalse();
    expect(component.loading).toBeFalse();
  });
});


describe('RrdChartComponent', () => {
  let component: RrdChartComponent;
  let fixture: ComponentFixture<RrdChartComponent>;

  const dataServiceMock = {
    getGraphData: jasmine.createSpy('getGraphData').and.returnValue(of({ labels: [], datasets: [] })),
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
});

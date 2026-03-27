import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of } from 'rxjs';

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
});

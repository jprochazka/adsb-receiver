import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { AdminFlightsComponent } from './admin-flights.component';
import { DataService } from '../service/data.service';

describe('AdminFlightsComponent', () => {
  let component: AdminFlightsComponent;
  let fixture: ComponentFixture<AdminFlightsComponent>;

  const dataServiceMock = {
    getSetting: jasmine.createSpy('getSetting').and.returnValue(of({ value: 'true' })),
    updateSetting: jasmine.createSpy('updateSetting').and.returnValue(of({})),
    GetFlightsCount: jasmine.createSpy('GetFlightsCount').and.returnValue(of({ flights: 12 })),
    getUatFlightsCount: jasmine.createSpy('getUatFlightsCount').and.returnValue(of({ flights: 3 })),
    getSystemDatabase: jasmine.createSpy('getSystemDatabase').and.returnValue(of({ size: 1048576 })),
    getSystemFlightsTables: jasmine.createSpy('getSystemFlightsTables').and.returnValue(of({ size: 2048 })),
    getSystemDisk: jasmine.createSpy('getSystemDisk').and.returnValue(of({
      disk_usage_used: 1024,
      disk_usage_total: 2048,
      disk_usage_percent: 50,
    })),
    purgeFlights: jasmine.createSpy('purgeFlights').and.returnValue(of({
      deleted_flights: 2,
      deleted_positions: 10,
      cutoff_date: '2026-03-01 00:00:00'
    })),
    purgeUatFlights: jasmine.createSpy('purgeUatFlights').and.returnValue(of({
      deleted_flights: 1,
      deleted_positions: 2,
      cutoff_date: '2026-03-01 00:00:00'
    })),
  };

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [AdminFlightsComponent],
      providers: [{ provide: DataService, useValue: dataServiceMock }],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminFlightsComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should load stats on init', () => {
    expect(component.totalFlights).toBe(12);
    expect(component.totalUatFlights).toBe(3);
    expect(component.loading).toBeFalse();
    expect(dataServiceMock.GetFlightsCount).toHaveBeenCalled();
  });

  it('should save nav settings', () => {
    component.flightsNavEnabled = false;
    component.saveFlightsNavEnabled();
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('flights_nav_enabled', 'false');
  });

  it('should purge ADS-B flights successfully', () => {
    dataServiceMock.purgeFlights.and.returnValue(of({
      deleted_flights: 2,
      deleted_positions: 10,
      cutoff_date: '2026-03-01 00:00:00'
    }));

    component.purgeDays = 30;
    component.confirmPurge();

    expect(dataServiceMock.purgeFlights).toHaveBeenCalledWith(30);
    expect(component.purging).toBeFalse();
    expect(component.successMessage).toContain('Purge complete');
  });

  it('should handle ADS-B purge error', () => {
    dataServiceMock.purgeFlights.and.returnValue(throwError(() => new Error('failed')));

    component.confirmPurge();

    expect(component.purging).toBeFalse();
    expect(component.errorMessage).toContain('Failed to purge flights');
  });

  it('should purge UAT flights successfully', () => {
    dataServiceMock.purgeUatFlights.and.returnValue(of({
      deleted_flights: 1,
      deleted_positions: 2,
      cutoff_date: '2026-03-01 00:00:00'
    }));

    component.uatPurgeDays = 14;
    component.confirmUatPurge();

    expect(dataServiceMock.purgeUatFlights).toHaveBeenCalledWith(14);
    expect(component.uatPurging).toBeFalse();
    expect(component.uatSuccessMessage).toContain('Purge complete');
  });
});

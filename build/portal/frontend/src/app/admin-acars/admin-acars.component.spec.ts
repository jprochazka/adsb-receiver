import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { AdminAcarsComponent } from './admin-acars.component';
import { DataService } from '../service/data.service';

describe('AdminAcarsComponent', () => {
  let component: AdminAcarsComponent;
  let fixture: ComponentFixture<AdminAcarsComponent>;

  const dataServiceMock = {
    getSetting: jasmine.createSpy('getSetting').and.returnValue(of({ value: 'true' })),
    updateSetting: jasmine.createSpy('updateSetting').and.returnValue(of({})),
    getAcarsFlightsCount: jasmine.createSpy('getAcarsFlightsCount').and.returnValue(of({ flights: 7 })),
    getAcarsMessagesCount: jasmine.createSpy('getAcarsMessagesCount').and.returnValue(of({ messages: 21 })),
    getSystemDatabase: jasmine.createSpy('getSystemDatabase').and.returnValue(of({ size: 1048576 })),
    getAcarsDatabase: jasmine.createSpy('getAcarsDatabase').and.returnValue(of({ size: 4096 })),
    getSystemDisk: jasmine.createSpy('getSystemDisk').and.returnValue(of({
      disk_usage_used: 1024,
      disk_usage_total: 2048,
      disk_usage_percent: 50,
    })),
    purgeAcarsFlights: jasmine.createSpy('purgeAcarsFlights').and.returnValue(of({
      deleted_flights: 2,
      deleted_messages: 9,
      cutoff_date: '2026-03-01 00:00:00'
    })),
  };

  beforeEach(async () => {
    Object.values(dataServiceMock).forEach((spy) => spy.calls.reset());
    dataServiceMock.getSetting.and.returnValue(of({ value: 'true' }));
    dataServiceMock.updateSetting.and.returnValue(of({}));
    dataServiceMock.getAcarsFlightsCount.and.returnValue(of({ flights: 7 }));
    dataServiceMock.getAcarsMessagesCount.and.returnValue(of({ messages: 21 }));
    dataServiceMock.getSystemDatabase.and.returnValue(of({ size: 1048576 }));
    dataServiceMock.getAcarsDatabase.and.returnValue(of({ size: 4096 }));
    dataServiceMock.getSystemDisk.and.returnValue(of({
      disk_usage_used: 1024,
      disk_usage_total: 2048,
      disk_usage_percent: 50,
    }));
    dataServiceMock.purgeAcarsFlights.and.returnValue(of({
      deleted_flights: 2,
      deleted_messages: 9,
      cutoff_date: '2026-03-01 00:00:00'
    }));

    await TestBed.configureTestingModule({
      imports: [AdminAcarsComponent],
      providers: [{ provide: DataService, useValue: dataServiceMock }],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminAcarsComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should load ACARS stats on init', () => {
    expect(component.totalFlights).toBe(7);
    expect(component.totalMessages).toBe(21);
    expect(component.loading).toBeFalse();
  });

  it('should save nav setting', () => {
    component.acarsNavEnabled = false;
    component.saveAcarsNavEnabled();

    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('acars_nav_enabled', 'false');
  });

  it('should purge ACARS successfully', () => {
    component.purgeDays = 10;
    component.confirmPurge();

    expect(dataServiceMock.purgeAcarsFlights).toHaveBeenCalledWith(10);
    expect(component.purging).toBeFalse();
    expect(component.successMessage).toContain('Purge complete');
  });

  it('should handle ACARS purge error', () => {
    dataServiceMock.purgeAcarsFlights.and.returnValue(throwError(() => new Error('failed')));

    component.confirmPurge();

    expect(component.purging).toBeFalse();
    expect(component.errorMessage).toContain('Failed to purge ACARS flights');
  });
});

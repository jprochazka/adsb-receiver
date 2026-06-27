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
    getIgnoredFlights: jasmine.createSpy('getIgnoredFlights').and.returnValue(of({
      flights: [
        { id: 1, flight: 'FLT0001', icao: 'icao01', last_seen: '2024-06-17 01:11:01', ignore_on_purge: true }
      ],
      total: 1,
    })),
    getIgnoredUatFlights: jasmine.createSpy('getIgnoredUatFlights').and.returnValue(of({
      flights: [
        { id: 1, flight: 'UAT0001', icao: 'uicao01', last_seen: '2024-06-17 01:11:01', ignore_on_purge: true }
      ],
      total: 1,
    })),
    updateFlightPurgePreference: jasmine.createSpy('updateFlightPurgePreference').and.returnValue(of({
      flight: 'FLT0001',
      ignore_on_purge: false,
    })),
    updateUatFlightPurgePreference: jasmine.createSpy('updateUatFlightPurgePreference').and.returnValue(of({
      flight: 'UAT0001',
      ignore_on_purge: false,
    })),
    getOpenSkyAircraftDatabaseStatus: jasmine.createSpy('getOpenSkyAircraftDatabaseStatus').and.returnValue(of({
      installed: false,
      source_url: 'https://opensky-network.org/datasets/metadata/aircraftDatabase.csv',
      license_name: 'Open Database License (ODbL) v1.0',
    })),
    updateOpenSkyAircraftDatabase: jasmine.createSpy('updateOpenSkyAircraftDatabase').and.returnValue(of({
      installed: true,
      source_url: 'https://opensky-network.org/datasets/metadata/aircraftDatabase.csv',
      license_name: 'Open Database License (ODbL) v1.0',
    })),
  };

  beforeEach(async () => {
    Object.values(dataServiceMock).forEach((spy) => spy.calls.reset());
    dataServiceMock.getSetting.and.returnValue(of({ value: 'true' }));
    dataServiceMock.updateSetting.and.returnValue(of({}));
    dataServiceMock.GetFlightsCount.and.returnValue(of({ flights: 12 }));
    dataServiceMock.getUatFlightsCount.and.returnValue(of({ flights: 3 }));
    dataServiceMock.getSystemDatabase.and.returnValue(of({ size: 1048576 }));
    dataServiceMock.getSystemFlightsTables.and.returnValue(of({ size: 2048 }));
    dataServiceMock.getSystemDisk.and.returnValue(of({
      disk_usage_used: 1024,
      disk_usage_total: 2048,
      disk_usage_percent: 50,
    }));
    dataServiceMock.purgeFlights.and.returnValue(of({
      deleted_flights: 2,
      deleted_positions: 10,
      cutoff_date: '2026-03-01 00:00:00'
    }));
    dataServiceMock.purgeUatFlights.and.returnValue(of({
      deleted_flights: 1,
      deleted_positions: 2,
      cutoff_date: '2026-03-01 00:00:00'
    }));
    dataServiceMock.getIgnoredFlights.and.returnValue(of({
      flights: [
        { id: 1, flight: 'FLT0001', icao: 'icao01', last_seen: '2024-06-17 01:11:01', ignore_on_purge: true }
      ],
      total: 1,
    }));
    dataServiceMock.getIgnoredUatFlights.and.returnValue(of({
      flights: [
        { id: 1, flight: 'UAT0001', icao: 'uicao01', last_seen: '2024-06-17 01:11:01', ignore_on_purge: true }
      ],
      total: 1,
    }));
    dataServiceMock.updateFlightPurgePreference.and.returnValue(of({
      flight: 'FLT0001',
      ignore_on_purge: false,
    }));
    dataServiceMock.updateUatFlightPurgePreference.and.returnValue(of({
      flight: 'UAT0001',
      ignore_on_purge: false,
    }));
    dataServiceMock.getOpenSkyAircraftDatabaseStatus.and.returnValue(of({
      installed: false,
      source_url: 'https://opensky-network.org/datasets/metadata/aircraftDatabase.csv',
      license_name: 'Open Database License (ODbL) v1.0',
    }));
    dataServiceMock.updateOpenSkyAircraftDatabase.and.returnValue(of({
      installed: true,
      source_url: 'https://opensky-network.org/datasets/metadata/aircraftDatabase.csv',
      license_name: 'Open Database License (ODbL) v1.0',
    }));

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
    expect(dataServiceMock.getIgnoredFlights).toHaveBeenCalled();
    expect(dataServiceMock.getIgnoredUatFlights).toHaveBeenCalled();
    expect(dataServiceMock.getOpenSkyAircraftDatabaseStatus).toHaveBeenCalled();
  });

  it('should keep OpenSky not-installed state from 404 payload', () => {
    dataServiceMock.getOpenSkyAircraftDatabaseStatus.and.returnValue(
      throwError(() => ({ status: 404, error: { installed: false, msg: 'not installed' } }))
    );

    component.loadOpenSkyAircraftDatabaseStatus();

    expect(component.openSkyError).toBe('');
    expect(component.openSkyStatus?.installed).toBeFalse();
  });

  it('should update OpenSky database and set success message', () => {
    dataServiceMock.updateOpenSkyAircraftDatabase.and.returnValue(of({ installed: true, sha256: 'abc' }));

    component.updateOpenSkyAircraftDatabase();

    expect(dataServiceMock.updateOpenSkyAircraftDatabase).toHaveBeenCalled();
    expect(component.openSkyUpdating).toBeFalse();
    expect(component.openSkySuccess).toContain('updated successfully');
    expect(component.openSkyStatus?.installed).toBeTrue();
  });

  it('should handle OpenSky update error', () => {
    dataServiceMock.updateOpenSkyAircraftDatabase.and.returnValue(
      throwError(() => ({ status: 500, error: { msg: 'Internal Server Error' } }))
    );

    component.updateOpenSkyAircraftDatabase();

    expect(component.openSkyUpdating).toBeFalse();
    expect(component.openSkyError).toBe('Failed to update OpenSky aircraft database: Internal Server Error.');
  });

  it('should show admin-specific OpenSky update error for forbidden responses', () => {
    dataServiceMock.updateOpenSkyAircraftDatabase.and.returnValue(
      throwError(() => ({ status: 403, error: {} }))
    );

    component.updateOpenSkyAircraftDatabase();

    expect(component.openSkyUpdating).toBeFalse();
    expect(component.openSkyError).toBe('Failed to update OpenSky aircraft database: admin access required.');
  });

  it('should save nav settings and show success feedback', () => {
    component.flightsNavEnabled = false;
    component.allTabEnabled = false;
    component.adsbTabEnabled = false;
    component.uatTabEnabled = false;

    component.saveFlightsNavEnabled();
    component.saveAllTabEnabled();
    component.saveAdsbTabEnabled();
    component.saveUatTabEnabled();

    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('flights_nav_enabled', 'false');
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('all_tab_enabled', 'false');
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('adsb_tab_enabled', 'false');
    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('uat_tab_enabled', 'false');
    expect(component.successMessage).toBe('Setting saved.');
    expect(component.errorMessage).toBe('');
  });

  it('should surface nav setting save failures', () => {
    dataServiceMock.updateSetting.and.returnValue(throwError(() => new Error('failed')));
    component.successMessage = 'Previous success';

    component.saveAdsbTabEnabled();

    expect(component.successMessage).toBe('');
    expect(component.errorMessage).toBe('Failed to save setting.');
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

  it('should update ADS-B ignored flight toggle', () => {
    const event = { target: { checked: false } } as any;
    component.updateIgnoredAdsbFlight({ flight: 'FLT0001' }, event);

    expect(dataServiceMock.updateFlightPurgePreference).toHaveBeenCalledWith('FLT0001', false);
  });

  it('should update UAT ignored flight toggle', () => {
    const event = { target: { checked: false } } as any;
    component.updateIgnoredUatFlight({ flight: 'UAT0001' }, event);

    expect(dataServiceMock.updateUatFlightPurgePreference).toHaveBeenCalledWith('UAT0001', false);
  });

  it('should reload ADS-B ignored flights when ADS-B page size changes', () => {
    dataServiceMock.getIgnoredFlights.calls.reset();
    component.ignoredAdsbOffset = 20;

    component.updateIgnoredAdsbPageSize(25);

    expect(component.ignoredAdsbPageSize).toBe(25);
    expect(component.ignoredAdsbOffset).toBe(0);
    expect(dataServiceMock.getIgnoredFlights).toHaveBeenCalledWith(0, 25);
  });

  it('should reload UAT ignored flights when UAT page size changes', () => {
    dataServiceMock.getIgnoredUatFlights.calls.reset();
    component.ignoredUatOffset = 20;

    component.updateIgnoredUatPageSize(25);

    expect(component.ignoredUatPageSize).toBe(25);
    expect(component.ignoredUatOffset).toBe(0);
    expect(dataServiceMock.getIgnoredUatFlights).toHaveBeenCalledWith(0, 25);
  });

  it('should render ignore-during-purge warning in both purge cards', () => {
    const warningText = 'Flights marked as Ignore During Purge will not be deleted.';
    const html = fixture.nativeElement as HTMLElement;
    const warnings = Array.from(html.querySelectorAll('p.small.text-warning-emphasis'));

    expect(warnings.length).toBe(2);
    expect(warnings.every((node) => node.textContent?.includes(warningText))).toBeTrue();
  });

  it('should apply purge-card class to both purge cards for consistent layout', () => {
    const html = fixture.nativeElement as HTMLElement;
    const purgeCards = html.querySelectorAll('.card.border-danger.purge-card');

    expect(purgeCards.length).toBe(2);
  });

  it('should render OpenSky status badge in header', () => {
    component.openSkyLoading = false;
    component.openSkyStatus = { installed: true };
    fixture.detectChanges();

    const html = fixture.nativeElement as HTMLElement;
    const badge = html.querySelector('.card-header .badge');

    expect(badge?.textContent?.trim()).toBe('Installed');
  });
});

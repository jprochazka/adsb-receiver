import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, provideRouter } from '@angular/router';
import { of } from 'rxjs';

import { FlightsComponent } from './flights.component';
import { DataService } from '../service/data.service';

describe('FlightsComponent', () => {
  let component: FlightsComponent;
  let fixture: ComponentFixture<FlightsComponent>;

  const dataServiceMock = {
    getSetting: jasmine.createSpy('getSetting').and.returnValue(of({ value: 'true' })),
    GetFlightsCount: jasmine.createSpy('GetFlightsCount').and.returnValue(of({ flights: 2 })),
    getFlights: jasmine.createSpy('getFlights').and.returnValue(of({
      flights: [{ flight: 'AAL123', icao: 'a1', last_seen: '2026-01-02 10:00:00' }],
      offset: 0,
      count: 1,
    })),
    getUatFlightsCount: jasmine.createSpy('getUatFlightsCount').and.returnValue(of({ flights: 1 })),
    getUatFlights: jasmine.createSpy('getUatFlights').and.returnValue(of({
      flights: [{ flight: 'UAL789', icao: 'u9', last_seen: '2026-01-01 10:00:00' }],
      offset: 0,
      count: 1,
    })),
    searchFlights: jasmine.createSpy('searchFlights').and.returnValue(of({ flights: [], count: 0 })),
    searchUatFlights: jasmine.createSpy('searchUatFlights').and.returnValue(of({ flights: [], count: 0 })),
    updateFlightPurgePreference: jasmine.createSpy('updateFlightPurgePreference').and.returnValue(of({
      flight: 'AAL123',
      ignore_on_purge: true,
    })),
    updateUatFlightPurgePreference: jasmine.createSpy('updateUatFlightPurgePreference').and.returnValue(of({
      flight: 'UAL789',
      ignore_on_purge: true,
    })),
  };

  beforeEach(async () => {
    Object.values(dataServiceMock).forEach((spy) => spy.calls.reset());
    dataServiceMock.getSetting.and.returnValue(of({ value: 'true' }));
    dataServiceMock.GetFlightsCount.and.returnValue(of({ flights: 2 }));
    dataServiceMock.getFlights.and.returnValue(of({
      flights: [{ flight: 'AAL123', icao: 'a1', last_seen: '2026-01-02 10:00:00' }],
      offset: 0,
      count: 1,
    }));
    dataServiceMock.getUatFlightsCount.and.returnValue(of({ flights: 1 }));
    dataServiceMock.getUatFlights.and.returnValue(of({
      flights: [{ flight: 'UAL789', icao: 'u9', last_seen: '2026-01-01 10:00:00' }],
      offset: 0,
      count: 1,
    }));

    await TestBed.configureTestingModule({
      imports: [FlightsComponent],
      providers: [
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: {
            paramMap: of(convertToParamMap({})),
            queryParamMap: of(convertToParamMap({})),
          },
        },
        { provide: DataService, useValue: dataServiceMock },
      ]
    })
    .compileComponents();

    fixture = TestBed.createComponent(FlightsComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should load ADS-B and UAT flights on init', () => {
    expect(dataServiceMock.GetFlightsCount).toHaveBeenCalled();
    expect(dataServiceMock.getFlights).toHaveBeenCalledWith(0, 50);
    expect(dataServiceMock.getUatFlightsCount).toHaveBeenCalled();
    expect(dataServiceMock.getUatFlights).toHaveBeenCalledWith(0, 50);
    expect(component.adsbTotalFlights).toBe(2);
    expect(component.uatTotalFlights).toBe(1);
    expect(component.combinedFlights.length).toBe(2);
    expect(component.loading).toBeFalse();
  });

  it('should filter combined flights and update tab counts', () => {
    component.filterQuery = 'ual';

    expect(component.filteredCombinedFlights.length).toBe(1);
    expect(component.filteredCombinedFlights[0].flight).toBe('UAL789');
    expect(component.combinedTabCount).toBe(1);
    expect(component.adsbTabCount).toBe(0);
    expect(component.uatTabCount).toBe(1);
  });

  it('should not allow non-admin users to toggle ignore on purge', () => {
    component.ignoreOnPurge = false;
    component.ignoreOnPurgeUpdating = false;
    component.currentUserRole = 'User';
    component.currentUserLocked = false;
    spyOn<any>(component, 'getTokenPayload').and.returnValue({ user_id: 2, role: 'User', exp: Math.floor(Date.now() / 1000) + 3600 });

    const input = document.createElement('input');
    input.type = 'checkbox';
    input.checked = true;

    component.updateIgnoreOnPurge({ target: input } as unknown as Event);

    expect(dataServiceMock.updateFlightPurgePreference).not.toHaveBeenCalled();
    expect(dataServiceMock.updateUatFlightPurgePreference).not.toHaveBeenCalled();
    expect(input.checked).toBeFalse();
    expect(component.ignoreOnPurge).toBeFalse();
  });

  it('should allow admin users to toggle ignore on purge', () => {
    component.flightType = 'adsb';
    component.flightId = 'AAL123';
    component.ignoreOnPurge = false;
    component.ignoreOnPurgeUpdating = false;
    component.currentUserRole = 'Admin';
    component.currentUserLocked = false;
    spyOn<any>(component, 'getTokenPayload').and.returnValue({ user_id: 1, role: 'Admin', exp: Math.floor(Date.now() / 1000) + 3600 });

    const input = document.createElement('input');
    input.type = 'checkbox';
    input.checked = true;

    component.updateIgnoreOnPurge({ target: input } as unknown as Event);

    expect(dataServiceMock.updateFlightPurgePreference).toHaveBeenCalledWith('AAL123', true);
    expect(component.ignoreOnPurge).toBeTrue();
  });
});

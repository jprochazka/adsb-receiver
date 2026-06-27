import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, provideRouter } from '@angular/router';
import { of } from 'rxjs';

import { FlightsComponent } from './flights.component';
import { inferAircraftClass } from './flight-display.helpers';
import { buildRenderableSegmentCoords, splitTrackSegments } from './flight-track.helpers';
import { DataService } from '../service/data.service';

describe('FlightsComponent', () => {
  let component: FlightsComponent;
  let fixture: ComponentFixture<FlightsComponent>;

  const dataServiceMock = {
    getSetting: jasmine.createSpy('getSetting').and.returnValue(of({ value: 'true' })),
    GetFlightsCount: jasmine.createSpy('GetFlightsCount').and.returnValue(of({ flights: 2 })),
    getFlights: jasmine.createSpy('getFlights').and.returnValue(of({
      flights: [{ flight: 'AAL123', icao: 'a1', aircraft_class: 'airliner', last_seen: '2026-01-02 10:00:00' }],
      offset: 0,
      count: 1,
    })),
    getUatFlightsCount: jasmine.createSpy('getUatFlightsCount').and.returnValue(of({ flights: 1 })),
    getUatFlights: jasmine.createSpy('getUatFlights').and.returnValue(of({
      flights: [{ flight: 'UAL789', icao: 'u9', aircraft_class: 'helicopter', last_seen: '2026-01-01 10:00:00' }],
      offset: 0,
      count: 1,
    })),
    searchFlights: jasmine.createSpy('searchFlights').and.returnValue(of({ flights: [], count: 0 })),
    searchUatFlights: jasmine.createSpy('searchUatFlights').and.returnValue(of({ flights: [], count: 0 })),
    getFlightDetails: jasmine.createSpy('getFlightDetails').and.returnValue(of({
      flight: 'N24680',
      first_seen: '2026-01-01 01:00:00',
      last_seen: '2026-01-01 02:00:00',
      icao: null,
      sightings_count: 7,
    })),
    getUatFlightDetails: jasmine.createSpy('getUatFlightDetails').and.returnValue(of({
      flight: 'UAT24680',
      first_seen: '2026-01-01 01:00:00',
      last_seen: '2026-01-01 02:00:00',
      icao: null,
      sightings_count: 5,
    })),
    getFlightPositions: jasmine.createSpy('getFlightPositions').and.returnValue(of({
      offset: 0,
      limit: 1000,
      count: 2,
      total: 1234,
      positions: [
        { latitude: 41, longitude: -83, time: '2026-01-01 01:00:00', altitude: 10000, speed: 200, squawk: 1200 },
        { latitude: 41.1, longitude: -83.1, time: '2026-01-01 01:10:00', altitude: 10100, speed: 205, squawk: 1200 },
      ],
    })),
    getUatFlightPositions: jasmine.createSpy('getUatFlightPositions').and.returnValue(of({
      offset: 0,
      limit: 1000,
      count: 1,
      total: 45,
      positions: [
        { latitude: 40, longitude: -82, time: '2026-01-01 01:00:00', altitude: 5000, speed: 120, squawk: 1200 },
      ],
    })),
    getAircraftPhoto: jasmine.createSpy('getAircraftPhoto').and.returnValue(of(null)),
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
      flights: [{ flight: 'AAL123', icao: 'a1', aircraft_class: 'airliner', last_seen: '2026-01-02 10:00:00' }],
      offset: 0,
      count: 1,
    }));
    dataServiceMock.getUatFlightsCount.and.returnValue(of({ flights: 1 }));
    dataServiceMock.getUatFlights.and.returnValue(of({
      flights: [{ flight: 'UAL789', icao: 'u9', aircraft_class: 'helicopter', last_seen: '2026-01-01 10:00:00' }],
      offset: 0,
      count: 1,
    }));
    dataServiceMock.getFlightDetails.and.returnValue(of({
      flight: 'N24680',
      first_seen: '2026-01-01 01:00:00',
      last_seen: '2026-01-01 02:00:00',
      icao: null,
      sightings_count: 7,
    }));
    dataServiceMock.getFlightPositions.and.returnValue(of({
      offset: 0,
      limit: 1000,
      count: 2,
      total: 1234,
      positions: [
        { latitude: 41, longitude: -83, time: '2026-01-01 01:00:00', altitude: 10000, speed: 200, squawk: 1200 },
        { latitude: 41.1, longitude: -83.1, time: '2026-01-01 01:10:00', altitude: 10100, speed: 205, squawk: 1200 },
      ],
    }));
    dataServiceMock.getAircraftPhoto.and.returnValue(of(null));

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

  it('should cap All Flights visible rows to per-page size', () => {
    component.searchQuery = '';
    component.filterQuery = '';
    component.perPage = 1;

    expect(component.displayedCombinedFlights.length).toBe(1);
  });

  it('should compute All Flights total pages from combined totals and per-page size', () => {
    component.adsbTotalFlights = 20;
    component.uatTotalFlights = 5;
    component.perPage = 10;

    expect(component.allTotalPages).toBe(3);
  });

  it('should update flights per page like admin users list pagination', () => {
    const navigateSpy = spyOn(component.router, 'navigate').and.returnValue(Promise.resolve(true));
    component.adsbCurrentPage = 3;
    component.uatCurrentPage = 2;

    component.updatePerPage(25);

    expect(component.perPage).toBe(25);
    expect(component.adsbCurrentPage).toBe(1);
    expect(component.uatCurrentPage).toBe(1);
    expect(navigateSpy).toHaveBeenCalledWith(['/flights'], {
      queryParams: { perPage: 25 },
    });
  });

  it('should refresh flights list when ngModel already applied the new per-page value', () => {
    const navigateSpy = spyOn(component.router, 'navigate').and.returnValue(Promise.resolve(true));
    component.perPage = 25;
    component.adsbCurrentPage = 2;
    component.uatCurrentPage = 2;

    component.updatePerPage(25);

    expect(component.adsbCurrentPage).toBe(1);
    expect(component.uatCurrentPage).toBe(1);
    expect(navigateSpy).toHaveBeenCalledWith(['/flights'], {
      queryParams: { perPage: 25 },
    });
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

  it('should render aircraft type icons in the flights table', () => {
    const icons = fixture.nativeElement.querySelectorAll('.aircraft-type-icon');
    expect(icons.length).toBeGreaterThan(0);

    const firstAlt = icons[0].getAttribute('alt') as string;
    expect(firstAlt.toLowerCase()).toContain('icon');
  });

  it('should render aircraft type icons in ADS-B and UAT tabs', () => {
    component.setTab('adsb');
    fixture.detectChanges();

    let icons = fixture.nativeElement.querySelectorAll('.aircraft-type-icon');
    expect(icons.length).toBeGreaterThan(0);

    component.setTab('uat');
    fixture.detectChanges();

    icons = fixture.nativeElement.querySelectorAll('.aircraft-type-icon');
    expect(icons.length).toBeGreaterThan(0);
  });

  it('should render compact external link icon set in flights table', () => {
    const linkIcons = fixture.nativeElement.querySelectorAll('.flight-link-icon');
    expect(linkIcons.length).toBeGreaterThan(0);

    const titles = Array.from(linkIcons).map((el: any) => String(el.getAttribute('title') || ''));
    expect(titles).toContain('FlightAware');
    expect(titles).toContain('PlaneFinder');
    expect(titles).toContain('Flightradar24');
    expect(titles).toContain('OpenSky Network');
    expect(titles).toContain('ADS-B Exchange');
  });

  it('should generate icon data URLs and fallback labels for unknown classes', () => {
    const known = {
      aircraft_class: 'helicopter'
    };
    const unknown = {
      aircraft_class: 'not_a_real_class'
    };

    const knownIcon = component.aircraftTypeIconDataUrl(known);
    const unknownIcon = component.aircraftTypeIconDataUrl(unknown);

    expect(knownIcon.startsWith('data:image/svg+xml;utf8,')).toBeTrue();
    expect(unknownIcon.startsWith('data:image/svg+xml;utf8,')).toBeTrue();
    expect(component.aircraftTypeLabelForFlight(unknown)).toBe('Unknown');
  });

  it('should generate flyout fallback icon and label from current aircraft class', () => {
    (component as any).currentAircraftClass = 'military';

    const icon = component.flyoutAircraftTypeIconDataUrl();
    const label = component.flyoutAircraftTypeLabel();

    expect(icon.startsWith('data:image/svg+xml;utf8,')).toBeTrue();
    expect(label).toBe('Military');
  });

  it('should fall back to emitter_category when aircraft_class is unknown', () => {
    const classify = (flight: any) => inferAircraftClass(flight);

    expect(classify({ aircraft_class: 'unknown',    emitter_category: 'A1' })).toBe('general_aviation');
    expect(classify({ aircraft_class: 'unknown',    emitter_category: 'A4' })).toBe('airliner');
    expect(classify({ aircraft_class: 'unknown',    emitter_category: 'A7' })).toBe('helicopter');
    expect(classify({ aircraft_class: 'unknown',    emitter_category: 'B1' })).toBe('glider');
    expect(classify({ aircraft_class: 'unknown',    emitter_category: 'B2' })).toBe('balloon');
    expect(classify({ aircraft_class: 'unknown',    emitter_category: 'B5' })).toBe('uav');
    expect(classify({ aircraft_class: 'unknown',    emitter_category: 'C1' })).toBe('ground');
    expect(classify({ aircraft_class: 'unknown',    emitter_category: 'D1' })).toBe('military');
    expect(classify({ aircraft_class: 'helicopter', emitter_category: 'A1' })).toBe('helicopter');
    expect(classify({ aircraft_class: 'unknown',    emitter_category: null })).toBe('unknown');
    expect(classify({ aircraft_class: 'unknown',    flight: 'RCH123' })).toBe('military');
  });

  it('should render a dedicated unknown icon for unknown aircraft class', () => {
    const svg = (component as any).svgForAircraftClass('unknown', '#000000', '#ffffff') as string;

    expect(svg).toContain('M25,4 C26.5,4 28,14 28,24');
    expect(svg).toContain('M28,22 L42,32 L40,36');
    expect(svg).toContain('M25,44 L32,48');
  });

  it('should render general aviation as a single-engine light-aircraft silhouette', () => {
    const svg = (component as any).svgForAircraftClass('general_aviation', '#000000', '#ffffff') as string;

    expect(svg).toContain('<path d="M25,3.8 L27.6,11.6 L40.8,16.4');
    expect(svg).toContain('<circle cx="25" cy="4.8" r="1.1"');
  });

  it('should return correct label for every aircraft class', () => {
    const label = (cls: string) => component.aircraftTypeLabelForFlight({ aircraft_class: cls });

    expect(label('airliner')).toBe('Airliner');
    expect(label('general_aviation')).toBe('General Aviation');
    expect(label('helicopter')).toBe('Helicopter');
    expect(label('military')).toBe('Military');
    expect(label('glider')).toBe('Glider');
    expect(label('balloon')).toBe('Balloon');
    expect(label('uav')).toBe('UAV');
    expect(label('ground')).toBe('Ground Vehicle');
    expect(label('space')).toBe('Space Vehicle');
    expect(label('unknown')).toBe('Unknown');
    expect(label('something_else')).toBe('Unknown');
  });

  it('should split positions into segments across a large time gap', () => {
    const contiguous = [
      { latitude: 41.0, longitude: -82.0, time: '2026-04-03 10:00:00' },
      { latitude: 41.1, longitude: -82.1, time: '2026-04-03 10:10:00' },
      { latitude: 41.2, longitude: -82.2, time: '2026-04-03 10:20:00' },
    ];
    expect(splitTrackSegments(contiguous).length).toBe(1);

    const gapped = [
      { latitude: 41.0, longitude: -82.0, time: '2026-04-03 07:00:00' },
      { latitude: 41.1, longitude: -82.1, time: '2026-04-03 10:00:00' },
      { latitude: 41.2, longitude: -82.2, time: '2026-04-03 10:10:00' },
    ];
    const segments = splitTrackSegments(gapped);
    expect(segments.length).toBe(2);
    expect(segments[0].length).toBe(1);
    expect(segments[1].length).toBe(2);
  });

  it('should rotate helicopter rotors by 45 degrees', () => {
    const svg = (component as any).svgForAircraftClass('helicopter', '#000000', '#ffffff') as string;

    expect(svg).toContain('transform="rotate(45 25 23)"');
  });

  it('should build interpolated coordinates for sparse flight samples', () => {
    const segment = [
      { latitude: 41.0, longitude: -82.0, time: '2026-04-03 10:00:00' },
      { latitude: 41.2, longitude: -81.7, time: '2026-04-03 10:00:30' },
    ];

    const coords = buildRenderableSegmentCoords(segment);

    expect(coords.length).toBeGreaterThan(2);
  });

  it('should navigate ADS-B pagination with canonical page 1 and preserve UAT page', () => {
    const navigateSpy = spyOn(component.router, 'navigate');

    component.adsbTotalPages = 10;
    component.adsbCurrentPage = 2;
    component.uatCurrentPage = 4;
    component.goToAdsbPage(1);

    expect(navigateSpy).toHaveBeenCalledWith(['/flights'], { queryParams: { uatPage: 4 } });

    component.goToAdsbPage(3);
    expect(navigateSpy).toHaveBeenCalledWith(['/flights', 3], { queryParams: { uatPage: 4 } });
  });

  it('should navigate UAT pagination with canonical page 1 and preserve ADS-B page', () => {
    const navigateSpy = spyOn(component.router, 'navigate');

    component.uatTotalPages = 10;
    component.uatCurrentPage = 2;
    component.adsbCurrentPage = 3;
    component.goToUatPage(1);

    expect(navigateSpy).toHaveBeenCalledWith(['/flights', 3], { queryParams: {} });

    component.goToUatPage(5);
    expect(navigateSpy).toHaveBeenCalledWith(['/flights', 3], { queryParams: { uatPage: 5 } });
  });

  it('should navigate All pagination using the allPage query parameter', () => {
    const navigateSpy = spyOn(component.router, 'navigate');

    component.adsbCurrentPage = 1;
    component.uatCurrentPage = 1;
    component.allCurrentPage = 2;
    component.adsbTotalFlights = 123;
    component.uatTotalFlights = 57;

    component.goToAllPage(1);
    expect(navigateSpy).toHaveBeenCalledWith(['/flights'], { queryParams: {} });

    component.goToAllPage(4);
    expect(navigateSpy).toHaveBeenCalledWith(['/flights'], { queryParams: { allPage: 4 } });
  });

  it('should compute all-tab display range and total like other pagers', () => {
    component.adsbCurrentPage = 2;
    component.uatCurrentPage = 2;
    component.allCurrentPage = 2;
    component.perPage = 100;
    component.adsbTotalFlights = 123;
    component.uatTotalFlights = 57;
    component.combinedFlights = new Array(100).fill(null);

    expect(component.allTotalFlights).toBe(180);
    expect(component.allDisplayStart).toBe(101);
    expect(component.allDisplayEnd).toBe(180);
  });

  it('should use API totals for detail positions and sightings from JSON', () => {
    component.flightType = 'adsb';
    component.flightId = 'N24680';
    component.loading = true;

    spyOn<any>(component, 'plotTracks').and.callFake(() => {});

    (component as any).loadDetailPositions();

    expect(dataServiceMock.getFlightDetails).toHaveBeenCalledWith('N24680');
    expect(dataServiceMock.getFlightPositions).toHaveBeenCalledWith('N24680');
    expect(component.flightInfo?.totalPositions).toBe(1234);
    expect(component.flightInfo?.trackCount).toBe(7);
  });
});

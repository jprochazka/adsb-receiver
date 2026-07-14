import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, provideRouter } from '@angular/router';
import { of } from 'rxjs';

import { AcarsComponent } from './acars.component';
import { DataService } from '../service/data.service';

describe('AcarsComponent', () => {
  let component: AcarsComponent;
  let fixture: ComponentFixture<AcarsComponent>;

  const dataServiceMock = {
    getAcarsFlightsCount: jasmine.createSpy('getAcarsFlightsCount').and.returnValue(of({ flights: 0 })),
    getAcarsFlights: jasmine.createSpy('getAcarsFlights').and.returnValue(of({ flights: [] })),
    getAcarsFlightMessages: jasmine.createSpy('getAcarsFlightMessages').and.returnValue(of({ messages: [], total: 0 })),
  };

  beforeEach(async () => {
    dataServiceMock.getAcarsFlightsCount.calls.reset();
    dataServiceMock.getAcarsFlightsCount.and.returnValue(of({ flights: 2 }));
    dataServiceMock.getAcarsFlights.calls.reset();
    dataServiceMock.getAcarsFlights.and.returnValue(of({
      flights: [
        { id: 1, flight_number: 'AAL123', registration: 'N123AA' },
        { id: 2, flight_number: 'DAL456', registration: 'N456DL' },
      ],
    }));
    dataServiceMock.getAcarsFlightMessages.calls.reset();
    dataServiceMock.getAcarsFlightMessages.and.returnValue(of({
      messages: [{ id: 99, text: 'HELLO' }],
      total: 1,
    }));

    await TestBed.configureTestingModule({
      imports: [AcarsComponent],
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
    }).compileComponents();

    fixture = TestBed.createComponent(AcarsComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should load flights on init', () => {
    expect(dataServiceMock.getAcarsFlightsCount).toHaveBeenCalled();
    expect(dataServiceMock.getAcarsFlights).toHaveBeenCalledWith(0, 50);
    expect(component.totalFlights).toBe(2);
    expect(component.flights.length).toBe(2);
    expect(component.loading).toBeFalse();
  });

  it('should update ACARS flights per page and navigate with query params', () => {
    const navigateSpy = spyOn(component['router'], 'navigate').and.returnValue(Promise.resolve(true));
    component.currentPage = 3;

    component.updatePerPage(25);

    expect(component.perPage).toBe(25);
    expect(component.currentPage).toBe(1);
    expect(navigateSpy).toHaveBeenCalledWith(['/acars'], {
      queryParams: { perPage: 25 },
    });
  });

  it('should filter flights by query', () => {
    component.filterQuery = 'n123';

    expect(component.filteredFlights.length).toBe(1);
    expect(component.filteredFlights[0].flight_number).toBe('AAL123');
  });

  it('should load and collapse messages for a selected flight', () => {
    component.toggleMessages({ id: 1 });

    expect(component.expandedFlightId).toBe(1);
    expect(dataServiceMock.getAcarsFlightMessages).toHaveBeenCalledWith(1, 0, 25);
    expect(component.messages.length).toBe(1);

    component.toggleMessages({ id: 1 });

    expect(component.expandedFlightId).toBeNull();
    expect(component.messages.length).toBe(0);
  });

  it('should render aircraft type icons in ACARS flights table', () => {
    const icons = fixture.nativeElement.querySelectorAll('.aircraft-type-icon');
    expect(icons.length).toBeGreaterThan(0);

    const firstAlt = icons[0].getAttribute('alt') as string;
    expect(firstAlt.toLowerCase()).toContain('icon');
  });

  it('should open text modal and set message fields', () => {
    const stopPropagation = jasmine.createSpy('stopPropagation');
    const event = { stopPropagation } as unknown as Event;
    const msg = {
      text: 'LONG MESSAGE TEXT',
      message_no: '42',
      label: 'CPDLC',
      time: '12:34:56',
    };

    component.openTextModal(msg, event);

    expect(stopPropagation).toHaveBeenCalled();
    expect(component.isTextModalOpen).toBeTrue();
    expect(component.modalText).toBe('LONG MESSAGE TEXT');
    expect(component.modalMsgNo).toBe('42');
    expect(component.modalLabel).toBe('CPDLC');
    expect(component.modalTime).toBe('12:34:56');
  });

  it('should close text modal and stop propagation when event is provided', () => {
    const stopPropagation = jasmine.createSpy('stopPropagation');
    const event = { stopPropagation } as unknown as Event;
    component.isTextModalOpen = true;

    component.closeTextModal(event);

    expect(stopPropagation).toHaveBeenCalled();
    expect(component.isTextModalOpen).toBeFalse();
  });

  it('should close text modal without an event', () => {
    component.isTextModalOpen = true;

    component.closeTextModal();

    expect(component.isTextModalOpen).toBeFalse();
  });
});

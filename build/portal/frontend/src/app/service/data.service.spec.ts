import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';

import { DataService } from './data.service';
import { environment } from '../../environments/environment';

describe('DataService', () => {
  let service: DataService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
      ]
    });
    service = TestBed.inject(DataService);
    httpMock = TestBed.inject(HttpTestingController);
    localStorage.setItem('access_token', 'test-token');
  });

  afterEach(() => {
    httpMock.verify();
    localStorage.removeItem('access_token');
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  it('should call getSchedulerStatus with auth header', () => {
    service.getSchedulerStatus().subscribe();

    const req = httpMock.expectOne(`${environment.apiUrl}/scheduler`);
    expect(req.request.method).toBe('GET');
    expect(req.request.headers.get('Authorization')).toBe('Bearer test-token');
    req.flush({ state: 'STATE_RUNNING' });
  });

  it('should call getSchedulerJobs with auth header', () => {
    service.getSchedulerJobs().subscribe();

    const req = httpMock.expectOne(`${environment.apiUrl}/scheduler/jobs`);
    expect(req.request.method).toBe('GET');
    expect(req.request.headers.get('Authorization')).toBe('Bearer test-token');
    req.flush([]);
  });

  it('should call startScheduler', () => {
    service.startScheduler().subscribe();

    const req = httpMock.expectOne(`${environment.apiUrl}/scheduler/start`);
    expect(req.request.method).toBe('POST');
    expect(req.request.headers.get('Authorization')).toBe('Bearer test-token');
    req.flush({});
  });

  it('should call pauseScheduler', () => {
    service.pauseScheduler().subscribe();

    const req = httpMock.expectOne(`${environment.apiUrl}/scheduler/pause`);
    expect(req.request.method).toBe('POST');
    expect(req.request.headers.get('Authorization')).toBe('Bearer test-token');
    req.flush({});
  });

  it('should call resumeScheduler', () => {
    service.resumeScheduler().subscribe();

    const req = httpMock.expectOne(`${environment.apiUrl}/scheduler/resume`);
    expect(req.request.method).toBe('POST');
    expect(req.request.headers.get('Authorization')).toBe('Bearer test-token');
    req.flush({});
  });

  it('should call shutdownScheduler', () => {
    service.shutdownScheduler().subscribe();

    const req = httpMock.expectOne(`${environment.apiUrl}/scheduler/shutdown`);
    expect(req.request.method).toBe('POST');
    expect(req.request.headers.get('Authorization')).toBe('Bearer test-token');
    req.flush({});
  });

  it('should call runSchedulerJob with encoded job id', () => {
    service.runSchedulerJob('maintenance job').subscribe();

    const req = httpMock.expectOne(`${environment.apiUrl}/scheduler/jobs/maintenance%20job/run`);
    expect(req.request.method).toBe('POST');
    expect(req.request.headers.get('Authorization')).toBe('Bearer test-token');
    req.flush({});
  });

  it('should call pauseSchedulerJob with encoded job id', () => {
    service.pauseSchedulerJob('maintenance/job').subscribe();

    const req = httpMock.expectOne(`${environment.apiUrl}/scheduler/jobs/maintenance%2Fjob/pause`);
    expect(req.request.method).toBe('POST');
    expect(req.request.headers.get('Authorization')).toBe('Bearer test-token');
    req.flush({});
  });

  it('should call resumeSchedulerJob with encoded job id', () => {
    service.resumeSchedulerJob('maintenance+job').subscribe();

    const req = httpMock.expectOne(`${environment.apiUrl}/scheduler/jobs/maintenance%2Bjob/resume`);
    expect(req.request.method).toBe('POST');
    expect(req.request.headers.get('Authorization')).toBe('Bearer test-token');
    req.flush({});
  });

  it('should call getSystemFlightsTables with auth header', () => {
    service.getSystemFlightsTables().subscribe();

    const req = httpMock.expectOne(`${environment.apiUrl}/devices/flights-tables`);
    expect(req.request.method).toBe('GET');
    expect(req.request.headers.get('Authorization')).toBe('Bearer test-token');
    req.flush({ size: 2048 });
  });

  it('should call purgeFlights with auth header', () => {
    service.purgeFlights(30).subscribe();

    const req = httpMock.expectOne(`${environment.apiUrl}/adsb/flights/purge?days=30`);
    expect(req.request.method).toBe('DELETE');
    expect(req.request.headers.get('Authorization')).toBe('Bearer test-token');
    req.flush({});
  });

  it('should call purgeUatFlights with auth header', () => {
    service.purgeUatFlights(14).subscribe();

    const req = httpMock.expectOne(`${environment.apiUrl}/uat/flights/purge?days=14`);
    expect(req.request.method).toBe('DELETE');
    expect(req.request.headers.get('Authorization')).toBe('Bearer test-token');
    req.flush({});
  });

  it('should call purgeAcarsFlights with auth header', () => {
    service.purgeAcarsFlights(7).subscribe();

    const req = httpMock.expectOne(`${environment.apiUrl}/acars/flights/purge?days=7`);
    expect(req.request.method).toBe('DELETE');
    expect(req.request.headers.get('Authorization')).toBe('Bearer test-token');
    req.flush({});
  });

  it('should call getOpenSkyAircraftDatabaseStatus', () => {
    service.getOpenSkyAircraftDatabaseStatus().subscribe();

    const req = httpMock.expectOne(`${environment.apiUrl}/setting/opensky-aircraft-database`);
    expect(req.request.method).toBe('GET');
    req.flush({ installed: false });
  });

  it('should call updateOpenSkyAircraftDatabase with auth header', () => {
    service.updateOpenSkyAircraftDatabase().subscribe();

    const req = httpMock.expectOne(`${environment.apiUrl}/setting/opensky-aircraft-database/update`);
    expect(req.request.method).toBe('POST');
    expect(req.request.headers.get('Authorization')).toBe('Bearer test-token');
    req.flush({ installed: true });
  });
});

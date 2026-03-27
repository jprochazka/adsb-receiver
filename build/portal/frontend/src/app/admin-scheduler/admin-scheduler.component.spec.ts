import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { Router } from '@angular/router';
import { of, throwError } from 'rxjs';

import { AdminSchedulerComponent } from './admin-scheduler.component';
import { DataService } from '../service/data.service';

describe('AdminSchedulerComponent', () => {
  let component: AdminSchedulerComponent;
  let fixture: ComponentFixture<AdminSchedulerComponent>;
  let router: Router;

  const dataServiceMock = {
    getSchedulerStatus: jasmine.createSpy('getSchedulerStatus').and.returnValue(of({ state: 'STATE_RUNNING' })),
    getSchedulerJobs: jasmine.createSpy('getSchedulerJobs').and.returnValue(of([])),
    startScheduler: jasmine.createSpy('startScheduler').and.returnValue(of({})),
    pauseScheduler: jasmine.createSpy('pauseScheduler').and.returnValue(of({})),
    resumeScheduler: jasmine.createSpy('resumeScheduler').and.returnValue(of({})),
    shutdownScheduler: jasmine.createSpy('shutdownScheduler').and.returnValue(of({})),
    runSchedulerJob: jasmine.createSpy('runSchedulerJob').and.returnValue(of({})),
    pauseSchedulerJob: jasmine.createSpy('pauseSchedulerJob').and.returnValue(of({})),
    resumeSchedulerJob: jasmine.createSpy('resumeSchedulerJob').and.returnValue(of({})),
  };

  const adminToken =
    'eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiQWRtaW4iLCJleHAiOjQxMDI0NDQ4MDB9.signature';

  beforeEach(async () => {
    localStorage.setItem('access_token', adminToken);

    dataServiceMock.getSchedulerStatus.calls.reset();
    dataServiceMock.getSchedulerStatus.and.returnValue(of({ state: 'STATE_RUNNING' }));
    dataServiceMock.getSchedulerJobs.calls.reset();
    dataServiceMock.getSchedulerJobs.and.returnValue(of([]));
    dataServiceMock.startScheduler.calls.reset();
    dataServiceMock.startScheduler.and.returnValue(of({}));
    dataServiceMock.pauseScheduler.calls.reset();
    dataServiceMock.pauseScheduler.and.returnValue(of({}));
    dataServiceMock.resumeScheduler.calls.reset();
    dataServiceMock.resumeScheduler.and.returnValue(of({}));
    dataServiceMock.shutdownScheduler.calls.reset();
    dataServiceMock.shutdownScheduler.and.returnValue(of({}));
    dataServiceMock.runSchedulerJob.calls.reset();
    dataServiceMock.runSchedulerJob.and.returnValue(of({}));
    dataServiceMock.pauseSchedulerJob.calls.reset();
    dataServiceMock.pauseSchedulerJob.and.returnValue(of({}));
    dataServiceMock.resumeSchedulerJob.calls.reset();
    dataServiceMock.resumeSchedulerJob.and.returnValue(of({}));

    await TestBed.configureTestingModule({
      imports: [AdminSchedulerComponent],
      providers: [
        provideRouter([]),
        { provide: DataService, useValue: dataServiceMock },
      ],
    }).compileComponents();

    router = TestBed.inject(Router);
    fixture = TestBed.createComponent(AdminSchedulerComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  afterEach(() => {
    localStorage.removeItem('access_token');
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should load scheduler status and jobs on init', () => {
    expect(dataServiceMock.getSchedulerStatus).toHaveBeenCalled();
    expect(dataServiceMock.getSchedulerJobs).toHaveBeenCalled();
  });

  it('should map running scheduler state label', () => {
    component.schedulerStatus = { state: 'STATE_RUNNING' };
    expect(component.schedulerStateLabel()).toBe('Running');
  });

  it('should map paused and stopped scheduler state labels', () => {
    component.schedulerStatus = { state: 'STATE_PAUSED' };
    expect(component.schedulerStateLabel()).toBe('Paused');

    component.schedulerStatus = { state: 'STATE_SHUTDOWN' };
    expect(component.schedulerStateLabel()).toBe('Stopped');
  });

  it('should map unknown scheduler state safely', () => {
    component.schedulerStatus = null;
    expect(component.schedulerStateLabel()).toBe('Unknown');

    component.schedulerStatus = { state: 'custom-state' };
    expect(component.schedulerStateLabel()).toBe('custom-state');
  });

  it('should redirect non-admin users to login', () => {
    localStorage.removeItem('access_token');
    const navigateSpy = spyOn(router, 'navigate').and.resolveTo(true);

    component.ngOnInit();

    expect(navigateSpy).toHaveBeenCalledWith(['/login']);
  });

  it('should normalize non-array jobs to empty array', () => {
    dataServiceMock.getSchedulerJobs.and.returnValue(of({}));

    component.refresh();

    expect(component.jobs).toEqual([]);
    expect(component.loading).toBeFalse();
  });

  it('should call start action through data service', () => {
    component.start();
    expect(dataServiceMock.startScheduler).toHaveBeenCalled();
    expect(component.successMessage).toBe('Scheduler started.');
    expect(component.actionBusy).toBeFalse();
  });

  it('should set scheduler action error message on failure', () => {
    dataServiceMock.pauseScheduler.and.returnValue(throwError(() => new Error('failed')));

    component.pause();

    expect(dataServiceMock.pauseScheduler).toHaveBeenCalled();
    expect(component.actionBusy).toBeFalse();
    expect(component.errorMessage).toBe('Scheduler action failed. Ensure you are logged in as Admin.');
  });

  it('should call runJob action through data service', () => {
    component.runJob('maintenance');
    expect(dataServiceMock.runSchedulerJob).toHaveBeenCalledWith('maintenance');
    expect(component.jobsBusy['maintenance']).toBeFalse();
    expect(component.successMessage).toBe('Job maintenance queued to run.');
  });

  it('should set job action error message on failure', () => {
    dataServiceMock.resumeSchedulerJob.and.returnValue(throwError(() => new Error('failed')));

    component.resumeJob('cleanup');

    expect(component.jobsBusy['cleanup']).toBeFalse();
    expect(component.errorMessage).toBe('Action failed for job cleanup.');
  });
});

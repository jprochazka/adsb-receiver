import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { AdminXAlertComponent } from './admin-x-alert.component';
import { DataService } from '../service/data.service';


describe('AdminXAlertComponent', () => {
  let component: AdminXAlertComponent;
  let fixture: ComponentFixture<AdminXAlertComponent>;

  const config = {
    x_alert_enabled: 'false',
    x_alert_poll_seconds: '15',
    x_alert_radius_nm: '3.0',
    credentials: { api_key: false, api_secret: false, access_token: false, access_secret: false },
  };
  const status = {
    last_run: null,
    last_result: 'never',
    posted_since_start: 0,
    dump1090_status: 'unknown',
    dump978_status: 'unknown',
    last_image_result: 'never',
    last_image_at: null,
  };
  const dataServiceMock = {
    getXAlertConfig: jasmine.createSpy('getXAlertConfig').and.returnValue(of(config)),
    updateXAlertConfig: jasmine.createSpy('updateXAlertConfig').and.returnValue(of(config)),
    getXAlertStatus: jasmine.createSpy('getXAlertStatus').and.returnValue(of(status)),
    dryRunXAlert: jasmine.createSpy('dryRunXAlert').and.returnValue(of({ result: 'success' })),
    sendXAlert: jasmine.createSpy('sendXAlert').and.returnValue(of({ result: 'success' })),
  };
  beforeEach(async () => {
    Object.values(dataServiceMock).forEach(spy => spy.calls.reset());
    dataServiceMock.getXAlertConfig.and.returnValue(of(config));
    dataServiceMock.updateXAlertConfig.and.returnValue(of(config));
    dataServiceMock.getXAlertStatus.and.returnValue(of(status));
    dataServiceMock.dryRunXAlert.and.returnValue(of({ result: 'success' }));
    dataServiceMock.sendXAlert.and.returnValue(of({ result: 'success' }));

    await TestBed.configureTestingModule({
      imports: [AdminXAlertComponent],
      providers: [{ provide: DataService, useValue: dataServiceMock }],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminXAlertComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('loads configuration and compact status', () => {
    expect(component).toBeTruthy();
    expect(dataServiceMock.getXAlertConfig).toHaveBeenCalled();
    expect(dataServiceMock.getXAlertStatus).toHaveBeenCalled();
    expect(component.status.last_result).toBe('never');
  });

  it('saves current configuration', () => {
    component.setEnabled(true);
    component.save();

    expect(dataServiceMock.updateXAlertConfig).toHaveBeenCalled();
    expect(component.successMessage).toBe('X alert settings saved.');
  });

  it('runs a dry-run action', () => {
    component.dryRun();

    expect(dataServiceMock.dryRunXAlert).toHaveBeenCalled();
    expect(component.successMessage).toBe('Dry run completed.');
  });

  it('shows backend action failures', () => {
    dataServiceMock.sendXAlert.and.returnValue(throwError(() => ({ error: { error: 'send failed' } })));

    component.sendNow();

    expect(component.errorMessage).toBe('send failed');
    expect(component.busy).toBeFalse();
  });
});
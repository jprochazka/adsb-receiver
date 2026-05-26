import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { of } from 'rxjs';

import { AppComponent } from './app.component';
import { DataService } from './service/data.service';

describe('AppComponent', () => {
  const dataServiceMock = {
    getRecentNotifications: jasmine.createSpy('getRecentNotifications').and.returnValue(of({ flights: [] })),
    getSetting: jasmine.createSpy('getSetting').and.returnValue(of({ value: 'true' })),
    getApiVersion: jasmine.createSpy('getApiVersion').and.returnValue(of({ version: 'v3.0.0' })),
    searchFlights: jasmine.createSpy('searchFlights').and.returnValue(of({ count: 0, flights: [] })),
  };

  beforeEach(async () => {
    localStorage.setItem(
      'access_token',
      'eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiQWRtaW4ifQ==.signature'
    );

    await TestBed.configureTestingModule({
      imports: [AppComponent],
      providers: [
        provideRouter([]),
        { provide: DataService, useValue: dataServiceMock },
      ]
    }).compileComponents();
  });

  afterEach(() => {
    localStorage.removeItem('access_token');
  });

  it('should create the app', () => {
    const fixture = TestBed.createComponent(AppComponent);
    const app = fixture.componentInstance;
    expect(app).toBeTruthy();
  });

  it('should have the frontend title', () => {
    const fixture = TestBed.createComponent(AppComponent);
    const app = fixture.componentInstance;
    expect(app.title).toEqual('frontend');
  });

  it('should load backend version from API', () => {
    const fixture = TestBed.createComponent(AppComponent);
    fixture.detectChanges();

    const app = fixture.componentInstance;
    expect(dataServiceMock.getApiVersion).toHaveBeenCalled();
    expect(app.backendVersion).toEqual('v3.0.0');
  });
});

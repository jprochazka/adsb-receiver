import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { of, throwError } from 'rxjs';

import { LoginComponent } from './login.component';
import { DataService } from '../service/data.service';

describe('LoginComponent', () => {
  let component: LoginComponent;
  let fixture: ComponentFixture<LoginComponent>;
  let router: Router;

  const dataServiceMock = {
    login: jasmine.createSpy('login').and.returnValue(of({ access_token: 'a-token', refresh_token: 'r-token' })),
  };

  beforeEach(async () => {
    dataServiceMock.login.calls.reset();
    dataServiceMock.login.and.returnValue(of({ access_token: 'a-token', refresh_token: 'r-token' }));

    await TestBed.configureTestingModule({
      imports: [LoginComponent],
      providers: [
        provideRouter([]),
        { provide: DataService, useValue: dataServiceMock },
      ],
    }).compileComponents();

    router = TestBed.inject(Router);
    fixture = TestBed.createComponent(LoginComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  afterEach(() => {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should login successfully and navigate to account', () => {
    const navigateSpy = spyOn(router, 'navigate').and.resolveTo(true);
    component.email = 'jane@example.com';
    component.password = 'password123';

    component.login();

    expect(dataServiceMock.login).toHaveBeenCalledWith('jane@example.com', 'password123');
    expect(localStorage.getItem('access_token')).toBe('a-token');
    expect(localStorage.getItem('refresh_token')).toBe('r-token');
    expect(navigateSpy).toHaveBeenCalledWith(['/account']);
  });

  it('should show error message on failed login', () => {
    dataServiceMock.login.and.returnValue(throwError(() => new Error('invalid')));
    component.email = 'jane@example.com';
    component.password = 'wrong';

    component.login();

    expect(component.errorMessage).toBe('Invalid email or password.');
    expect(component.loading).toBeFalse();
  });
});

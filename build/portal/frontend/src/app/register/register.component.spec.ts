import { fakeAsync, tick, ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { of, throwError } from 'rxjs';

import { RegisterComponent } from './register.component';
import { DataService } from '../service/data.service';

describe('RegisterComponent', () => {
  let component: RegisterComponent;
  let fixture: ComponentFixture<RegisterComponent>;
  let router: Router;

  const dataServiceMock = {
    register: jasmine.createSpy('register').and.returnValue(of({})),
  };

  beforeEach(async () => {
    dataServiceMock.register.calls.reset();
    dataServiceMock.register.and.returnValue(of({}));

    await TestBed.configureTestingModule({
      imports: [RegisterComponent],
      providers: [
        provideRouter([]),
        { provide: DataService, useValue: dataServiceMock },
      ],
    }).compileComponents();

    router = TestBed.inject(Router);
    fixture = TestBed.createComponent(RegisterComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should require all fields', () => {
    component.name = '  ';
    component.email = ' '; 
    component.password = '';
    component.confirmPassword = '';

    component.register();

    expect(component.errorMessage).toBe('All fields are required.');
    expect(dataServiceMock.register).not.toHaveBeenCalled();
  });

  it('should validate minimum password length', () => {
    component.name = 'Jane';
    component.email = 'jane@example.com';
    component.password = 'short';
    component.confirmPassword = 'short';

    component.register();

    expect(component.errorMessage).toBe('Password must be at least 8 characters.');
    expect(dataServiceMock.register).not.toHaveBeenCalled();
  });

  it('should validate password confirmation match', () => {
    component.name = 'Jane';
    component.email = 'jane@example.com';
    component.password = 'password123';
    component.confirmPassword = 'password321';

    component.register();

    expect(component.errorMessage).toBe('Passwords do not match.');
    expect(dataServiceMock.register).not.toHaveBeenCalled();
  });

  it('should register successfully and navigate to login', fakeAsync(() => {
    const navigateSpy = spyOn(router, 'navigate').and.resolveTo(true);
    component.name = ' Jane Doe ';
    component.email = ' jane@example.com ';
    component.password = 'password123';
    component.confirmPassword = 'password123';

    component.register();

    expect(dataServiceMock.register).toHaveBeenCalledWith('Jane Doe', 'jane@example.com', 'password123');
    expect(component.loading).toBeFalse();
    expect(component.successMessage).toBe('Account created! Redirecting to login…');

    tick(1500);
    expect(navigateSpy).toHaveBeenCalledWith(['/login']);
  }));

  it('should show backend error message on registration failure', () => {
    dataServiceMock.register.and.returnValue(throwError(() => ({ error: { msg: 'Email already exists.' } })));
    component.name = 'Jane';
    component.email = 'jane@example.com';
    component.password = 'password123';
    component.confirmPassword = 'password123';

    component.register();

    expect(component.loading).toBeFalse();
    expect(component.errorMessage).toBe('Email already exists.');
  });

  it('should show fallback error message when backend payload is invalid', () => {
    dataServiceMock.register.and.returnValue(throwError(() => ({ error: {} })));
    component.name = 'Jane';
    component.email = 'jane@example.com';
    component.password = 'password123';
    component.confirmPassword = 'password123';

    component.register();

    expect(component.errorMessage).toBe('Registration failed. Please try again.');
  });
});

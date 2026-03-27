import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { AdminUsersComponent } from './admin-users.component';
import { DataService } from '../service/data.service';

describe('AdminUsersComponent', () => {
  let component: AdminUsersComponent;
  let fixture: ComponentFixture<AdminUsersComponent>;

  const dataServiceMock = {
    getUsers: jasmine.createSpy('getUsers').and.returnValue(of({ users: [{ id: 1, name: 'Jane', email: 'jane@example.com', role: 'User', locked: false }] })),
    createUser: jasmine.createSpy('createUser').and.returnValue(of({})),
    updateUser: jasmine.createSpy('updateUser').and.returnValue(of({})),
    deleteUser: jasmine.createSpy('deleteUser').and.returnValue(of({})),
    setUserLocked: jasmine.createSpy('setUserLocked').and.returnValue(of({})),
  };

  beforeEach(async () => {
    Object.values(dataServiceMock).forEach((spy) => spy.calls.reset());
    dataServiceMock.getUsers.and.returnValue(of({ users: [{ id: 1, name: 'Jane', email: 'jane@example.com', role: 'User', locked: false }] }));
    dataServiceMock.createUser.and.returnValue(of({}));
    dataServiceMock.updateUser.and.returnValue(of({}));
    dataServiceMock.deleteUser.and.returnValue(of({}));
    dataServiceMock.setUserLocked.and.returnValue(of({}));

    await TestBed.configureTestingModule({
      imports: [AdminUsersComponent],
      providers: [{ provide: DataService, useValue: dataServiceMock }],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminUsersComponent);
    component = fixture.componentInstance;
  });

  it('should create', () => {
    fixture.detectChanges();
    expect(component).toBeTruthy();
  });

  it('should load users on init', () => {
    fixture.detectChanges();

    expect(dataServiceMock.getUsers).toHaveBeenCalledWith(0, 1000);
    expect(component.allUsers.length).toBe(1);
    expect(component.loading).toBeFalse();
  });

  it('should validate create user fields', () => {
    fixture.detectChanges();
    component.newName = ' ';
    component.newEmail = ' ';
    component.newPassword = '';

    component.createUser();

    expect(component.errorMessage).toBe('Name, email, and password are required.');
    expect(dataServiceMock.createUser).not.toHaveBeenCalled();
  });

  it('should validate create user password length', () => {
    fixture.detectChanges();
    component.newName = 'Jane';
    component.newEmail = 'jane@example.com';
    component.newPassword = 'short';

    component.createUser();

    expect(component.errorMessage).toBe('Password must be at least 8 characters.');
    expect(dataServiceMock.createUser).not.toHaveBeenCalled();
  });

  it('should create user successfully', () => {
    fixture.detectChanges();
    component.newName = ' Jane ';
    component.newEmail = ' jane@example.com ';
    component.newPassword = 'password123';
    component.newRole = 'Admin';

    component.createUser();

    expect(dataServiceMock.createUser).toHaveBeenCalledWith({
      name: 'Jane',
      email: 'jane@example.com',
      password: 'password123',
      role: 'Admin',
    });
    expect(component.creating).toBeFalse();
    expect(component.successMessage).toBe('User created successfully.');
  });

  it('should show backend create error message', () => {
    dataServiceMock.createUser.and.returnValue(throwError(() => ({ error: { msg: 'Email already exists.' } })));
    fixture.detectChanges();
    component.newName = 'Jane';
    component.newEmail = 'jane@example.com';
    component.newPassword = 'password123';

    component.createUser();

    expect(component.errorMessage).toBe('Email already exists.');
  });
});

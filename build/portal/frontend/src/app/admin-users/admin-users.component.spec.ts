import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { AdminUsersComponent } from './admin-users.component';
import { DataService } from '../service/data.service';

describe('AdminUsersComponent', () => {
  let component: AdminUsersComponent;
  let fixture: ComponentFixture<AdminUsersComponent>;

  const dataServiceMock = {
    getUsers: jasmine.createSpy('getUsers').and.returnValue(of({
      users: [{ id: 1, name: 'Jane', email: 'jane@example.com', role: 'User', locked: false }],
      total: 1,
      all_total: 1,
      active_total: 1,
      locked_total: 0,
    })),
    createUser: jasmine.createSpy('createUser').and.returnValue(of({})),
    updateUser: jasmine.createSpy('updateUser').and.returnValue(of({})),
    deleteUser: jasmine.createSpy('deleteUser').and.returnValue(of({})),
    setUserLocked: jasmine.createSpy('setUserLocked').and.returnValue(of({})),
  };

  beforeEach(async () => {
    Object.values(dataServiceMock).forEach((spy) => spy.calls.reset());
    dataServiceMock.getUsers.and.returnValue(of({
      users: [{ id: 1, name: 'Jane', email: 'jane@example.com', role: 'User', locked: false }],
      total: 1,
      all_total: 1,
      active_total: 1,
      locked_total: 0,
    }));
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

    expect(dataServiceMock.getUsers).toHaveBeenCalledWith(0, 50, { q: '', locked: null });
    expect(component.users.length).toBe(1);
    expect(component.allCount).toBe(1);
    expect(component.loading).toBeFalse();
  });

  it('should reload users when switching tabs', () => {
    fixture.detectChanges();
    dataServiceMock.getUsers.calls.reset();

    component.switchTab('locked');

    expect(dataServiceMock.getUsers).toHaveBeenCalledWith(0, 50, { q: '', locked: true });
  });

  it('should derive active and locked counts when legacy responses omit them', () => {
    dataServiceMock.getUsers.and.returnValue(of({
      users: [
        { id: 1, name: 'Admin', email: 'admin@example.com', role: 'Admin', locked: false },
        { id: 2, name: 'Locked', email: 'locked@example.com', role: 'User', locked: true },
      ],
      total: 2,
      count: 2,
      offset: 0,
      limit: 50,
    }));

    fixture.detectChanges();

    expect(component.allCount).toBe(2);
    expect(component.activeCount).toBe(1);
    expect(component.lockedCount).toBe(1);
  });

  it('should locally filter users for the selected tab when legacy responses ignore the locked filter', () => {
    dataServiceMock.getUsers.and.returnValue(of({
      users: [
        { id: 1, name: 'Admin', email: 'admin@example.com', role: 'Admin', locked: false },
        { id: 2, name: 'Locked', email: 'locked@example.com', role: 'User', locked: true },
      ],
      total: 2,
      count: 2,
      offset: 0,
      limit: 50,
    }));

    fixture.detectChanges();
    dataServiceMock.getUsers.calls.reset();

    component.switchTab('locked');

    expect(component.users.length).toBe(1);
    expect(component.users[0].id).toBe(2);
  });

  it('should reload users when page size changes', () => {
    fixture.detectChanges();
    dataServiceMock.getUsers.calls.reset();
    component.allPage = 3;

    component.updatePerPage(25);

    expect(component.perPage).toBe(25);
    expect(component.currentPage).toBe(1);
    expect(dataServiceMock.getUsers).toHaveBeenCalledWith(0, 25, { q: '', locked: null });
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

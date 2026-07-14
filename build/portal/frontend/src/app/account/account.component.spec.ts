import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of } from 'rxjs';

import { AccountComponent } from './account.component';
import { DataService } from '../service/data.service';

describe('AccountComponent', () => {
  let component: AccountComponent;
  let fixture: ComponentFixture<AccountComponent>;

  const dataServiceMock = {
    getCurrentUser: jasmine.createSpy('getCurrentUser').and.returnValue(of({ id: 7, name: 'Jane', email: 'jane@example.com' })),
    getNotifications: jasmine.createSpy('getNotifications').and.returnValue(of({ notifications: [{ flight: 'AAL123' }] })),
    updateCurrentUser: jasmine.createSpy('updateCurrentUser').and.returnValue(of({})),
    createNotification: jasmine.createSpy('createNotification').and.returnValue(of({})),
    deleteNotification: jasmine.createSpy('deleteNotification').and.returnValue(of({})),
  };

  beforeEach(async () => {
    Object.values(dataServiceMock).forEach((spy) => spy.calls.reset());
    localStorage.setItem('access_token', 'header.eyJ1c2VyX2lkIjo3fQ==.sig');

    await TestBed.configureTestingModule({
      imports: [AccountComponent],
      providers: [{ provide: DataService, useValue: dataServiceMock }],
    }).compileComponents();

    fixture = TestBed.createComponent(AccountComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  afterEach(() => {
    localStorage.removeItem('access_token');
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should load profile and notifications on init', () => {
    expect(dataServiceMock.getCurrentUser).toHaveBeenCalled();
    expect(component.name).toBe('Jane');
    expect(component.email).toBe('jane@example.com');
    expect(component.notifications).toBe('AAL123');
    expect(component.loading).toBeFalse();
  });

  it('should save profile changes', () => {
    component.name = 'Jane Doe';
    component.email = 'jane.doe@example.com';
    component.currentPassword = 'oldpass';

    component.saveProfile();

    expect(dataServiceMock.updateCurrentUser).toHaveBeenCalledWith({
      name: 'Jane Doe',
      email: 'jane.doe@example.com',
      current_password: 'oldpass',
    });
    expect(component.profileSuccess).toBe('Profile updated successfully.');
  });

  it('should validate password fields before changing password', () => {
    component.newPassword = '';
    component.confirmPassword = '';
    component.changePassword();
    expect(component.authError).toBe('New password is required.');

    component.newPassword = 'password123';
    component.confirmPassword = 'password999';
    component.changePassword();
    expect(component.authError).toBe('New passwords do not match.');
  });

  it('should update password and clear auth form', () => {
    component.name = 'Jane';
    component.newPassword = 'password123';
    component.confirmPassword = 'password123';
    component.currentPassword = 'oldpass';

    component.changePassword();

    expect(dataServiceMock.updateCurrentUser).toHaveBeenCalledWith({
      name: 'Jane',
      password: 'password123',
      current_password: 'oldpass',
    });
    expect(component.authSuccess).toBe('Password updated successfully.');
    expect(component.currentPassword).toBe('');
    expect(component.newPassword).toBe('');
    expect(component.confirmPassword).toBe('');
  });

  it('should show no-change message for notifications when unchanged', () => {
    component.notifications = 'AAL123';

    component.saveNotifications();

    expect(dataServiceMock.createNotification).not.toHaveBeenCalled();
    expect(dataServiceMock.deleteNotification).not.toHaveBeenCalled();
    expect(component.notifSuccess).toBe('No changes to save.');
  });

  it('should add and remove notifications', () => {
    component.notifications = 'AAL123, dal456';
    (component as any).originalNotifications = ['AAL123', 'UAL111'];

    component.saveNotifications();

    expect(dataServiceMock.createNotification).toHaveBeenCalledWith('DAL456');
    expect(dataServiceMock.deleteNotification).toHaveBeenCalledWith('UAL111');
    expect(component.notifSuccess).toBe('Notifications updated successfully.');
  });
});

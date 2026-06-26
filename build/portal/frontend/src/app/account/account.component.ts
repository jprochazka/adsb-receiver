import { Component, OnInit, inject, ChangeDetectionStrategy } from '@angular/core';

import { FormsModule } from '@angular/forms';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';
import { catchError, of, forkJoin } from 'rxjs';
import { getCurrentUserId } from '../shared/auth-session';

@Component({
  selector: 'app-account',
  standalone: true,
  imports: [FormsModule, SpinnerComponent],
  templateUrl: './account.component.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './account.component.scss'
})
export class AccountComponent implements OnInit {
  userId!: number;

  loading = true;

  // Profile
  name = '';
  email = '';
  profileSuccess = '';
  profileError = '';

  // Authentication
  currentPassword = '';
  newPassword = '';
  confirmPassword = '';
  authSuccess = '';
  authError = '';

  // Notifications
  notifications = '';
  private originalNotifications: string[] = [];
  notifSuccess = '';
  notifError = '';

  constructor(private dataService: DataService) {}

  ngOnInit() {
    const userId = getCurrentUserId();
    if (userId !== null) {
      this.userId = userId;

      this.dataService.getUser(this.userId).subscribe({
        next: (user) => {
          this.name  = user.name;
          this.email = user.email;
          this.loading = false;
        },
        error: () => {
          this.profileError = 'Failed to load profile from the server.';
          this.loading = false;
        }
      });

      this.dataService.getNotifications().pipe(
        catchError(() => of({ notifications: [] }))
      ).subscribe((notifs) => {
        const flights: string[] = notifs.notifications.map((n: any) => n.flight);
        this.originalNotifications = flights;
        this.notifications = flights.join(', ');
      });
    }
  }

  saveProfile() {
    this.profileSuccess = '';
    this.profileError = '';
    this.dataService.updateUser(this.userId, { name: this.name, email: this.email }).subscribe({
      next: () => this.profileSuccess = 'Profile updated successfully.',
      error: () => this.profileError = 'Failed to update profile.'
    });
  }

  changePassword() {
    this.authSuccess = '';
    this.authError = '';
    if (!this.newPassword) {
      this.authError = 'New password is required.';
      return;
    }
    if (this.newPassword !== this.confirmPassword) {
      this.authError = 'New passwords do not match.';
      return;
    }
    this.dataService.updateUser(this.userId, { name: this.name, password: this.newPassword }).subscribe({
      next: () => {
        this.authSuccess = 'Password updated successfully.';
        this.currentPassword = '';
        this.newPassword = '';
        this.confirmPassword = '';
      },
      error: () => this.authError = 'Failed to update password.'
    });
  }

  saveNotifications() {
    this.notifSuccess = '';
    this.notifError = '';

    const updated = this.notifications
      .split(',')
      .map((f) => f.trim().toUpperCase())
      .filter((f) => f.length > 0);

    const toAdd = updated.filter((f) => !this.originalNotifications.includes(f));
    const toRemove = this.originalNotifications.filter((f) => !updated.includes(f));

    const adds = toAdd.map((f) => this.dataService.createNotification(f));
    const removes = toRemove.map((f) => this.dataService.deleteNotification(f));
    const all = [...adds, ...removes];

    if (all.length === 0) {
      this.notifSuccess = 'No changes to save.';
      return;
    }

    forkJoin(all).subscribe({
      next: () => {
        this.originalNotifications = updated;
        this.notifications = updated.join(', ');
        this.notifSuccess = 'Notifications updated successfully.';
      },
      error: () => this.notifError = 'Failed to update notifications.'
    });
  }
}

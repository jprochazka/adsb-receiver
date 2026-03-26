import { Component, OnInit } from '@angular/core';

import { FormsModule } from '@angular/forms';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

@Component({
  selector: 'app-admin-users',
  standalone: true,
  imports: [FormsModule, SpinnerComponent],
  templateUrl: './admin-users.component.html',
  styleUrl: './admin-users.component.scss'
})
export class AdminUsersComponent implements OnInit {
  users: any[] = [];
  loading = true;
  errorMessage = '';
  successMessage = '';

  // Pagination
  currentPage = 1;
  totalPages  = 1;
  total       = 0;
  readonly perPage = 10;

  // Create form state
  showCreateForm = false;
  creating = false;
  newName = '';
  newEmail = '';
  newPassword = '';
  newRole = 'User';

  // Edit form state
  editingUser: any = null;
  editName = '';
  editEmail = '';
  editRole = '';
  editPassword = '';
  saving = false;

  constructor(private dataService: DataService) {}

  ngOnInit() {
    this.loadUsers();
  }

  loadUsers() {
    this.loading = true;
    const offset = (this.currentPage - 1) * this.perPage;
    this.dataService.getUsers(offset, this.perPage).subscribe({
      next: (data) => {
        this.users      = data.users;
        this.total      = data.total ?? data.count ?? 0;
        this.totalPages = Math.max(1, Math.ceil(this.total / this.perPage));
        if (this.currentPage > this.totalPages) this.currentPage = this.totalPages;
        this.loading = false;
      },
      error: () => {
        this.errorMessage = 'Failed to load users.';
        this.loading = false;
      }
    });
  }

  goToPage(page: number) {
    if (page < 1 || page > this.totalPages || page === this.currentPage) return;
    this.currentPage = page;
    this.loadUsers();
  }

  get pageNumbers(): number[] {
    const start = Math.max(1, this.currentPage - 2);
    const end   = Math.min(this.totalPages, this.currentPage + 2);
    const range: number[] = [];
    for (let i = start; i <= end; i++) range.push(i);
    return range;
  }

  toggleCreateForm() {
    this.showCreateForm = !this.showCreateForm;
    this.newName = '';
    this.newEmail = '';
    this.newPassword = '';
    this.newRole = 'User';
    this.successMessage = '';
    this.errorMessage = '';
  }

  createUser() {
    if (!this.newName.trim() || !this.newEmail.trim() || !this.newPassword) {
      this.errorMessage = 'Name, email, and password are required.';
      return;
    }
    if (this.newPassword.length < 8) {
      this.errorMessage = 'Password must be at least 8 characters.';
      return;
    }
    this.creating = true;
    this.errorMessage = '';
    this.dataService.createUser({
      name: this.newName.trim(),
      email: this.newEmail.trim(),
      password: this.newPassword,
      role: this.newRole
    }).subscribe({
      next: () => {
        this.creating = false;
        this.showCreateForm = false;
        this.successMessage = 'User created successfully.';
        this.currentPage = 1;
        this.loadUsers();
      },
      error: (err) => {
        this.creating = false;
        const msg = err?.error?.msg;
        this.errorMessage = msg && typeof msg === 'string' ? msg : 'Failed to create user.';
      }
    });
  }

  startEdit(user: any) {
    this.editingUser = user;
    this.editName = user.name;
    this.editEmail = user.email;
    this.editRole = user.role;
    this.editPassword = '';
    this.successMessage = '';
    this.errorMessage = '';
  }

  cancelEdit() {
    this.editingUser = null;
  }

  saveEdit() {
    if (!this.editName.trim()) {
      this.errorMessage = 'Name is required.';
      return;
    }
    if (this.editPassword && this.editPassword.length < 8) {
      this.errorMessage = 'Password must be at least 8 characters.';
      return;
    }
    this.saving = true;
    this.errorMessage = '';
    const payload: any = { name: this.editName.trim(), email: this.editEmail.trim(), role: this.editRole };
    if (this.editPassword) {
      payload['password'] = this.editPassword;
    }
    this.dataService.updateUser(this.editingUser.id, payload).subscribe({
      next: () => {
        this.saving = false;
        this.editingUser = null;
        this.successMessage = 'User updated successfully.';
        this.loadUsers();
      },
      error: (err) => {
        this.saving = false;
        const msg = err?.error?.msg;
        this.errorMessage = msg && typeof msg === 'string' ? msg : 'Failed to update user.';
      }
    });
  }

  deleteUser(user: any) {
    if (!confirm(`Delete user "${user.name}" (${user.email})? This cannot be undone.`)) return;
    this.errorMessage = '';
    this.dataService.deleteUser(user.id).subscribe({
      next: () => {
        this.successMessage = `User "${user.name}" deleted.`;
        if (this.users.length === 1 && this.currentPage > 1) this.currentPage--;
        this.loadUsers();
      },
      error: (err) => {
        const msg = err?.error?.msg;
        this.errorMessage = msg && typeof msg === 'string' ? msg : 'Failed to delete user.';
      }
    });
  }
}

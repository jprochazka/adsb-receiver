import { Component, OnInit, ChangeDetectionStrategy } from '@angular/core';

import { FormsModule } from '@angular/forms';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

@Component({
  selector: 'app-admin-users',
  standalone: true,
  imports: [FormsModule, SpinnerComponent],
  templateUrl: './admin-users.component.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './admin-users.component.scss'
})
export class AdminUsersComponent implements OnInit {
  users: any[] = [];
  loading = true;
  errorMessage = '';
  successMessage = '';
  totalUsers = 0;
  allMatchingCount = 0;
  activeMatchingCount = 0;
  lockedMatchingCount = 0;

  // Tabs
  activeTab: 'active' | 'locked' | 'all' = 'all';
  activePage = 1;
  lockedPage = 1;
  allPage    = 1;
  readonly pageSizeOptions = [10, 25, 50, 100];
  perPage = 50;
  private _searchQuery = '';
  get searchQuery(): string { return this._searchQuery; }
  set searchQuery(val: string) {
    this._searchQuery = val;
    this.activePage = 1; this.lockedPage = 1; this.allPage = 1;
    this.loadUsers();
  }

  get allCount(): number      { return this.allMatchingCount; }
  get activeCount(): number   { return this.activeMatchingCount; }
  get lockedCount(): number   { return this.lockedMatchingCount; }
  get currentPage(): number  {
    if (this.activeTab === 'active') return this.activePage;
    if (this.activeTab === 'locked') return this.lockedPage;
    return this.allPage;
  }
  get totalPages(): number   { return Math.max(1, Math.ceil(this.currentTabTotal / this.perPage)); }
  get currentTabTotal(): number {
    if (this.activeTab === 'active') return this.activeMatchingCount;
    if (this.activeTab === 'locked') return this.lockedMatchingCount;
    return this.allMatchingCount;
  }
  get pagedUsers(): any[] { return this.users; }

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

  lockingUserId: number | null = null;

  constructor(private dataService: DataService) {}

  ngOnInit() {
    this.loadUsers();
  }

  loadUsers() {
    this.loading = true;
    this.errorMessage = '';

    const offset = (this.currentPage - 1) * this.perPage;
    const locked = this.activeTab === 'all' ? null : this.activeTab === 'locked';

    this.dataService.getUsers(offset, this.perPage, {
      q: this.searchQuery,
      locked,
    }).subscribe({
      next: (data) => {
        this.users = Array.isArray(data.users) ? data.users : [];
        this.totalUsers = Number(data.total ?? 0);

        const allTotal = data.all_total;
        const activeTotal = data.active_total;
        const lockedTotal = data.locked_total;
        const hasLegacyFullResultFallback =
          (allTotal === undefined || activeTotal === undefined || lockedTotal === undefined) &&
          Number(data.offset ?? 0) === 0 &&
          this.users.length === this.totalUsers;

        if (hasLegacyFullResultFallback && this.activeTab !== 'all') {
          this.users = this.users.filter((user) => this.activeTab === 'locked' ? !!user.locked : !user.locked);
        }

        this.allMatchingCount = Number(allTotal ?? data.total ?? 0);
        this.activeMatchingCount = Number(
          activeTotal ?? (hasLegacyFullResultFallback ? this.users.filter((user) => !user.locked).length : 0)
        );
        this.lockedMatchingCount = Number(
          lockedTotal ?? (hasLegacyFullResultFallback ? this.users.filter((user) => !!user.locked).length : 0)
        );
        this.loading = false;
      },
      error: () => {
        this.users = [];
        this.errorMessage = 'Failed to load users.';
        this.loading = false;
      }
    });
  }

  switchTab(tab: 'active' | 'locked' | 'all') {
    this.activeTab = tab;
    this.activePage = 1;
    this.lockedPage = 1;
    this.allPage = 1;
    this.loadUsers();
  }

  goToPage(page: number) {
    if (page < 1 || page > this.totalPages || page === this.currentPage) return;
    if (this.activeTab === 'active') this.activePage = page;
    else if (this.activeTab === 'locked') this.lockedPage = page;
    else this.allPage = page;
    this.loadUsers();
  }

  updatePerPage(perPage: number) {
    this.perPage = perPage;
    this.activePage = 1;
    this.lockedPage = 1;
    this.allPage = 1;
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
        this.loadUsers();
      },
      error: (err) => {
        const msg = err?.error?.msg;
        this.errorMessage = msg && typeof msg === 'string' ? msg : 'Failed to delete user.';
      }
    });
  }

  toggleLock(user: any) {
    const action = user.locked ? 'unlock' : 'lock';
    if (!confirm(`${action.charAt(0).toUpperCase() + action.slice(1)} user "${user.name}"?`)) return;
    this.lockingUserId = user.id;
    this.errorMessage = '';
    this.dataService.setUserLocked(user.id, !user.locked).subscribe({
      next: () => {
        this.lockingUserId = null;
        this.successMessage = `User "${user.name}" ${action}ed successfully.`;
        this.loadUsers();
      },
      error: (err) => {
        this.lockingUserId = null;
        const msg = err?.error?.msg;
        this.errorMessage = msg && typeof msg === 'string' ? msg : `Failed to ${action} user.`;
      }
    });
  }

  fmtDate(iso: string | null): string {
    if (!iso) return '—';
    const d = new Date(iso.replace(' ', 'T'));
    const date = iso.slice(0, 10);
    const time = d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
    return `${date} ${time}`;
  }
}

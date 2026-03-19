import { Component, OnInit } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { catchError, of } from 'rxjs';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

@Component({
  selector: 'app-admin-links',
  standalone: true,
  imports: [NgFor, NgIf, FormsModule, SpinnerComponent],
  templateUrl: './admin-links.component.html',
  styleUrl: './admin-links.component.scss'
})
export class AdminLinksComponent implements OnInit {
  links: any[] = [];
  loading = true;
  errorMessage = '';
  successMessage = '';

  linksNavEnabled   = true;
  savingNav         = false;
  navSuccessMessage = '';
  navErrorMessage   = '';

  // Pagination
  currentPage = 1;
  totalPages  = 1;
  total       = 0;
  readonly perPage = 10;
  // Create form state
  showCreateForm = false;
  creating = false;
  newName = '';
  newAddress = '';

  // Edit form state
  editingLink: any = null;
  editName = '';
  editAddress = '';
  saving = false;

  constructor(private dataService: DataService) {}

  ngOnInit() {
    this.loadNavSetting();
    this.loadLinks();
  }

  loadNavSetting() {
    this.dataService.getSetting('links_nav_enabled').pipe(catchError(() => of({ value: 'true' }))).subscribe(res => {
      this.linksNavEnabled = res?.value !== 'false';
    });
  }

  saveNavSetting() {
    this.savingNav = true;
    this.navSuccessMessage = '';
    this.navErrorMessage = '';
    this.dataService.updateSetting('links_nav_enabled', String(this.linksNavEnabled)).subscribe({
      next: () => {
        this.savingNav = false;
        this.navSuccessMessage = 'Links management settings saved successfully.';
      },
      error: () => {
        this.savingNav = false;
        this.navErrorMessage = 'Failed to save settings.';
      }
    });
  }

  loadLinks() {
    this.loading = true;
    const offset = (this.currentPage - 1) * this.perPage;
    this.dataService.getLinks(offset, this.perPage).subscribe({
      next: (data) => {
        this.links      = data.links;
        this.total      = data.total ?? data.count ?? 0;
        this.totalPages = Math.max(1, Math.ceil(this.total / this.perPage));
        if (this.currentPage > this.totalPages) this.currentPage = this.totalPages;
        this.loading = false;
      },
      error: () => {
        this.errorMessage = 'Failed to load links.';
        this.loading = false;
      }
    });
  }

  goToPage(page: number) {
    if (page < 1 || page > this.totalPages || page === this.currentPage) return;
    this.currentPage = page;
    this.loadLinks();
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
    this.newAddress = '';
    this.successMessage = '';
    this.errorMessage = '';
  }

  createLink() {
    if (!this.newName.trim() || !this.newAddress.trim()) {
      this.errorMessage = 'Name and address are required.';
      return;
    }
    this.creating = true;
    this.errorMessage = '';
    this.dataService.createLink({
      name: this.newName.trim(),
      address: this.newAddress.trim()
    }).subscribe({
      next: () => {
        this.creating = false;
        this.showCreateForm = false;
        this.successMessage = 'Link created successfully.';
        this.currentPage = 1;
        this.loadLinks();
      },
      error: () => {
        this.creating = false;
        this.errorMessage = 'Failed to create link.';
      }
    });
  }

  startEdit(link: any) {
    this.editingLink = link;
    this.editName = link.name;
    this.editAddress = link.address;
    this.successMessage = '';
    this.errorMessage = '';
    this.showCreateForm = false;
  }

  cancelEdit() {
    this.editingLink = null;
  }

  saveEdit() {
    if (!this.editName.trim() || !this.editAddress.trim()) {
      this.errorMessage = 'Name and address are required.';
      return;
    }
    this.saving = true;
    this.errorMessage = '';
    this.dataService.updateLink(this.editingLink.id, {
      name: this.editName.trim(),
      address: this.editAddress.trim()
    }).subscribe({
      next: () => {
        this.saving = false;
        this.editingLink = null;
        this.successMessage = 'Link updated successfully.';
        this.loadLinks();
      },
      error: () => {
        this.saving = false;
        this.errorMessage = 'Failed to update link.';
      }
    });
  }

  deleteLink(link: any) {
    if (!confirm(`Delete "${link.name}"? This cannot be undone.`)) return;
    this.errorMessage = '';
    this.dataService.deleteLink(link.id).subscribe({
      next: () => {
        this.successMessage = `"${link.name}" was deleted.`;
        if (this.editingLink?.id === link.id) this.editingLink = null;
        if (this.links.length === 1 && this.currentPage > 1) this.currentPage--;
        this.loadLinks();
      },
      error: () => {
        this.errorMessage = 'Failed to delete link.';
      }
    });
  }
}

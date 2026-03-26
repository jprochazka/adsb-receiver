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

  // Drag-and-drop state
  dragIndex: number | null = null;
  dragOverIndex: number | null = null;

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

  saveLinksNavEnabled() {
    this.dataService.updateSetting('links_nav_enabled', String(this.linksNavEnabled)).subscribe();
  }

  loadLinks() {
    this.loading = true;
    this.dataService.getLinks(0, 100).subscribe({
      next: (data) => {
        this.links   = data.links;
        this.loading = false;
      },
      error: () => {
        this.errorMessage = 'Failed to load links.';
        this.loading = false;
      }
    });
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
        this.loadLinks();
      },
      error: () => {
        this.errorMessage = 'Failed to delete link.';
      }
    });
  }

  // Drag-and-drop handlers
  onDragStart(index: number) {
    this.dragIndex = index;
  }

  onDragOver(event: DragEvent, index: number) {
    event.preventDefault();
    this.dragOverIndex = index;
  }

  onDragLeave() {
    this.dragOverIndex = null;
  }

  onDrop(event: DragEvent, dropIndex: number) {
    event.preventDefault();
    if (this.dragIndex === null || this.dragIndex === dropIndex) {
      this.dragIndex = null;
      this.dragOverIndex = null;
      return;
    }

    const reordered = [...this.links];
    const [moved] = reordered.splice(this.dragIndex, 1);
    reordered.splice(dropIndex, 0, moved);
    this.links = reordered;
    this.dragIndex = null;
    this.dragOverIndex = null;

    this.dataService.reorderLinks(reordered.map(l => l.id)).subscribe({
      next: () => { this.successMessage = 'Link order saved.'; },
      error: () => {
        this.errorMessage = 'Failed to save link order.';
        this.loadLinks();
      }
    });
  }

  onDragEnd() {
    this.dragIndex = null;
    this.dragOverIndex = null;
  }
}

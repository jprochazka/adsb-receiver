import { Component, OnInit } from '@angular/core';
import { SlicePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { catchError, of } from 'rxjs';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

@Component({
  selector: 'app-admin-blog',
  standalone: true,
  imports: [SlicePipe, FormsModule, SpinnerComponent],
  templateUrl: './admin-blog.component.html',
  styleUrl: './admin-blog.component.scss'
})
export class AdminBlogComponent implements OnInit {
  posts: any[] = [];
  loading = true;
  errorMessage = '';
  successMessage = '';

  blogNavEnabled  = true;

  // Pagination
  currentPage = 1;
  totalPages  = 1;
  total       = 0;
  readonly perPage = 10;
  // Create form state
  showCreateForm = false;
  creating = false;
  newTitle = '';
  newAuthor = '';
  newContent = '';
  newDate = this.todayIso();
  newVisible = true;

  // Edit form state
  editingPost: any = null;
  editTitle = '';
  editContent = '';
  editDate = '';
  editVisible = true;
  saving = false;

  constructor(private dataService: DataService) {}

  ngOnInit() {
    this.loadNavSetting();
    this.loadPosts();
  }

  loadNavSetting() {
    this.dataService.getSetting('blog_nav_enabled').pipe(catchError(() => of({ value: 'true' }))).subscribe(res => {
      this.blogNavEnabled = res?.value !== 'false';
    });
  }

  saveBlogNavEnabled() {
    this.dataService.updateSetting('blog_nav_enabled', String(this.blogNavEnabled)).subscribe();
  }

  todayIso(): string {
    const now = new Date();
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}`;
  }

  isFuture(date: string): boolean {
    return date > this.todayIso();
  }

  loadPosts() {
    this.loading = true;
    const offset = (this.currentPage - 1) * this.perPage;
    this.dataService.getAdminBlogPosts(offset, this.perPage).subscribe({
      next: (data) => {
        this.posts      = data.blog_posts;
        this.total      = data.total ?? data.count ?? 0;
        this.totalPages = Math.max(1, Math.ceil(this.total / this.perPage));
        if (this.currentPage > this.totalPages) {
          this.currentPage = this.totalPages;
        }
        this.loading = false;
      },
      error: () => {
        this.errorMessage = 'Failed to load blog posts.';
        this.loading = false;
      }
    });
  }

  goToPage(page: number) {
    if (page < 1 || page > this.totalPages || page === this.currentPage) return;
    this.currentPage = page;
    this.loadPosts();
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
    this.newTitle = '';
    this.newAuthor = '';
    this.newContent = '';
    this.newDate = this.todayIso();
    this.newVisible = true;
    this.successMessage = '';
    this.errorMessage = '';
  }

  createPost() {
    if (!this.newTitle.trim() || !this.newAuthor.trim() || !this.newContent.trim()) {
      this.errorMessage = 'Title, author, and content are required.';
      return;
    }
    this.creating = true;
    this.errorMessage = '';
    this.dataService.createBlogPost({
      title: this.newTitle.trim(),
      author: this.newAuthor.trim(),
      content: this.newContent.trim(),
      date: this.newDate,
      visible: this.newVisible
    }).subscribe({
      next: () => {
        this.creating = false;
        this.showCreateForm = false;
        this.successMessage = 'Blog post created successfully.';
        this.currentPage = 1;
        this.loadPosts();
      },
      error: () => {
        this.creating = false;
        this.errorMessage = 'Failed to create blog post.';
      }
    });
  }

  startEdit(post: any) {
    this.editingPost = post;
    this.editTitle = post.title;
    this.editContent = post.content;
    this.editDate = post.date;
    this.editVisible = post.visible;
    this.successMessage = '';
    this.errorMessage = '';
    this.showCreateForm = false;
  }

  cancelEdit() {
    this.editingPost = null;
  }

  saveEdit() {
    if (!this.editTitle.trim() || !this.editContent.trim()) {
      this.errorMessage = 'Title and content are required.';
      return;
    }
    this.saving = true;
    this.errorMessage = '';
    this.dataService.updateBlogPost(this.editingPost.id, {
      title: this.editTitle.trim(),
      content: this.editContent.trim(),
      date: this.editDate,
      visible: this.editVisible
    }).subscribe({
      next: () => {
        this.saving = false;
        this.editingPost = null;
        this.successMessage = 'Blog post updated successfully.';
        this.loadPosts();
      },
      error: () => {
        this.saving = false;
        this.errorMessage = 'Failed to update blog post.';
      }
    });
  }

  deletePost(post: any) {
    if (!confirm(`Delete "${post.title}"? This cannot be undone.`)) return;
    this.errorMessage = '';
    this.dataService.deleteBlogPost(post.id).subscribe({
      next: () => {
        this.successMessage = `"${post.title}" was deleted.`;
        if (this.editingPost?.id === post.id) this.editingPost = null;
        // If we deleted the last item on a non-first page, step back
        if (this.posts.length === 1 && this.currentPage > 1) this.currentPage--;
        this.loadPosts();
      },
      error: () => {
        this.errorMessage = 'Failed to delete blog post.';
      }
    });
  }
}

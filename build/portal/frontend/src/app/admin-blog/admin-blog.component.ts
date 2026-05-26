import { Component, OnInit } from '@angular/core';
import { SlicePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { catchError, finalize, forkJoin, of } from 'rxjs';
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
  allPosts: any[] = [];
  posts: any[] = [];
  loading = true;
  errorMessage = '';
  successMessage = '';

  blogNavEnabled  = true;

  // Tabs
  activeTab: 'all' | 'published' | 'draft' | 'scheduled' = 'all';
  allPage       = 1;
  publishedPage = 1;
  draftPage     = 1;
  scheduledPage = 1;
  readonly pageSizeOptions = [10, 25, 50, 100];
  perPage = 10;
  private _searchQuery = '';
  get searchQuery(): string { return this._searchQuery; }
  set searchQuery(val: string) {
    this._searchQuery = val;
    this.allPage = 1; this.publishedPage = 1; this.draftPage = 1; this.scheduledPage = 1;
    this.loadPagedPosts();
  }

  get publishedPosts(): any[]  { return this.allPosts.filter(p => p.visible && !this.isFuture(p.date)); }
  get draftPosts(): any[]      { return this.allPosts.filter(p => !p.visible); }
  get scheduledPosts(): any[]  { return this.allPosts.filter(p => p.visible && this.isFuture(p.date)); }
  get basePosts(): any[] {
    if (this.activeTab === 'published') return this.publishedPosts;
    if (this.activeTab === 'draft')     return this.draftPosts;
    if (this.activeTab === 'scheduled') return this.scheduledPosts;
    return this.allPosts;
  }
  get tabPosts(): any[] {
    const q = this.searchQuery.trim().toLowerCase();
    if (!q) return this.basePosts;
    return this.basePosts.filter(p =>
      p.title?.toLowerCase().includes(q) || p.author?.toLowerCase().includes(q)
    );
  }

  private filterPosts(posts: any[]): any[] {
    const q = this.searchQuery.trim().toLowerCase();
    if (!q) return posts;
    return posts.filter(p =>
      p.title?.toLowerCase().includes(q) || p.author?.toLowerCase().includes(q)
    );
  }
  get allCount(): number       { return this.filterPosts(this.allPosts).length; }
  get publishedCount(): number { return this.filterPosts(this.publishedPosts).length; }
  get draftCount(): number     { return this.filterPosts(this.draftPosts).length; }
  get scheduledCount(): number { return this.filterPosts(this.scheduledPosts).length; }
  get currentPage(): number {
    if (this.activeTab === 'published') return this.publishedPage;
    if (this.activeTab === 'draft')     return this.draftPage;
    if (this.activeTab === 'scheduled') return this.scheduledPage;
    return this.allPage;
  }
  get totalPages(): number { return Math.max(1, Math.ceil(this.tabPosts.length / this.perPage)); }
  get pagedPosts(): any[] { return this.posts; }
  // Create form state
  showCreateForm = false;
  creating = false;
  managingTaxonomy = false;
  showTaxonomySection = false;
  newTitle = '';
  newAuthor = '';
  newContent = '';
  newDate = this.todayIso();
  newVisible = true;
  newTags: string[] = [];
  newTagInput = '';
  newCategory = 'Uncategorized';
  newCategoryCustom = '';

  // Edit form state
  editingPost: any = null;
  editTitle = '';
  editContent = '';
  editDate = '';
  editVisible = true;
  editTags: string[] = [];
  editTagInput = '';
  editCategory = '';
  editCategoryCustom = '';
  saving = false;

  constructor(private dataService: DataService) {}

  get tagCatalog(): Array<{ name: string; count: number }> {
    const counts = new Map<string, { name: string; count: number }>();
    for (const post of this.allPosts) {
      for (const rawTag of this.getPostTags(post)) {
        const tag = rawTag.trim();
        if (!tag) continue;
        const key = tag.toLowerCase();
        const existing = counts.get(key);
        if (existing) {
          existing.count += 1;
          continue;
        }
        counts.set(key, { name: tag, count: 1 });
      }
    }
    return Array.from(counts.values()).sort((a, b) => a.name.localeCompare(b.name));
  }

  toggleNewTag(tag: string): void {
    const idx = this.newTags.findIndex(t => t.toLowerCase() === tag.toLowerCase());
    if (idx >= 0) this.newTags.splice(idx, 1);
    else this.newTags = this.deduplicateTags([...this.newTags, tag]);
  }

  addNewTag(): void {
    const tag = this.newTagInput.trim();
    if (!tag) return;
    this.newTags = this.deduplicateTags([...this.newTags, tag]);
    this.newTagInput = '';
  }

  toggleEditTag(tag: string): void {
    const idx = this.editTags.findIndex(t => t.toLowerCase() === tag.toLowerCase());
    if (idx >= 0) this.editTags.splice(idx, 1);
    else this.editTags = this.deduplicateTags([...this.editTags, tag]);
  }

  addEditTag(): void {
    const tag = this.editTagInput.trim();
    if (!tag) return;
    this.editTags = this.deduplicateTags([...this.editTags, tag]);
    this.editTagInput = '';
  }

  isNewTagSelected(tag: string): boolean {
    return this.newTags.some(t => t.toLowerCase() === tag.toLowerCase());
  }

  isEditTagSelected(tag: string): boolean {
    return this.editTags.some(t => t.toLowerCase() === tag.toLowerCase());
  }

  /** Returns the category to actually submit for the create form. */
  get resolvedNewCategory(): string {
    if (this.newCategory === '__new__') {
      return this.newCategoryCustom.trim() || 'Uncategorized';
    }
    return this.newCategory || 'Uncategorized';
  }

  /** Returns the category to actually submit for the edit form. */
  get resolvedEditCategory(): string {
    if (this.editCategory === '__new__') {
      return this.editCategoryCustom.trim() || 'Uncategorized';
    }
    return this.editCategory || 'Uncategorized';
  }

  get categoryCatalog(): Array<{ name: string; count: number }> {
    const counts = new Map<string, { name: string; count: number }>();
    // Seed Uncategorized at 0 so it always appears
    counts.set('uncategorized', { name: 'Uncategorized', count: 0 });
    for (const post of this.allPosts) {
      const category = (post.category ?? '').trim() || 'Uncategorized';
      const key = category.toLowerCase();
      const existing = counts.get(key);
      if (existing) {
        existing.count += 1;
        continue;
      }
      counts.set(key, { name: category, count: 1 });
    }
    return Array.from(counts.values()).sort((a, b) => a.name.localeCompare(b.name));
  }

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
    this.errorMessage = '';

    this.loadAllPostsSnapshot(0, []);
  }

  private loadAllPostsSnapshot(offset: number, accumulatedPosts: any[]): void {
    this.dataService.getAdminBlogPosts(offset, 100).subscribe({
      next: (data) => {
        const fetchedPosts = Array.isArray(data.blog_posts) ? data.blog_posts : [];
        const mergedPosts = [...accumulatedPosts, ...fetchedPosts];
        const reportedTotal = Number(data.total ?? mergedPosts.length);
        const isComplete = fetchedPosts.length < 100 || mergedPosts.length >= reportedTotal;

        if (isComplete) {
          this.allPosts = mergedPosts;
          this.loadPagedPosts();
          return;
        }

        this.loadAllPostsSnapshot(offset + 100, mergedPosts);
      },
      error: () => {
        this.errorMessage = 'Failed to load blog posts.';
        this.loading = false;
      }
    });
  }

  loadPagedPosts() {
    const offset = (this.currentPage - 1) * this.perPage;
    this.loading = true;
    this.errorMessage = '';

    this.dataService.getAdminBlogPosts(offset, this.perPage, {
      q: this.searchQuery,
      status: this.activeTab,
    }).subscribe({
      next: (data) => {
        this.posts = Array.isArray(data.blog_posts) ? data.blog_posts : [];

        const hasLegacyLocalPagingFallback =
          (data.all_total === undefined || data.published_total === undefined || data.draft_total === undefined || data.scheduled_total === undefined) &&
          Number(data.offset ?? 0) === offset &&
          this.allPosts.length > 0 &&
          this.allPosts.length === Number(data.total ?? this.allPosts.length);

        if (hasLegacyLocalPagingFallback) {
          this.posts = this.tabPosts.slice(offset, offset + this.perPage);
        }

        this.loading = false;
      },
      error: () => {
        this.posts = [];
        this.errorMessage = 'Failed to load blog posts.';
        this.loading = false;
      }
    });
  }

  renameTag(currentTag: string) {
    const nextTag = prompt(`Rename tag "${currentTag}" to:`, currentTag)?.trim() ?? '';
    if (!nextTag || nextTag === currentTag) return;
    const affectedPosts = this.allPosts.filter(post => this.getPostTags(post).some(t => t.toLowerCase() === currentTag.toLowerCase()));
    if (affectedPosts.length === 0) return;

    this.applyBulkPostUpdates(
      affectedPosts,
      (post) => {
        const tags = this.getPostTags(post).map(tag =>
          tag.toLowerCase() === currentTag.toLowerCase() ? nextTag : tag
        );
        return { tags: this.deduplicateTags(tags) };
      },
      `Tag "${currentTag}" renamed to "${nextTag}".`,
      'Failed to rename tag.'
    );
  }

  deleteTag(tagToDelete: string) {
    if (!confirm(`Delete tag "${tagToDelete}" from all posts?`)) return;
    const affectedPosts = this.allPosts.filter(post => this.getPostTags(post).some(t => t.toLowerCase() === tagToDelete.toLowerCase()));
    if (affectedPosts.length === 0) return;

    this.applyBulkPostUpdates(
      affectedPosts,
      (post) => ({
        tags: this.getPostTags(post).filter(tag => tag.toLowerCase() !== tagToDelete.toLowerCase())
      }),
      `Tag "${tagToDelete}" removed from ${affectedPosts.length} post${affectedPosts.length === 1 ? '' : 's'}.`,
      'Failed to delete tag.'
    );
  }

  renameCategory(currentCategory: string) {
    if (currentCategory.toLowerCase() === 'uncategorized') return;
    const nextCategory = prompt(`Rename category "${currentCategory}" to:`, currentCategory)?.trim() ?? '';
    if (!nextCategory || nextCategory === currentCategory) return;
    const affectedPosts = this.allPosts.filter(post => (post.category ?? '').trim().toLowerCase() === currentCategory.toLowerCase());
    if (affectedPosts.length === 0) return;

    this.applyBulkPostUpdates(
      affectedPosts,
      () => ({ category: nextCategory }),
      `Category "${currentCategory}" renamed to "${nextCategory}".`,
      'Failed to rename category.'
    );
  }

  deleteCategory(categoryToDelete: string) {
    if (categoryToDelete.toLowerCase() === 'uncategorized') return;
    if (!confirm(`Remove category "${categoryToDelete}" from all posts? They will be moved to Uncategorized.`)) return;
    const affectedPosts = this.allPosts.filter(post => (post.category ?? '').trim().toLowerCase() === categoryToDelete.toLowerCase());
    if (affectedPosts.length === 0) return;

    this.applyBulkPostUpdates(
      affectedPosts,
      () => ({ category: 'Uncategorized' }),
      `Category "${categoryToDelete}" removed from ${affectedPosts.length} post${affectedPosts.length === 1 ? '' : 's'}. Posts moved to Uncategorized.`,
      'Failed to delete category.'
    );
  }

  switchTab(tab: 'all' | 'published' | 'draft' | 'scheduled') {
    this.activeTab = tab;
    this.allPage = 1; this.publishedPage = 1; this.draftPage = 1; this.scheduledPage = 1;
    this.loadPagedPosts();
  }

  goToPage(page: number) {
    if (page < 1 || page > this.totalPages || page === this.currentPage) return;
    if (this.activeTab === 'published') this.publishedPage = page;
    else if (this.activeTab === 'draft') this.draftPage = page;
    else if (this.activeTab === 'scheduled') this.scheduledPage = page;
    else this.allPage = page;
    this.loadPagedPosts();
  }

  updatePerPage(perPage: number) {
    this.perPage = perPage;
    this.allPage = 1;
    this.publishedPage = 1;
    this.draftPage = 1;
    this.scheduledPage = 1;
    this.loadPagedPosts();
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
    this.newTags = [];
    this.newTagInput = '';
    this.newCategory = 'Uncategorized';
    this.newCategoryCustom = '';
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
      visible: this.newVisible,
      tags: this.deduplicateTags(this.newTags),
      category: this.resolvedNewCategory
    }).subscribe({
      next: () => {
        this.creating = false;
        this.showCreateForm = false;
        this.successMessage = 'Blog post created successfully.';
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
    this.editTags = Array.isArray(post.tags) ? [...post.tags] : [];
    this.editTagInput = '';
    this.editCategory = post.category ?? '';
    this.editCategoryCustom = '';
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
      visible: this.editVisible,
      tags: this.deduplicateTags(this.editTags),
      category: this.resolvedEditCategory
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
        this.loadPosts();
      },
      error: () => {
        this.errorMessage = 'Failed to delete blog post.';
      }
    });
  }

  private getPostTags(post: any): string[] {
    if (!Array.isArray(post?.tags)) return [];
    return post.tags
      .map((tag: string) => (tag ?? '').trim())
      .filter((tag: string) => !!tag);
  }

  private deduplicateTags(tags: string[]): string[] {
    const seen = new Set<string>();
    const result: string[] = [];
    for (const rawTag of tags) {
      const tag = rawTag.trim();
      if (!tag) continue;
      const key = tag.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      result.push(tag);
    }
    return result;
  }

  private applyBulkPostUpdates(
    posts: any[],
    mapper: (post: any) => { tags?: string[]; category?: string },
    successMessage: string,
    failureMessage: string
  ) {
    if (this.managingTaxonomy || posts.length === 0) return;

    this.managingTaxonomy = true;
    this.errorMessage = '';

    const updates = posts.map(post => {
      const mapped = mapper(post);
      return this.dataService.updateBlogPost(post.id, {
        title: post.title,
        content: post.content,
        date: post.date,
        visible: post.visible,
        tags: mapped.tags ?? this.getPostTags(post),
        category: mapped.category ?? (post.category ?? '').trim(),
      });
    });

    forkJoin(updates)
      .pipe(finalize(() => { this.managingTaxonomy = false; }))
      .subscribe({
        next: () => {
          this.successMessage = successMessage;
          this.loadPosts();
        },
        error: () => {
          this.errorMessage = failureMessage;
        }
      });
  }
}

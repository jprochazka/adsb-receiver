import { Component, OnInit } from '@angular/core';

import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

@Component({
  selector: 'app-blog',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, SpinnerComponent],
  templateUrl: './blog.component.html',
  styleUrl: './blog.component.scss'
})
export class BlogComponent implements OnInit {
  posts: any[] = [];
  selectedPost: any = null;
  detailNotFound = false;
  loading = true;
  currentPage = 1;
  totalPages = 1;
  total = 0;
  readonly perPage = 10;

  tagCloud: Array<{ name: string; count: number; weight: number }> = [];
  categoryList: Array<{ name: string; count: number }> = [];
  selectedCategory = '';
  selectedTag = '';
  metaLoading = false;
  metaError = '';

  comments: any[] = [];
  commentsLoading = false;
  commentsError = '';
  commentContent = '';
  commentSubmitting = false;
  commentSubmitError = '';
  commentSubmitSuccess = '';

  replyDrafts: Record<number, string> = {};
  replyFormOpen: Record<number, boolean> = {};
  replySubmitting: Record<number, boolean> = {};
  replyErrors: Record<number, string> = {};

  editFormOpen: Record<number, boolean> = {};
  editDrafts: Record<number, string> = {};
  editSubmitting: Record<number, boolean> = {};
  editErrors: Record<number, string> = {};

  isAuthenticated = false;
  currentUserId: number | null = null;
  currentUserRole: string | null = null;

  constructor(private dataService: DataService, private route: ActivatedRoute, private router: Router) {}

  get loginQueryParams(): { returnUrl: string } {
    return { returnUrl: this.router.url };
  }

  ngOnInit() {
    this.isAuthenticated = this.hasValidToken();
    this.currentUserId = this.getCurrentUserId();
    this.currentUserRole = this.getCurrentUserRole();

    this.route.params.subscribe(params => {
      const id = params['id'];
      if (id) {
        this.loadPost(id);
        return;
      }
      this.currentPage = Math.max(1, parseInt(params['page'] ?? '1', 10) || 1);
      this.loadPage();
    });
  }

  loadPage() {
    this.loading = true;
    this.selectedPost = null;
    this.detailNotFound = false;
    this.comments = [];
    this.commentContent = '';
    this.commentSubmitError = '';
    this.commentSubmitSuccess = '';
    this.loadMeta();
    const offset = (this.currentPage - 1) * this.perPage;
    this.dataService.getBlogPosts(offset, this.perPage, this.selectedCategory, this.selectedTag).subscribe({
      next: (response) => {
        this.posts    = response.blog_posts ?? [];
        this.total    = response.total ?? 0;
        this.totalPages = Math.max(1, Math.ceil(this.total / this.perPage));
        this.loading  = false;
      },
      error: () => { this.loading = false; }
    });
  }

  selectCategory(name: string): void {
    this.selectedCategory = this.selectedCategory === name ? '' : name;
    this.currentPage = 1;
    this.loadPage();
  }

  selectTag(name: string): void {
    this.selectedTag = this.selectedTag === name ? '' : name;
    this.currentPage = 1;
    this.loadPage();
  }

  private loadMeta(): void {
    this.metaLoading = true;
    this.metaError = '';
    this.dataService.getBlogPostsMeta().subscribe({
      next: (response) => {
        const tags = Array.isArray(response?.tags) ? response.tags : [];
        const categories = Array.isArray(response?.categories) ? response.categories : [];
        const maxTagCount = Math.max(1, ...tags.map((tag: any) => Number(tag.count) || 0));
        const logMax = Math.log(maxTagCount + 1);

        this.tagCloud = tags.map((tag: any) => {
          const count = Number(tag.count) || 0;
          return {
            name: tag.name,
            count,
            weight: logMax > 0 ? Math.log(count + 1) / logMax : 0,
          };
        }).sort((a: { name: string }, b: { name: string }) => a.name.localeCompare(b.name));
        this.categoryList = categories.map((category: any) => ({
          name: category.name,
          count: Number(category.count) || 0,
        }));
        this.metaLoading = false;
      },
      error: () => {
        this.metaLoading = false;
        this.metaError = 'Failed to load blog metadata.';
      }
    });
  }

  loadPost(id: string): void {
    this.loading = true;
    this.posts = [];
    this.total = 0;
    this.totalPages = 1;
    this.selectedPost = null;
    this.detailNotFound = false;

    this.dataService.getBlogPost(id).subscribe({
      next: (response) => {
        this.selectedPost = response;
        this.loading = false;
        this.loadComments(response.id);
      },
      error: () => {
        this.detailNotFound = true;
        this.loading = false;
      }
    });
  }

  submitComment(): void {
    this.commentSubmitError = '';
    this.commentSubmitSuccess = '';

    const content = this.commentContent.trim();
    if (!content) {
      this.commentSubmitError = 'Comment cannot be empty.';
      return;
    }

    if (!this.selectedPost?.id) {
      this.commentSubmitError = 'Unable to post comment right now.';
      return;
    }

    this.commentSubmitting = true;
    this.dataService.createBlogComment(this.selectedPost.id, { content }).subscribe({
      next: () => {
        this.commentSubmitting = false;
        this.commentContent = '';
        this.commentSubmitSuccess = 'Comment posted.';
        this.loadComments(this.selectedPost.id);
      },
      error: (err) => {
        this.commentSubmitting = false;
        this.commentSubmitError = err?.error?.msg ?? 'Failed to post comment.';
      }
    });
  }

  toggleReplyForm(commentId: number): void {
    this.replyFormOpen[commentId] = !this.replyFormOpen[commentId];
    if (!this.replyFormOpen[commentId]) {
      this.replyErrors[commentId] = '';
      this.replyDrafts[commentId] = '';
    }
  }

  submitReply(parentComment: any): void {
    const commentId = parentComment.id as number;
    const content = (this.replyDrafts[commentId] || '').trim();

    this.replyErrors[commentId] = '';

    if (!content) {
      this.replyErrors[commentId] = 'Reply cannot be empty.';
      return;
    }

    if (!this.selectedPost?.id) {
      this.replyErrors[commentId] = 'Unable to post reply right now.';
      return;
    }

    this.replySubmitting[commentId] = true;
    this.dataService.createBlogComment(this.selectedPost.id, {
      content,
      parent_comment_id: commentId,
    }).subscribe({
      next: () => {
        this.replySubmitting[commentId] = false;
        this.replyDrafts[commentId] = '';
        this.replyErrors[commentId] = '';
        this.replyFormOpen[commentId] = false;
        this.loadComments(this.selectedPost.id);
      },
      error: (err) => {
        this.replySubmitting[commentId] = false;
        this.replyErrors[commentId] = err?.error?.msg ?? 'Failed to post reply.';
      }
    });
  }

  trackComment(_: number, comment: any): number {
    return comment.id;
  }

  private loadComments(postId: number): void {
    this.comments = [];
    this.commentsError = '';
    this.commentsLoading = true;
    this.dataService.getBlogPostComments(postId).subscribe({
      next: (res) => {
        this.comments = res?.comments ?? [];
        this.commentsLoading = false;
      },
      error: (err) => {
        this.commentsLoading = false;
        this.commentsError = err?.error?.msg ?? 'Failed to load comments.';
      }
    });
  }

  toggleEditForm(comment: any): void {
    const id = comment.id as number;
    const opening = !this.editFormOpen[id];
    this.editFormOpen[id] = opening;
    if (opening) {
      this.editDrafts[id] = comment.content;
      this.editErrors[id] = '';
    } else {
      this.editDrafts[id] = '';
      this.editErrors[id] = '';
    }
  }

  submitEdit(comment: any): void {
    const id = comment.id as number;
    const content = (this.editDrafts[id] ?? '').trim();
    this.editErrors[id] = '';

    if (!content) {
      this.editErrors[id] = 'Comment cannot be empty.';
      return;
    }

    if (!this.selectedPost?.id) {
      this.editErrors[id] = 'Unable to save edit right now.';
      return;
    }

    this.editSubmitting[id] = true;
    this.dataService.updateBlogComment(this.selectedPost.id, id, { content }).subscribe({
      next: () => {
        this.editSubmitting[id] = false;
        this.editFormOpen[id] = false;
        this.editDrafts[id] = '';
        this.loadComments(this.selectedPost.id);
      },
      error: (err) => {
        this.editSubmitting[id] = false;
        this.editErrors[id] = err?.error?.msg ?? 'Failed to save edit.';
      }
    });
  }

  canDelete(comment: any): boolean {
    if (!this.currentUserId || comment.deleted) return false;
    return comment.user_id === this.currentUserId || this.currentUserRole === 'Admin';
  }

  deleteComment(comment: any): void {
    if (!confirm('Are you sure you want to delete this comment?')) return;
    if (!this.selectedPost?.id) return;

    this.dataService.deleteBlogComment(this.selectedPost.id, comment.id).subscribe({
      next: () => this.loadComments(this.selectedPost.id),
      error: (err) => {
        alert(err?.error?.msg ?? 'Failed to delete comment.');
      }
    });
  }

  private hasValidToken(): boolean {
    const token = localStorage.getItem('access_token');
    if (!token) return false;

    try {
      const base64 = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
      const payload = JSON.parse(atob(base64));
      return !!payload && payload.exp * 1000 > Date.now();
    } catch {
      return false;
    }
  }

  private getCurrentUserId(): number | null {
    const token = localStorage.getItem('access_token');
    if (!token) return null;

    try {
      const base64 = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
      const payload = JSON.parse(atob(base64));
      const id = payload?.user_id;
      return typeof id === 'number' ? id : null;
    } catch {
      return null;
    }
  }

  private getCurrentUserRole(): string | null {
    const token = localStorage.getItem('access_token');
    if (!token) return null;

    try {
      const base64 = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
      const payload = JSON.parse(atob(base64));
      return payload?.role ?? null;
    } catch {
      return null;
    }
  }

  get pageNumbers(): number[] {
    const range: number[] = [];
    const start = Math.max(1, this.currentPage - 2);
    const end   = Math.min(this.totalPages, this.currentPage + 2);
    for (let i = start; i <= end; i++) range.push(i);
    return range;
  }

  truncate(text: string, limit: number): string {
    if (text.length <= limit) return text;
    const cut = text.lastIndexOf(' ', limit);
    return text.slice(0, cut > 0 ? cut : limit) + '...';
  }
}


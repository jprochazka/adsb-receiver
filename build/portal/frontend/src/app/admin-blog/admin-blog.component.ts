import { Component, OnInit } from '@angular/core';
import { NgFor, NgIf } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { DataService } from '../service/data.service';
import { SpinnerComponent } from '../shared/spinner/spinner.component';

@Component({
  selector: 'app-admin-blog',
  standalone: true,
  imports: [NgFor, NgIf, FormsModule, SpinnerComponent],
  templateUrl: './admin-blog.component.html',
  styleUrl: './admin-blog.component.scss'
})
export class AdminBlogComponent implements OnInit {
  posts: any[] = [];
  loading = true;
  errorMessage = '';
  successMessage = '';

  // Create form state
  showCreateForm = false;
  creating = false;
  newTitle = '';
  newAuthor = '';
  newContent = '';

  // Edit form state
  editingPost: any = null;
  editTitle = '';
  editContent = '';
  saving = false;

  constructor(private dataService: DataService) {}

  ngOnInit() {
    this.loadPosts();
  }

  loadPosts() {
    this.loading = true;
    this.dataService.getBlogPosts().subscribe({
      next: (data) => {
        this.posts = data.blog_posts;
        this.loading = false;
      },
      error: () => {
        this.errorMessage = 'Failed to load blog posts.';
        this.loading = false;
      }
    });
  }

  toggleCreateForm() {
    this.showCreateForm = !this.showCreateForm;
    this.newTitle = '';
    this.newAuthor = '';
    this.newContent = '';
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
      content: this.newContent.trim()
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
      content: this.editContent.trim()
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
}

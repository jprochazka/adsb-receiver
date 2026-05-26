import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';

import { AdminBlogComponent } from './admin-blog.component';
import { DataService } from '../service/data.service';

describe('AdminBlogComponent', () => {
  let component: AdminBlogComponent;
  let fixture: ComponentFixture<AdminBlogComponent>;

  const dataServiceMock = {
    getSetting: jasmine.createSpy('getSetting').and.returnValue(of({ value: 'true' })),
    updateSetting: jasmine.createSpy('updateSetting').and.returnValue(of({})),
    getAdminBlogPosts: jasmine.createSpy('getAdminBlogPosts').and.returnValue(of({ blog_posts: [] })),
    createBlogPost: jasmine.createSpy('createBlogPost').and.returnValue(of({})),
    updateBlogPost: jasmine.createSpy('updateBlogPost').and.returnValue(of({})),
    deleteBlogPost: jasmine.createSpy('deleteBlogPost').and.returnValue(of({})),
  };

  beforeEach(async () => {
    Object.values(dataServiceMock).forEach((spy) => spy.calls.reset());
    dataServiceMock.getSetting.and.returnValue(of({ value: 'true' }));
    dataServiceMock.updateSetting.and.returnValue(of({}));
    dataServiceMock.createBlogPost.and.returnValue(of({}));
    dataServiceMock.updateBlogPost.and.returnValue(of({}));
    dataServiceMock.deleteBlogPost.and.returnValue(of({}));
    dataServiceMock.getAdminBlogPosts.and.returnValues(
      of({
        blog_posts: [
          { id: 1, title: 'Post 1', author: 'Admin', content: 'Content', date: '2001-01-01T10:00', visible: true },
        ],
      }),
      of({
        blog_posts: [
          { id: 1, title: 'Post 1', author: 'Admin', content: 'Content', date: '2001-01-01T10:00', visible: true },
        ],
      })
    );

    await TestBed.configureTestingModule({
      imports: [AdminBlogComponent],
      providers: [{ provide: DataService, useValue: dataServiceMock }],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminBlogComponent);
    component = fixture.componentInstance;
  });

  it('should create', () => {
    fixture.detectChanges();
    expect(component).toBeTruthy();
  });

  it('should load nav setting and posts on init', () => {
    fixture.detectChanges();

    expect(dataServiceMock.getSetting).toHaveBeenCalledWith('blog_nav_enabled');
    expect(dataServiceMock.getAdminBlogPosts).toHaveBeenCalledWith(0, 100);
    expect(dataServiceMock.getAdminBlogPosts).toHaveBeenCalledWith(0, 10, { q: '', status: 'all' });
    expect(component.allPosts.length).toBe(1);
    expect(component.posts.length).toBe(1);
    expect(component.loading).toBeFalse();
  });

  it('should validate required fields when creating post', () => {
    fixture.detectChanges();
    component.newTitle = ' ';
    component.newAuthor = ' ';
    component.newContent = '';

    component.createPost();

    expect(component.errorMessage).toBe('Title, author, and content are required.');
    expect(dataServiceMock.createBlogPost).not.toHaveBeenCalled();
  });

  it('should create post successfully', () => {
    fixture.detectChanges();
    component.newTitle = ' New Post ';
    component.newAuthor = ' Author ';
    component.newContent = ' Body ';

    component.createPost();

    expect(dataServiceMock.createBlogPost).toHaveBeenCalledWith(jasmine.objectContaining({
      title: 'New Post',
      author: 'Author',
      content: 'Body',
    }));
    expect(component.creating).toBeFalse();
    expect(component.successMessage).toBe('Blog post created successfully.');
  });

  it('should set load error when posts request fails', () => {
    dataServiceMock.getAdminBlogPosts.and.returnValue(throwError(() => new Error('failed')));

    fixture.detectChanges();

    expect(component.loading).toBeFalse();
    expect(component.errorMessage).toBe('Failed to load blog posts.');
  });

  it('should set error when creating post fails', () => {
    fixture.detectChanges();
    dataServiceMock.createBlogPost.and.returnValue(throwError(() => new Error('fail')));
    component.newTitle = 'New Post';
    component.newAuthor = 'Author';
    component.newContent = 'Body';

    component.createPost();

    expect(component.creating).toBeFalse();
    expect(component.errorMessage).toBe('Failed to create blog post.');
  });

  it('startEdit should populate edit fields from the post', () => {
    fixture.detectChanges();
    const post = { id: 1, title: 'Post 1', content: 'Body', date: '2001-01-01T10:00', visible: true, tags: ['news', 'update'], category: 'Updates' };

    component.startEdit(post);

    expect(component.editingPost).toBe(post);
    expect(component.editTitle).toBe('Post 1');
    expect(component.editContent).toBe('Body');
    expect(component.editDate).toBe('2001-01-01T10:00');
    expect(component.editVisible).toBeTrue();
    expect(component.editTags).toEqual(['news', 'update']);
    expect(component.editCategory).toBe('Updates');
  });

  it('cancelEdit should clear editingPost', () => {
    fixture.detectChanges();
    component.editingPost = { id: 1 };

    component.cancelEdit();

    expect(component.editingPost).toBeNull();
  });

  it('saveEdit should set error when title or content is empty', () => {
    fixture.detectChanges();
    component.editingPost = { id: 1 };
    component.editTitle = '';
    component.editContent = '';

    component.saveEdit();

    expect(component.errorMessage).toBe('Title and content are required.');
    expect(dataServiceMock.updateBlogPost).not.toHaveBeenCalled();
  });

  it('saveEdit should call updateBlogPost and show success message', () => {
    fixture.detectChanges();
    component.editingPost = { id: 1, title: 'Old', content: 'Old body', date: '2001-01-01T10:00', visible: true, tags: [], category: 'News' };
    component.editTitle = ' Updated Title ';
    component.editContent = ' Updated Body ';
    component.editDate = '2002-02-02T10:00';
    component.editVisible = false;

    component.saveEdit();

    expect(dataServiceMock.updateBlogPost).toHaveBeenCalledWith(1, jasmine.objectContaining({
      title: 'Updated Title',
      content: 'Updated Body',
    }));
    expect(component.saving).toBeFalse();
    expect(component.editingPost).toBeNull();
    expect(component.successMessage).toBe('Blog post updated successfully.');
  });

  it('saveEdit should set error on failure', () => {
    fixture.detectChanges();
    dataServiceMock.updateBlogPost.and.returnValue(throwError(() => new Error('fail')));
    component.editingPost = { id: 1, title: 'T', content: 'C', date: '2001-01-01T10:00', visible: true, tags: [], category: '' };
    component.editTitle = 'Title';
    component.editContent = 'Content';

    component.saveEdit();

    expect(component.saving).toBeFalse();
    expect(component.errorMessage).toBe('Failed to update blog post.');
  });

  it('deletePost should call deleteBlogPost and show success after confirm', () => {
    fixture.detectChanges();
    spyOn(window, 'confirm').and.returnValue(true);
    const post = { id: 1, title: 'Post 1' };

    component.deletePost(post);

    expect(dataServiceMock.deleteBlogPost).toHaveBeenCalledWith(1);
    expect(component.successMessage).toBe('"Post 1" was deleted.');
  });

  it('deletePost should not call deleteBlogPost when confirm is cancelled', () => {
    fixture.detectChanges();
    spyOn(window, 'confirm').and.returnValue(false);

    component.deletePost({ id: 1, title: 'Post 1' });

    expect(dataServiceMock.deleteBlogPost).not.toHaveBeenCalled();
  });

  it('deletePost should set error message on failure', () => {
    fixture.detectChanges();
    spyOn(window, 'confirm').and.returnValue(true);
    dataServiceMock.deleteBlogPost.and.returnValue(throwError(() => new Error('fail')));

    component.deletePost({ id: 1, title: 'Post 1' });

    expect(component.errorMessage).toBe('Failed to delete blog post.');
  });

  it('switchTab should change activeTab and reset pagination', () => {
    fixture.detectChanges();
    component.allPage = 3;
    dataServiceMock.getAdminBlogPosts.calls.reset();

    component.switchTab('published');

    expect(component.activeTab).toBe('published');
    expect(component.allPage).toBe(1);
    expect(dataServiceMock.getAdminBlogPosts).toHaveBeenCalledWith(0, 10, { q: '', status: 'published' });
  });

  it('searchQuery setter should reload paged posts with the query', () => {
    fixture.detectChanges();
    dataServiceMock.getAdminBlogPosts.calls.reset();

    component.searchQuery = 'Post 1';

    expect(dataServiceMock.getAdminBlogPosts).toHaveBeenCalledWith(0, 10, { q: 'Post 1', status: 'all' });
  });

  it('should reload paged posts when page size changes', () => {
    fixture.detectChanges();
    dataServiceMock.getAdminBlogPosts.calls.reset();
    component.allPage = 4;

    component.updatePerPage(25);

    expect(component.perPage).toBe(25);
    expect(component.currentPage).toBe(1);
    expect(dataServiceMock.getAdminBlogPosts).toHaveBeenCalledWith(0, 25, { q: '', status: 'all' });
  });

  it('should locally preserve the selected tab when legacy paged responses ignore status filtering', () => {
    dataServiceMock.getAdminBlogPosts.and.returnValues(
      of({
        blog_posts: [
          { id: 3, title: 'Published 1', author: 'Admin', content: 'Content', date: '2001-01-03T10:00', visible: true },
          { id: 2, title: 'Draft 1', author: 'Admin', content: 'Content', date: '2001-01-02T10:00', visible: false },
          { id: 1, title: 'Published 2', author: 'Admin', content: 'Content', date: '2001-01-01T10:00', visible: true },
        ],
        total: 3,
        offset: 0,
        limit: 10,
      }),
      of({
        blog_posts: [
          { id: 3, title: 'Published 1', author: 'Admin', content: 'Content', date: '2001-01-03T10:00', visible: true },
          { id: 2, title: 'Draft 1', author: 'Admin', content: 'Content', date: '2001-01-02T10:00', visible: false },
          { id: 1, title: 'Published 2', author: 'Admin', content: 'Content', date: '2001-01-01T10:00', visible: true },
        ],
        total: 3,
        offset: 0,
        limit: 10,
      })
    );

    fixture.detectChanges();

    component.switchTab('draft');

    expect(component.posts.length).toBe(1);
    expect(component.posts[0].visible).toBeFalse();
  });

  it('addNewTag should add a trimmed tag and clear the input', () => {
    fixture.detectChanges();
    component.newTagInput = ' hello ';

    component.addNewTag();

    expect(component.newTags).toContain('hello');
    expect(component.newTagInput).toBe('');
  });

  it('toggleNewTag should remove an already-selected tag', () => {
    fixture.detectChanges();
    component.newTags = ['news', 'update'];

    component.toggleNewTag('news');

    expect(component.newTags).not.toContain('news');
    expect(component.newTags).toContain('update');
  });

  it('toggleNewTag should add a tag that is not yet selected', () => {
    fixture.detectChanges();
    component.newTags = [];

    component.toggleNewTag('feature');

    expect(component.newTags).toContain('feature');
  });

  it('resolvedNewCategory should use custom input when __new__ is selected', () => {
    fixture.detectChanges();
    component.newCategory = '__new__';
    component.newCategoryCustom = ' My Category ';

    expect(component.resolvedNewCategory).toBe('My Category');
  });

  it('resolvedNewCategory should fall back to Uncategorized when custom input is blank', () => {
    fixture.detectChanges();
    component.newCategory = '__new__';
    component.newCategoryCustom = '  ';

    expect(component.resolvedNewCategory).toBe('Uncategorized');
  });

  it('goToPage should advance the current page', () => {
    fixture.detectChanges();
    component.allPosts = Array.from({ length: 25 }, (_, i) => ({
      id: i + 1, title: `Post ${i + 1}`, author: 'Admin', content: 'Content',
      date: '2001-01-01T10:00', visible: true, tags: [], category: 'News',
    }));

    component.goToPage(2);

    expect(component.currentPage).toBe(2);
  });

  it('pageNumbers should return a range centred on the current page', () => {
    fixture.detectChanges();
    component.allPosts = Array.from({ length: 100 }, (_, i) => ({
      id: i + 1, title: `Post ${i + 1}`, author: 'Admin', content: 'Content',
      date: '2001-01-01T10:00', visible: true, tags: [], category: 'News',
    }));
    component.allPage = 6;

    expect(component.pageNumbers).toEqual([4, 5, 6, 7, 8]);
  });

  it('saveBlogNavEnabled should call updateSetting with the current value', () => {
    fixture.detectChanges();
    component.blogNavEnabled = false;

    component.saveBlogNavEnabled();

    expect(dataServiceMock.updateSetting).toHaveBeenCalledWith('blog_nav_enabled', 'false');
  });

  it('should default blogNavEnabled to true when getSetting fails', () => {
    dataServiceMock.getSetting.and.returnValue(throwError(() => new Error('error')));

    fixture.detectChanges();

    expect(component.blogNavEnabled).toBeTrue();
  });
});

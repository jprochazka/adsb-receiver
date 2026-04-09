import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { of, throwError } from 'rxjs';

import { BlogComponent } from './blog.component';
import { DataService } from '../service/data.service';

describe('BlogComponent', () => {
  let component: BlogComponent;
  let fixture: ComponentFixture<BlogComponent>;

  const dataServiceMock = {
    getBlogPosts: jasmine.createSpy('getBlogPosts').and.returnValue(of({
      blog_posts: [{ id: 1, title: 'Post 1', author: 'Admin', date: '2026-01-01', content: 'Body' }],
      total: 21,
    })),
    getBlogPostsMeta: jasmine.createSpy('getBlogPostsMeta').and.returnValue(of({
      tags: [{ name: 'update', count: 3 }, { name: 'guide', count: 1 }],
      categories: [{ name: 'Updates', count: 2 }, { name: 'Guides', count: 1 }],
      total_posts: 3,
    })),
    getBlogPost: jasmine.createSpy('getBlogPost').and.returnValue(of({ id: 5, title: 'Detail', author: 'Admin', date: '2026-01-02', content: 'Full' })),
    getBlogPostComments: jasmine.createSpy('getBlogPostComments').and.returnValue(of({ comments: [] })),
    createBlogComment: jasmine.createSpy('createBlogComment').and.returnValue(of({})),
    updateBlogComment: jasmine.createSpy('updateBlogComment').and.returnValue(of({})),
    deleteBlogComment: jasmine.createSpy('deleteBlogComment').and.returnValue(of({})),
  };

  beforeEach(async () => {
    dataServiceMock.getBlogPosts.calls.reset();
    dataServiceMock.getBlogPosts.and.returnValue(of({
      blog_posts: [{ id: 1, title: 'Post 1', author: 'Admin', date: '2026-01-01', content: 'Body' }],
      total: 21,
    }));
    dataServiceMock.getBlogPost.calls.reset();
    dataServiceMock.getBlogPost.and.returnValue(of({ id: 5, title: 'Detail', author: 'Admin', date: '2026-01-02', content: 'Full' }));
    dataServiceMock.getBlogPostsMeta.calls.reset();
    dataServiceMock.getBlogPostsMeta.and.returnValue(of({
      tags: [{ name: 'update', count: 3 }, { name: 'guide', count: 1 }],
      categories: [{ name: 'Updates', count: 2 }, { name: 'Guides', count: 1 }],
      total_posts: 3,
    }));
    dataServiceMock.getBlogPostComments.calls.reset();
    dataServiceMock.getBlogPostComments.and.returnValue(of({ comments: [] }));
    dataServiceMock.createBlogComment.calls.reset();
    dataServiceMock.createBlogComment.and.returnValue(of({}));
    dataServiceMock.updateBlogComment.calls.reset();
    dataServiceMock.updateBlogComment.and.returnValue(of({}));
    dataServiceMock.deleteBlogComment.calls.reset();
    dataServiceMock.deleteBlogComment.and.returnValue(of({}));

    await TestBed.configureTestingModule({
      imports: [BlogComponent],
      providers: [
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: {
            params: of({ page: '2' }),
          },
        },
        { provide: DataService, useValue: dataServiceMock },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(BlogComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should load blog posts for current route page', () => {
    expect(component.currentPage).toBe(2);
    expect(dataServiceMock.getBlogPosts).toHaveBeenCalledWith(10, 10, '', '');
    expect(dataServiceMock.getBlogPostsMeta).toHaveBeenCalled();
    expect(component.posts.length).toBe(1);
    expect(component.total).toBe(21);
    expect(component.totalPages).toBe(3);
    expect(component.tagCloud.length).toBe(2);
    expect(component.categoryList.length).toBe(2);
    expect(component.loading).toBeFalse();
  });

  it('should set loading false when blog load fails', () => {
    dataServiceMock.getBlogPosts.and.returnValue(throwError(() => new Error('failed')));

    component.loadPage();

    expect(component.loading).toBeFalse();
  });

  it('should build acars-style page window with first/last pages', () => {
    component.currentPage = 4;
    component.totalPages = 8;

    expect(component.pageNumbers).toEqual([1, 2, 3, 4, 5, 6, 8]);
  });

  it('should load detail post mode when id route param is present', () => {
    component.loadPost('5');

    expect(dataServiceMock.getBlogPost).toHaveBeenCalledWith('5');
    expect(component.selectedPost).toEqual({ id: 5, title: 'Detail', author: 'Admin', date: '2026-01-02', content: 'Full' });
    expect(component.loading).toBeFalse();
  });

  it('should set detail not found when post load fails', () => {
    dataServiceMock.getBlogPost.and.returnValue(throwError(() => new Error('not found')));

    component.loadPost('404');

    expect(component.detailNotFound).toBeTrue();
    expect(component.loading).toBeFalse();
  });

  it('selectCategory should set selectedCategory and reload page', () => {
    dataServiceMock.getBlogPosts.calls.reset();
    component.selectCategory('News');
    expect(component.selectedCategory).toBe('News');
    expect(component.currentPage).toBe(1);
    expect(dataServiceMock.getBlogPosts).toHaveBeenCalledWith(0, 10, 'News', '');
  });

  it('selectCategory should clear filter when called again with same name', () => {
    component.selectedCategory = 'News';
    component.selectCategory('News');
    expect(component.selectedCategory).toBe('');
  });

  it('selectTag should set selectedTag and reload page', () => {
    dataServiceMock.getBlogPosts.calls.reset();
    component.selectTag('receiver');
    expect(component.selectedTag).toBe('receiver');
    expect(component.currentPage).toBe(1);
    expect(dataServiceMock.getBlogPosts).toHaveBeenCalledWith(0, 10, '', 'receiver');
  });

  it('selectTag should clear filter when called again with same name', () => {
    component.selectedTag = 'receiver';
    component.selectTag('receiver');
    expect(component.selectedTag).toBe('');
  });

  it('loadPage should pass both category and tag filters to getBlogPosts', () => {
    dataServiceMock.getBlogPosts.calls.reset();
    component.selectedCategory = 'Updates';
    component.selectedTag = 'portal';
    component.currentPage = 1;
    component.loadPage();
    expect(dataServiceMock.getBlogPosts).toHaveBeenCalledWith(0, 10, 'Updates', 'portal');
  });

  it('should set metaError when getBlogPostsMeta fails', () => {
    dataServiceMock.getBlogPostsMeta.and.returnValue(throwError(() => new Error('meta error')));
    component.loadPage();
    expect(component.metaError).toBe('Failed to load blog metadata.');
    expect(component.metaLoading).toBeFalse();
  });

  it('loadPost should load comments for the returned post', () => {
    const comments = [{ id: 10, content: 'Hello' }];
    dataServiceMock.getBlogPostComments.and.returnValue(of({ comments }));

    component.loadPost('5');

    expect(dataServiceMock.getBlogPostComments).toHaveBeenCalledWith(5);
    expect(component.comments).toEqual(comments);
    expect(component.commentsLoading).toBeFalse();
  });

  it('loadPost should load comments without requiring authentication (public access)', () => {
    // Simulate an unauthenticated visitor — isAuthenticated is false, no user id
    component.isAuthenticated = false;
    component.currentUserId = null;
    const comments = [
      { id: 1, user_id: 2, content: 'A comment', user: { id: 2, name: 'Alice' }, replies: [] },
    ];
    dataServiceMock.getBlogPostComments.and.returnValue(of({ comments }));

    component.loadPost('5');

    expect(dataServiceMock.getBlogPostComments).toHaveBeenCalledWith(5);
    expect(component.comments.length).toBe(1);
    // Email must not be present in comment user data
    expect(component.comments[0].user.email).toBeUndefined();
  });

  it('comments are loaded regardless of authentication state', () => {
    const comments = [{ id: 1, content: 'Hello', user: { id: 2, name: 'Alice' }, replies: [] }];
    dataServiceMock.getBlogPostComments.and.returnValue(of({ comments }));

    // Unauthenticated path
    component.isAuthenticated = false;
    component.loadPost('5');
    expect(component.comments.length).toBe(1);

    // Authenticated path
    component.isAuthenticated = true;
    dataServiceMock.getBlogPostComments.calls.reset();
    dataServiceMock.getBlogPostComments.and.returnValue(of({ comments }));
    component.loadPost('5');
    expect(component.comments.length).toBe(1);
  });

  it('should set commentsError when loading comments fails', () => {
    dataServiceMock.getBlogPostComments.and.returnValue(
      throwError(() => ({ error: { msg: 'Server error' } }))
    );

    component.loadPost('5');

    expect(component.commentsError).toBe('Server error');
    expect(component.commentsLoading).toBeFalse();
  });

  describe('submitComment', () => {
    beforeEach(() => {
      component.selectedPost = { id: 5, title: 'Detail', author: 'Admin', date: '2026-01-02', content: 'Full' };
    });

    it('should set commentSubmitError when content is empty', () => {
      component.commentContent = '   ';
      component.submitComment();
      expect(component.commentSubmitError).toBe('Comment cannot be empty.');
      expect(dataServiceMock.createBlogComment).not.toHaveBeenCalled();
    });

    it('should post comment and reload comments on success', () => {
      const comments = [{ id: 1, content: 'New comment' }];
      dataServiceMock.getBlogPostComments.and.returnValue(of({ comments }));
      component.commentContent = 'A valid comment';

      component.submitComment();

      expect(dataServiceMock.createBlogComment).toHaveBeenCalledWith(5, { content: 'A valid comment' });
      expect(component.commentContent).toBe('');
      expect(component.commentSubmitSuccess).toBe('Comment posted.');
      expect(component.comments).toEqual(comments);
      expect(component.commentSubmitting).toBeFalse();
    });

    it('should set commentSubmitError on failure', () => {
      dataServiceMock.createBlogComment.and.returnValue(
        throwError(() => ({ error: { msg: 'Not allowed' } }))
      );
      component.commentContent = 'A comment';

      component.submitComment();

      expect(component.commentSubmitError).toBe('Not allowed');
      expect(component.commentSubmitting).toBeFalse();
    });
  });

  describe('toggleReplyForm', () => {
    it('should open the reply form for a comment', () => {
      component.toggleReplyForm(1);
      expect(component.replyFormOpen[1]).toBeTrue();
    });

    it('should close the reply form and clear draft when toggled again', () => {
      component.replyFormOpen[1] = true;
      component.replyDrafts[1] = 'draft text';
      component.toggleReplyForm(1);
      expect(component.replyFormOpen[1]).toBeFalse();
      expect(component.replyDrafts[1]).toBe('');
    });
  });

  describe('submitReply', () => {
    beforeEach(() => {
      component.selectedPost = { id: 5 };
    });

    it('should set replyError when reply content is empty', () => {
      component.replyDrafts[1] = '  ';
      component.submitReply({ id: 1 });
      expect(component.replyErrors[1]).toBe('Reply cannot be empty.');
      expect(dataServiceMock.createBlogComment).not.toHaveBeenCalled();
    });

    it('should post reply with parent_comment_id and reload on success', () => {
      component.replyDrafts[1] = 'Great post!';
      component.replyFormOpen[1] = true;

      component.submitReply({ id: 1 });

      expect(dataServiceMock.createBlogComment).toHaveBeenCalledWith(5, {
        content: 'Great post!',
        parent_comment_id: 1,
      });
      expect(component.replyFormOpen[1]).toBeFalse();
      expect(component.replySubmitting[1]).toBeFalse();
    });

    it('should set replyError on failure', () => {
      dataServiceMock.createBlogComment.and.returnValue(
        throwError(() => ({ error: { msg: 'Forbidden' } }))
      );
      component.replyDrafts[1] = 'A reply';

      component.submitReply({ id: 1 });

      expect(component.replyErrors[1]).toBe('Forbidden');
      expect(component.replySubmitting[1]).toBeFalse();
    });
  });

  describe('toggleEditForm', () => {
    it('should open the edit form and populate draft from comment content', () => {
      component.toggleEditForm({ id: 2, content: 'Original text' });
      expect(component.editFormOpen[2]).toBeTrue();
      expect(component.editDrafts[2]).toBe('Original text');
    });

    it('should close the edit form and clear draft when toggled again', () => {
      component.editFormOpen[2] = true;
      component.editDrafts[2] = 'Some draft';
      component.toggleEditForm({ id: 2, content: 'Original text' });
      expect(component.editFormOpen[2]).toBeFalse();
      expect(component.editDrafts[2]).toBe('');
    });
  });

  describe('submitEdit', () => {
    beforeEach(() => {
      component.selectedPost = { id: 5 };
    });

    it('should set editError when content is empty', () => {
      component.editDrafts[3] = '   ';
      component.submitEdit({ id: 3 });
      expect(component.editErrors[3]).toBe('Comment cannot be empty.');
      expect(dataServiceMock.updateBlogComment).not.toHaveBeenCalled();
    });

    it('should call updateBlogComment and reload on success', () => {
      component.editDrafts[3] = 'Updated comment';
      component.editFormOpen[3] = true;

      component.submitEdit({ id: 3 });

      expect(dataServiceMock.updateBlogComment).toHaveBeenCalledWith(5, 3, { content: 'Updated comment' });
      expect(component.editFormOpen[3]).toBeFalse();
      expect(component.editSubmitting[3]).toBeFalse();
    });

    it('should set editError on failure', () => {
      dataServiceMock.updateBlogComment.and.returnValue(
        throwError(() => ({ error: { msg: 'Conflict' } }))
      );
      component.editDrafts[3] = 'Some edit';

      component.submitEdit({ id: 3 });

      expect(component.editErrors[3]).toBe('Conflict');
      expect(component.editSubmitting[3]).toBeFalse();
    });
  });

  describe('canDelete', () => {
    it('should return false when currentUserId is null', () => {
      component.currentUserId = null;
      expect(component.canDelete({ id: 1, user_id: 42, deleted: false })).toBeFalse();
    });

    it('should return false for a deleted comment', () => {
      component.currentUserId = 42;
      expect(component.canDelete({ id: 1, user_id: 42, deleted: true })).toBeFalse();
    });

    it('should return true when comment belongs to the current user', () => {
      component.currentUserId = 42;
      component.currentUserRole = 'User';
      expect(component.canDelete({ id: 1, user_id: 42, deleted: false })).toBeTrue();
    });

    it('should return true for admin regardless of comment owner', () => {
      component.currentUserId = 1;
      component.currentUserRole = 'Admin';
      expect(component.canDelete({ id: 1, user_id: 99, deleted: false })).toBeTrue();
    });

    it('should return false when comment belongs to a different non-admin user', () => {
      component.currentUserId = 42;
      component.currentUserRole = 'User';
      expect(component.canDelete({ id: 1, user_id: 99, deleted: false })).toBeFalse();
    });
  });

  describe('deleteComment', () => {
    beforeEach(() => {
      component.selectedPost = { id: 5 };
    });

    it('should call deleteBlogComment and reload comments after confirm', () => {
      spyOn(window, 'confirm').and.returnValue(true);

      component.deleteComment({ id: 7 });

      expect(dataServiceMock.deleteBlogComment).toHaveBeenCalledWith(5, 7);
      expect(dataServiceMock.getBlogPostComments).toHaveBeenCalledWith(5);
    });

    it('should not call deleteBlogComment when confirm is cancelled', () => {
      spyOn(window, 'confirm').and.returnValue(false);

      component.deleteComment({ id: 7 });

      expect(dataServiceMock.deleteBlogComment).not.toHaveBeenCalled();
    });
  });

  describe('truncate', () => {
    it('should return the original text when it is within the limit', () => {
      expect(component.truncate('short', 10)).toBe('short');
    });

    it('should truncate at the last word boundary before the limit', () => {
      const result = component.truncate('one two three four five', 12);
      expect(result).toBe('one two...');
    });
  });
});

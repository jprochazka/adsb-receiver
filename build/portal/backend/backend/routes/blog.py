import datetime
import logging
from collections import Counter

from flask import Blueprint, request
from flask_restx import Namespace, Resource, fields as restx_fields
from marshmallow import Schema, fields, ValidationError, validate
from sqlalchemy import select, func
from sqlalchemy.exc import OperationalError
from backend.models import db, BlogComment, BlogPost
from backend.auth import get_current_user, require_admin, require_user_or_admin
from backend.routes.common import QueryParamError, get_stripped_arg, parse_pagination

blog = Blueprint('blog', __name__)

# Create Flask-RESTX namespace for blog operations
blog_ns = Namespace('blog', description='Blog post management')

# Define API models for documentation
blog_post_model = blog_ns.model('BlogPost', {
    'id': restx_fields.Integer(description='Blog post ID'),
    'title': restx_fields.String(description='Blog post title'),
    'author': restx_fields.String(description='Blog post author'),
    'content': restx_fields.String(description='Blog post content'),
    'date': restx_fields.String(description='Publication date (YYYY-MM-DD)'),
    'visible': restx_fields.Boolean(description='Whether the post is visible on the public blog'),
    'tags': restx_fields.List(restx_fields.String, description='List of tags'),
    'category': restx_fields.String(description='Post category')
})

create_blog_post_model = blog_ns.model('CreateBlogPost', {
    'title': restx_fields.String(required=True, description='Blog post title', example='My First Post'),
    'author': restx_fields.String(required=True, description='Author name', example='John Doe'),
    'content': restx_fields.String(required=True, description='Blog post content', example='This is the content of my first blog post.'),
    'date': restx_fields.String(description='Publication date and time (YYYY-MM-DDTHH:MM). Defaults to now.', example='2026-03-26T14:30'),
    'visible': restx_fields.Boolean(description='Whether the post is visible on the public blog. Defaults to true.'),
    'tags': restx_fields.List(restx_fields.String, description='List of tags', example=['receiver', 'update']),
    'category': restx_fields.String(description='Post category', example='News')
})

update_blog_post_model = blog_ns.model('UpdateBlogPost', {
    'title': restx_fields.String(required=True, description='Updated blog post title'),
    'content': restx_fields.String(required=True, description='Updated blog post content'),
    'date': restx_fields.String(description='Publication date (YYYY-MM-DD)'),
    'visible': restx_fields.Boolean(description='Whether the post is visible on the public blog'),
    'tags': restx_fields.List(restx_fields.String, description='List of tags'),
    'category': restx_fields.String(description='Post category')
})

blog_posts_list_model = blog_ns.model('BlogPostsList', {
    'blog_posts': restx_fields.List(restx_fields.Nested(blog_post_model)),
    'offset': restx_fields.Integer(description='Pagination offset'),
    'limit': restx_fields.Integer(description='Pagination limit'),
    'count': restx_fields.Integer(description='Number of blog posts returned'),
    'total': restx_fields.Integer(description='Total number of blog posts'),
    'all_total': restx_fields.Integer(description='Total number of matching posts across all statuses'),
    'published_total': restx_fields.Integer(description='Total number of matching published posts'),
    'draft_total': restx_fields.Integer(description='Total number of matching draft posts'),
    'scheduled_total': restx_fields.Integer(description='Total number of matching scheduled posts')
})

blog_tag_count_model = blog_ns.model('BlogTagCount', {
    'name': restx_fields.String(description='Tag name'),
    'count': restx_fields.Integer(description='Number of posts using this tag')
})

blog_category_count_model = blog_ns.model('BlogCategoryCount', {
    'name': restx_fields.String(description='Category name'),
    'count': restx_fields.Integer(description='Number of posts using this category')
})

blog_posts_meta_model = blog_ns.model('BlogPostsMeta', {
    'tags': restx_fields.List(restx_fields.Nested(blog_tag_count_model)),
    'categories': restx_fields.List(restx_fields.Nested(blog_category_count_model)),
    'total_posts': restx_fields.Integer(description='Total number of visible published posts')
})

blog_comment_user_model = blog_ns.model('BlogCommentUser', {
    'id': restx_fields.Integer(description='User ID'),
    'name': restx_fields.String(description='Display name. Email addresses are intentionally excluded to protect user privacy.')
})

blog_comment_model = blog_ns.model('BlogComment', {
    'id': restx_fields.Integer(description='Comment ID'),
    'blog_post_id': restx_fields.Integer(description='Blog post ID'),
    'user_id': restx_fields.Integer(description='Author user ID'),
    'parent_comment_id': restx_fields.Integer(description='Parent comment ID for replies'),
    'content': restx_fields.String(description='Comment text'),
    'created_at': restx_fields.String(description='Creation timestamp'),
    'edited': restx_fields.Boolean(description='Whether the comment has been edited'),
    'edited_at': restx_fields.String(description='Last edit timestamp'),
    'deleted': restx_fields.Boolean(description='Whether the comment has been deleted'),
    'deleted_at': restx_fields.String(description='Deletion timestamp'),
    'user': restx_fields.Nested(blog_comment_user_model),
    'replies': restx_fields.List(restx_fields.Raw(description='Nested replies'))
})

create_blog_comment_model = blog_ns.model('CreateBlogComment', {
    'content': restx_fields.String(required=True, description='Comment text', example='Thanks for the update.'),
    'parent_comment_id': restx_fields.Integer(description='Parent comment ID when creating a reply', example=1)
})

create_blog_post_response_model = blog_ns.model('CreateBlogPostResponse', {
    'msg': restx_fields.String(description='Result message'),
    'id': restx_fields.Integer(description='ID of the newly created blog post')
})

update_blog_comment_model = blog_ns.model('UpdateBlogComment', {
    'content': restx_fields.String(required=True, description='Updated comment text', example='Updated comment text.')
})

blog_comments_list_model = blog_ns.model('BlogCommentsList', {
    'blog_post_id': restx_fields.Integer(description='Blog post ID'),
    'count': restx_fields.Integer(description='Number of top-level comments returned'),
    'comments': restx_fields.List(restx_fields.Nested(blog_comment_model))
})


class CreateBlogPostRequestSchema(Schema):
    title = fields.String(required=True, validate=validate.Length(min=1, max=255))
    author = fields.String(required=True, validate=validate.Length(min=1, max=100))
    content = fields.String(required=True, validate=validate.Length(min=1, max=65535))
    date = fields.String(load_default=None, validate=validate.Length(max=16))
    visible = fields.Boolean(load_default=True)
    tags = fields.List(fields.String(validate=validate.Length(max=50)), load_default=[], validate=validate.Length(max=20))
    category = fields.String(load_default='', validate=validate.Length(max=100))

class UpdateBlogPostRequestSchema(Schema):
    title = fields.String(required=True, validate=validate.Length(min=1, max=255))
    content = fields.String(required=True, validate=validate.Length(min=1, max=65535))
    date = fields.String(load_default=None, validate=validate.Length(max=16))
    visible = fields.Boolean(load_default=None)
    tags = fields.List(fields.String(validate=validate.Length(max=50)), load_default=None, validate=validate.Length(max=20))
    category = fields.String(load_default=None, validate=validate.Length(max=100))


class CreateBlogCommentRequestSchema(Schema):
    content = fields.String(required=True, validate=validate.Length(min=1, max=5000))
    parent_comment_id = fields.Integer(load_default=None)


class UpdateBlogCommentRequestSchema(Schema):
    content = fields.String(required=True, validate=validate.Length(min=1, max=5000))


def _serialize_comment_tree(comment, replies_by_parent):
    serialized = comment.to_dict()
    serialized['replies'] = [
        _serialize_comment_tree(reply, replies_by_parent)
        for reply in replies_by_parent.get(comment.id, [])
    ]
    return serialized


def _get_commentable_blog_post(blog_post_id):
    blog_post = db.session.get(BlogPost, blog_post_id)
    if not blog_post:
        return None
    return blog_post


def _validate_comment_content(content):
    normalized_content = content.strip()
    if not normalized_content:
        return None, {'msg': 'Validation error', 'errors': {'content': ['Shorter than minimum length 1.']}}, 400
    return normalized_content, None, None


@blog_ns.route('/post')
class BlogPostCreateResource(Resource):
    @blog_ns.expect((create_blog_post_model, 'Blog post fields. title, author and content are required.'), validate=True)
    @blog_ns.response(201, 'Blog post created successfully')
    @blog_ns.response(400, 'Bad request - validation error')
    @blog_ns.response(401, 'Unauthorized - authentication required')
    @blog_ns.response(403, 'Forbidden - admin role required')
    @blog_ns.response(500, 'Internal server error')
    @blog_ns.doc('create_blog_post', security='Bearer')
    @require_admin()
    def post(self):
        """Create a new blog post (Admin only)"""
        try:
            payload = CreateBlogPostRequestSchema().load(request.json)
        except ValidationError as err:
            return {'msg': 'Validation error', 'errors': err.messages}, 400

        try:
            now = datetime.datetime.now().strftime('%Y-%m-%dT%H:%M')
            post_date = payload['date'] if payload.get('date') else now
            new_post = BlogPost(
                date=post_date,
                title=payload['title'],
                author=payload['author'],
                content=payload['content'],
                visible=payload['visible'],
                tags=','.join(t.strip() for t in payload['tags'] if t.strip()),
                category=payload.get('category', '').strip() or 'Uncategorized'
            )
            db.session.add(new_post)
            db.session.commit()
            return {'msg': 'Blog post created successfully', 'id': new_post.id}, 201
        except Exception as ex:
            db.session.rollback()
            logging.error('Error encountered while trying to add post blog post', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@blog_ns.route('/post/<int:blog_post_id>')
class BlogPostResource(Resource):
    @blog_ns.marshal_with(blog_post_model, code=200)
    @blog_ns.response(404, 'Blog post not found, hidden, or not yet published')
    @blog_ns.response(500, 'Internal server error')
    @blog_ns.doc('get_blog_post', params={
        'blog_post_id': {'description': 'The unique ID of the blog post', 'type': 'integer', 'in': 'path', 'required': True}
    })
    def get(self, blog_post_id):
        """Get a visible, published blog post by ID (public)"""
        try:
            now = datetime.datetime.now().strftime('%Y-%m-%dT%H:%M')
            blog_post = db.session.get(BlogPost, blog_post_id)

            if not blog_post or not blog_post.visible or blog_post.date > now:
                return {'msg': 'Blog post not found'}, 404

            return blog_post.to_dict(), 200
        except Exception as ex:
            logging.error(f"Error encountered while trying to get blog post id {blog_post_id}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    @blog_ns.expect((update_blog_post_model, 'Updated blog post fields. title and content are required. All other fields are optional.'), validate=True)
    @blog_ns.response(204, 'Blog post updated successfully')
    @blog_ns.response(400, 'Bad request - validation error')
    @blog_ns.response(401, 'Unauthorized - authentication required')
    @blog_ns.response(403, 'Forbidden - admin role required')
    @blog_ns.response(404, 'Blog post not found')
    @blog_ns.response(500, 'Internal server error')
    @blog_ns.doc('put_blog_post', security='Bearer', params={
        'blog_post_id': {'description': 'The unique ID of the blog post to update', 'type': 'integer', 'in': 'path', 'required': True}
    })
    @require_admin()
    def put(self, blog_post_id):
        """Update blog post by ID (Admin only)"""
        try:
            payload = UpdateBlogPostRequestSchema().load(request.json)
        except ValidationError as err:
            return {'msg': 'Validation error', 'errors': err.messages}, 400

        try:
            blog_post = db.session.get(BlogPost, blog_post_id)
            
            if not blog_post:
                return {'msg': 'Blog post not found'}, 404
                
            blog_post.title = payload['title']
            blog_post.content = payload['content']
            if payload.get('date') is not None:
                blog_post.date = payload['date']
            if payload.get('visible') is not None:
                blog_post.visible = payload['visible']
            if payload.get('tags') is not None:
                blog_post.tags = ','.join(t.strip() for t in payload['tags'] if t.strip())
            if payload.get('category') is not None:
                new_category = payload['category'].strip()
                blog_post.category = new_category or 'Uncategorized'
            
            db.session.commit()
            return {'msg': 'Blog post updated successfully'}, 204
        except Exception as ex:
            db.session.rollback()
            logging.error(f"Error encountered while trying to put blog post id {blog_post_id}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    @blog_ns.response(204, 'Blog post deleted successfully')
    @blog_ns.response(404, 'Blog post not found')
    @blog_ns.response(401, 'Unauthorized - authentication required')
    @blog_ns.response(403, 'Forbidden - admin role required')
    @blog_ns.response(500, 'Internal server error')
    @blog_ns.doc('delete_blog_post', security='Bearer', params={
        'blog_post_id': {'description': 'The unique ID of the blog post to delete', 'type': 'integer', 'in': 'path', 'required': True}
    })
    @require_admin()
    def delete(self, blog_post_id):
        """Delete blog post by ID (Admin only)"""
        try:
            blog_post = db.session.get(BlogPost, blog_post_id)
            
            if not blog_post:
                return {'msg': 'Blog post not found'}, 404
                
            db.session.delete(blog_post)
            db.session.commit()
            return {'msg': 'Blog post deleted successfully'}, 204
        except Exception as ex:
            db.session.rollback()
            logging.error(f"Error encountered while trying to delete blog post id {blog_post_id}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@blog_ns.route('/post/<int:blog_post_id>/comments')
class BlogPostCommentsResource(Resource):
    @blog_ns.response(200, 'Comments retrieved successfully', blog_comments_list_model)
    @blog_ns.response(404, 'Blog post not found')
    @blog_ns.response(500, 'Internal server error')
    @blog_ns.response(503, 'Service unavailable - database migration required')
    @blog_ns.doc('get_blog_post_comments', params={
        'blog_post_id': {'description': 'The unique ID of the blog post whose comments to retrieve', 'type': 'integer', 'in': 'path', 'required': True}
    })
    def get(self, blog_post_id):
        """Get comments for a blog post. No authentication required — visible to all visitors.
        User email addresses are never included in the response."""
        try:
            blog_post = _get_commentable_blog_post(blog_post_id)
            if not blog_post:
                return {'msg': 'Blog post not found'}, 404

            comments = db.session.execute(
                select(BlogComment)
                .where(BlogComment.blog_post_id == blog_post_id)
                .order_by(BlogComment.created_at.asc(), BlogComment.id.asc())
            ).scalars().all()

            replies_by_parent = {}
            root_comments = []
            for comment in comments:
                if comment.parent_comment_id is None:
                    root_comments.append(comment)
                    continue
                replies_by_parent.setdefault(comment.parent_comment_id, []).append(comment)

            return {
                'blog_post_id': blog_post_id,
                'count': len(root_comments),
                'comments': [
                    _serialize_comment_tree(comment, replies_by_parent)
                    for comment in root_comments
                ]
            }, 200
        except OperationalError as ex:
            logging.error('Comments query failed due to database schema mismatch', exc_info=ex)
            return {'msg': 'Comments are temporarily unavailable. Please run database migrations and try again.'}, 503
        except Exception as ex:
            logging.error(f"Error encountered while trying to get comments for blog post id {blog_post_id}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    @blog_ns.expect((create_blog_comment_model, 'Comment content. Optionally supply a parent_comment_id to post a reply.'), validate=True)
    @blog_ns.response(201, 'Comment created successfully', blog_comment_model)
    @blog_ns.response(400, 'Bad request - validation error or invalid parent comment')
    @blog_ns.response(401, 'Unauthorized - authentication required')
    @blog_ns.response(403, 'Forbidden - account is locked or invalid role')
    @blog_ns.response(404, 'Blog post not found')
    @blog_ns.response(500, 'Internal server error')
    @blog_ns.response(503, 'Service unavailable - database migration required')
    @blog_ns.doc('create_blog_post_comment', security='Bearer', params={
        'blog_post_id': {'description': 'The unique ID of the blog post to comment on', 'type': 'integer', 'in': 'path', 'required': True}
    })
    @require_user_or_admin()
    def post(self, blog_post_id):
        """Create a comment or reply on a blog post. Authentication required (registered, unlocked users only).
        User email addresses are never included in the response."""
        try:
            payload = CreateBlogCommentRequestSchema().load(request.json)
        except ValidationError as err:
            return {'msg': 'Validation error', 'errors': err.messages}, 400

        try:
            now = datetime.datetime.now().strftime('%Y-%m-%dT%H:%M')
            blog_post = _get_commentable_blog_post(blog_post_id)
            if not blog_post or not blog_post.visible or blog_post.date > now:
                return {'msg': 'Blog post not found'}, 404

            current_user = get_current_user()
            if not current_user:
                return {'msg': 'User not found'}, 401

            comment_content, error_body, error_status = _validate_comment_content(payload['content'])
            if error_body:
                return error_body, error_status

            parent_comment = None
            parent_comment_id = payload.get('parent_comment_id')
            if parent_comment_id is not None:
                parent_comment = db.session.get(BlogComment, parent_comment_id)
                if not parent_comment or parent_comment.blog_post_id != blog_post_id:
                    return {'msg': 'Parent comment not found for this blog post'}, 400

            new_comment = BlogComment(
                blog_post_id=blog_post_id,
                user_id=current_user.id,
                parent_comment_id=parent_comment.id if parent_comment else None,
                content=comment_content,
            )
            db.session.add(new_comment)
            db.session.commit()
            return {
                **new_comment.to_dict(),
                'replies': []
            }, 201
        except OperationalError as ex:
            db.session.rollback()
            logging.error('Comment creation failed due to database schema mismatch', exc_info=ex)
            return {'msg': 'Comments are temporarily unavailable. Please run database migrations and try again.'}, 503
        except Exception as ex:
            db.session.rollback()
            logging.error(f"Error encountered while trying to create comment for blog post id {blog_post_id}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@blog_ns.route('/post/<int:blog_post_id>/comments/<int:comment_id>')
class BlogPostCommentResource(Resource):
    @blog_ns.expect((update_blog_comment_model, 'The updated comment text.'), validate=True)
    @blog_ns.response(200, 'Comment updated successfully', blog_comment_model)
    @blog_ns.response(400, 'Bad request - validation error')
    @blog_ns.response(401, 'Unauthorized - authentication required')
    @blog_ns.response(403, 'Forbidden - you can only edit your own comments unless you are an admin')
    @blog_ns.response(404, 'Blog post or comment not found')
    @blog_ns.response(500, 'Internal server error')
    @blog_ns.response(503, 'Service unavailable - database migration required')
    @blog_ns.doc('update_blog_post_comment', security='Bearer', params={
        'blog_post_id': {'description': 'The unique ID of the blog post containing the comment', 'type': 'integer', 'in': 'path', 'required': True},
        'comment_id': {'description': 'The unique ID of the comment to edit', 'type': 'integer', 'in': 'path', 'required': True}
    })
    @require_user_or_admin()
    def put(self, blog_post_id, comment_id):
        """Edit a blog comment. Authentication required (owner or admin, registered and unlocked users only).
        User email addresses are never included in the response."""
        try:
            payload = UpdateBlogCommentRequestSchema().load(request.json)
        except ValidationError as err:
            return {'msg': 'Validation error', 'errors': err.messages}, 400

        try:
            blog_post = _get_commentable_blog_post(blog_post_id)
            if not blog_post:
                return {'msg': 'Blog post not found'}, 404

            comment = db.session.get(BlogComment, comment_id)
            if not comment or comment.blog_post_id != blog_post_id:
                return {'msg': 'Comment not found for this blog post'}, 404

            current_user = get_current_user()
            if not current_user:
                return {'msg': 'User not found'}, 401

            if not current_user.is_admin() and current_user.id != comment.user_id:
                return {'msg': 'Access denied. You can only edit your own comments'}, 403

            if comment.deleted:
                return {'msg': 'Deleted comments cannot be edited'}, 400

            comment_content, error_body, error_status = _validate_comment_content(payload['content'])
            if error_body:
                return error_body, error_status

            comment.content = comment_content
            comment.edited = True
            comment.edited_at = datetime.datetime.now(datetime.timezone.utc)
            db.session.commit()

            return {
                **comment.to_dict(),
                'replies': [reply.to_dict() for reply in comment.replies]
            }, 200
        except OperationalError as ex:
            db.session.rollback()
            logging.error('Comment update failed due to database schema mismatch', exc_info=ex)
            return {'msg': 'Comments are temporarily unavailable. Please run database migrations and try again.'}, 503
        except Exception as ex:
            db.session.rollback()
            logging.error(
                f"Error encountered while trying to update comment id {comment_id} for blog post id {blog_post_id}",
                exc_info=ex
            )
            return {'msg': 'Internal Server Error'}, 500

    @blog_ns.response(204, 'Comment deleted successfully')
    @blog_ns.response(401, 'Unauthorized - authentication required')
    @blog_ns.response(403, 'Forbidden - you can only delete your own comments unless you are an admin')
    @blog_ns.response(404, 'Blog post or comment not found')
    @blog_ns.response(500, 'Internal server error')
    @blog_ns.response(503, 'Service unavailable - database migration required')
    @blog_ns.doc('delete_blog_post_comment', security='Bearer', params={
        'blog_post_id': {'description': 'The unique ID of the blog post containing the comment', 'type': 'integer', 'in': 'path', 'required': True},
        'comment_id': {'description': 'The unique ID of the comment to delete', 'type': 'integer', 'in': 'path', 'required': True}
    })
    @require_user_or_admin()
    def delete(self, blog_post_id, comment_id):
        """Soft-delete a blog comment. Authentication required (owner or admin, registered and unlocked users only)."""
        try:
            blog_post = _get_commentable_blog_post(blog_post_id)
            if not blog_post:
                return {'msg': 'Blog post not found'}, 404

            comment = db.session.get(BlogComment, comment_id)
            if not comment or comment.blog_post_id != blog_post_id:
                return {'msg': 'Comment not found for this blog post'}, 404

            current_user = get_current_user()
            if not current_user:
                return {'msg': 'User not found'}, 401

            if not current_user.is_admin() and current_user.id != comment.user_id:
                return {'msg': 'Access denied. You can only delete your own comments'}, 403

            # If this comment has no replies, remove it entirely.
            if not comment.replies:
                db.session.delete(comment)
                db.session.commit()
                return {'msg': 'Comment deleted successfully'}, 204

            if comment.deleted:
                return {'msg': 'Comment deleted successfully'}, 204

            comment.deleted = True
            comment.deleted_at = datetime.datetime.now(datetime.timezone.utc)
            db.session.commit()
            return {'msg': 'Comment deleted successfully'}, 204
        except OperationalError as ex:
            db.session.rollback()
            logging.error('Comment deletion failed due to database schema mismatch', exc_info=ex)
            return {'msg': 'Comments are temporarily unavailable. Please run database migrations and try again.'}, 503
        except Exception as ex:
            db.session.rollback()
            logging.error(
                f"Error encountered while trying to delete comment id {comment_id} for blog post id {blog_post_id}",
                exc_info=ex
            )
            return {'msg': 'Internal Server Error'}, 500


@blog_ns.route('/posts')
class BlogPostsListResource(Resource):
    @blog_ns.marshal_with(blog_posts_list_model, code=200)
    @blog_ns.response(400, 'Bad request - invalid offset or limit parameters')
    @blog_ns.response(500, 'Internal server error')
    @blog_ns.doc('get_blog_posts_list', params={
        'offset': {'description': 'Number of posts to skip for pagination', 'type': 'integer', 'in': 'query', 'default': 0},
        'limit': {'description': 'Maximum number of posts to return', 'type': 'integer', 'in': 'query', 'default': 25, 'minimum': 1, 'maximum': 100},
        'category': {'description': 'Filter posts to those belonging to this category. Use "Uncategorized" to match posts with no category assigned.', 'type': 'string', 'in': 'query'},
        'tag': {'description': 'Filter posts to those tagged with this value (case-sensitive substring match)', 'type': 'string', 'in': 'query'}
    })
    def get(self):
        """Get list of published, visible blog posts with pagination (public)"""
        try:
            offset, limit = parse_pagination(request.args, default_limit=25, max_limit=100)
        except QueryParamError as ex:
            return {'msg': str(ex)}, 400

        category = get_stripped_arg(request.args, 'category')
        tag = get_stripped_arg(request.args, 'tag')

        try:
            now = datetime.datetime.now().strftime('%Y-%m-%dT%H:%M')
            base_conditions = [
                BlogPost.visible == True,
                BlogPost.date <= now
            ]
            if category:
                if category == 'Uncategorized':
                    base_conditions.append(
                        (BlogPost.category == None) | (BlogPost.category == '') | (BlogPost.category == 'Uncategorized')
                    )
                else:
                    base_conditions.append(BlogPost.category == category)
            if tag:
                base_conditions.append(BlogPost.tags.contains(tag))
            base_query = select(BlogPost).where(*base_conditions)
            total = db.session.execute(
                select(func.count()).select_from(base_query.subquery())
            ).scalar()
            blog_posts_result = db.session.execute(
                base_query
                .order_by(BlogPost.date.desc())
                .offset(offset)
                .limit(limit)
            )
            blog_posts_data = [post.to_dict() for post in blog_posts_result.scalars()]

            return {
                'offset': offset,
                'limit': limit,
                'count': len(blog_posts_data),
                'total': total,
                'blog_posts': blog_posts_data
            }, 200
        except Exception as ex:
            logging.error('Error encountered while trying to get blog posts', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@blog_ns.route('/posts/meta')
class BlogPostsMetaResource(Resource):
    @blog_ns.marshal_with(blog_posts_meta_model, code=200)
    @blog_ns.response(500, 'Internal server error')
    @blog_ns.doc('get_blog_posts_meta')
    def get(self):
        """Get tag and category metadata for visible, published blog posts (public)"""
        try:
            now = datetime.datetime.now().strftime('%Y-%m-%dT%H:%M')
            posts = db.session.execute(
                select(BlogPost.tags, BlogPost.category)
                .where(
                    BlogPost.visible == True,
                    BlogPost.date <= now
                )
            ).all()

            tag_counts = Counter()
            category_counts = Counter({'Uncategorized': 0})  # always present

            for row in posts:
                raw_tags = row.tags or ''
                for tag in [t.strip() for t in raw_tags.split(',') if t.strip()]:
                    tag_counts[tag] += 1

                category = (row.category or '').strip() or 'Uncategorized'
                category_counts[category] += 1

            tags = [
                {'name': name, 'count': count}
                for name, count in sorted(tag_counts.items(), key=lambda item: (-item[1], item[0].lower()))
                if count > 0
            ]
            categories = [
                {'name': name, 'count': count}
                for name, count in sorted(category_counts.items(), key=lambda item: (-item[1], item[0].lower()))
                if count > 0
            ]

            return {
                'tags': tags,
                'categories': categories,
                'total_posts': len(posts),
            }, 200
        except Exception as ex:
            logging.error('Error encountered while trying to get blog post metadata', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@blog_ns.route('/posts/all')
class BlogPostsAdminListResource(Resource):
    @blog_ns.marshal_with(blog_posts_list_model, code=200)
    @blog_ns.response(400, 'Bad request - invalid offset or limit parameters')
    @blog_ns.response(401, 'Unauthorized - authentication required')
    @blog_ns.response(403, 'Forbidden - admin role required')
    @blog_ns.response(500, 'Internal server error')
    @blog_ns.doc('get_all_blog_posts_list', security='Bearer', params={
        'offset': {'description': 'Number of posts to skip for pagination', 'type': 'integer', 'in': 'query', 'default': 0},
        'limit': {'description': 'Maximum number of posts to return', 'type': 'integer', 'in': 'query', 'default': 25, 'minimum': 1, 'maximum': 100},
        'q': {'description': 'Optional title/author search query', 'type': 'string', 'in': 'query'},
        'status': {'description': 'Optional admin status filter: all, published, draft, scheduled', 'type': 'string', 'in': 'query'}
    })
    @require_admin()
    def get(self):
        """Get all blog posts including hidden and future-dated (Admin only)"""
        try:
            offset, limit = parse_pagination(request.args, default_limit=25, max_limit=100)
        except QueryParamError as ex:
            return {'msg': str(ex)}, 400

        search_query = get_stripped_arg(request.args, 'q')
        status = get_stripped_arg(request.args, 'status', default='all').lower()

        if status not in {'all', 'published', 'draft', 'scheduled'}:
            return {'msg': 'Bad Request - invalid status parameter'}, 400

        try:
            now_iso = datetime.datetime.now().strftime('%Y-%m-%dT%H:%M')

            def apply_filters(statement, status_filter='all'):
                filtered_statement = statement
                if search_query:
                    pattern = f"%{search_query}%"
                    filtered_statement = filtered_statement.where(
                        BlogPost.title.ilike(pattern) | BlogPost.author.ilike(pattern)
                    )

                if status_filter == 'published':
                    filtered_statement = filtered_statement.where(BlogPost.visible.is_(True), BlogPost.date <= now_iso)
                elif status_filter == 'draft':
                    filtered_statement = filtered_statement.where(BlogPost.visible.is_(False))
                elif status_filter == 'scheduled':
                    filtered_statement = filtered_statement.where(BlogPost.visible.is_(True), BlogPost.date > now_iso)

                return filtered_statement

            total = db.session.execute(select(func.count()).select_from(BlogPost)).scalar()
            all_total = db.session.execute(apply_filters(select(func.count()).select_from(BlogPost))).scalar()
            published_total = db.session.execute(apply_filters(select(func.count()).select_from(BlogPost), 'published')).scalar()
            draft_total = db.session.execute(apply_filters(select(func.count()).select_from(BlogPost), 'draft')).scalar()
            scheduled_total = db.session.execute(apply_filters(select(func.count()).select_from(BlogPost), 'scheduled')).scalar()
            blog_posts_result = db.session.execute(
                apply_filters(select(BlogPost), status)
                .order_by(BlogPost.date.desc())
                .offset(offset)
                .limit(limit)
            )
            blog_posts_data = [post.to_dict() for post in blog_posts_result.scalars()]

            return {
                'offset': offset,
                'limit': limit,
                'count': len(blog_posts_data),
                'total': total,
                'all_total': all_total,
                'published_total': published_total,
                'draft_total': draft_total,
                'scheduled_total': scheduled_total,
                'blog_posts': blog_posts_data
            }, 200
        except Exception as ex:
            logging.error('Error encountered while trying to get all blog posts (admin)', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500



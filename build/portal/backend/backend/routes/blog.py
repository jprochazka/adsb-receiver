import datetime
import logging

from flask import abort, Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from flask_restx import Namespace, Resource, fields as restx_fields
from marshmallow import Schema, fields, ValidationError
from sqlalchemy import select, func
from backend.models import db, BlogPost
from backend.auth import require_admin, require_user_or_admin
from werkzeug.exceptions import HTTPException

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
    'visible': restx_fields.Boolean(description='Whether the post is visible on the public blog')
})

create_blog_post_model = blog_ns.model('CreateBlogPost', {
    'title': restx_fields.String(required=True, description='Blog post title', example='My First Post'),
    'author': restx_fields.String(required=True, description='Author name', example='John Doe'),
    'content': restx_fields.String(required=True, description='Blog post content', example='This is the content of my first blog post.'),
    'date': restx_fields.String(description='Publication date and time (YYYY-MM-DDTHH:MM). Defaults to now.', example='2026-03-26T14:30'),
    'visible': restx_fields.Boolean(description='Whether the post is visible on the public blog. Defaults to true.')
})

update_blog_post_model = blog_ns.model('UpdateBlogPost', {
    'title': restx_fields.String(required=True, description='Updated blog post title'),
    'content': restx_fields.String(required=True, description='Updated blog post content'),
    'date': restx_fields.String(description='Publication date (YYYY-MM-DD)'),
    'visible': restx_fields.Boolean(description='Whether the post is visible on the public blog')
})

blog_posts_list_model = blog_ns.model('BlogPostsList', {
    'blog_posts': restx_fields.List(restx_fields.Nested(blog_post_model)),
    'offset': restx_fields.Integer(description='Pagination offset'),
    'limit': restx_fields.Integer(description='Pagination limit'),
    'count': restx_fields.Integer(description='Number of blog posts returned'),
    'total': restx_fields.Integer(description='Total number of blog posts')
})


class CreateBlogPostRequestSchema(Schema):
    title = fields.String(required=True)
    author = fields.String(required=True)
    content = fields.String(required=True)
    date = fields.String(load_default=None)
    visible = fields.Boolean(load_default=True)

class UpdateBlogPostRequestSchema(Schema):
    title = fields.String(required=True)
    content = fields.String(required=True)
    date = fields.String(load_default=None)
    visible = fields.Boolean(load_default=None)


@blog_ns.route('/post')
class BlogPostCreateResource(Resource):
    @blog_ns.expect(create_blog_post_model, validate=True)
    @blog_ns.response(201, 'Blog post created successfully')
    @blog_ns.response(400, 'Bad request - validation error')
    @blog_ns.response(401, 'Unauthorized - admin access required')
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
                visible=payload['visible']
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
    @blog_ns.response(404, 'Blog post not found')
    @blog_ns.response(500, 'Internal server error')
    @blog_ns.doc('get_blog_post')
    def get(self, blog_post_id):
        """Get blog post by ID"""
        try:
            blog_post = db.session.get(BlogPost, blog_post_id)
            
            if not blog_post:
                return {'msg': 'Blog post not found'}, 404
                
            return blog_post.to_dict(), 200
        except Exception as ex:
            logging.error(f"Error encountered while trying to get blog post id {blog_post_id}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    @blog_ns.expect(update_blog_post_model, validate=True)
    @blog_ns.response(204, 'Blog post updated successfully')
    @blog_ns.response(400, 'Bad request - validation error')
    @blog_ns.response(404, 'Blog post not found')
    @blog_ns.response(401, 'Unauthorized - admin access required')
    @blog_ns.response(500, 'Internal server error')
    @blog_ns.doc('update_blog_post', security='Bearer')
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
            
            db.session.commit()
            return {'msg': 'Blog post updated successfully'}, 204
        except Exception as ex:
            db.session.rollback()
            logging.error(f"Error encountered while trying to put blog post id {blog_post_id}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    @blog_ns.response(204, 'Blog post deleted successfully')
    @blog_ns.response(404, 'Blog post not found')
    @blog_ns.response(401, 'Unauthorized - admin access required')
    @blog_ns.response(500, 'Internal server error')
    @blog_ns.doc('delete_blog_post', security='Bearer')
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


@blog_ns.route('/posts')
class BlogPostsListResource(Resource):
    @blog_ns.marshal_with(blog_posts_list_model, code=200)
    @blog_ns.response(400, 'Bad request - invalid offset or limit parameters')
    @blog_ns.response(500, 'Internal server error')
    @blog_ns.doc('get_blog_posts_list', params={
        'offset': 'Pagination offset (default: 0)',
        'limit': 'Number of posts to return (default: 25, max: 100)'
    })
    def get(self):
        """Get list of published, visible blog posts with pagination (public)"""
        offset = request.args.get('offset', default=0, type=int)
        limit = request.args.get('limit', default=25, type=int)

        if offset < 0 or limit < 1 or limit > 100:
            return {'msg': 'Bad Request - invalid offset or limit parameters'}, 400

        try:
            now = datetime.datetime.now().strftime('%Y-%m-%dT%H:%M')
            base_query = select(BlogPost).where(
                BlogPost.visible == True,
                BlogPost.date <= now
            )
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


@blog_ns.route('/posts/all')
class BlogPostsAdminListResource(Resource):
    @blog_ns.marshal_with(blog_posts_list_model, code=200)
    @blog_ns.response(400, 'Bad request - invalid offset or limit parameters')
    @blog_ns.response(401, 'Unauthorized - admin access required')
    @blog_ns.response(500, 'Internal server error')
    @blog_ns.doc('get_all_blog_posts_list', security='Bearer', params={
        'offset': 'Pagination offset (default: 0)',
        'limit': 'Number of posts to return (default: 25, max: 10000)'
    })
    @require_admin()
    def get(self):
        """Get all blog posts including hidden and future-dated (Admin only)"""
        offset = request.args.get('offset', default=0, type=int)
        limit = request.args.get('limit', default=25, type=int)

        if offset < 0 or limit < 1 or limit > 10000:
            return {'msg': 'Bad Request - invalid offset or limit parameters'}, 400

        try:
            total = db.session.execute(select(func.count()).select_from(BlogPost)).scalar()
            blog_posts_result = db.session.execute(
                select(BlogPost)
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
            logging.error('Error encountered while trying to get all blog posts (admin)', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500



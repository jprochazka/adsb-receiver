import logging
import yaml

from datetime import datetime
from flask import abort, Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from marshmallow import Schema, fields, ValidationError
from backend.db import create_connection

blog = Blueprint('blog', __name__)
config=yaml.safe_load(open("config.yml"))


class CreateBlogPostRequestSchema(Schema):
    title = fields.String(required=True)
    author = fields.String(required=True)
    content = fields.String(required=True)

class UpdateBlogPostRequestSchema(Schema):
    title = fields.String(required=True)
    content = fields.String(required=True)


@blog.route('/api/blog/post', methods=['POST'])
@jwt_required()
def post_blog_post():
    try:
        payload = CreateBlogPostRequestSchema().load(request.json)
    except ValidationError as err:
        return jsonify(err.messages), 400

    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute(
            "INSERT INTO blog_posts (date, title, author, content) VALUES (%s, %s, %s, %s)",
            (datetime.now(), payload['title'], payload['author'], payload['content'])
        )
        connection.commit()
    except Exception as ex:
        logging.error('Error encountered while trying to add post blog post', exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    return "Created", 201

@blog.route('/api/blog/post/<int:blog_post_id>', methods=['DELETE'])
@jwt_required()
def delete_blog_post(blog_post_id):
    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT COUNT(*) FROM blog_posts WHERE id = %s", (blog_post_id,))
        if cursor.fetchone()[0] == 0:
            return "Not Found", 404
        else:
            cursor.execute("DELETE FROM blog_posts WHERE id = %s", (blog_post_id,))
            connection.commit()
    except Exception as ex:
        logging.error(f"Error encountered while trying to delete blog post id {blog_post_id}", exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    return "No Content", 204

@blog.route('/api/blog/post/<int:blog_post_id>', methods=['GET'])
@jwt_required()
def get_blog_post(blog_post_id):
    data=[]

    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT * FROM blog_posts WHERE id = %s", (blog_post_id,))
        columns=[x[0] for x in cursor.description]
        results = cursor.fetchall()
        for result in results:
            data.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error(f"Error encountered while trying to get blog post id {blog_post_id,}", blog_post_id, exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()
            
    if not data:
        abort(404, description="Not Found")

    return jsonify(data[0]), 200

@blog.route('/api/blog/post/<int:blog_post_id>', methods=['PUT'])
@jwt_required()
def put_blog_post(blog_post_id):
    try:
        payload = UpdateBlogPostRequestSchema().load(request.json)
    except ValidationError as err:
        return jsonify(err.messages), 400

    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT COUNT(*) FROM blog_posts WHERE id = %s", (blog_post_id,))
        if cursor.fetchone()[0] == 0:
            return "Not Found", 404
        else:
            cursor.execute(
                "UPDATE blog_posts SET date = %s, title = %s, content = %s WHERE id = %s", 
                (datetime.now(), payload['title'], payload['content'], blog_post_id)
            )
        connection.commit()
    except Exception as ex:
        logging.error(f"Error encountered while trying to put blog post id {blog_post_id}", exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    return "No Content", 204

@blog.route('/api/blog/posts', methods=['GET'])
@jwt_required()
def get_blog_posts():
    offset = request.args.get('offset', default=0, type=int)
    limit = request.args.get('limit', default=25, type=int)
    if offset < 0 or limit < 1 or limit > 100:
        abort(400, description="Bad Request")

    blog_posts=[]

    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT * FROM blog_posts ORDER BY date DESC LIMIT %s, %s", (offset, limit))
        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            blog_posts.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error('Error encountered while trying to get blog posts', exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    data={}
    data['offset'] = offset
    data['limit'] = limit
    data['count'] = len(blog_posts)
    data['blog_posts'] = blog_posts
    
    return jsonify(data), 200
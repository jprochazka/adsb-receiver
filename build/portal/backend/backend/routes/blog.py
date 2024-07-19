import datetime
import logging

from flask import abort, Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from marshmallow import Schema, fields, ValidationError
from backend.db import get_db
from werkzeug.exceptions import HTTPException

blog = Blueprint('blog', __name__)


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
        now = str(datetime.datetime.now(datetime.UTC))
        db=get_db()
        cursor=db.cursor()
        cursor.execute(

            "INSERT INTO blog_posts (date, title, author, content) VALUES (?, ?, ?, ?)",
            #"INSERT INTO blog_posts (date, title, author, content) VALUES (%s, %s, %s, %s)",

            (now, payload['title'], payload['author'], payload['content'])
        )
        db.commit()
    except Exception as ex:
        logging.error('Error encountered while trying to add post blog post', exc_info=ex)
        abort(500, description="Internal Server Error")

    return "Created", 201

@blog.route('/api/blog/post/<int:blog_post_id>', methods=['DELETE'])
@jwt_required()
def delete_blog_post(blog_post_id):
    try:
        db=get_db()
        cursor=db.cursor()

        cursor.execute("SELECT COUNT(*) FROM blog_posts WHERE id = ?", (blog_post_id,))
        #cursor.execute("SELECT COUNT(*) FROM blog_posts WHERE id = %s", (blog_post_id,))

        if cursor.fetchone()[0] == 0:
            abort(404, description="Not Found")
        else:

            cursor.execute("DELETE FROM blog_posts WHERE id = ?", (blog_post_id,))
            #cursor.execute("DELETE FROM blog_posts WHERE id = %s", (blog_post_id,))

            db.commit()
    except Exception as ex:
        if isinstance(ex, HTTPException):
            abort(ex.code)
        else:
            logging.error(f"Error encountered while trying to delete blog post id {blog_post_id}", exc_info=ex)
            abort(500, description="Internal Server Error")

    return "No Content", 204

@blog.route('/api/blog/post/<int:blog_post_id>', methods=['GET'])
def get_blog_post(blog_post_id):
    data=[]

    try:
        db=get_db()
        cursor=db.cursor()

        cursor.execute("SELECT * FROM blog_posts WHERE id = ?", (blog_post_id,))
        #cursor.execute("SELECT * FROM blog_posts WHERE id = %s", (blog_post_id,))

        columns=[x[0] for x in cursor.description]
        results = cursor.fetchall()
        for result in results:
            data.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error(f"Error encountered while trying to get blog post id {blog_post_id,}", blog_post_id, exc_info=ex)
        abort(500, description="Internal Server Error")
            
    if not data:
        abort(404, description="Not Found")

    response = jsonify(data)
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response, 200

@blog.route('/api/blog/post/<int:blog_post_id>', methods=['PUT'])
@jwt_required()
def put_blog_post(blog_post_id):
    try:
        payload = UpdateBlogPostRequestSchema().load(request.json)
    except ValidationError as err:
        return jsonify(err.messages), 400

    try:
        db=get_db()
        cursor=db.cursor()

        cursor.execute("SELECT COUNT(*) FROM blog_posts WHERE id = ?", (blog_post_id,))
        #cursor.execute("SELECT COUNT(*) FROM blog_posts WHERE id = %s", (blog_post_id,))

        if cursor.fetchone()[0] == 0:
            abort(404, description="Not Found")
        else:
            now = str(datetime.datetime.now(datetime.UTC))
            cursor.execute(

                "UPDATE blog_posts SET date = ?, title = ?, content = ? WHERE id = ?",
                #"UPDATE blog_posts SET date = %s, title = %s, content = %s WHERE id = %s",

                (now, payload['title'], payload['content'], blog_post_id)
            )
        db.commit()
    except Exception as ex:
        if isinstance(ex, HTTPException):
            abort(ex.code)
        else:
            logging.error(f"Error encountered while trying to put blog post id {blog_post_id}", exc_info=ex)
            abort(500, description="Internal Server Error")

    return "No Content", 204

@blog.route('/api/blog/posts', methods=['GET'])
def get_blog_posts():
    offset = request.args.get('offset', default=0, type=int)
    limit = request.args.get('limit', default=25, type=int)
    if offset < 0 or limit < 1 or limit > 100:
        abort(400, description="Bad Request")

    blog_posts=[]

    try:
        db=get_db()
        cursor=db.cursor()

        cursor.execute("SELECT * FROM blog_posts ORDER BY date DESC LIMIT ?, ?", (offset, limit))
        #cursor.execute("SELECT * FROM blog_posts ORDER BY date DESC LIMIT %s, %s", (offset, limit))

        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            blog_posts.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error('Error encountered while trying to get blog posts', exc_info=ex)
        abort(500, description="Internal Server Error")

    data={}
    data['offset'] = offset
    data['limit'] = limit
    data['count'] = len(blog_posts)
    data['blog_posts'] = blog_posts
    
    response = jsonify(data)
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response, 200
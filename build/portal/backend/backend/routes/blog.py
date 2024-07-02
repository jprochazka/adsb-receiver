import logging
import mysql.connector
import sqlite3
import yaml

from datetime import datetime
from flask import abort, Blueprint, jsonify, request
from marshmallow import Schema, fields, ValidationError

blog = Blueprint('blog', __name__)

config=yaml.safe_load(open("config.yml"))


class BlogPostSchema(Schema):
    BlogPostId = fields.Integer
    DateAdded = fields.DateTime
    Title = fields.String
    Author = fields.String
    Content = fields.String

class CreateBlogPostRequestSchema(Schema):
    Title = fields.String
    Author = fields.String
    Content = fields.String

class UpdateBlogPostRequestSchema(Schema):
    Title = fields.String
    Content = fields.String


def create_connetion():
    match config['database']['use'].lower():
        case 'mysql':
            return mysql.connector.connect(
                host=config['database']['mysql']['host'],
                user=config['database']['mysql']['user'],
                password=config['database']['mysql']['password'],
                database=config['database']['mysql']['database']
            )
        case 'sqlite':
            return sqlite3.connect(config['database']['sqlite']['path'])


@blog.route('/api/v1/blog/post', methods=['POST'])
def post_blog_post():
    payload = request.json
    payload_schema = CreateBlogPostRequestSchema

    try:
        payload_object = payload_schema.load(payload)
    except ValidationError as err:
        return jsonify(err.messages), 400

    try:
        connection = create_connetion()
        cursor=connection.cursor()
        cursor.execute(
            "INSERT INTO blogposts (date, title, author, content) VALUES (%s, %s, %s, %s)",
            (datetime.now(), payload_object['title'], payload_object['author'], payload_object['content'])
        )
        connection.commit()
    except Exception as ex:
        logging.error('Error encountered while trying to post blog post', exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    return "", 201

@blog.route('/api/v1/blog/post/<int:id>', methods=['DELETE'])
def delete_blog_post(id):
    try:
        connection = create_connetion()
        cursor=connection.cursor()
        cursor.execute("SELECT * FROM BlogPosts WHERE BlogPostId = %s", (id))
        if cursor.fetchone() != 0:
            abort(404, description="Not Found")
        else:
            cursor.execute("DELETE FROM blogposts WHERE id = %s", (id))
            connection.commit()
    except Exception as ex:
        logging.error(f"Error encountered while trying to delete blog post id {id}", id, exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    return "", 204

@blog.route('/api/v1/blog/post/<int:id>', methods=['GET'])
def get_blog_post(id):
    data=[]

    try:
        connection = create_connetion()
        cursor=connection.cursor()
        cursor.execute("SELECT * FROM blogposts WHERE id = %s", (id))
        columns=[x[0] for x in cursor.description]
        for result in result:
            data.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error(f"Error encountered while trying to get blog post id {id}", id, exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()
            
    if not data:
        abort(404, description="Not Found")

    return jsonify(data), 200

@blog.route('/api/v1/blog/post/<int:id>', methods=['PUT'])
def put_blog_post(id):
    payload = request.json
    payload_schema = UpdateBlogPostRequestSchema

    try:
        payload_object = payload_schema.load(payload)
    except ValidationError as err:
        return jsonify(err.messages), 400

    try:
        connection = create_connetion()
        cursor=connection.cursor()
        cursor.execute(
            "UPDATE blogposts SET date = %s, title = %s, content = %s WHERE id = %s", 
            (datetime.now(), payload_object['title'], payload_object['content'], id)
        )
        connection.commit()
    except Exception as ex:
        logging.error(f"Error encountered while trying to put blog post id {id}", exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    return "", 204

@blog.route('/api/v1/blog/posts', methods=['GET'], defaults={'offset': 0, 'limit': 100})
def get_blog_posts(offset, limit):
    if not isinstance(offset, int) or offset < 0  or not isinstance(limit, int) or limit < 1 or limit > 100:
        abort(400, description="Bad Request")

    data=[]

    try:
        connection = create_connetion()
        cursor=connection.cursor()
        cursor.execute("SELECT * FROM blogposts ORDER BY date DESC LIMIT %s, %s", (offset, limit))
        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            data.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error('Error encountered while trying to get blog posts', exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    return jsonify(data), 200
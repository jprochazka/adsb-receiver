import logging

from flask import abort, Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from marshmallow import Schema, fields, ValidationError
from backend.db import create_connection

users = Blueprint('users', __name__)


class CreateUserRequestSchema(Schema):
    name = fields.String(required=True)
    email = fields.String(required=True)
    password = fields.String(required=True)
    administrator = fields.Boolean(required=True)

class UpdateUserRequestSchema(Schema):
    name = fields.String(required=True)
    password = fields.String(required=True)
    administrator = fields.Boolean(required=True)


@users.route('/api/user', methods=['POST'])
@jwt_required()
def post_user():
    try:
        payload = CreateUserRequestSchema().load(request.json)
    except ValidationError as err:
        return jsonify(err.messages), 400
    
    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute(
            "INSERT INTO users (name, email, password, administrator) VALUES (%s, %s, %s, %s)",
            (payload['name'], payload['email'], payload['password'], payload['administrator'])
        )
        connection.commit()
    except Exception as ex:
        logging.error('Error encountered while trying to post user', exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    return "Created", 201

@users.route('/api/user/<string:email>', methods=['DELETE'])
@jwt_required()
def delete_user(email):
    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT COUNT(*) FROM users WHERE email = %s", (email,))
        if cursor.fetchone()[0] == 0:
            return "Not Found", 404
        else:
            cursor.execute("DELETE FROM users WHERE email = %s", (email,))
            connection.commit()
    except Exception as ex:
        logging.error(f"Error encountered while trying to delete user related to email {email}", exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    return "No Content", 204

@users.route('/api/user/<string:email>', methods=['GET'])
@jwt_required()
def get_user(email):
    data=[]

    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
        columns=[x[0] for x in cursor.description]
        results = cursor.fetchall()
        for result in results:
            data.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error(f"Error encountered while trying to get user related to email {email,}", email, exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()
            
    if not data:
        abort(404, description="Not Found")

    return jsonify(data[0]), 200

@users.route('/api/user/<string:email>', methods=['PUT'])
@jwt_required()
def put_user(email):
    try:
        payload = UpdateUserRequestSchema().load(request.json)
    except ValidationError as err:
        return jsonify(err.messages), 400

    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT COUNT(*) FROM users WHERE email = %s", (email,))
        if cursor.fetchone()[0] == 0:
            return "Not Found", 404
        else:
            cursor.execute(
                "UPDATE users SET name = %s, password = %s, administrator = %s WHERE email = %s", 
                (payload['name'], payload['password'], payload['administrator'], email)
            )
        connection.commit()
    except Exception as ex:
        logging.error(f"Error encountered while trying to put user related to email {email}", exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    return "No Content", 204

@users.route('/api/users', methods=['GET'])
@jwt_required()
def get_users():
    offset = request.args.get('offset', default=0, type=int)
    limit = request.args.get('limit', default=100, type=int)
    if offset < 0  or limit < 1 or limit > 1000:
        abort(400, description="Bad Request")

    users=[]

    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT * FROM users ORDER BY name LIMIT %s, %s", (offset, limit))
        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            users.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error(f"Error encountered while trying to get users", exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    data={}
    data['offset'] = offset
    data['limit'] = limit
    data['count'] = len(users)
    data['users'] = users

    return jsonify(data), 200
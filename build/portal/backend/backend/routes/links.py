import logging

from flask import abort, Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from marshmallow import Schema, fields, ValidationError
from backend.db import get_db

links = Blueprint('links', __name__)


class CreateLinkRequestSchema(Schema):
    name = fields.String(required=True)
    address = fields.String(required=True)

class UpdateLinkRequestSchema(Schema):
    name = fields.String(required=True)
    address = fields.String(required=True)
        

@links.route('/api/link', methods=['POST'])
@jwt_required()
def post_link():
    try:
        payload = CreateLinkRequestSchema().load(request.json)
    except ValidationError as err:
        return jsonify(err.messages), 400

    try:
        db=get_db()
        cursor=db.cursor()
        cursor.execute(
            "INSERT INTO links (name, address) VALUES (%s, %s)",
            (payload['name'], payload['address'])
        )
        db.commit()
    except Exception as ex:
        logging.error(f"Error encountered while trying to post link", exc_info=ex)
        abort(500, description="Internal Server Error")

    return "Created", 201

@links.route('/api/link/<int:link_id>', methods=['DELETE'])
@jwt_required()
def delete_link(link_id):
    try:
        db=get_db()
        cursor=db.cursor()
        cursor.execute("SELECT COUNT(*) FROM links WHERE id = %s", (link_id,))
        if cursor.fetchone()[0] == 0:
            return "Not Found", 404
        else:
            cursor.execute("DELETE FROM links WHERE id = %s", (link_id,))
            db.commit()
    except Exception as ex:
        logging.error(f"Error encountered while trying to delete link id {link_id}", exc_info=ex)
        abort(500, description="Internal Server Error")

    return "No Content", 204

@links.route('/api/link/<int:link_id>', methods=['GET'])
@jwt_required()
def get_link(link_id):
    data=[]

    try:
        db=get_db()
        cursor=db.cursor()
        cursor.execute("SELECT * FROM links WHERE id = %s", (link_id,))
        columns=[x[0] for x in cursor.description]
        results = cursor.fetchall()
        for result in results:
            data.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error(f"Error encountered while trying to get link id {link_id}", link_id, exc_info=ex)
        abort(500, description="Internal Server Error")
            
    if not data:
        abort(404, description="Not Found")

    return jsonify(data[0]), 200

@links.route('/api/link/<int:id>', methods=['PUT'])
@jwt_required()
def put_link(id):
    payload = request.json
    payload_schema = UpdateLinkRequestSchema

    try:
        payload_object = payload_schema.load(payload)
    except ValidationError as err:
        return jsonify(err.messages), 400

    try:
        db=get_db()
        cursor=db.cursor()
        cursor.execute("SELECT COUNT(*) FROM links WHERE id = %s", (id))
        if cursor.fetchone()[0] == 0:
            abort(404, description="Not Found")
        else:
            cursor.execute(
                "UPDATE links SET name = %s, address = %s WHERE id = %s",
                (payload_object['name'], payload_object['address'], id)
            )
            db.commit()
    except Exception as ex:
        logging.error(f"Error encountered while trying to put link id {id}", exc_info=ex)
        abort(500, description="Internal Server Error")

    return "No Content", 204

@links.route('/api/links', methods=['GET'])
def get_links():
    offset = request.args.get('offset', default=0, type=int)
    limit = request.args.get('limit', default=50, type=int)
    if offset < 0  or limit < 1 or limit > 100:
        abort(400, description="Bad Request")

    links=[]

    try:
        db=get_db()
        cursor=db.cursor()
        cursor.execute("SELECT * FROM links ORDER BY name LIMIT %s, %s", (offset, limit))
        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            links.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error(f"Error encountered while trying to get links", exc_info=ex)
        abort(500, description="Internal Server Error")

    data={}
    data['offset'] = offset
    data['limit'] = limit
    data['count'] = len(links)
    data['links'] = links
    
    response = jsonify(data)
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response, 200
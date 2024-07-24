import logging

from flask import abort, Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from marshmallow import Schema, fields, ValidationError
from backend.db import get_db
from werkzeug.exceptions import HTTPException

settings = Blueprint('settings', __name__)


class UpdateSettingRequestSchema(Schema):
    name = fields.String(required=True)
    value = fields.String(required=True)


@settings.route('/api/setting', methods=['PUT'])
@jwt_required()
def put_setting():
    try:
        payload = UpdateSettingRequestSchema().load(request.json)
    except ValidationError as err:
        return jsonify(err.messages), 400

    try:
        db=get_db()
        cursor=db.cursor()

        cursor.execute("SELECT COUNT(*) FROM settings WHERE name = ?", (payload['name'],))
        #cursor.execute("SELECT COUNT(*) FROM settings WHERE name = %s", (payload['name'],))

        if cursor.fetchone()[0] == 0:
            abort(404, description="Not Found")
        else:
            cursor.execute(

                "UPDATE settings SET value = ? WHERE name = ?",
                #"UPDATE settings SET value = %s WHERE name = %s",

                (payload['value'], payload['name'])
            )
            db.commit()
    except Exception as ex:
        if isinstance(ex, HTTPException):
            abort(ex.code)
        else:
            logging.error(f"Error encountered while trying to put setting named {payload['name']}", exc_info=ex)
            abort(500, description="Internal Server Error")

    return "No Content", 204

@settings.route('/api/setting/<string:name>', methods=['GET'])
def get_setting(name):
    data=[]

    try:
        db=get_db()
        cursor=db.cursor()

        cursor.execute("SELECT * FROM settings WHERE name = ?", (name,))
        #cursor.execute("SELECT * FROM settings WHERE name = %s", (name,))

        columns=[x[0] for x in cursor.description]
        results = cursor.fetchall()
        for result in results:
            data.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error(f"Error encountered while trying to get setting named {name}", id, exc_info=ex)
        abort(500, description="Internal Server Error")
            
    if not data:
        abort(404, description="Not Found")

    response = jsonify(data[0])
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response, 200

@settings.route('/api/settings', methods=['GET'])
@jwt_required()
def get_settings():
    settings=[]

    try:
        db=get_db()
        cursor=db.cursor()
        cursor.execute("SELECT * FROM settings ORDER BY name")
        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            settings.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error(f"Error encountered while trying to get settings", exc_info=ex)
        abort(500, description="Internal Server Error")

    response = jsonify(settings)
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response, 200


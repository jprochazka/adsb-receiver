import logging
import yaml

from flask import abort, Blueprint, jsonify, request
from marshmallow import Schema, fields, ValidationError
from backend.db import create_connection


notifications = Blueprint('links', __name__)
config=yaml.safe_load(open("config.yml"))


@notifications.route('/api/notification/<string:flight>', methods=['DELETE'])
def delete_notification(flight):
    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT COUNT(*) FROM notifications WHERE flight = %s", (flight,))
        if cursor.fetchone()[0] == 0:
            return "Not Found", 404
        else:
            cursor.execute("DELETE FROM notifications WHERE flight = %s", (flight,))
            connection.commit()
    except Exception as ex:
        logging.error(f"Error encountered while trying to delete blog post id {flight}", exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    return "No Content", 204

@notifications.route('/api/notification/<string:flight>', methods=['POST'])
def post_notification(flight):
    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT COUNT(*) FROM notifications WHERE flight = %s", (flight,))
        if cursor.fetchone()[0] > 0:
            return "Bad Request", 400
        else:
            cursor.execute(
                "INSERT INTO notifications (flight) VALUES (%s)",
                (flight,)
            )
        connection.commit()
    except Exception as ex:
        logging.error('Error encountered while trying to add notification', exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    return "Created", 201

@notifications.route('/api/notifications', methods=['GET'])
def get_notifications():
    offset = request.args.get('offset', default=0, type=int)
    limit = request.args.get('limit', default=100, type=int)
    if offset < 0  or limit < 1 or limit > 1000:
        abort(400, description="Bad Request")

    notifications=[]

    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT * FROM notifications ORDER BY flight LIMIT %s, %s", (offset, limit))
        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            notifications.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error(f"Error encountered while trying to get notifications", exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    data={}
    data['offset'] = offset
    data['limit'] = limit
    data['count'] = len(notifications)
    data['notifications'] = notifications

    return jsonify(data), 200
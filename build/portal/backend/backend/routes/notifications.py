import logging

from flask import abort, Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from backend.db import get_db

notifications = Blueprint('notifications', __name__)


@notifications.route('/api/notification/<string:flight>', methods=['DELETE'])
@jwt_required()
def delete_notification(flight):
    try:
        db=get_db()
        cursor=db.cursor()

        cursor.execute("SELECT COUNT(*) FROM notifications WHERE flight = ?", (flight,))
        #cursor.execute("SELECT COUNT(*) FROM notifications WHERE flight = %s", (flight,))

        if cursor.fetchone()[0] == 0:
            return "Not Found", 404
        else:

            cursor.execute("DELETE FROM notifications WHERE flight = ?", (flight,))
            #cursor.execute("DELETE FROM notifications WHERE flight = %s", (flight,))

            db.commit()
    except Exception as ex:
        logging.error(f"Error encountered while trying to delete blog post id {flight}", exc_info=ex)
        abort(500, description="Internal Server Error")

    return "No Content", 204

@notifications.route('/api/notification/<string:flight>', methods=['POST'])
@jwt_required()
def post_notification(flight):
    try:
        db=get_db()
        cursor=db.cursor()

        cursor.execute("SELECT COUNT(*) FROM notifications WHERE flight = ?", (flight,))
        #cursor.execute("SELECT COUNT(*) FROM notifications WHERE flight = %s", (flight,))

        if cursor.fetchone()[0] > 0:
            return "Bad Request", 400
        else:
            cursor.execute(

                "INSERT INTO notifications (flight) VALUES (?)",
                #"INSERT INTO notifications (flight) VALUES (%s)",

                (flight,)
            )
        db.commit()
    except Exception as ex:
        logging.error('Error encountered while trying to add notification', exc_info=ex)
        abort(500, description="Internal Server Error")

    return "Created", 201

@notifications.route('/api/notifications', methods=['GET'])
def get_notifications():
    offset = request.args.get('offset', default=0, type=int)
    limit = request.args.get('limit', default=100, type=int)
    if offset < 0  or limit < 1 or limit > 1000:
        abort(400, description="Bad Request")

    notifications=[]

    try:
        db=get_db()
        cursor=db.cursor()

        cursor.execute("SELECT * FROM notifications ORDER BY flight LIMIT ?, ?", (offset, limit))
        #cursor.execute("SELECT * FROM notifications ORDER BY flight LIMIT %s, %s", (offset, limit))

        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            notifications.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error(f"Error encountered while trying to get notifications", exc_info=ex)
        abort(500, description="Internal Server Error")

    data={}
    data['offset'] = offset
    data['limit'] = limit
    data['count'] = len(notifications)
    data['notifications'] = notifications

    return jsonify(data), 200
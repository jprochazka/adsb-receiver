import logging

from flask import abort, Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from flask_restx import Namespace, Resource, fields as restx_fields
from backend.models import db, Notification
from backend.auth import require_admin, require_user_or_admin
from werkzeug.exceptions import HTTPException
from sqlalchemy import select

notifications = Blueprint('notifications', __name__)

# Create Flask-RESTX namespaces for notifications management
notification_ns = Namespace('notification', description='Individual notification management')
notifications_ns = Namespace('notifications', description='Notifications list management')

# Define API models for documentation - shared across namespaces
notification_model = notification_ns.model('Notification', {
    'id': restx_fields.Integer(description='Notification ID'),
    'flight': restx_fields.String(description='Flight number/callsign to monitor')
})

notifications_list_model = notifications_ns.model('NotificationsList', {
    'notifications': restx_fields.List(restx_fields.Nested(notification_model)),
    'offset': restx_fields.Integer(description='Pagination offset'),
    'limit': restx_fields.Integer(description='Pagination limit'),
    'count': restx_fields.Integer(description='Number of notifications returned')
})


@notification_ns.route('/<string:flight>')
class NotificationResource(Resource):
    @notification_ns.response(201, 'Notification created successfully')
    @notification_ns.response(409, 'Conflict - notification already exists')
    @notification_ns.response(401, 'Unauthorized - authentication required')
    @notification_ns.response(500, 'Internal server error')
    @notification_ns.doc('create_notification', security='Bearer')
    @require_user_or_admin()
    def post(self, flight):
        """Create a flight notification (User or Admin required)"""
        try:
            # Check if notification already exists
            existing_notification = db.session.execute(select(Notification).filter_by(flight=flight)).scalar_one_or_none()
            
            if existing_notification:
                return {'msg': 'Conflict - Notification already exists'}, 409
                
            new_notification = Notification(flight=flight)
            db.session.add(new_notification)
            db.session.commit()
            return {'msg': 'Notification created successfully'}, 201
        except Exception as ex:
            db.session.rollback()
            logging.error(f"Error encountered while trying to post notification for flight {flight}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    @notification_ns.response(204, 'Notification deleted successfully')
    @notification_ns.response(404, 'Notification not found')
    @notification_ns.response(401, 'Unauthorized - admin access required')
    @notification_ns.response(500, 'Internal server error')
    @notification_ns.doc('delete_notification', security='Bearer')
    @require_admin()
    def delete(self, flight):
        """Delete a flight notification (Admin only)"""
        try:
            notification = db.session.execute(select(Notification).filter_by(flight=flight)).scalar_one_or_none()
            
            if not notification:
                return {'msg': 'Notification not found'}, 404
                
            db.session.delete(notification)
            db.session.commit()
            return {'msg': 'Notification deleted successfully'}, 204
        except Exception as ex:
            db.session.rollback()
            logging.error(f"Error encountered while trying to delete notification for flight {flight}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@notifications_ns.route('', strict_slashes=False)
class NotificationsListResource(Resource):
    @notifications_ns.marshal_with(notifications_list_model, code=200)
    @notifications_ns.response(400, 'Bad request - invalid offset or limit parameters')
    @notifications_ns.response(500, 'Internal server error')
    @notifications_ns.doc('get_notifications_list', params={
        'offset': 'Pagination offset (default: 0)',
        'limit': 'Number of notifications to return (default: 100, max: 1000)'
    })
    def get(self):
        """Get list of flight notifications with pagination"""
        offset = request.args.get('offset', default=0, type=int)
        limit = request.args.get('limit', default=100, type=int)
        
        if offset < 0 or limit < 1 or limit > 1000:
            return {'msg': 'Bad Request - invalid offset or limit parameters'}, 400
            
        try:
            notifications_result = db.session.execute(
                select(Notification)
                .order_by(Notification.id)
                .offset(offset)
                .limit(limit)
            )
            notifications_data = [notification.to_dict() for notification in notifications_result.scalars()]
            
            return {
                'offset': offset,
                'limit': limit,
                'count': len(notifications_data),
                'notifications': notifications_data
            }, 200
        except Exception as ex:
            logging.error('Error encountered while trying to get notifications', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500



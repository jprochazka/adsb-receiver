import logging
import datetime
import yaml

from flask import Blueprint, request
from flask_restx import Namespace, Resource, fields as restx_fields
from backend.models import db, Notification, Flight, Dump978Flight, Setting
from backend.auth import require_user_or_admin
from sqlalchemy import create_engine, select, text
from sqlalchemy.exc import OperationalError

notifications = Blueprint('notifications', __name__)

# Create Flask-RESTX namespaces for notifications management
notifications_ns = Namespace('notifications', description='Notifications list management')

# Define API models for documentation - shared across namespaces
notification_model = notifications_ns.model('Notification', {
    'id': restx_fields.Integer(description='Notification ID'),
    'flight': restx_fields.String(description='Flight number/callsign to monitor')
})

notifications_list_model = notifications_ns.model('NotificationsList', {
    'notifications': restx_fields.List(restx_fields.Nested(notification_model)),
    'offset': restx_fields.Integer(description='Pagination offset'),
    'limit': restx_fields.Integer(description='Pagination limit'),
    'count': restx_fields.Integer(description='Number of notifications returned')
})


@notifications_ns.route('/<string:flight>')
class NotificationResource(Resource):
    @notifications_ns.response(201, 'Notification created successfully')
    @notifications_ns.response(403, 'Forbidden')
    @notifications_ns.response(409, 'Conflict - notification already exists')
    @notifications_ns.response(401, 'Unauthorized - authentication required')
    @notifications_ns.response(500, 'Internal server error')
    @notifications_ns.doc('create_notification', security='Bearer')
    @require_user_or_admin()
    def post(self, flight):
        """Create a flight notification (authenticated user or admin)"""
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

    @notifications_ns.response(204, 'Notification deleted successfully')
    @notifications_ns.response(404, 'Notification not found')
    @notifications_ns.response(401, 'Unauthorized - authentication required')
    @notifications_ns.response(403, 'Forbidden')
    @notifications_ns.response(500, 'Internal server error')
    @notifications_ns.doc('delete_notification', security='Bearer')
    @require_user_or_admin()
    def delete(self, flight):
        """Delete a flight notification (authenticated user or admin)"""
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


recent_flight_model = notifications_ns.model('RecentFlight', {
    'id': restx_fields.Integer(description='Flight ID'),
    'flight': restx_fields.String(description='Flight number/callsign'),
    'type': restx_fields.String(description='Flight type: adsb or uat'),
    'first_seen': restx_fields.String(description='First seen timestamp'),
    'last_seen': restx_fields.String(description='Last seen timestamp')
})

recent_notifications_model = notifications_ns.model('RecentNotifications', {
    'flights': restx_fields.List(restx_fields.Nested(recent_flight_model)),
    'count': restx_fields.Integer(description='Number of matching flights'),
    'lookback_minutes': restx_fields.Integer(description='Lookback window used in minutes')
})


@notifications_ns.route('/recent')
class RecentNotificationsResource(Resource):
    @notifications_ns.marshal_with(recent_notifications_model, code=200)
    @notifications_ns.response(500, 'Internal server error')
    @notifications_ns.doc('get_recent_notifications')
    def get(self):
        """Get flights seen recently that match a notification entry"""
        try:
            lookback_setting = db.session.execute(
                select(Setting).filter_by(name='notification_lookback_minutes')
            ).scalar_one_or_none()
            lookback_minutes = int(lookback_setting.value) if lookback_setting else 30

            cutoff = datetime.datetime.now(datetime.UTC) - datetime.timedelta(minutes=lookback_minutes)
            cutoff_str = cutoff.strftime('%Y-%m-%d %H:%M:%S')

            # Get all monitored callsigns from the notifications table
            monitored = [
                n.flight for n in db.session.execute(select(Notification)).scalars()
            ]

            if not monitored:
                return {'flights': [], 'count': 0, 'lookback_minutes': lookback_minutes}, 200

            # Find flights seen within the lookback window whose callsign is monitored
            adsb_result = db.session.execute(
                select(Flight)
                .filter(
                    Flight.flight.in_(monitored),
                    Flight.last_seen >= cutoff_str
                )
                .order_by(Flight.last_seen.desc())
            )
            uat_result = db.session.execute(
                select(Dump978Flight)
                .filter(
                    Dump978Flight.flight.in_(monitored),
                    Dump978Flight.last_seen >= cutoff_str
                )
                .order_by(Dump978Flight.last_seen.desc())
            )

            seen_callsigns: set[str] = set()
            flights_data = []
            for f in adsb_result.scalars():
                if f.flight not in seen_callsigns:
                    seen_callsigns.add(f.flight)
                    d = f.to_dict()
                    d['type'] = 'adsb'
                    flights_data.append(d)
            for f in uat_result.scalars():
                if f.flight not in seen_callsigns:
                    seen_callsigns.add(f.flight)
                    d = f.to_dict()
                    d['type'] = 'uat'
                    flights_data.append(d)

            # Check ACARS database if available
            try:
                with open('config.yml') as f:
                    config = yaml.safe_load(f)
                acars_db_path = config.get('acars', {}).get('database', '/run/acarsdec.sqlite')
                acars_engine = create_engine(f'sqlite:///{acars_db_path}', connect_args={'check_same_thread': False})
                with acars_engine.connect() as conn:
                    placeholders = ','.join(f':m{i}' for i in range(len(monitored)))
                    params = {f'm{i}': v for i, v in enumerate(monitored)}
                    params['cutoff'] = cutoff_str
                    rows = conn.execute(
                        text(
                            f'SELECT FlightID, FlightNumber, StartTime, LastTime FROM Flights '
                            f'WHERE FlightNumber IN ({placeholders}) AND LastTime >= :cutoff '
                            f'ORDER BY LastTime DESC'
                        ),
                        params,
                    ).fetchall()
                for row in rows:
                    callsign = row[1]
                    if callsign and callsign not in seen_callsigns:
                        seen_callsigns.add(callsign)
                        flights_data.append({
                            'id': row[0],
                            'flight': callsign,
                            'type': 'acars',
                            'first_seen': str(row[2]) if row[2] else None,
                            'last_seen': str(row[3]) if row[3] else None,
                        })
            except OperationalError:
                pass  # ACARS database unavailable
            except FileNotFoundError:
                pass  # config.yml missing ACARS section

            return {
                'flights': flights_data,
                'count': len(flights_data),
                'lookback_minutes': lookback_minutes
            }, 200
        except Exception as ex:
            logging.error('Error encountered while trying to get recent notifications', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500



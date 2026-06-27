import datetime
import logging
import time

from flask import Blueprint, request
from flask_restx import Namespace, Resource, fields as restx_fields
from backend.auth import get_current_user, require_admin, require_user_or_admin
from backend.models import db, Aircraft, Flight, FlightComment, Position
from backend.routes.common import QueryParamError, get_stripped_arg, parse_pagination
from backend.routes.flight_common import (
    apply_flight_filters,
    can_modify_comment,
    get_sightings_counts,
    parse_ignore_on_purge,
    serialize_flights,
    validate_flight_comment_content,
)
from sqlalchemy import select, func, delete

flights = Blueprint('dump1090', __name__)
SIGHTING_GAP = datetime.timedelta(minutes=30)
TIMESTAMP_FORMAT = '%Y-%m-%d %H:%M:%S'

# Create Flask-RESTX namespaces for flight operations
adsb_ns = Namespace('adsb', description='ADS-B operations')
flights_ns = adsb_ns
flight_ns = adsb_ns

# Define API models for documentation
flight_model = flight_ns.model('Flight', {
    'id': restx_fields.Integer(description='Flight ID'),
    'aircraft': restx_fields.Integer(description='Aircraft ID'),
    'icao': restx_fields.String(description='Aircraft ICAO hex'),
    'flight': restx_fields.String(description='Flight number/callsign'),
    'first_seen': restx_fields.String(description='First seen timestamp'),
    'last_seen': restx_fields.String(description='Last seen timestamp'),
    'emitter_category': restx_fields.String(description='Emitter category (A0-D7) from decoder data'),
    'message_type': restx_fields.String(description='Decoder message type label'),
    'aircraft_class': restx_fields.String(description='Mapped aircraft class for iconography'),
    'ignore_on_purge': restx_fields.Boolean(description='Whether the flight is ignored by purge operations'),
    'sightings_count': restx_fields.Integer(description='Sightings count grouped by callsign with a 30-minute separation threshold'),
})

flights_list_model = flights_ns.model('FlightsList', {
    'flights': restx_fields.List(restx_fields.Nested(flight_model)),
    'offset': restx_fields.Integer(description='Pagination offset'),
    'limit': restx_fields.Integer(description='Pagination limit'),
    'count': restx_fields.Integer(description='Number of flights returned'),
    'total': restx_fields.Integer(description='Total number of flights matching filters')
})

flight_count_model = flights_ns.model('FlightCount', {
    'flights': restx_fields.Integer(description='Total number of flights')
})

# Position models for flight namespace
position_model = flight_ns.model('Position', {
    'id': restx_fields.Integer(description='Position ID'),
    'flight': restx_fields.Integer(description='Flight ID'),
    'aircraft': restx_fields.Integer(description='Aircraft ID'),
    'time': restx_fields.String(description='Timestamp'),
    'message': restx_fields.Integer(description='Message ID'),
    'squawk': restx_fields.Integer(description='Squawk code'),
    'latitude': restx_fields.Float(description='Latitude coordinate'),
    'longitude': restx_fields.Float(description='Longitude coordinate'),
    'track': restx_fields.Integer(description='Track heading'),
    'altitude': restx_fields.Integer(description='Altitude in feet'),
    'vertical_rate': restx_fields.Integer(description='Vertical rate'),
    'speed': restx_fields.Integer(description='Ground speed')
})

positions_list_model = flight_ns.model('PositionsList', {
    'positions': restx_fields.List(restx_fields.Nested(position_model)),
    'offset': restx_fields.Integer(description='Pagination offset'),
    'limit': restx_fields.Integer(description='Pagination limit'),
    'count': restx_fields.Integer(description='Number of positions returned'),
    'total': restx_fields.Integer(description='Total number of positions in the database for this flight')
})


def _serialize_adsb_flights(rows):
    return serialize_flights(rows, _get_adsb_sightings_counts)


def _get_adsb_sightings_counts(flights: list[str]):
    return get_sightings_counts(
        Flight,
        flights,
        gap=SIGHTING_GAP,
        timestamp_format=TIMESTAMP_FORMAT,
    )


def _parse_ignore_on_purge(value: str | None):
    return parse_ignore_on_purge(value)


def _apply_adsb_flight_filters(stmt, q: str | None, ignore_on_purge: bool | None):
    return apply_flight_filters(stmt, Flight, Aircraft, q, ignore_on_purge)


def _query_adsb_flights(q: str | None, offset: int, limit: int, ignore_on_purge: bool | None = None):
    query_started = time.perf_counter()
    base_stmt = select(Flight).join(Aircraft, Flight.aircraft == Aircraft.id)
    filtered_stmt = _apply_adsb_flight_filters(base_stmt, q=q, ignore_on_purge=ignore_on_purge)

    stmt = filtered_stmt.order_by(Flight.last_seen.desc(), Flight.flight)

    total = db.session.execute(
        select(func.count()).select_from(filtered_stmt.subquery())
    ).scalar_one()

    flights_result = db.session.execute(
        stmt.offset(offset).limit(limit)
    )
    elapsed_ms = (time.perf_counter() - query_started) * 1000
    logging.info(
        'adsb_query_flights q=%r offset=%d limit=%d ignore_on_purge=%r total=%d elapsed_ms=%.2f',
        q,
        offset,
        limit,
        ignore_on_purge,
        total,
        elapsed_ms,
    )
    return _serialize_adsb_flights(flights_result.scalars()), total


purge_result_model = flights_ns.model('PurgeResult', {
    'deleted_flights': restx_fields.Integer(description='Number of flights deleted'),
    'deleted_positions': restx_fields.Integer(description='Number of positions deleted'),
    'deleted_comments': restx_fields.Integer(description='Number of flight comments deleted'),
    'cutoff_date': restx_fields.String(description='Cutoff date used for deletion')
})

flight_comment_user_model = flights_ns.model('FlightCommentUser', {
    'id': restx_fields.Integer(description='User ID'),
    'name': restx_fields.String(description='Display name'),
})

flight_comment_model = flights_ns.model('FlightComment', {
    'id': restx_fields.Integer(description='Comment ID'),
    'flight_id': restx_fields.Integer(description='Flight table ID'),
    'user_id': restx_fields.Integer(description='Author user ID'),
    'content': restx_fields.String(description='Comment text'),
    'created_at': restx_fields.String(description='Creation timestamp'),
    'edited': restx_fields.Boolean(description='Whether the comment has been edited'),
    'edited_at': restx_fields.String(description='Last edit timestamp'),
    'user': restx_fields.Nested(flight_comment_user_model),
})

flight_comments_list_model = flights_ns.model('FlightCommentsList', {
    'flight': restx_fields.String(description='Flight callsign'),
    'count': restx_fields.Integer(description='Number of comments returned'),
    'comments': restx_fields.List(restx_fields.Nested(flight_comment_model)),
})

create_flight_comment_model = flights_ns.model('CreateFlightComment', {
    'content': restx_fields.String(required=True, description='Comment text', example='Interesting track over the lake.'),
})

update_flight_comment_model = flights_ns.model('UpdateFlightComment', {
    'content': restx_fields.String(required=True, description='Updated comment text', example='Updated moderation note.'),
})

flight_purge_preference_model = flights_ns.model('FlightPurgePreference', {
    'flight': restx_fields.String(description='Flight callsign'),
    'ignore_on_purge': restx_fields.Boolean(description='Whether the flight is ignored by purge operations'),
})

update_flight_purge_preference_model = flights_ns.model('UpdateFlightPurgePreference', {
    'ignore_on_purge': restx_fields.Boolean(required=True, description='Whether to exclude this flight from purge operations'),
})


def _purge_adsb_flights():
    """Delete flights (and their positions) older than X days. Admin only."""
    days = request.args.get('days', type=int)
    if days is None or days < 1:
        return {'msg': 'Bad Request - days parameter is required and must be a positive integer'}, 400

    cutoff = datetime.datetime.now(datetime.UTC) - datetime.timedelta(days=days)
    cutoff_str = cutoff.strftime('%Y-%m-%d %H:%M:%S')

    try:
        old_flight_ids = db.session.execute(
            select(Flight.id).where(
                ((Flight.last_seen < cutoff_str) | (Flight.last_seen.is_(None)))
                & (Flight.ignore_on_purge.is_(False))
            )
        ).scalars().all()

        if not old_flight_ids:
            return {'deleted_flights': 0, 'deleted_positions': 0, 'deleted_comments': 0, 'cutoff_date': cutoff_str}, 200

        deleted_comments = db.session.execute(
            delete(FlightComment).where(FlightComment.flight_id.in_(old_flight_ids))
        ).rowcount

        deleted_positions = db.session.execute(
            delete(Position).where(Position.flight.in_(old_flight_ids))
        ).rowcount

        deleted_flights = db.session.execute(
            delete(Flight).where(Flight.id.in_(old_flight_ids))
        ).rowcount

        db.session.commit()

        logging.info(f'Purged {deleted_flights} flights and {deleted_positions} positions older than {days} days (cutoff: {cutoff_str})')
        return {
            'deleted_flights': deleted_flights,
            'deleted_positions': deleted_positions,
            'deleted_comments': deleted_comments,
            'cutoff_date': cutoff_str
        }, 200

    except Exception as ex:
        db.session.rollback()
        logging.error('Error encountered while purging flights', exc_info=ex)
        return {'msg': 'Internal Server Error'}, 500


class AdsbFlightsController(Resource):
    """Unified controller for all ADS-B endpoints."""

    def get(self, flight=None):
        if flight is not None:
            if request.path.rstrip('/').endswith('/positions'):
                return self._get_flight_positions(flight)
            return self._get_flight(flight)

        path = request.path.rstrip('/')
        if path.endswith('/search'):
            return self._search_flights()
        if path.endswith('/count'):
            return self._get_flights_count()
        return self._list_flights()

    def _get_flight(self, flight):
        try:
            flight_obj = db.session.execute(select(Flight).filter_by(flight=flight)).scalar_one_or_none()
            if not flight_obj:
                return {'msg': 'Flight not found'}, 404

            data = flight_obj.to_dict()
            data['icao'] = flight_obj.aircraft_ref.icao if flight_obj.aircraft_ref else None
            data['sightings_count'] = _get_adsb_sightings_counts([flight_obj.flight]).get(flight_obj.flight, 1)
            return data, 200
        except Exception as ex:
            logging.error(f"Error encountered while trying to get flight {flight}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    def _get_flight_positions(self, flight):
        try:
            offset, limit = parse_pagination(request.args, default_limit=500, max_limit=1000)
        except QueryParamError as ex:
            return {'msg': str(ex)}, 400

        try:
            flight_obj = db.session.execute(select(Flight).filter_by(flight=flight)).scalar_one_or_none()
            if not flight_obj:
                return {'msg': 'Flight not found'}, 404

            positions_result = db.session.execute(
                select(Position)
                .filter_by(flight=flight_obj.id)
                .order_by(Position.time)
                .offset(offset)
                .limit(limit)
            )
            positions = [pos.to_dict() for pos in positions_result.scalars()]
            total = db.session.execute(
                select(func.count(Position.id)).where(Position.flight == flight_obj.id)
            ).scalar_one()

            return {
                'offset': offset,
                'limit': limit,
                'count': len(positions),
                'total': total,
                'positions': positions
            }, 200

        except Exception as ex:
            logging.error(f"Error encountered while trying to get flight positions for flight {flight}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    def _search_flights(self):
        request_started = time.perf_counter()
        q = get_stripped_arg(request.args, 'q')
        if not q:
            return {'msg': 'Bad Request - search query required'}, 400

        ignore_param = request.args.get('ignore_on_purge', default=None, type=str)
        try:
            ignore_on_purge = _parse_ignore_on_purge(ignore_param)
        except ValueError:
            return {'msg': 'Bad Request - ignore_on_purge must be true, false, 1, or 0'}, 400

        try:
            flights_data, total = _query_adsb_flights(
                q=q,
                offset=0,
                limit=100,
                ignore_on_purge=ignore_on_purge,
            )
            return {
                'offset': 0,
                'limit': 100,
                'count': len(flights_data),
                'total': total,
                'flights': flights_data
            }, 200
        except Exception as ex:
            logging.error(f'Error encountered while searching flights for query: {q}', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500
        finally:
            elapsed_ms = (time.perf_counter() - request_started) * 1000
            logging.info('adsb_search_request q=%r elapsed_ms=%.2f', q, elapsed_ms)

    def _list_flights(self):
        request_started = time.perf_counter()
        try:
            offset, limit = parse_pagination(request.args, default_limit=50, max_limit=100)
        except QueryParamError as ex:
            return {'msg': str(ex)}, 400

        ignore_param = request.args.get('ignore_on_purge', default=None, type=str)
        try:
            ignore_on_purge = _parse_ignore_on_purge(ignore_param)
        except ValueError:
            return {'msg': 'Bad Request - ignore_on_purge must be true, false, 1, or 0'}, 400

        try:
            q = get_stripped_arg(request.args, 'q')
            flights_data, total = _query_adsb_flights(
                q=q or None,
                offset=offset,
                limit=limit,
                ignore_on_purge=ignore_on_purge,
            )
            return {
                'offset': offset,
                'limit': limit,
                'count': len(flights_data),
                'total': total,
                'flights': flights_data
            }, 200

        except Exception as ex:
            logging.error('Error encountered while trying to get flights', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500
        finally:
            elapsed_ms = (time.perf_counter() - request_started) * 1000
            logging.info('adsb_list_request q=%r offset=%d limit=%d elapsed_ms=%.2f', q if 'q' in locals() else '', offset, limit, elapsed_ms)

    def _get_flights_count(self):
        try:
            count_result = db.session.execute(select(db.func.count(Flight.id)))
            count = count_result.scalar()
            return {'flights': count}, 200
        except Exception as ex:
            logging.error('Error encountered while trying to get flight count', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500



class AdsbFlightsPurgeController(Resource):
    @flights_ns.marshal_with(purge_result_model, code=200)
    @flights_ns.response(400, 'Bad request - days parameter is required and must be a positive integer')
    @flights_ns.response(401, 'Unauthorized - authentication required')
    @flights_ns.response(403, 'Forbidden - admin role required')
    @flights_ns.response(500, 'Internal server error')
    @flights_ns.param('days', 'Number of days of history to keep before purging older flights', _in='query', type='integer', required=True)
    @flights_ns.doc('purge_adsb_flights', security='Bearer')
    @require_admin()
    def delete(self):
        """Purge ADS-B flights and positions older than the supplied number of days (Admin only)"""
        return _purge_adsb_flights()


@flight_ns.route('/flight/<string:flight>/purge-preference')
class AdsbFlightPurgePreferenceController(Resource):
    @flight_ns.response(200, 'Purge preference updated successfully', flight_purge_preference_model)
    @flight_ns.response(400, 'Bad request - ignore_on_purge is required')
    @flight_ns.response(401, 'Unauthorized - authentication required')
    @flight_ns.response(403, 'Forbidden - admin role required')
    @flight_ns.response(404, 'Flight not found')
    @flight_ns.response(500, 'Internal server error')
    @flight_ns.expect((update_flight_purge_preference_model, 'Purge preference update payload. Admin only.'), validate=True)
    @flight_ns.doc('update_adsb_flight_purge_preference', security='Bearer')
    @require_admin()
    def put(self, flight):
        """Update whether an ADS-B flight is ignored during purge operations (Admin only)"""
        payload = request.json or {}
        if 'ignore_on_purge' not in payload:
            return {'msg': 'Bad Request - ignore_on_purge is required'}, 400

        try:
            flight_obj = db.session.execute(select(Flight).filter_by(flight=flight)).scalar_one_or_none()
            if not flight_obj:
                return {'msg': 'Flight not found'}, 404

            flight_obj.ignore_on_purge = bool(payload.get('ignore_on_purge'))
            db.session.commit()
            return {
                'flight': flight_obj.flight,
                'ignore_on_purge': flight_obj.ignore_on_purge,
            }, 200
        except Exception as ex:
            db.session.rollback()
            logging.error(f'Error encountered while updating purge preference for ADS-B flight {flight}', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@flight_ns.route('/flight/<string:flight>/comments')
class AdsbFlightCommentsController(Resource):
    @flight_ns.response(200, 'Comments retrieved successfully', flight_comments_list_model)
    @flight_ns.response(404, 'Flight not found')
    @flight_ns.response(500, 'Internal server error')
    @flight_ns.doc('get_adsb_flight_comments')
    def get(self, flight):
        """Get comments for an ADS-B flight (public)"""
        try:
            flight_obj = db.session.execute(select(Flight).filter_by(flight=flight)).scalar_one_or_none()
            if not flight_obj:
                return {'msg': 'Flight not found'}, 404

            comments = db.session.execute(
                select(FlightComment)
                .where(FlightComment.flight_id == flight_obj.id)
                .order_by(FlightComment.created_at.asc(), FlightComment.id.asc())
            ).scalars().all()

            return {
                'flight': flight,
                'count': len(comments),
                'comments': [comment.to_dict() for comment in comments],
            }, 200
        except Exception as ex:
            logging.error(f'Error encountered while trying to get comments for ADS-B flight {flight}', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    @flight_ns.expect((create_flight_comment_model, 'Comment content. Requires authenticated unlocked user or admin.'), validate=True)
    @flight_ns.response(201, 'Comment created successfully', flight_comment_model)
    @flight_ns.response(400, 'Bad request - comment content is required')
    @flight_ns.response(401, 'Unauthorized - authentication required')
    @flight_ns.response(403, 'Forbidden - account is locked or role is invalid')
    @flight_ns.response(404, 'Flight not found')
    @flight_ns.response(500, 'Internal server error')
    @flight_ns.doc('create_adsb_flight_comment', security='Bearer')
    @require_user_or_admin()
    def post(self, flight):
        """Create a comment for an ADS-B flight (authenticated unlocked user/admin)"""
        content, error_body, error_status = validate_flight_comment_content(
            (request.json or {}).get('content', '')
        )
        if error_body:
            return error_body, error_status

        try:
            flight_obj = db.session.execute(select(Flight).filter_by(flight=flight)).scalar_one_or_none()
            if not flight_obj:
                return {'msg': 'Flight not found'}, 404

            current_user = get_current_user()
            if not current_user:
                return {'msg': 'User not found'}, 401

            new_comment = FlightComment(
                flight_id=flight_obj.id,
                user_id=current_user.id,
                content=content,
            )
            db.session.add(new_comment)
            db.session.commit()
            return new_comment.to_dict(), 201
        except Exception as ex:
            db.session.rollback()
            logging.error(f'Error encountered while trying to create comment for ADS-B flight {flight}', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@flight_ns.route('/flight/<string:flight>/comments/<int:comment_id>')
class AdsbFlightCommentModerationController(Resource):
    @flight_ns.expect((update_flight_comment_model, 'Updated comment content. Requires authenticated unlocked comment owner or admin.'), validate=True)
    @flight_ns.response(200, 'Comment updated successfully', flight_comment_model)
    @flight_ns.response(400, 'Bad request - content is required')
    @flight_ns.response(401, 'Unauthorized - authentication required')
    @flight_ns.response(403, 'Forbidden - only the comment owner or admin may edit')
    @flight_ns.response(404, 'Flight or comment not found')
    @flight_ns.response(500, 'Internal server error')
    @flight_ns.doc('update_adsb_flight_comment', security='Bearer')
    @require_user_or_admin()
    def put(self, flight, comment_id):
        """Update an ADS-B flight comment (comment owner or admin)"""
        content, error_body, error_status = validate_flight_comment_content(
            (request.json or {}).get('content', '')
        )
        if error_body:
            return error_body, error_status

        try:
            flight_obj = db.session.execute(select(Flight).filter_by(flight=flight)).scalar_one_or_none()
            if not flight_obj:
                return {'msg': 'Flight not found'}, 404

            comment = db.session.get(FlightComment, comment_id)
            if not comment or comment.flight_id != flight_obj.id:
                return {'msg': 'Comment not found for this flight'}, 404

            current_user = get_current_user()
            if not current_user:
                return {'msg': 'User not found'}, 401
            if not can_modify_comment(current_user, comment):
                return {'msg': 'Access denied. You can only edit your own comments'}, 403

            comment.content = content
            comment.edited = True
            comment.edited_at = datetime.datetime.now(datetime.UTC)
            db.session.commit()
            return comment.to_dict(), 200
        except Exception as ex:
            db.session.rollback()
            logging.error(f'Error encountered while trying to update comment {comment_id} for ADS-B flight {flight}', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    @flight_ns.response(204, 'Comment deleted successfully')
    @flight_ns.response(401, 'Unauthorized - authentication required')
    @flight_ns.response(403, 'Forbidden - admin role required')
    @flight_ns.response(404, 'Flight or comment not found')
    @flight_ns.response(500, 'Internal server error')
    @flight_ns.doc('delete_adsb_flight_comment', security='Bearer')
    @require_admin()
    def delete(self, flight, comment_id):
        """Delete an ADS-B flight comment (Admin only)"""
        try:
            flight_obj = db.session.execute(select(Flight).filter_by(flight=flight)).scalar_one_or_none()
            if not flight_obj:
                return {'msg': 'Flight not found'}, 404

            comment = db.session.get(FlightComment, comment_id)
            if not comment or comment.flight_id != flight_obj.id:
                return {'msg': 'Comment not found for this flight'}, 404

            db.session.delete(comment)
            db.session.commit()
            return {'msg': 'Comment deleted successfully'}, 200
        except Exception as ex:
            db.session.rollback()
            logging.error(f'Error encountered while trying to delete comment {comment_id} for ADS-B flight {flight}', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


class AdsbFlightsListResource(AdsbFlightsController):
    @flights_ns.marshal_with(flights_list_model, code=200)
    @flights_ns.response(400, 'Bad request - invalid offset, limit, or ignore_on_purge parameter')
    @flights_ns.response(500, 'Internal server error')
    @flights_ns.doc('list_adsb_flights', params={
        'offset': {'description': 'Number of flights to skip for pagination', 'type': 'integer', 'in': 'query', 'default': 0},
        'limit': {'description': 'Maximum number of flights to return', 'type': 'integer', 'in': 'query', 'default': 50, 'minimum': 1, 'maximum': 100},
        'q': {'description': 'Optional flight callsign or ICAO search query', 'type': 'string', 'in': 'query'},
        'ignore_on_purge': {'description': 'Optional purge-protection filter: true, false, 1, or 0', 'type': 'boolean', 'in': 'query'},
    })
    def get(self):
        """List ADS-B flights."""
        return self._list_flights()


class AdsbFlightsSearchResource(AdsbFlightsController):
    @flights_ns.marshal_with(flights_list_model, code=200)
    @flights_ns.response(400, 'Bad request - q is required or ignore_on_purge is invalid')
    @flights_ns.response(500, 'Internal server error')
    @flights_ns.doc('search_adsb_flights', params={
        'q': {'description': 'Required flight callsign or ICAO search query', 'type': 'string', 'in': 'query', 'required': True},
        'ignore_on_purge': {'description': 'Optional purge-protection filter: true, false, 1, or 0', 'type': 'boolean', 'in': 'query'},
    })
    def get(self):
        """Search ADS-B flights by callsign or ICAO."""
        return self._search_flights()


class AdsbFlightsCountResource(AdsbFlightsController):
    @flights_ns.marshal_with(flight_count_model, code=200)
    @flights_ns.response(500, 'Internal server error')
    @flights_ns.doc('count_adsb_flights')
    def get(self):
        """Count ADS-B flights."""
        return self._get_flights_count()


class AdsbFlightResource(AdsbFlightsController):
    @flight_ns.marshal_with(flight_model, code=200)
    @flight_ns.response(404, 'Flight not found')
    @flight_ns.response(500, 'Internal server error')
    @flight_ns.doc('get_adsb_flight', params={
        'flight': {'description': 'Flight callsign to retrieve', 'type': 'string', 'in': 'path', 'required': True},
    })
    def get(self, flight):
        """Get one ADS-B flight by callsign."""
        return self._get_flight(flight)


class AdsbFlightPositionsResource(AdsbFlightsController):
    @flight_ns.marshal_with(positions_list_model, code=200)
    @flight_ns.response(400, 'Bad request - invalid offset or limit parameters')
    @flight_ns.response(404, 'Flight not found')
    @flight_ns.response(500, 'Internal server error')
    @flight_ns.doc('get_adsb_flight_positions', params={
        'flight': {'description': 'Flight callsign whose positions should be returned', 'type': 'string', 'in': 'path', 'required': True},
        'offset': {'description': 'Number of positions to skip for pagination', 'type': 'integer', 'in': 'query', 'default': 0},
        'limit': {'description': 'Maximum number of positions to return', 'type': 'integer', 'in': 'query', 'default': 500, 'minimum': 1, 'maximum': 1000},
    })
    def get(self, flight):
        """Get ADS-B positions for one flight."""
        return self._get_flight_positions(flight)


flights_ns.add_resource(AdsbFlightsListResource, '/flights')
flights_ns.add_resource(AdsbFlightsSearchResource, '/flights/search')
flights_ns.add_resource(AdsbFlightsCountResource, '/flights/count')
flights_ns.add_resource(AdsbFlightsPurgeController, '/flights/purge')

flight_ns.add_resource(AdsbFlightResource, '/flight/<string:flight>')
flight_ns.add_resource(AdsbFlightPositionsResource, '/flight/<string:flight>/positions')

flight_ns.add_resource(
    AdsbFlightCommentsController,
    '/flight/<string:flight>/comments',
)

flight_ns.add_resource(
    AdsbFlightCommentModerationController,
    '/flight/<string:flight>/comments/<int:comment_id>',
)

flight_ns.add_resource(
    AdsbFlightPurgePreferenceController,
    '/flight/<string:flight>/purge-preference',
)


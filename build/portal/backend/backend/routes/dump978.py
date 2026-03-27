import datetime
import logging

from flask import Blueprint, request
from flask_restx import Namespace, Resource, fields as restx_fields
from backend.auth import require_admin
from backend.models import db, Dump978Aircraft, Dump978Flight, Dump978Position
from sqlalchemy import select, delete, or_

uat = Blueprint('dump978', __name__)

# Create Flask-RESTX namespaces for UAT flight operations
uat_ns = Namespace('uat', description='UAT operations')
uat_flights_ns = uat_ns
uat_flight_ns = uat_ns

# Define API models for documentation
uat_flight_model = uat_flight_ns.model('UATFlight', {
    'id':         restx_fields.Integer(description='Flight ID'),
    'aircraft':   restx_fields.Integer(description='Aircraft ID'),
    'icao':       restx_fields.String( description='Aircraft ICAO hex'),
    'flight':     restx_fields.String( description='Flight number/callsign'),
    'first_seen': restx_fields.String( description='First seen timestamp'),
    'last_seen':  restx_fields.String( description='Last seen timestamp'),
})

uat_flights_list_model = uat_flights_ns.model('UATFlightsList', {
    'flights': restx_fields.List(restx_fields.Nested(uat_flight_model)),
    'offset':  restx_fields.Integer(description='Pagination offset'),
    'limit':   restx_fields.Integer(description='Pagination limit'),
    'count':   restx_fields.Integer(description='Number of flights returned'),
})

uat_flight_count_model = uat_flights_ns.model('UATFlightCount', {
    'flights': restx_fields.Integer(description='Total number of UAT flights'),
})

# Position model — flight and message are nullable for UAT
uat_position_model = uat_flight_ns.model('UATPosition', {
    'id':            restx_fields.Integer(description='Position ID'),
    'flight':        restx_fields.Integer(description='Flight ID (nullable)', required=False),
    'aircraft':      restx_fields.Integer(description='Aircraft ID'),
    'time':          restx_fields.String( description='Timestamp'),
    'message':       restx_fields.Integer(description='Message count (nullable)', required=False),
    'squawk':        restx_fields.Integer(description='Squawk code'),
    'latitude':      restx_fields.Float(  description='Latitude coordinate'),
    'longitude':     restx_fields.Float(  description='Longitude coordinate'),
    'track':         restx_fields.Integer(description='Track heading'),
    'altitude':      restx_fields.Integer(description='Altitude in feet'),
    'vertical_rate': restx_fields.Integer(description='Vertical rate'),
    'speed':         restx_fields.Integer(description='Ground speed'),
})

uat_positions_list_model = uat_flight_ns.model('UATPositionsList', {
    'positions': restx_fields.List(restx_fields.Nested(uat_position_model)),
    'offset':    restx_fields.Integer(description='Pagination offset'),
    'limit':     restx_fields.Integer(description='Pagination limit'),
    'count':     restx_fields.Integer(description='Number of positions returned'),
})

uat_purge_result_model = uat_flights_ns.model('UATPurgeResult', {
    'deleted_flights':   restx_fields.Integer(description='Number of flights deleted'),
    'deleted_positions': restx_fields.Integer(description='Number of positions deleted'),
    'cutoff_date':       restx_fields.String( description='Cutoff date used for deletion'),
})


def _purge_uat_flights():
    """Delete UAT flights (and their positions) older than X days. Admin only."""
    days = request.args.get('days', type=int)
    if days is None or days < 1:
        return {'msg': 'Bad Request - days parameter is required and must be a positive integer'}, 400

    cutoff = datetime.datetime.now(datetime.UTC) - datetime.timedelta(days=days)
    cutoff_str = cutoff.strftime('%Y-%m-%d %H:%M:%S')

    try:
        old_flight_ids = db.session.execute(
            select(Dump978Flight.id).where(
                (Dump978Flight.last_seen < cutoff_str) | (Dump978Flight.last_seen.is_(None))
            )
        ).scalars().all()

        if not old_flight_ids:
            return {'deleted_flights': 0, 'deleted_positions': 0, 'cutoff_date': cutoff_str}, 200

        deleted_positions = db.session.execute(
            delete(Dump978Position).where(Dump978Position.flight.in_(old_flight_ids))
        ).rowcount

        deleted_flights = db.session.execute(
            delete(Dump978Flight).where(Dump978Flight.id.in_(old_flight_ids))
        ).rowcount

        db.session.commit()

        logging.info(
            f'Purged {deleted_flights} UAT flights and {deleted_positions} positions '
            f'older than {days} days (cutoff: {cutoff_str})'
        )
        return {
            'deleted_flights': deleted_flights,
            'deleted_positions': deleted_positions,
            'cutoff_date': cutoff_str,
        }, 200

    except Exception as ex:
        db.session.rollback()
        logging.error('Error encountered while purging UAT flights', exc_info=ex)
        return {'msg': 'Internal Server Error'}, 500


def _serialize_uat_flights(rows):
    flights_data = []
    for flight_obj in rows:
        data = flight_obj.to_dict()
        data['icao'] = flight_obj.aircraft_ref.icao if flight_obj.aircraft_ref else None
        flights_data.append(data)
    return flights_data


def _query_uat_flights(q: str | None, offset: int, limit: int):
    stmt = (
        select(Dump978Flight)
        .join(Dump978Aircraft, Dump978Flight.aircraft == Dump978Aircraft.id)
        .order_by(Dump978Flight.last_seen.desc(), Dump978Flight.flight)
    )

    if q:
        stmt = stmt.filter(
            or_(
                Dump978Flight.flight.ilike(f'%{q}%'),
                Dump978Aircraft.icao.ilike(f'%{q}%')
            )
        )

    flights_result = db.session.execute(stmt.offset(offset).limit(limit))
    return _serialize_uat_flights(flights_result.scalars())


class UatFlightsController(Resource):
    """Unified controller for all UAT endpoints."""

    def get(self, flight=None):
        if flight is not None:
            if request.path.rstrip('/').endswith('/positions'):
                return self._get_uat_flight_positions(flight)
            return self._get_uat_flight(flight)

        path = request.path.rstrip('/')
        if path.endswith('/search'):
            return self._search_uat_flights()
        if path.endswith('/count'):
            return self._get_uat_flights_count()
        return self._list_uat_flights()

    def _get_uat_flight(self, flight):
        try:
            flight_obj = db.session.execute(
                select(Dump978Flight).filter_by(flight=flight)
            ).scalar_one_or_none()

            if not flight_obj:
                return {'msg': 'Flight not found'}, 404

            data = flight_obj.to_dict()
            data['icao'] = flight_obj.aircraft_ref.icao if flight_obj.aircraft_ref else None
            return data, 200
        except Exception as ex:
            logging.error(f'Error encountered while trying to get UAT flight {flight}', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    def _get_uat_flight_positions(self, flight):
        offset = request.args.get('offset', default=0, type=int)
        limit = request.args.get('limit', default=500, type=int)

        if offset < 0 or limit < 1 or limit > 1000:
            return {'msg': 'Bad Request - invalid offset or limit parameters'}, 400

        try:
            flight_obj = db.session.execute(
                select(Dump978Flight).filter_by(flight=flight)
            ).scalar_one_or_none()

            if not flight_obj:
                return {'msg': 'Flight not found'}, 404

            positions_result = db.session.execute(
                select(Dump978Position)
                .filter_by(flight=flight_obj.id)
                .order_by(Dump978Position.time)
                .offset(offset)
                .limit(limit)
            )
            positions = [pos.to_dict() for pos in positions_result.scalars()]

            return {
                'offset': offset,
                'limit': limit,
                'count': len(positions),
                'positions': positions,
            }, 200
        except Exception as ex:
            logging.error(f'Error encountered while trying to get UAT flight positions for {flight}', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    def _search_uat_flights(self):
        q = request.args.get('q', '', type=str).strip()
        if not q:
            return {'msg': 'Bad Request - search query required'}, 400
        try:
            flights_data = _query_uat_flights(q=q, offset=0, limit=100)
            return {
                'offset': 0,
                'limit': 100,
                'count': len(flights_data),
                'flights': flights_data,
            }, 200
        except Exception as ex:
            logging.error(f'Error encountered while searching UAT flights for query: {q}', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    def _list_uat_flights(self):
        offset = request.args.get('offset', default=0, type=int)
        limit = request.args.get('limit', default=50, type=int)

        if offset < 0 or limit < 1 or limit > 100:
            return {'msg': 'Bad Request - invalid offset or limit parameters'}, 400

        try:
            q = request.args.get('q', default='', type=str).strip()
            flights_data = _query_uat_flights(q=q or None, offset=offset, limit=limit)
            return {
                'offset': offset,
                'limit': limit,
                'count': len(flights_data),
                'flights': flights_data,
            }, 200
        except Exception as ex:
            logging.error('Error encountered while trying to get UAT flights', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    def _get_uat_flights_count(self):
        try:
            count = db.session.execute(select(db.func.count(Dump978Flight.id))).scalar()
            return {'flights': count}, 200
        except Exception as ex:
            logging.error('Error encountered while trying to get UAT flight count', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500



class UatFlightsPurgeController(Resource):
    @uat_flights_ns.marshal_with(uat_purge_result_model, code=200)
    @uat_flights_ns.response(400, 'Bad request - days parameter is required and must be a positive integer')
    @uat_flights_ns.response(401, 'Unauthorized - authentication required')
    @uat_flights_ns.response(403, 'Forbidden - admin role required')
    @uat_flights_ns.response(500, 'Internal server error')
    @uat_flights_ns.doc('purge_uat_flights', security='Bearer')
    @require_admin()
    def delete(self):
        """Purge UAT flights and positions older than the supplied number of days (Admin only)"""
        return _purge_uat_flights()


uat_flights_ns.add_resource(
    UatFlightsController,
    '/flights',
    '/flights/search',
    '/flights/count',
)

uat_flights_ns.add_resource(UatFlightsPurgeController, '/flights/purge')

uat_flight_ns.add_resource(
    UatFlightsController,
    '/flight/<string:flight>',
    '/flight/<string:flight>/positions',
)

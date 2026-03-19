import datetime
import logging

from flask import abort, Blueprint, jsonify, request
from flask_restx import Namespace, Resource, fields as restx_fields
from backend.auth import require_admin
from backend.models import db, Flight, Position
from werkzeug.exceptions import HTTPException
from sqlalchemy import select, func, delete

flights = Blueprint('flights', __name__)

# Create Flask-RESTX namespaces for flight operations
flights_ns = Namespace('flights', description='Flight list operations')
flight_ns = Namespace('flight', description='Individual flight operations')

# Define API models for documentation
flight_model = flight_ns.model('Flight', {
    'id': restx_fields.Integer(description='Flight ID'),
    'aircraft': restx_fields.Integer(description='Aircraft ID'),
    'flight': restx_fields.String(description='Flight number/callsign'),
    'first_seen': restx_fields.String(description='First seen timestamp'),
    'last_seen': restx_fields.String(description='Last seen timestamp')
})

flights_list_model = flights_ns.model('FlightsList', {
    'flights': restx_fields.List(restx_fields.Nested(flight_model)),
    'offset': restx_fields.Integer(description='Pagination offset'),
    'limit': restx_fields.Integer(description='Pagination limit'),
    'count': restx_fields.Integer(description='Number of flights returned')
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
    'count': restx_fields.Integer(description='Number of positions returned')
})


@flight_ns.route('/<string:flight>')
class FlightResource(Resource):
    @flight_ns.marshal_with(flight_model, code=200)
    @flight_ns.response(404, 'Flight not found')
    @flight_ns.response(500, 'Internal server error')
    @flight_ns.doc('get_flight')
    def get(self, flight):
        """Get flight details by callsign/flight number"""
        try:
            flight_obj = db.session.execute(select(Flight).filter_by(flight=flight)).scalar_one_or_none()
            
            if not flight_obj:
                return {'msg': 'Flight not found'}, 404
                
            return flight_obj.to_dict(), 200
        except Exception as ex:
            logging.error(f"Error encountered while trying to get flight {flight}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@flight_ns.route('/<string:flight>/positions')
class FlightPositionsResource(Resource):
    @flight_ns.marshal_with(positions_list_model, code=200)
    @flight_ns.response(400, 'Bad request - invalid offset or limit parameters')
    @flight_ns.response(404, 'Flight not found')
    @flight_ns.response(500, 'Internal server error')
    @flight_ns.doc('get_flight_positions', params={
        'offset': 'Pagination offset (default: 0)',
        'limit': 'Number of positions to return (default: 500, max: 1000)'
    })
    def get(self, flight):
        """Get positions for a specific flight"""
        offset = request.args.get('offset', default=0, type=int)
        limit = request.args.get('limit', default=500, type=int)
        
        if offset < 0 or limit < 1 or limit > 1000:
            return {'msg': 'Bad Request - invalid offset or limit parameters'}, 400

        try:
            # Check if flight exists
            flight_obj = db.session.execute(select(Flight).filter_by(flight=flight)).scalar_one_or_none()
            if not flight_obj:
                return {'msg': 'Flight not found'}, 404

            # Get positions for this flight
            positions_result = db.session.execute(
                select(Position)
                .filter_by(flight=flight_obj.id)
                .order_by(Position.time)
                .offset(offset)
                .limit(limit)
            )
            positions = [pos.to_dict() for pos in positions_result.scalars()]
            
            return {
                'offset': offset,
                'limit': limit,
                'count': len(positions),
                'positions': positions
            }, 200
            
        except Exception as ex:
            logging.error(f"Error encountered while trying to get flight positions for flight {flight}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@flights_ns.route('/search')
class FlightsSearchResource(Resource):
    @flights_ns.marshal_with(flights_list_model, code=200)
    @flights_ns.response(400, 'Bad request - search query required')
    @flights_ns.response(500, 'Internal server error')
    @flights_ns.doc('search_flights', params={'q': 'Partial flight number or callsign to search for'})
    def get(self):
        """Search flights by partial flight number or callsign"""
        q = request.args.get('q', '', type=str).strip()
        if not q:
            return {'msg': 'Bad Request - search query required'}, 400
        try:
            flights_result = db.session.execute(
                select(Flight)
                .filter(Flight.flight.ilike(f'%{q}%'))
                .order_by(Flight.last_seen.desc(), Flight.flight)
                .limit(100)
            )
            flights_data = [flight_obj.to_dict() for flight_obj in flights_result.scalars()]
            return {
                'offset': 0,
                'limit': 100,
                'count': len(flights_data),
                'flights': flights_data
            }, 200
        except Exception as ex:
            logging.error(f'Error encountered while searching flights for query: {q}', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@flights_ns.route('')
class FlightsListResource(Resource):
    @flights_ns.marshal_with(flights_list_model, code=200)
    @flights_ns.response(400, 'Bad request - invalid offset or limit parameters')
    @flights_ns.response(500, 'Internal server error')
    @flights_ns.doc('get_flights_list', params={
        'offset': 'Pagination offset (default: 0)',
        'limit': 'Number of flights to return (default: 50, max: 100)'
    })
    def get(self):
        """Get list of flights with pagination"""
        offset = request.args.get('offset', default=0, type=int)
        limit = request.args.get('limit', default=50, type=int)
        
        if offset < 0 or limit < 1 or limit > 100:
            return {'msg': 'Bad Request - invalid offset or limit parameters'}, 400

        try:
            flights_result = db.session.execute(
                select(Flight)
                .order_by(Flight.last_seen.desc(), Flight.flight)
                .offset(offset)
                .limit(limit)
            )
            flights_data = [flight_obj.to_dict() for flight_obj in flights_result.scalars()]
            
            return {
                'offset': offset,
                'limit': limit,
                'count': len(flights_data),
                'flights': flights_data
            }, 200
            
        except Exception as ex:
            logging.error('Error encountered while trying to get flights', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@flights_ns.route('/count')
class FlightsCountResource(Resource):
    @flights_ns.marshal_with(flight_count_model, code=200)
    @flights_ns.response(500, 'Internal server error')
    @flights_ns.doc('get_flights_count')
    def get(self):
        """Get total count of flights"""
        try:
            count_result = db.session.execute(select(db.func.count(Flight.id)))
            count = count_result.scalar()
            return {'flights': count}, 200
        except Exception as ex:
            logging.error('Error encountered while trying to get flight count', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


purge_result_model = flights_ns.model('PurgeResult', {
    'deleted_flights': restx_fields.Integer(description='Number of flights deleted'),
    'deleted_positions': restx_fields.Integer(description='Number of positions deleted'),
    'cutoff_date': restx_fields.String(description='Cutoff date used for deletion')
})


@flights_ns.route('/purge')
class FlightsPurgeResource(Resource):
    @require_admin()
    @flights_ns.marshal_with(purge_result_model, code=200)
    @flights_ns.response(400, 'Bad request - invalid days parameter')
    @flights_ns.response(401, 'Unauthorized')
    @flights_ns.response(403, 'Forbidden - Admin role required')
    @flights_ns.response(500, 'Internal server error')
    @flights_ns.doc('purge_old_flights', security='Bearer', params={
        'days': 'Delete flights whose last_seen is older than this many days (must be >= 1)'
    })
    def delete(self):
        """Delete flights (and their positions) older than X days. Admin only."""
        days = request.args.get('days', type=int)
        if days is None or days < 1:
            return {'msg': 'Bad Request - days parameter is required and must be a positive integer'}, 400

        cutoff = datetime.datetime.now(datetime.UTC) - datetime.timedelta(days=days)
        cutoff_str = cutoff.strftime('%Y-%m-%d %H:%M:%S')

        try:
            old_flight_ids = db.session.execute(
                select(Flight.id).where(
                    (Flight.last_seen < cutoff_str) | (Flight.last_seen.is_(None))
                )
            ).scalars().all()

            if not old_flight_ids:
                return {'deleted_flights': 0, 'deleted_positions': 0, 'cutoff_date': cutoff_str}, 200

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
                'cutoff_date': cutoff_str
            }, 200

        except Exception as ex:
            db.session.rollback()
            logging.error('Error encountered while purging flights', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


import logging

from flask import abort, Blueprint, jsonify, request
from flask_restx import Namespace, Resource, fields as restx_fields
from backend.models import db, Flight, Position
from werkzeug.exceptions import HTTPException
from sqlalchemy import select, func

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


import logging

from flask import abort, Blueprint, jsonify, request
from flask_restx import Namespace, Resource, fields as restx_fields
from backend.models import db, Aircraft, Position
from werkzeug.exceptions import HTTPException
from sqlalchemy import select

aircraft = Blueprint('aircraft', __name__)

# Create Flask-RESTX namespace for aircraft operations
aircraft_ns = Namespace('adsb/aircraft', description='Aircraft tracking and position data')

# Define API models for documentation
position_model = aircraft_ns.model('Position', {
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

aircraft_model = aircraft_ns.model('Aircraft', {
    'id': restx_fields.Integer(description='Aircraft ID'),
    'icao': restx_fields.String(description='ICAO code'),
    'first_seen': restx_fields.String(description='First seen timestamp'),
    'last_seen': restx_fields.String(description='Last seen timestamp')
})

aircraft_list_model = aircraft_ns.model('AircraftList', {
    'aircraft': restx_fields.List(restx_fields.Nested(aircraft_model)),
    'offset': restx_fields.Integer(description='Pagination offset'),
    'limit': restx_fields.Integer(description='Pagination limit'),
    'count': restx_fields.Integer(description='Number of aircraft returned')
})

positions_list_model = aircraft_ns.model('PositionsList', {
    'positions': restx_fields.List(restx_fields.Nested(position_model)),
    'offset': restx_fields.Integer(description='Pagination offset'),
    'limit': restx_fields.Integer(description='Pagination limit'),
    'count': restx_fields.Integer(description='Number of positions returned')
})

aircraft_count_model = aircraft_ns.model('AircraftCount', {
    'aircraft': restx_fields.Integer(description='Total number of aircraft')
})


@aircraft_ns.route('/<string:icao>')
class AircraftByIcaoResource(Resource):
    @aircraft_ns.response(200, 'Aircraft retrieved successfully')
    @aircraft_ns.response(404, 'Aircraft not found')
    @aircraft_ns.response(500, 'Internal server error')
    @aircraft_ns.doc('get_aircraft_by_icao')
    def get(self, icao):
        """Get aircraft details by ICAO code"""
        try:
            aircraft_obj = db.session.execute(select(Aircraft).filter_by(icao=icao)).scalar_one_or_none()
            
            if not aircraft_obj:
                return {'msg': 'Aircraft not found'}, 404
                
            response = jsonify(aircraft_obj.to_dict())
            response.headers['Access-Control-Allow-Origin'] = '*'
            return response
        except Exception as ex:
            logging.error(f"Error encountered while trying to get aircraft using ICAO {icao}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@aircraft_ns.route('/<string:icao>/positions')
class AircraftPositionsResource(Resource):
    @aircraft_ns.response(200, 'Aircraft positions retrieved successfully')
    @aircraft_ns.response(400, 'Bad request - invalid offset or limit parameters')
    @aircraft_ns.response(404, 'Aircraft not found')
    @aircraft_ns.response(500, 'Internal server error')
    @aircraft_ns.doc('get_aircraft_positions', params={
        'offset': 'Pagination offset (default: 0)',
        'limit': 'Number of positions to return (default: 500, max: 1000)'
    })
    def get(self, icao):
        """Get positions for a specific aircraft by ICAO code"""
        offset = request.args.get('offset', default=0, type=int)
        limit = request.args.get('limit', default=500, type=int)
        
        if offset < 0 or limit < 1 or limit > 1000:
            return {'msg': 'Bad Request - invalid offset or limit parameters'}, 400

        try:
            # Check if aircraft exists
            aircraft_obj = db.session.execute(select(Aircraft).filter_by(icao=icao)).scalar_one_or_none()
            if not aircraft_obj:
                return {'msg': 'Aircraft not found'}, 404

            # Get positions for this aircraft
            positions_result = db.session.execute(
                select(Position)
                .filter_by(aircraft=aircraft_obj.id)
                .order_by(Position.time)
                .offset(offset)
                .limit(limit)
            )
            positions = [pos.to_dict() for pos in positions_result.scalars()]
            
            data = {
                'offset': offset,
                'limit': limit,
                'count': len(positions),
                'positions': positions
            }
            response = jsonify(data)
            response.headers['Access-Control-Allow-Origin'] = '*'
            return response
            
        except Exception as ex:
            logging.error(f"Error encountered while trying to get flight positions for aircraft ICAO {icao}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@aircraft_ns.route('')
class AircraftListResource(Resource):
    @aircraft_ns.marshal_with(aircraft_list_model, code=200)
    @aircraft_ns.response(400, 'Bad request - invalid offset or limit parameters')
    @aircraft_ns.response(500, 'Internal server error')
    @aircraft_ns.doc('get_aircraft_list', params={
        'offset': 'Pagination offset (default: 0)',
        'limit': 'Number of aircraft to return (default: 50, max: 100)'
    })
    def get(self):
        """Get list of aircraft with pagination"""
        offset = request.args.get('offset', default=0, type=int)
        limit = request.args.get('limit', default=50, type=int)
        
        if offset < 0 or limit < 1 or limit > 100:
            return {'msg': 'Bad Request - invalid offset or limit parameters'}, 400
            
        try:
            aircraft_result = db.session.execute(
                select(Aircraft)
                .order_by(Aircraft.last_seen.desc(), Aircraft.icao)
                .offset(offset)
                .limit(limit)
            )
            aircraft_data = [aircraft_obj.to_dict() for aircraft_obj in aircraft_result.scalars()]
            
            return {
                'offset': offset,
                'limit': limit,
                'count': len(aircraft_data),
                'aircraft': aircraft_data
            }, 200
            
        except Exception as ex:
            logging.error('Error encountered while trying to get aircraft', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@aircraft_ns.route('/count')
class AircraftCountResource(Resource):
    @aircraft_ns.marshal_with(aircraft_count_model, code=200)
    @aircraft_ns.response(500, 'Internal server error')
    @aircraft_ns.doc('get_aircraft_count')
    def get(self):
        """Get total count of aircraft"""
        try:
            count_result = db.session.execute(select(db.func.count(Aircraft.id)))
            count = count_result.scalar()
            return {'aircraft': count}, 200
        except Exception as ex:
            logging.error('Error encountered while trying to get aircraft count', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


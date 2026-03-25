import logging
import os
import yaml

from flask import Blueprint, request
from flask_restx import Namespace, Resource, fields as restx_fields
from sqlalchemy import create_engine, text
from sqlalchemy.exc import OperationalError

acars = Blueprint('acars', __name__)

# Namespaces
acars_flights_ns = Namespace('acars/flights', description='ACARS flight operations')
acars_flight_ns = Namespace('acars/flight', description='ACARS individual flight operations')
acars_messages_ns = Namespace('acars/messages', description='ACARS message operations')
acars_stations_ns = Namespace('acars/stations', description='ACARS station operations')

# --- API Models ---

acars_station_model = acars_stations_ns.model('AcarsStation', {
    'id': restx_fields.Integer(description='Station ID'),
    'station': restx_fields.String(description='Station identifier'),
    'ip_address': restx_fields.String(description='Station IP address'),
})

acars_stations_list_model = acars_stations_ns.model('AcarsStationsList', {
    'stations': restx_fields.List(restx_fields.Nested(acars_station_model)),
    'count': restx_fields.Integer(description='Number of stations returned'),
})

acars_flight_model = acars_flights_ns.model('AcarsFlight', {
    'id': restx_fields.Integer(description='Flight ID'),
    'registration': restx_fields.String(description='Aircraft registration'),
    'flight_number': restx_fields.String(description='Flight number'),
    'start_time': restx_fields.String(description='Flight start time'),
    'last_time': restx_fields.String(description='Flight last seen time'),
    'nb_messages': restx_fields.Integer(description='Number of messages'),
})

acars_flights_list_model = acars_flights_ns.model('AcarsFlightsList', {
    'flights': restx_fields.List(restx_fields.Nested(acars_flight_model)),
    'offset': restx_fields.Integer(description='Pagination offset'),
    'limit': restx_fields.Integer(description='Pagination limit'),
    'count': restx_fields.Integer(description='Number of flights returned'),
    'total': restx_fields.Integer(description='Total number of flights'),
})

acars_flight_count_model = acars_flights_ns.model('AcarsFlightCount', {
    'flights': restx_fields.Integer(description='Total number of ACARS flights'),
})

acars_message_model = acars_messages_ns.model('AcarsMessage', {
    'id': restx_fields.Integer(description='Message ID'),
    'flight_id': restx_fields.Integer(description='Associated flight ID'),
    'time': restx_fields.String(description='Message timestamp'),
    'station_id': restx_fields.Integer(description='Station ID'),
    'channel': restx_fields.Integer(description='Channel'),
    'error': restx_fields.Integer(description='Error code'),
    'signal_level': restx_fields.Float(description='Signal level'),
    'mode': restx_fields.String(description='Mode'),
    'ack': restx_fields.String(description='Acknowledgement'),
    'label': restx_fields.String(description='Message label'),
    'block_no': restx_fields.String(description='Block number'),
    'message_no': restx_fields.String(description='Message number'),
    'text': restx_fields.String(description='Message text'),
})

acars_messages_list_model = acars_messages_ns.model('AcarsMessagesList', {
    'messages': restx_fields.List(restx_fields.Nested(acars_message_model)),
    'offset': restx_fields.Integer(description='Pagination offset'),
    'limit': restx_fields.Integer(description='Pagination limit'),
    'count': restx_fields.Integer(description='Number of messages returned'),
    'total': restx_fields.Integer(description='Total number of messages'),
})


def _get_acars_engine():
    """Create and return a SQLAlchemy engine connected to the ACARS SQLite database."""
    config = yaml.safe_load(open("config.yml"))
    db_path = config.get('acars', {}).get('database', '/run/acarsdec.sqlite')
    return create_engine(f"sqlite:///{db_path}", connect_args={"check_same_thread": False})


def _row_to_flight(row):
    return {
        'id': row[0],
        'registration': row[1],
        'flight_number': row[2],
        'start_time': str(row[3]) if row[3] else None,
        'last_time': str(row[4]) if row[4] else None,
        'nb_messages': row[5],
    }


def _row_to_message(row):
    return {
        'id': row[0],
        'flight_id': row[1],
        'time': str(row[2]) if row[2] else None,
        'station_id': row[3],
        'channel': row[4],
        'error': row[5],
        'signal_level': row[6],
        'mode': row[7],
        'ack': row[8],
        'label': row[9],
        'block_no': row[10],
        'message_no': row[11],
        'text': row[12],
    }


def _row_to_station(row):
    return {
        'id': row[0],
        'station': row[1],
        'ip_address': row[2],
    }


# --- Stations ---

@acars_stations_ns.route('')
class AcarsStationsListResource(Resource):
    @acars_stations_ns.marshal_with(acars_stations_list_model, code=200)
    @acars_stations_ns.response(500, 'Internal server error')
    @acars_stations_ns.response(503, 'ACARS database unavailable')
    @acars_stations_ns.doc('get_acars_stations')
    def get(self):
        """Get all ACARS stations"""
        try:
            engine = _get_acars_engine()
            with engine.connect() as conn:
                rows = conn.execute(
                    text("SELECT StID, IdStation, IpAddr FROM Stations ORDER BY StID")
                ).fetchall()
            stations = [_row_to_station(row) for row in rows]
            return {'stations': stations, 'count': len(stations)}, 200
        except OperationalError as ex:
            logging.warning("ACARS database unavailable", exc_info=ex)
            return {'msg': 'ACARS database unavailable'}, 503
        except Exception as ex:
            logging.error("Error retrieving ACARS stations", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


# --- Flights ---

@acars_flights_ns.route('')
class AcarsFlightsListResource(Resource):
    @acars_flights_ns.marshal_with(acars_flights_list_model, code=200)
    @acars_flights_ns.response(400, 'Bad request - invalid offset or limit parameters')
    @acars_flights_ns.response(500, 'Internal server error')
    @acars_flights_ns.response(503, 'ACARS database unavailable')
    @acars_flights_ns.doc('get_acars_flights', params={
        'offset': 'Pagination offset (default: 0)',
        'limit': 'Number of flights to return (default: 50, max: 200)',
    })
    def get(self):
        """Get paginated list of ACARS flights"""
        offset = request.args.get('offset', default=0, type=int)
        limit = request.args.get('limit', default=50, type=int)

        if offset < 0 or limit < 1 or limit > 200:
            return {'msg': 'Bad Request - invalid offset or limit parameters'}, 400

        try:
            engine = _get_acars_engine()
            with engine.connect() as conn:
                total = conn.execute(
                    text("SELECT COUNT(*) FROM Flights")
                ).scalar()
                rows = conn.execute(
                    text(
                        "SELECT FlightID, Registration, FlightNumber, StartTime, LastTime, NbMessages "
                        "FROM Flights ORDER BY LastTime DESC LIMIT :limit OFFSET :offset"
                    ),
                    {"limit": limit, "offset": offset},
                ).fetchall()
            flights_data = [_row_to_flight(row) for row in rows]
            return {
                'flights': flights_data,
                'offset': offset,
                'limit': limit,
                'count': len(flights_data),
                'total': total,
            }, 200
        except OperationalError as ex:
            logging.warning("ACARS database unavailable", exc_info=ex)
            return {'msg': 'ACARS database unavailable'}, 503
        except Exception as ex:
            logging.error("Error retrieving ACARS flights", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@acars_flights_ns.route('/count')
class AcarsFlightsCountResource(Resource):
    @acars_flights_ns.marshal_with(acars_flight_count_model, code=200)
    @acars_flights_ns.response(500, 'Internal server error')
    @acars_flights_ns.response(503, 'ACARS database unavailable')
    @acars_flights_ns.doc('get_acars_flights_count')
    def get(self):
        """Get total number of ACARS flights"""
        try:
            engine = _get_acars_engine()
            with engine.connect() as conn:
                total = conn.execute(text("SELECT COUNT(*) FROM Flights")).scalar()
            return {'flights': total}, 200
        except OperationalError as ex:
            logging.warning("ACARS database unavailable", exc_info=ex)
            return {'msg': 'ACARS database unavailable'}, 503
        except Exception as ex:
            logging.error("Error retrieving ACARS flight count", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@acars_flights_ns.route('/search')
class AcarsFlightsSearchResource(Resource):
    @acars_flights_ns.marshal_with(acars_flights_list_model, code=200)
    @acars_flights_ns.response(400, 'Bad request - search query required')
    @acars_flights_ns.response(500, 'Internal server error')
    @acars_flights_ns.response(503, 'ACARS database unavailable')
    @acars_flights_ns.doc('search_acars_flights', params={
        'q': 'Partial flight number or registration to search for',
    })
    def get(self):
        """Search ACARS flights by flight number or registration"""
        q = request.args.get('q', '', type=str).strip()
        if not q:
            return {'msg': 'Bad Request - search query required'}, 400

        pattern = f"%{q}%"
        try:
            engine = _get_acars_engine()
            with engine.connect() as conn:
                rows = conn.execute(
                    text(
                        "SELECT FlightID, Registration, FlightNumber, StartTime, LastTime, NbMessages "
                        "FROM Flights "
                        "WHERE FlightNumber LIKE :pattern OR Registration LIKE :pattern "
                        "ORDER BY LastTime DESC LIMIT 100"
                    ),
                    {"pattern": pattern},
                ).fetchall()
            flights_data = [_row_to_flight(row) for row in rows]
            return {
                'flights': flights_data,
                'offset': 0,
                'limit': 100,
                'count': len(flights_data),
                'total': len(flights_data),
            }, 200
        except OperationalError as ex:
            logging.warning("ACARS database unavailable", exc_info=ex)
            return {'msg': 'ACARS database unavailable'}, 503
        except Exception as ex:
            logging.error(f"Error searching ACARS flights for query: {q}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


# --- Individual Flight ---

@acars_flight_ns.route('/<int:flight_id>')
class AcarsFlightResource(Resource):
    @acars_flight_ns.marshal_with(acars_flight_model, code=200)
    @acars_flight_ns.response(404, 'Flight not found')
    @acars_flight_ns.response(500, 'Internal server error')
    @acars_flight_ns.response(503, 'ACARS database unavailable')
    @acars_flight_ns.doc('get_acars_flight')
    def get(self, flight_id):
        """Get a single ACARS flight by ID"""
        try:
            engine = _get_acars_engine()
            with engine.connect() as conn:
                row = conn.execute(
                    text(
                        "SELECT FlightID, Registration, FlightNumber, StartTime, LastTime, NbMessages "
                        "FROM Flights WHERE FlightID = :flight_id"
                    ),
                    {"flight_id": flight_id},
                ).fetchone()
            if not row:
                return {'msg': 'Flight not found'}, 404
            return _row_to_flight(row), 200
        except OperationalError as ex:
            logging.warning("ACARS database unavailable", exc_info=ex)
            return {'msg': 'ACARS database unavailable'}, 503
        except Exception as ex:
            logging.error(f"Error retrieving ACARS flight {flight_id}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


@acars_flight_ns.route('/<int:flight_id>/messages')
class AcarsFlightMessagesResource(Resource):
    @acars_flight_ns.marshal_with(acars_messages_list_model, code=200)
    @acars_flight_ns.response(400, 'Bad request - invalid offset or limit parameters')
    @acars_flight_ns.response(404, 'Flight not found')
    @acars_flight_ns.response(500, 'Internal server error')
    @acars_flight_ns.response(503, 'ACARS database unavailable')
    @acars_flight_ns.doc('get_acars_flight_messages', params={
        'offset': 'Pagination offset (default: 0)',
        'limit': 'Number of messages to return (default: 100, max: 500)',
    })
    def get(self, flight_id):
        """Get paginated messages for a specific ACARS flight"""
        offset = request.args.get('offset', default=0, type=int)
        limit = request.args.get('limit', default=100, type=int)

        if offset < 0 or limit < 1 or limit > 500:
            return {'msg': 'Bad Request - invalid offset or limit parameters'}, 400

        try:
            engine = _get_acars_engine()
            with engine.connect() as conn:
                flight_row = conn.execute(
                    text("SELECT FlightID FROM Flights WHERE FlightID = :flight_id"),
                    {"flight_id": flight_id},
                ).fetchone()
                if not flight_row:
                    return {'msg': 'Flight not found'}, 404

                total = conn.execute(
                    text("SELECT COUNT(*) FROM Messages WHERE FlightID = :flight_id"),
                    {"flight_id": flight_id},
                ).scalar()
                rows = conn.execute(
                    text(
                        "SELECT MessageID, FlightID, Time, StID, Channel, Error, SignalLvl, "
                        "Mode, Ack, Label, BlockNo, MessNo, Txt "
                        "FROM Messages WHERE FlightID = :flight_id "
                        "ORDER BY Time LIMIT :limit OFFSET :offset"
                    ),
                    {"flight_id": flight_id, "limit": limit, "offset": offset},
                ).fetchall()
            messages = [_row_to_message(row) for row in rows]
            return {
                'messages': messages,
                'offset': offset,
                'limit': limit,
                'count': len(messages),
                'total': total,
            }, 200
        except OperationalError as ex:
            logging.warning("ACARS database unavailable", exc_info=ex)
            return {'msg': 'ACARS database unavailable'}, 503
        except Exception as ex:
            logging.error(f"Error retrieving messages for ACARS flight {flight_id}", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500


# --- Messages ---

@acars_messages_ns.route('')
class AcarsMessagesListResource(Resource):
    @acars_messages_ns.marshal_with(acars_messages_list_model, code=200)
    @acars_messages_ns.response(400, 'Bad request - invalid offset or limit parameters')
    @acars_messages_ns.response(500, 'Internal server error')
    @acars_messages_ns.response(503, 'ACARS database unavailable')
    @acars_messages_ns.doc('get_acars_messages', params={
        'offset': 'Pagination offset (default: 0)',
        'limit': 'Number of messages to return (default: 100, max: 500)',
    })
    def get(self):
        """Get paginated list of all ACARS messages"""
        offset = request.args.get('offset', default=0, type=int)
        limit = request.args.get('limit', default=100, type=int)

        if offset < 0 or limit < 1 or limit > 500:
            return {'msg': 'Bad Request - invalid offset or limit parameters'}, 400

        try:
            engine = _get_acars_engine()
            with engine.connect() as conn:
                total = conn.execute(text("SELECT COUNT(*) FROM Messages")).scalar()
                rows = conn.execute(
                    text(
                        "SELECT MessageID, FlightID, Time, StID, Channel, Error, SignalLvl, "
                        "Mode, Ack, Label, BlockNo, MessNo, Txt "
                        "FROM Messages ORDER BY Time DESC LIMIT :limit OFFSET :offset"
                    ),
                    {"limit": limit, "offset": offset},
                ).fetchall()
            messages = [_row_to_message(row) for row in rows]
            return {
                'messages': messages,
                'offset': offset,
                'limit': limit,
                'count': len(messages),
                'total': total,
            }, 200
        except OperationalError as ex:
            logging.warning("ACARS database unavailable", exc_info=ex)
            return {'msg': 'ACARS database unavailable'}, 503
        except Exception as ex:
            logging.error("Error retrieving ACARS messages", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

import datetime
import logging
import os

from flask import Blueprint, request
from flask_restx import Namespace, Resource, fields as restx_fields
from sqlalchemy import create_engine, text
from sqlalchemy.exc import OperationalError

from backend.auth import require_admin
from backend.aircraft_classification import classify_aircraft
from backend.config_loader import get_acars_config, load_portal_config
from backend.opensky_classification import get_opensky_classification_by_registration

acars = Blueprint('acars', __name__)

# Namespaces
acars_ns = Namespace('acars', description='ACARS operations')
acars_flights_ns = acars_ns
acars_flight_ns = acars_ns
acars_messages_ns = acars_ns

# --- API Models ---

acars_flight_model = acars_flights_ns.model('AcarsFlight', {
    'id': restx_fields.Integer(description='Flight ID'),
    'registration': restx_fields.String(description='Aircraft registration'),
    'flight_number': restx_fields.String(description='Flight number'),
    'start_time': restx_fields.String(description='Flight start time'),
    'last_time': restx_fields.String(description='Flight last seen time'),
    'nb_messages': restx_fields.Integer(description='Number of messages'),
    'aircraft_class': restx_fields.String(description='Mapped aircraft class for iconography'),
    'classification_source': restx_fields.String(description='Classification source: opensky or heuristic'),
    'classification_confidence': restx_fields.String(description='Classification confidence: high, medium, or low'),
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

acars_messages_count_model = acars_messages_ns.model('AcarsMessagesCount', {
    'messages': restx_fields.Integer(description='Total number of ACARS messages'),
})

acars_database_model = acars_flights_ns.model('AcarsDatabaseInfo', {
    'size': restx_fields.Integer(description='ACARS database size in bytes'),
})

acars_purge_result_model = acars_flights_ns.model('AcarsPurgeResult', {
    'deleted_flights': restx_fields.Integer(description='Number of flights deleted'),
    'deleted_messages': restx_fields.Integer(description='Number of messages deleted'),
    'cutoff_date': restx_fields.String(description='Cutoff date used for deletion'),
})


def _purge_acars_flights():
    """Delete ACARS flights (and their messages) older than X days. Admin only."""
    days = request.args.get('days', type=int)
    if days is None or days < 1:
        return {'msg': 'Bad Request - days parameter is required and must be a positive integer'}, 400

    cutoff = datetime.datetime.now(datetime.UTC) - datetime.timedelta(days=days)
    cutoff_str = cutoff.strftime('%Y-%m-%d %H:%M:%S')

    try:
        engine = _get_acars_engine()
        with engine.connect() as conn:
            old_flight_ids = [
                row[0] for row in conn.execute(
                    text("SELECT FlightID FROM Flights WHERE LastTime < :cutoff OR LastTime IS NULL"),
                    {"cutoff": cutoff_str},
                ).fetchall()
            ]

            if not old_flight_ids:
                conn.commit()
                return {'deleted_flights': 0, 'deleted_messages': 0, 'cutoff_date': cutoff_str}, 200

            placeholders = ','.join(str(fid) for fid in old_flight_ids)
            deleted_messages = conn.execute(
                text(f"DELETE FROM Messages WHERE FlightID IN ({placeholders})")
            ).rowcount
            deleted_flights = conn.execute(
                text(f"DELETE FROM Flights WHERE FlightID IN ({placeholders})")
            ).rowcount
            conn.commit()

        logging.info(
            f'Purged {deleted_flights} ACARS flights and {deleted_messages} messages '
            f'older than {days} days (cutoff: {cutoff_str})'
        )
        return {
            'deleted_flights': deleted_flights,
            'deleted_messages': deleted_messages,
            'cutoff_date': cutoff_str,
        }, 200
    except OperationalError as ex:
        logging.warning("ACARS database unavailable", exc_info=ex)
        return {'msg': 'ACARS database unavailable'}, 503
    except Exception as ex:
        logging.error("Error purging ACARS flights", exc_info=ex)
        return {'msg': 'Internal Server Error'}, 500


def _get_acars_engine():
    """Create and return a SQLAlchemy engine connected to the ACARS SQLite database."""
    db_path = get_acars_config().get('database', '/run/acarsdec.sqlite')
    return create_engine(f"sqlite:///{db_path}", connect_args={"check_same_thread": False})


def _row_to_flight(row):
    registration = row[1]
    flight_number = row[2]
    opensky_class, opensky_source, opensky_confidence = get_opensky_classification_by_registration(registration)
    aircraft_class = classify_aircraft(None, None, flight_number, opensky_class=opensky_class)
    classification_source = opensky_source or 'heuristic'
    classification_confidence = opensky_confidence or ('medium' if aircraft_class != 'unknown' else 'low')

    return {
        'id': row[0],
        'registration': registration,
        'flight_number': flight_number,
        'start_time': str(row[3]) if row[3] else None,
        'last_time': str(row[4]) if row[4] else None,
        'nb_messages': row[5],
        'aircraft_class': aircraft_class,
        'classification_source': classification_source,
        'classification_confidence': classification_confidence,
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


class AcarsController(Resource):
    """Unified controller for all ACARS endpoints."""

    def get(self, flight_id=None):
        path = request.path.rstrip('/')

        if flight_id is not None:
            return self._get_flight_messages(flight_id)

        if path.endswith('/database'):
            return self._get_database_info()
        if path.endswith('/count'):
            if '/acars/messages' in path:
                return self._get_messages_count()
            return self._get_flights_count()
        return self._get_flights()

    def _get_flights(self):
        offset = request.args.get('offset', default=0, type=int)
        limit = request.args.get('limit', default=50, type=int)

        if offset < 0 or limit < 1 or limit > 100:
            return {'msg': 'Bad Request - invalid offset or limit parameters'}, 400

        try:
            engine = _get_acars_engine()
            with engine.connect() as conn:
                total = conn.execute(text("SELECT COUNT(*) FROM Flights")).scalar()
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

    def _get_flights_count(self):
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

    def _get_flight_messages(self, flight_id: int):
        offset = request.args.get('offset', default=0, type=int)
        limit = request.args.get('limit', default=100, type=int)

        if offset < 0 or limit < 1 or limit > 100:
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

    def _get_database_info(self):
        try:
            db_path = get_acars_config(load_portal_config()).get('database', '/run/acarsdec.sqlite')
            if not os.path.exists(db_path):
                return {'msg': 'ACARS database unavailable'}, 503
            size = os.path.getsize(db_path)
            return {'size': size}, 200
        except Exception as ex:
            logging.error('Error retrieving ACARS database size', exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500

    def _get_messages_count(self):
        try:
            engine = _get_acars_engine()
            with engine.connect() as conn:
                total = conn.execute(text("SELECT COUNT(*) FROM Messages")).scalar()
            return {'messages': total}, 200
        except OperationalError as ex:
            logging.warning("ACARS database unavailable", exc_info=ex)
            return {'msg': 'ACARS database unavailable'}, 503
        except Exception as ex:
            logging.error("Error retrieving ACARS message count", exc_info=ex)
            return {'msg': 'Internal Server Error'}, 500



class AcarsPurgeController(Resource):
    @acars_flights_ns.marshal_with(acars_purge_result_model, code=200)
    @acars_flights_ns.response(400, 'Bad request - days parameter is required and must be a positive integer')
    @acars_flights_ns.response(401, 'Unauthorized - authentication required')
    @acars_flights_ns.response(403, 'Forbidden - admin role required')
    @acars_flights_ns.response(500, 'Internal server error')
    @acars_flights_ns.response(503, 'ACARS database unavailable')
    @acars_flights_ns.param('days', 'Number of days of history to keep before purging older flights', _in='query', type='integer', required=True)
    @acars_flights_ns.doc('purge_acars_flights', security='Bearer')
    @require_admin()
    def delete(self):
        """Purge ACARS flights and messages older than the supplied number of days (Admin only)"""
        return _purge_acars_flights()


class AcarsFlightsListResource(AcarsController):
    @acars_flights_ns.marshal_with(acars_flights_list_model, code=200)
    @acars_flights_ns.response(400, 'Bad request - invalid offset or limit parameters')
    @acars_flights_ns.response(500, 'Internal server error')
    @acars_flights_ns.response(503, 'ACARS database unavailable')
    @acars_flights_ns.doc('list_acars_flights', params={
        'offset': {'description': 'Number of flights to skip for pagination', 'type': 'integer', 'in': 'query', 'default': 0},
        'limit': {'description': 'Maximum number of flights to return', 'type': 'integer', 'in': 'query', 'default': 50, 'minimum': 1, 'maximum': 100},
    })
    def get(self):
        """List ACARS flights."""
        return self._get_flights()


class AcarsFlightsCountResource(AcarsController):
    @acars_flights_ns.marshal_with(acars_flight_count_model, code=200)
    @acars_flights_ns.response(500, 'Internal server error')
    @acars_flights_ns.response(503, 'ACARS database unavailable')
    @acars_flights_ns.doc('count_acars_flights')
    def get(self):
        """Count ACARS flights."""
        return self._get_flights_count()


class AcarsFlightsDatabaseResource(AcarsController):
    @acars_flights_ns.marshal_with(acars_database_model, code=200)
    @acars_flights_ns.response(500, 'Internal server error')
    @acars_flights_ns.response(503, 'ACARS database unavailable')
    @acars_flights_ns.doc('get_acars_database_info')
    def get(self):
        """Get ACARS database size information."""
        return self._get_database_info()


class AcarsFlightMessagesResource(AcarsController):
    @acars_flight_ns.marshal_with(acars_messages_list_model, code=200)
    @acars_flight_ns.response(400, 'Bad request - invalid offset or limit parameters')
    @acars_flight_ns.response(404, 'Flight not found')
    @acars_flight_ns.response(500, 'Internal server error')
    @acars_flight_ns.response(503, 'ACARS database unavailable')
    @acars_flight_ns.doc('get_acars_flight_messages', params={
        'flight_id': {'description': 'ACARS flight ID whose messages should be returned', 'type': 'integer', 'in': 'path', 'required': True},
        'offset': {'description': 'Number of messages to skip for pagination', 'type': 'integer', 'in': 'query', 'default': 0},
        'limit': {'description': 'Maximum number of messages to return', 'type': 'integer', 'in': 'query', 'default': 100, 'minimum': 1, 'maximum': 100},
    })
    def get(self, flight_id):
        """List messages for one ACARS flight."""
        return self._get_flight_messages(flight_id)


class AcarsMessagesCountResource(AcarsController):
    @acars_messages_ns.marshal_with(acars_messages_count_model, code=200)
    @acars_messages_ns.response(500, 'Internal server error')
    @acars_messages_ns.response(503, 'ACARS database unavailable')
    @acars_messages_ns.doc('count_acars_messages')
    def get(self):
        """Count ACARS messages."""
        return self._get_messages_count()


acars_flights_ns.add_resource(AcarsFlightsListResource, '/flights')
acars_flights_ns.add_resource(AcarsFlightsCountResource, '/flights/count')
acars_flights_ns.add_resource(AcarsFlightsDatabaseResource, '/flights/database')
acars_flights_ns.add_resource(AcarsPurgeController, '/flights/purge')

acars_flight_ns.add_resource(AcarsFlightMessagesResource, '/flight/<int:flight_id>/messages')
acars_messages_ns.add_resource(AcarsMessagesCountResource, '/messages/count')

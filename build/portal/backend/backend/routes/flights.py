import logging
import yaml

from flask import abort, Blueprint, jsonify, request
from backend.db import create_connection

flights = Blueprint('flights', __name__)
config=yaml.safe_load(open("config.yml"))
        

@flights.route('/api/flight/<string:flight>', methods=['GET'])
def get_flight(flight):
    data=[]

    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT * FROM flights WHERE flight = %s", (flight,))
        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            data.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error(f"Error encountered while trying to get flight {flight}", exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    if not data:
        abort(404, description="Not Found")

    return jsonify(data[0]), 200

@flights.route('/api/flight/<flight>/positions', methods=['GET'])
def get_flight_positions(flight):
    offset = request.args.get('offset', default=0, type=int)
    limit = request.args.get('limit', default=500, type=int)
    if offset < 0 or limit < 1 or limit > 1000:
        abort(400, description="Bad Request")

    positions=[]

    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT * FROM positions WHERE flight = %s ORDER BY time LIMIT %s, %s", (flight, offset, limit))
        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            positions.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error(f"Error encountered while trying to get flight positions for flight {flight}", exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    data={}
    data['offset'] = offset
    data['limit'] = limit
    data['count'] = len(positions)
    data['positions'] = positions

    return jsonify(data), 200

@flights.route('/api/flights', methods=['GET'])
def get_flights():
    offset = request.args.get('offset', default=0, type=int)
    limit = request.args.get('limit', default=50, type=int)
    if offset < 0 or limit < 1 or limit > 100:
        abort(400, description="Bad Request")

    flights=[]

    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT * FROM flights ORDER BY last_seen DESC, flight LIMIT %s, %s", (offset, limit))
        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            flights.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error('Error encountered while trying to get flights', exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    data={}
    data['offset'] = offset
    data['limit'] = limit
    data['count'] = len(flights)
    data['flights'] = flights

    return jsonify(data), 200

@flights.route('/api/flights/count', methods=['GET'])
def get_flights_count():
    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT COUNT(*) FROM flights")
        count=cursor.fetchone()[0]
    except Exception as ex:
        logging.error('Error encountered while trying to get flight count', exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    return jsonify(flights=count), 200
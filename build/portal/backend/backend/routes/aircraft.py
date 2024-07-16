import logging

from flask import abort, Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from backend.db import create_connection

aircraft = Blueprint('aircraft', __name__)
        

@aircraft.route('/api/aircraft/<string:icao>', methods=['GET'])
def get_aircraft_by_icao(icao):
    data=[]

    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT * FROM aircraft WHERE icao = %s", (icao,))
        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            data.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error(f"Error encountered while trying to get aircraft using ICAO {icao}", exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    if not data:
        abort(404, description="Not Found")

    return jsonify(data[0]), 200

@aircraft.route('/api/aircraft/<icao>/positions', methods=['GET'])
def get_aircraft_positions(icao):
    offset = request.args.get('offset', default=0, type=int)
    limit = request.args.get('limit', default=500, type=int)
    if offset < 0 or limit < 1 or limit > 1000:
        abort(400, description="Bad Request")

    positions=[]

    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT id FROM aircraft WHERE icao = %s", (icao,))
        aircraft_id = cursor.fetchone()[0]
        cursor.execute("SELECT * FROM positions WHERE aircraft = %s ORDER BY time LIMIT %s, %s", (aircraft_id, offset, limit))
        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            positions.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error(f"Error encountered while trying to get flight positions for aircraft ICAO {icao}", exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    data={}
    data['offset'] = offset
    data['limit'] = limit
    data['count'] = len(positions)
    data['positions'] = positions

    return jsonify(data), 200

@aircraft.route('/api/aircraft', methods=['GET'])
def get_aircraft():
    offset = request.args.get('offset', default=0, type=int)
    limit = request.args.get('limit', default=50, type=int)
    if offset < 0 or limit < 1 or limit > 100:
        abort(400, description="Bad Request")

    aircraft_data=[]

    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT * FROM aircraft ORDER BY last_seen DESC, icao LIMIT %s, %s", (offset, limit))
        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            aircraft_data.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error('Error encountered while trying to get aircraft', exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    data={}
    data['offset'] = offset
    data['limit'] = limit
    data['count'] = len(aircraft_data)
    data['aircraft'] = aircraft_data

    response = jsonify(data)
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response, 200

@aircraft.route('/api/aircraft/count', methods=['GET'])
def get_aircraft_count():
    try:
        connection = create_connection()
        cursor=connection.cursor()
        cursor.execute("SELECT COUNT(*) FROM aircraft")
        count=cursor.fetchone()[0]
    except Exception as ex:
        logging.error('Error encountered while trying to get aircraft count', exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    response = jsonify(aircraft=count)
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response, 200
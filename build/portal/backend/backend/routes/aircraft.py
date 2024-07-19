import logging

from flask import abort, Blueprint, jsonify, request
from backend.db import get_db
from werkzeug.exceptions import HTTPException

aircraft = Blueprint('aircraft', __name__)
        

@aircraft.route('/api/aircraft/<string:icao>', methods=['GET'])
def get_aircraft_by_icao(icao):
    data=[]

    try:
        db=get_db()
        cursor=db.cursor()

        cursor.execute("SELECT * FROM aircraft WHERE icao = ?", (icao,))
        #cursor.execute("SELECT * FROM aircraft WHERE icao = %s", (icao,))

        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            data.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error(f"Error encountered while trying to get aircraft using ICAO {icao}", exc_info=ex)
        abort(500, description="Internal Server Error")

    if not data:
        abort(404, description="Not Found")

    response = jsonify(data[0])
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response, 200

@aircraft.route('/api/aircraft/<icao>/positions', methods=['GET'])
def get_aircraft_positions(icao):
    offset = request.args.get('offset', default=0, type=int)
    limit = request.args.get('limit', default=500, type=int)
    if offset < 0 or limit < 1 or limit > 1000:
        abort(400, description="Bad Request")

    positions=[]

    try:
        db=get_db()
        cursor=db.cursor()

        cursor.execute("SELECT COUNT(*) FROM aircraft WHERE icao = ?", (icao,))
        #cursor.execute("SELECT COUNT(*) FROM aircraft WHERE icao = %s", (icao,))

        if cursor.fetchone()[0] == 0:
            abort(404, description="Not Found")

        cursor.execute("SELECT id FROM aircraft WHERE icao = ?", (icao,))
        #cursor.execute("SELECT id FROM aircraft WHERE icao = %s", (icao,))

        aircraft_id = cursor.fetchone()[0]

        cursor.execute("SELECT * FROM positions WHERE aircraft = ? ORDER BY time LIMIT ?, ?", (aircraft_id, offset, limit))
        #cursor.execute("SELECT * FROM positions WHERE aircraft = %s ORDER BY time LIMIT %s, %s", (aircraft_id, offset, limit))

        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            positions.append(dict(zip(columns,result)))
    except Exception as ex:
        if isinstance(ex, HTTPException):
            abort(ex.code)
        else:
            logging.error(f"Error encountered while trying to get flight positions for aircraft ICAO {icao}", exc_info=ex)
            abort(500, description="Internal Server Error")

    data={}
    data['offset'] = offset
    data['limit'] = limit
    data['count'] = len(positions)
    data['positions'] = positions

    response = jsonify(data)
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response, 200

@aircraft.route('/api/aircraft', methods=['GET'])
def get_aircraft():
    offset = request.args.get('offset', default=0, type=int)
    limit = request.args.get('limit', default=50, type=int)
    
    if offset < 0 or limit < 1 or limit > 100:
        abort(400, description="Bad Request")
        
    aircraft_data=[]

    try:
        db=get_db()
        cursor=db.cursor()

        cursor.execute("SELECT * FROM aircraft ORDER BY last_seen DESC, icao LIMIT ?, ?", (offset, limit))
        #cursor.execute("SELECT * FROM aircraft ORDER BY last_seen DESC, icao LIMIT %s, %s", (offset, limit))

        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            aircraft_data.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error('Error encountered while trying to get aircraft', exc_info=ex)
        abort(500, description="Internal Server Error")

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
        db=get_db()
        cursor=db.cursor()
        cursor.execute("SELECT COUNT(*) FROM aircraft")
        count = cursor.fetchone()[0]
    except Exception as ex:
        logging.error('Error encountered while trying to get aircraft count', exc_info=ex)
        abort(500, description="Internal Server Error")

    response = jsonify(aircraft=count)
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response, 200
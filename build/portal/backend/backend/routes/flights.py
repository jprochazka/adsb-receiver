import logging
import mysql.connector
import sqlite3
import yaml

from flask import abort, Blueprint, jsonify

flights = Blueprint('flights', __name__)

config=yaml.safe_load(open("config.yml"))


def create_connetion():
    match config['database']['use'].lower():
        case 'mysql':
            return mysql.connector.connect(
                host=config['database']['mysql']['host'],
                user=config['database']['mysql']['user'],
                password=config['database']['mysql']['password'],
                database=config['database']['mysql']['database']
            )
        case 'sqlite':
            return sqlite3.connect(config['database']['sqlite']['path'])
        

@flights.route('/api/v1/flight/<string:flight>', methods=['GET'])
def get_flight(flight):
    data=[]

    try:
        connection = create_connetion()
        cursor=connection.cursor()
        cursor.execute("SELECT * FROM flights WHERE flight = %s", (flight))
        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            data.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error(f"Error encountered while trying to get flight {flight}", exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    return jsonify(data), 200

@flights.route('/api/v1/flight/<flight>/positions', methods=['GET'], defaults={'offset': 0, 'limit': 500})
def get_flight_positions(flight, offset, limit):
    if not isinstance(offset, int) or offset < 0  or not isinstance(limit, int) or limit < 1 or limit > 1000:
        abort(400, description="Bad Request")

    data=[]

    try:
        connection = create_connetion()
        cursor=connection.cursor()
        cursor.execute("SELECT * positions WHERE flight = %s ORDER BY time LIMIT %s, %s", (flight, offset, limit))
        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            data.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error(f"Error encountered while trying to get flight positions fo flight {flight}", exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    return jsonify(data), 200

@flights.route('/api/v1/flights', methods=['GET'], defaults={'offset': 0, 'limit': 50})
def get_flights(offset, limit):
    if not isinstance(offset, int) or offset < 0  or not isinstance(limit, int) or limit < 1 or limit > 100:
        abort(400, description="Bad Request")

    data=[]

    try:
        connection = create_connetion()
        cursor=connection.cursor()
        cursor.execute("SELECT * FROM flights ORDER BY lastSeen DESC, flight LIMIT %s, %s", (offset, limit))
        columns=[x[0] for x in cursor.description]
        result=cursor.fetchall()
        for result in result:
            data.append(dict(zip(columns,result)))
    except Exception as ex:
        logging.error('Error encountered while trying to get flights', exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    return jsonify(data), 200

@flights.route('/api/v1/flights/count', methods=['GET'])
def get_flights_count():
    try:
        connection = create_connetion()
        cursor=connection.cursor()
        cursor.execute("SELECT COUNT(*) FROM flights")
        count=cursor.fetchone()[0]
    except Exception as ex:
        logging.error('Error encountered while trying to get flight count', exc_info=ex)
        abort(500, description="Internal Server Error")
    finally:
        connection.close()

    return jsonify(flights=count), 200
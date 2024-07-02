import logging
import mysql.connector
import sqlite3
import yaml

from flask import abort, Blueprint, jsonify

links = Blueprint('links', __name__)

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
        

@links.route('/api/v1/links', methods=['GET'], defaults={'offset': 0, 'limit': 50})
def get_links(flight, offset, limit):
    if not isinstance(offset, int) or offset < 0  or not isinstance(limit, int) or limit < 1 or limit > 100:
        abort(400, description="Bad Request")

    data=[]

    try:
        connection = create_connetion()
        cursor=connection.cursor()
        cursor.execute("SELECT * FROM adsb_links ORDER BY name LIMIT %s, %s", (flight, offset, limit))
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
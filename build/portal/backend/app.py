import mysql.connector
import os
import psycopg2
import sqlite3
import yaml

from flask_restful import Api, Resource
from flask import Flask, jsonify
from flasgger import Swagger

dir_path=os.path.dirname(os.path.realpath(__file__))
config=yaml.safe_load(open("config.yml"))

app=Flask(__name__)
api=Api(app)
app.config['SWAGGER'] = {
    'title': 'ADS-B Portal API',
    'description': 'This API is used to supply data to ADS-B Portal frontends hosted both locally and remotely.',
    'version': 'v1.0.0',
    'openapi': '3.0.2'
}
app.json.sort_keys=False
swag=Swagger(app)

## BLOG

class GetPosts(Resource):
    def get(self, offset, limit):
        """
        Get data for multiple blog posts in cronicalogical order.
        Returns all blog post data currently available in the database. The amount of blog posts returned can be controled by optionally setting an offset and/or limit.
        ---
        tags:
          - blog
        parameters:
          - in: query
            name: offset
            type: integer
            required: false
            default: 0
            description: The number of blog posts to be skipped in the results set before returning the first blog post. Useful for returning results which are to be paginated.
          - in: query
            name: limit
            type: integer
            required: false
            default: 100
            description: The maximum number of blog posts to be returned in the response. Using this along with the offset parameter is useful for returning results which are to be paginated.
        responses:
          200:
            description: Multiple blog posts ordered by their creation date.
        """
        data=[]
        
        # MariaDB (MySQL)
        if config['database']['use']=="mysql":
            connection=mysql.connector.connect(
                host=config['database']['mysql']['host'],
                user=config['database']['mysql']['user'],
                password=config['database']['mysql']['password'],
                database=config['database']['mysql']['database']
            )
            cursor=connection.cursor()
            cursor.execute("SELECT * FROM adsb_blogposts ORDER BY date DESC LIMIT %s, %s", (offset, limit))
            columns=[x[0] for x in cursor.description]
            result=cursor.fetchall()
            for result in result:
                data.append(dict(zip(columns,result)))

        # PostgreSQL
        if config['database']['use']=="postgresql":
            connection=psycopg2.connect(
                host=config['database']['postgresql']['host'],
                user=config['database']['postgresql']['user'],
                password=config['database']['postgresql']['password'],
                database=config['database']['postgresql']['database']
            )
            cursor = connection.cursor()
            cursor.execute("SELECT * FROM adsb_blogposts ORDER BY date DESC LIMIT %s, %s", (offset, limit))
            columns=[x[0] for x in cursor.description]
            for result in result:
                data.append(dict(zip(columns,result)))

        # SQLite
        if config['database']['use']=="sqlite":
            connection=sqlite3.connect(config['database']['sqlite']['path'])
            cursor=connection.cursor()
            cursor.execute("SELECT * FROM adsb_blogposts ORDER BY date DESC LIMIT %s, %s", (offset, limit))
            columns=[x[0] for x in cursor.description]
            for result in result:
                data.append(dict(zip(columns,result)))

        return jsonify(data)

## FLIGHT_DATA
    
class GetFlight(Resource):
    def get(self, flight):
        """
        Get data for a spcific flight.
        Returns all flight data currently available in the database. The amount of flights returned can be controled by optionally setting an offset and/or limit.
        ---
        tags:
          - flight_data
        parameters:
          - in: path
            name: flight
            type: string
            required: true
            description: The flights for which data is to be returned.
        responses:
          200:
            description: All flight data pertaining to the supplied flight.
        """
        data=[]

        # MariaDB (MySQL)
        if config['database']['use']=="mysql":
            connection=mysql.connector.connect(
                host=config['database']['mysql']['host'],
                user=config['database']['mysql']['user'],
                password=config['database']['mysql']['password'],
                database=config['database']['mysql']['database']
            )
            cursor=connection.cursor()
            cursor.execute("SELECT * FROM adsb_flights WHERE flight = %s", (flight))
            columns=[x[0] for x in cursor.description]
            result=cursor.fetchall()
            for result in result:
                data.append(dict(zip(columns,result)))

        # PostgreSQL
        if config['database']['use']=="postgresql":
            connection=psycopg2.connect(
                host=config['database']['postgresql']['host'],
                user=config['database']['postgresql']['user'],
                password=config['database']['postgresql']['password'],
                database=config['database']['postgresql']['database']
            )
            cursor = connection.cursor()
            cursor.execute("SELECT * FROM adsb_flights WHERE flight = %s", (flight))
            columns=[x[0] for x in cursor.description]
            for result in result:
                data.append(dict(zip(columns,result)))

        # SQLite
        if config['database']['use']=="sqlite":
            connection=sqlite3.connect(config['database']['sqlite']['path'])
            cursor=connection.cursor()
            cursor.execute("SELECT * FROM adsb_flights WHERE flight = %s", (flight))
            columns=[x[0] for x in cursor.description]
            for result in result:
                data.append(dict(zip(columns,result)))
            
        return jsonify(data)

class GetFlightCount(Resource):
    def get(self):
        """
        Get the total count of flights tracks.
        Returns the number of flights currently tracked within the database at this time.
        ---
        tags:
         - flight_data
        responses:
          200:
            description: The total number of flights currently tracked within the database.
        """
        count=0

        # MariaDB (MySQL)
        if config['database']['use']=="mysql":
            connection = mysql.connector.connect(
                host=config['database']['mysql']['host'],
                user=config['database']['mysql']['user'],
                password=config['database']['mysql']['password'],
                database=config['database']['mysql']['database']
            )
            cursor=connection.cursor()
            cursor.execute("SELECT COUNT(*) FROM adsb_flights")
            count=cursor.fetchone()[0]

        # PostgreSQL
        if config['database']['use']=="postgresql":
            connection=psycopg2.connect(
                host=config['database']['postgresql']['host'],
                user=config['database']['postgresql']['user'],
                password=config['database']['postgresql']['password'],
                database=config['database']['postgresql']['database']
            )
            cursor = connection.cursor()
            cursor.execute("SELECT COUNT(*) FROM adsb_flights")
            count=connection.fetchall()

        # SQLite
        if config['database']['use']=="sqlite":
            connection=sqlite3.connect(config['database']['sqlite']['path'])
            cursor=connection.cursor()
            cursor.execute("SELECT COUNT(*) FROM adsb_flights")
            count=connection.fetchall()

        return jsonify(flights=count)

class GetFlights(Resource):
    def get(self, offset, limit):
        """
        Get data for multiple flights in cronicalogical order.
        Returns all flight data currently available in the database. The amount of flights returned can be controled by optionally setting an offset and/or limit.
        ---
        tags:
          - flight_data
        parameters:
          - in: query
            name: offset
            type: integer
            required: false
            default: 0
            description: The number of flights to be skipped in the results set before returning the first flight. Useful for returning results which are to be paginated.
          - in: query
            name: limit
            type: integer
            required: false
            default: 100
            description: The maximum number of flights to be returned in the response. Using this along with the offset parameter is useful for returning results which are to be paginated.
        responses:
          200:
            description: All flight data currently available ordered by the most recently seen flight ahead of older ones.
        """
        data=[]

        # MariaDB (MySQL)
        if config['database']['use']=="mysql":
            connection=mysql.connector.connect(
                host=config['database']['mysql']['host'],
                user=config['database']['mysql']['user'],
                password=config['database']['mysql']['password'],
                database=config['database']['mysql']['database']
            )
            cursor=connection.cursor()
            cursor.execute("SELECT * FROM adsb_flights ORDER BY lastSeen DESC, flight LIMIT %s, %s", (offset, limit))
            columns=[x[0] for x in cursor.description]
            result=cursor.fetchall()
            for result in result:
                data.append(dict(zip(columns,result)))

        # PostgreSQL
        if config['database']['use']=="postgresql":
            connection=psycopg2.connect(
                host=config['database']['postgresql']['host'],
                user=config['database']['postgresql']['user'],
                password=config['database']['postgresql']['password'],
                database=config['database']['postgresql']['database']
            )
            cursor = connection.cursor()
            cursor.execute("SELECT * FROM adsb_flights ORDER BY lastSeen DESC, flight LIMIT %s, %s", (offset, limit))
            columns=[x[0] for x in cursor.description]
            for result in result:
                data.append(dict(zip(columns,result)))

        # SQLite
        if config['database']['use']=="sqlite":
            connection=sqlite3.connect(config['database']['sqlite']['path'])
            cursor=connection.cursor()
            cursor.execute("SELECT * FROM adsb_flights ORDER BY lastSeen DESC, flight LIMIT %s, %s", (offset, limit))
            columns=[x[0] for x in cursor.description]
            for result in result:
                data.append(dict(zip(columns,result)))
            
        return jsonify(data)
    
class GetPositions(Resource):
    def get(self, flight, offset, limit):
        """
        Get position data for the specified flight.
        Returns all position data currently available in the database for the specified flight. The amount of positions returned can be controled by optionally setting an offset and/or limit.
        ---
        tags:
          - flight_data
        parameters:
          - in: path
            name: flight
            type: string
            required: true
            description: The flights for which data is to be returned.
          - in: query
            name: offset
            type: integer
            required: false
            default: 0
            description: The number of positions to be skipped in the results set before returning the position. Useful for returning results which are to be paginated.
          - in: query
            name: limit
            type: integer
            required: false
            default: 100
            description: The maximum number of positions to be returned in the response. Using this along with the offset parameter is useful for returning results which are to be paginated.
        responses:
          200:
            description: All position data currently available ordered by the most recently seen position ahead of older ones.
        """
        data=[]

        # MariaDB (MySQL)
        if config['database']['use']=="mysql":
            connection=mysql.connector.connect(
                host=config['database']['mysql']['host'],
                user=config['database']['mysql']['user'],
                password=config['database']['mysql']['password'],
                database=config['database']['mysql']['database']
            )
            cursor=connection.cursor()
            cursor.execute("SELECT * FROM adsb_positions WHERE flight = %s ORDER BY time LIMIT %s, %s", (flight, offset, limit))
            columns=[x[0] for x in cursor.description]
            result=cursor.fetchall()
            for result in result:
                data.append(dict(zip(columns,result)))
            
        # PostgreSQL
        if config['database']['use']=="postgresql":
            connection=psycopg2.connect(
                host=config['database']['postgresql']['host'],
                user=config['database']['postgresql']['user'],
                password=config['database']['postgresql']['password'],
                database=config['database']['postgresql']['database']
            )
            cursor = connection.cursor()
            cursor.execute("SELECT * FROM adsb_positions WHERE flight = %s ORDER BY time LIMIT %s, %s", (flight, offset, limit))
            columns=[x[0] for x in cursor.description]
            for result in result:
                data.append(dict(zip(columns,result)))

        # SQLite
        if config['database']['use']=="sqlite":
            connection=sqlite3.connect(config['database']['sqlite']['path'])
            cursor=connection.cursor()
            cursor.execute("SELECT * FROM adsb_positions WHERE flight = %s ORDER BY time LIMIT %s, %s", (flight, offset, limit))
            columns=[x[0] for x in cursor.description]
            for result in result:
                data.append(dict(zip(columns,result)))

        return jsonify(data)
    
# LINKS

class GetLink(Resource):
    def get(self, id):
        """
        Get a link by the ID assinged to it.
        Returns link data currently available in the database for the link assigned the supplied ID.
        ---
        tags:
          - links
        parameters:
          - in: path
            name: offset
            type: integer
            required: true
            description: The ID assigned to the link when it was created.
        responses:
          200:
            description: Data pertaining to the link assigned the supplied ID.
        """
        data=[]
        
        # MariaDB (MySQL)
        if config['database']['use']=="mysql":
            connection=mysql.connector.connect(
                host=config['database']['mysql']['host'],
                user=config['database']['mysql']['user'],
                password=config['database']['mysql']['password'],
                database=config['database']['mysql']['database']
            )
            cursor=connection.cursor()
            cursor.execute("SELECT * FROM adsb_links WHERE id = %s", (id))
            columns=[x[0] for x in cursor.description]
            result=cursor.fetchall()
            for result in result:
                data.append(dict(zip(columns,result)))

        # PostgreSQL
        if config['database']['use']=="postgresql":
            connection=psycopg2.connect(
                host=config['database']['postgresql']['host'],
                user=config['database']['postgresql']['user'],
                password=config['database']['postgresql']['password'],
                database=config['database']['postgresql']['database']
            )
            cursor = connection.cursor()
            cursor.execute("SELECT * FROM adsb_links WHERE id = %s", (id))
            columns=[x[0] for x in cursor.description]
            for result in result:
                data.append(dict(zip(columns,result)))

        # SQLite
        if config['database']['use']=="sqlite":
            connection=sqlite3.connect(config['database']['sqlite']['path'])
            cursor=connection.cursor()
            cursor.execute("SELECT * FROM adsb_links WHERE id = %s", (id))
            columns=[x[0] for x in cursor.description]
            for result in result:
                data.append(dict(zip(columns,result)))

        return jsonify(data)

class GetLinks(Resource):
    def get(self):
        """
        Get links ordered by name.
        Returns all link data currently available in the database ordered by their name.
        ---
        tags:
          - links
        responses:
          200:
            description: Multiple links ordered by their name.
        """
        data=[]
        
        # MariaDB (MySQL)
        if config['database']['use']=="mysql":
            connection=mysql.connector.connect(
                host=config['database']['mysql']['host'],
                user=config['database']['mysql']['user'],
                password=config['database']['mysql']['password'],
                database=config['database']['mysql']['database']
            )
            cursor=connection.cursor()
            cursor.execute("SELECT * FROM adsb_links ORDER BY name")
            columns=[x[0] for x in cursor.description]
            result=cursor.fetchall()
            for result in result:
                data.append(dict(zip(columns,result)))

        # PostgreSQL
        if config['database']['use']=="postgresql":
            connection=psycopg2.connect(
                host=config['database']['postgresql']['host'],
                user=config['database']['postgresql']['user'],
                password=config['database']['postgresql']['password'],
                database=config['database']['postgresql']['database']
            )
            cursor = connection.cursor()
            cursor.execute("SELECT * FROM adsb_links ORDER BY name")
            columns=[x[0] for x in cursor.description]
            for result in result:
                data.append(dict(zip(columns,result)))

        # SQLite
        if config['database']['use']=="sqlite":
            connection=sqlite3.connect(config['database']['sqlite']['path'])
            cursor=connection.cursor()
            cursor.execute("SELECT * FROM adsb_links ORDER BY name")
            columns=[x[0] for x in cursor.description]
            for result in result:
                data.append(dict(zip(columns,result)))

        return jsonify(data)

api.add_resource(GetPosts, '/blog/posts', defaults={'offset': 0, 'limit': 100})
api.add_resource(GetFlight, '/flight-data/<flight>')
api.add_resource(GetFlightCount, '/flight-data/count')
api.add_resource(GetFlights, '/flight-data', defaults={'offset': 0, 'limit': 100})
api.add_resource(GetPositions, '/flight-data/<flight>/positions', defaults={'offset': 0, 'limit': 100})
api.add_resource(GetLink, '/links/<id>')
api.add_resource(GetLinks, '/links')

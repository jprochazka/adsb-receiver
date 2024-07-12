#!/usr/bin/python

import datetime
import fcntl
import json
import logging
import os
import time

from urllib import urlopen

now = None

class AircraftProcessor(object):

    # Create database connection
    def create_connection():
        with open(os.path.dirname(os.path.realpath(__file__)) + '/config.json') as config_file:
            config = json.load(config_file)

        match config["database"]["type"].lower():
            case 'mysql':
                import mysql.connector
                return mysql.connector.connect(
                    host=config["database"]["host"],
                    user=config["database"]["user"],
                    password=config["database"]["passwd"],
                    database=config["database"]["db"]
                )
            case 'sqlite':
                import sqlite3
                return sqlite3.connect(config["database"]["db"])

    # Read JSON supplied by dump1090
    def read_json():
        try:
            raw_json = urlopen('http://127.0.0.1/dump1090/data/aircraft.json')
            json_object = json.load(raw_json)
            return json_object
        except:
            logging.error("There was a problem consuming aircraft.json")
            return

    # Begin processing data retrived from dump1090
    def process_all_aircraft(self, all_aircraft):

        connection = self.create_connection()
        self.cursor = connection.cursor()

        for aircraft in all_aircraft:
            self.process_aircraft(aircraft)

        connection.commit()
        connection.close()

        return

    # Process the aircraft
    def process_aircraft(self, aircraft):
        tracked=False
        aircraft_id=None
        
        try:
            self.cursor.execute("SELECT COUNT(*) FROM aircraft WHERE icao = %s", (aircraft["hex"],))
            if self.cursor.fetchone()[0] > 0:
                tracked=True
        except Exception as ex:
            logging.error(f"Error encountered while checking if aircraft '{aircraft["hex"]}' has already been added", exc_info=ex)
            return

        if tracked:
            query = "UPDATE aircraft SET lastSeen = %s WHERE icao = %s",
            parameters = (now, aircraft["hex"])
            error_message = f"Error encountered while trying to update aircraft '{aircraft["hex"]}'"
        else:
            query = "INSERT INTO aircraft (icao, firstSeen, lastSeen) VALUES (%s, %s, %s)",
            parameters = (aircraft["hex"], now, now)
            error_message = f"Error encountered while trying to insert aircraft '{aircraft["hex"]}'"

        try:
            self.cursor.execute(query, parameters)
            aircraft_id = self.cursor.lastrowid
        except Exception as ex:
            logging.error(error_message, exc_info=ex)
            return

        if 'flight' in aircraft:
            self.process_flight(aircraft_id, aircraft)

        return

    # Process the flight
    def process_flight(self, aircraft_id, aircraft):
        tracked=False
        try:
            self.cursor.execute("SELECT COUNT(*) FROM flights WHERE flight = %s", (aircraft["flight"],))
            if self.cursor.fetchone()[0] > 0:
                tracked=True
        except Exception as ex:
            logging.error(f"Error encountered while checking if flight '{aircraft["flight"]}' has already been added", exc_info=ex)
            return

        if tracked:
            query = "UPDATE flights SET lastSeen = %s WHERE icao = %s",
            parameters = (now, aircraft["flight"])
            error_message = f"Error encountered while trying to update flight '{aircraft["flight"]}'"
        else:
            query = "INSERT INTO flights (aircraft, flight, firstSeen, lastSeen) VALUES (%s, %s, %s, %s)",
            parameters = (aircraft_id, aircraft["flight"], now, now)
            error_message = f"Error encountered while trying to insert flight '{aircraft["flight"]}'"

        try:
            self.cursor.execute(query, parameters)
            flight_id = self.cursor.lastrowid
        except Exception as ex:
            logging.error(error_message, exc_info=ex)
            return

        position_keys = ('lat', 'lon', 'nav_altitude', 'gs', 'track', 'geom_rate', 'hex')
        if (all(key in aircraft for key in position_keys) and aircraft["altitude"] != "ground"):
            self.process_positions(aircraft_id, flight_id, aircraft)

        return

    # Process positions
    def process_positions(self, aircraft_id , flight_id, aircraft):
        tracked=False
        try:
            self.cursor.execute("SELECT COUNT(*) FROM positions WHERE flight = %s AND message = %s", (flight_id, aircraft["messages"]))
            if self.cursor.fetchone()[0] > 0:
                tracked=True
        except Exception as ex:
            logging.error(f"Error encountered while checking if position has already been added for message ID '{aircraft["messages"]}' related to flight '{flight_id}'", exc_info=ex)
            return

        if tracked:
            return

        squawk = None
        if 'squawk' in aircraft:
            squawk = aircraft["squawk"]

        try:
            self.cursor.execute(
                "INSERT INTO positions (flight, time, message, squawk, latitude, longitude, track, altitude, verticleRate, speed, aircraft) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)", 
                (flight_id, now, aircraft["messages"], squawk, aircraft["lat"], aircraft["lon"], aircraft["track"], aircraft["nav_altitude"], aircraft["geom_rate"], aircraft["gs"], aircraft_id)
            )
            flight_id = self.cursor.lastrowid
        except Exception as ex:
            logging.error(f"Error encountered while inserting position data for message ID '{aircraft["messages"]}' related to flight '{flight_id}'", exc_info=ex)
            return
            
        return

if __name__ == "__main__":
    processor = AircraftProcessor()

    logging.info(f"Beginning flight recording job on {datetime.datetime.now().strftime("%Y/%m/%d %H:%M:%S")}")

    # Do not allow another instance of the job to run
    lock_file = open('/tmp/flights.py.lock','w')
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX|fcntl.LOCK_NB)
    except (IOError, OSError):
        logging.info('Another instance already running')
        quit()

    # Begin flight recording job
    lock_file.write('%d\n'%os.getpid())
    while True:
        now = datetime.datetime.now()
        data = processor.read_json()
        processor.process_all_aircraft(data["aircraft"])
        logging.info(f"Flight recording job ended on {datetime.datetime.now().strftime("%Y/%m/%d %H:%M:%S")}")
        time.sleep(15)
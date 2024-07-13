import fcntl
import json
import logging
import MySQLdb
import os
import sqlite3

from datetime import datetime
from time import sleep
from urllib.request import urlopen

class AircraftProcessor(object):

    # Log infromation to console
    def log(self, string):
        #print(f'[{datetime.now().strftime("%Y/%m/%d %H:%M:%S")}] {string}') # uncomment to enable debug logging
        return

    # Create database connection
    def create_connection(self):
        self.log("Setting up database connection")
        with open(os.path.dirname(os.path.realpath(__file__)) + '/config.json') as config_file:
            config = json.load(config_file)

        match config["database"]["type"].lower():
            case 'mysql':
                return MySQLdb.connect(
                    host=config["database"]["host"],
                    user=config["database"]["user"],
                    passwd=config["database"]["passwd"],
                    db=config["database"]["db"]
                )
            case 'sqlite':
                return sqlite3.connect(config["database"]["db"])

    # Read JSON supplied by dump1090
    def read_json(self):
        self.log("Reading aircraft.json")
        try:
            raw_json = urlopen('http://127.0.0.1/dump1090/data/aircraft.json')
            json_object = json.load(raw_json)
            return json_object
        except:
            logging.error("There was a problem consuming aircraft.json")
            return

    # Begin processing data retrived from dump1090
    def process_all_aircraft(self):
        data = self.read_json()
        aircraft_data = data["aircraft"]

        if len(aircraft_data) == 0:
            self.log(f'There is no aircraft data to process at this time')
            return

        self.log(f'Begining to proocess {len(aircraft_data)} aircraft')
        for aircraft in aircraft_data:
            self.process_aircraft(aircraft)

        connection.close()

        return

    # Process the aircraft
    def process_aircraft(self, aircraft):
        tracked=False
        aircraft_id=None

        try:
            cursor.execute("SELECT COUNT(*) FROM adsb_aircraft WHERE icao = %s", (aircraft["hex"],))
            if cursor.fetchone()[0] > 0:
                tracked=True
        except Exception as ex:
            logging.error(f'Error encountered while checking if aircraft {aircraft["hex"]} has already been added', exc_info=ex)
            return

        if tracked:
            self.log(f'Updating aircraft ICAO {aircraft["hex"]}')
            try:
                cursor.execute(
                    "UPDATE adsb_aircraft SET lastSeen = %s WHERE icao = %s",
                    (now, aircraft["hex"])
                )
                connection.commit()
                cursor.execute(
                    "SELECT id FROM adsb_aircraft WHERE icao = %s",
                    (aircraft["hex"],)
                )
                aircraft_id = cursor.fetchone()[0]
            except Exception as ex:
                logging.error(f'Error encountered while trying to update aircraft {aircraft["hex"]}', exc_info=ex)
                return
        else:
            self.log(f'Inserting aircraft ICAO {aircraft["hex"]}')
            try:
                cursor.execute(
                    "INSERT INTO adsb_aircraft (icao, firstSeen, lastSeen) VALUES (%s, %s, %s)",
                    (aircraft["hex"], now, now)
                )
                connection.commit()
                aircraft_id = cursor.lastrowid
            except Exception as ex:
                logging.error(f'Error encountered while trying to insert aircraft {aircraft["hex"]}', exc_info=ex)
                return

        if 'flight' in aircraft:
            self.process_flight(aircraft_id, aircraft)
        else:
            self.process_positions(aircraft_id , None, aircraft)

        return

    # Process the flight
    def process_flight(self, aircraft_id, aircraft):
        if 'flight' in aircraft:
            flight = aircraft["flight"].strip()

            tracked=False
            try:
                cursor.execute("SELECT COUNT(*) FROM adsb_flights WHERE flight = %s", (flight,))
                if cursor.fetchone()[0] > 0:
                    tracked=True
            except Exception as ex:
                logging.error(f'Error encountered while checking if flight {flight} has already been added', exc_info=ex)
                return

            if tracked:
                self.log(f'  Updating flight {flight} assigned to aircraft ICAO {aircraft["hex"]}')
                try:
                    cursor.execute(
                        "UPDATE adsb_flights SET lastSeen = %s WHERE flight = %s",
                        (now, flight)
                    )
                    connection.commit()
                    cursor.execute(
                        "SELECT id FROM adsb_flights WHERE flight = %s",
                        (flight,)
                    )
                    flight_id = cursor.fetchone()[0]
                except Exception as ex:
                    logging.error(f'Error encountered while trying to update flight {flight}', exc_info=ex)
                    return
            else:
                self.log(f'Inserting flight {flight} assigned to aircraft ICAO {aircraft["hex"]}')
                try:
                    cursor.execute(
                        "INSERT INTO adsb_flights (aircraft, flight, firstSeen, lastSeen) VALUES (%s, %s, %s, %s)",
                        (aircraft_id, flight, now, now)
                    )
                    connection.commit()
                    flight_id = cursor.lastrowid
                except Exception as ex:
                    logging.error(f'Error encountered while trying to insert flight {flight}', exc_info=ex)
                    return

        else:
            self.log(f'  Aircraft ICAO {aircraft["hex"]} was not assigned a flight')

        self.process_positions(aircraft_id, flight_id, aircraft)

        return

    # Process positions
    def process_positions(self, aircraft_id , flight_id, aircraft):

        position_keys = ('lat', 'lon', 'alt_baro', 'gs', 'track', 'geom_rate', 'hex')
        if (all(key in aircraft for key in position_keys)):

            tracked=False
            try:
                cursor.execute("SELECT COUNT(*) FROM adsb_positions WHERE flight = %s AND message = %s", (flight_id, aircraft["messages"]))
                if cursor.fetchone()[0] > 0:
                    tracked=True
            except Exception as ex:
                logging.error(f'Error encountered while checking if position has already been added for message ID {aircraft["messages"]} related to flight {flight_id}', exc_info=ex)
                return

            if tracked:
                return

            squawk = None
            if 'squawk' in aircraft:
                squawk = aircraft["squawk"]

            altitude = aircraft["alt_baro"]
            if 'alt_geom' in aircraft:
                altitude = aircraft["alt_geom"]

            try:
                if flight_id is None:
                    self.log(f'  Inserting position for aircraft ICAO {aircraft["hex"]}')
                else:
                    self.log(f'  Inserting position for aircraft ICAO {aircraft["hex"]} assigned flight {flight_id}')
                cursor.execute(
                    "INSERT INTO adsb_positions (flight, time, message, squawk, latitude, longitude, track, altitude, verticleRate, speed, aircraft) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)", 
                    (flight_id, now, aircraft["messages"], squawk, aircraft["lat"], aircraft["lon"], aircraft["track"], altitude, aircraft["geom_rate"], aircraft["gs"], aircraft_id)
                )
                connection.commit()
            except Exception as ex:
                logging.error(f'Error encountered while inserting position data for message ID {aircraft["messages"]} related to flight {flight_id}', exc_info=ex)
                return

        else:
            self.log(f'  Data required to insert position data for Aircraft ICAO {aircraft["hex"]} is not present')

        return

if __name__ == "__main__":
    processor = AircraftProcessor()

    processor.log("-- CHECKING IF FLIGHT RECORDER JOB IS ALREADY RUNNING")

    # Do not allow another instance of the job to run
    lock_file = open('/tmp/flights.py.lock','w')
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX|fcntl.LOCK_NB)
    except (IOError, OSError):
        processor.log("-- ANOTHER INSTANCE OF THIS JOB IS RUNNING")
        quit()
    lock_file.write('%d\n'%os.getpid())

    while True:
        processor.log("-- BEGINING FLIGHT RECORDER JOB")

        # Set up database connection
        connection =  processor.create_connection()
        cursor = connection.cursor()

        # Begin flight recording job
        now = datetime.now()
        processor.process_all_aircraft()
        processor.log("-- FLIGHT RECORD JOB COMPLETE")
        processor.log("SLEEPING 15 SECONDS BEFORE NEXT RUN")
        sleep(15)

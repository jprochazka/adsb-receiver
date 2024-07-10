#!/usr/bin/python

# WHAT THIS DOES:
# ---------------------------------------------------------------
#
# 1) Read aircraft.json generated by dump1090-fa.
# 2) Add the flight to the database if it does not already exist.
# 3) Update the last time the flight was seen.

import datetime
import fcntl
import json
import os
import time

from urllib.request import urlopen

def log(string):
    #print(string) # uncomment to enable debug logging
    return

# Do not allow another instance of the script to run.
lock_file = open('/tmp/flights.py.lock','w')

try:
    fcntl.flock(lock_file, fcntl.LOCK_EX|fcntl.LOCK_NB)
except (IOError, OSError):
    log('another instance already running')
    quit()

lock_file.write('%d\n'%os.getpid())
lock_file.flush()

# Read the configuration file.
with open(os.path.dirname(os.path.realpath(__file__)) + '/config.json') as config_file:
    config = json.load(config_file)

# Import the needed database library.
if config["database"]["type"] == "mysql":
    import MySQLdb
else:
    import sqlite3

class FlightsProcessor(object):
    def __init__(self, config):
        self.config = config
        self.dbType = config["database"]["type"]
        # List of required keys for position data entries
        self.position_keys = ('lat', 'lon', 'nav_altitude', 'gs', 'track', 'geom_rate', 'hex')

    def setupDBStatements(self, formatSymbol):
        if hasattr(self, 'STMTS'):
            return
        mapping = { "s": formatSymbol }
        self.STMTS = {
            'select_aircraft_count':"SELECT COUNT(*) FROM aircraft WHERE icao = %(s)s" % mapping,
            'select_aircraft_id':   "SELECT id FROM aircraft WHERE icao = %(s)s" % mapping,
            'select_flight_count':  "SELECT COUNT(*) FROM flights WHERE flight = %(s)s" % mapping,
            'select_flight_id':     "SELECT id FROM flights WHERE flight = %(s)s" % mapping,
            'select_position':      "SELECT message FROM positions WHERE flight = %(s)s AND message = %(s)s ORDER BY time DESC LIMIT 1" % mapping,
            'insert_aircraft':      "INSERT INTO aircraft (icao, first_seen, last_seen) VALUES (%(s)s, %(s)s, %(s)s)" % mapping,
            'insert_flight':        "INSERT INTO flights (aircraft, flight, first_seen, last_seen) VALUES (%(s)s, %(s)s, %(s)s, %(s)s)" % mapping,
            'insert_position_sqwk': "INSERT INTO positions (flight, time, message, squawk, latitude, longitude, track, altitude, verticleRate, speed, aircraft) VALUES (%(s)s, %(s)s, %(s)s, %(s)s, %(s)s, %(s)s, %(s)s, %(s)s, %(s)s, %(s)s, %(s)s)" % mapping,
            'insert_position':      "INSERT INTO positions (flight, time, message, latitude, longitude, track, altitude, verticleRate, speed, aircraft) VALUES (%(s)s, %(s)s, %(s)s, %(s)s, %(s)s, %(s)s, %(s)s, %(s)s, %(s)s, %(s)s)" % mapping,
            'update_aircraft_seen': "UPDATE aircraft SET last_seen = %(s)s WHERE icao = %(s)s" % mapping,
            'update_flight_seen':   "UPDATE flights SET aircraft = %(s)s, last_seen = %(s)s WHERE flight = %(s)s" % mapping
        }

    def connectDB(self):
        if self.dbType == "sqlite": ## Connect to a SQLite database.
            self.setupDBStatements("?")
            return sqlite3.connect(self.config["database"]["db"])
        else: ## Connect to a MySQL database.
            self.setupDBStatements("%s")
            return MySQLdb.connect(host=self.config["database"]["host"],
                user=self.config["database"]["user"],
                passwd=self.config["database"]["passwd"],
                db=self.config["database"]["db"])

    def processAircraftList(self, aircraftList):
        db = self.connectDB()
        # Get Database cursor handle
        self.cursor = db.cursor()
        # Assign the time to a variable.
        self.time_now = datetime.datetime.utcnow().strftime("%Y/%m/%d %H:%M:%S")

        for aircraft in aircraftList:
            self.processAircraft(aircraft)

        # Close the database connection.
        db.commit()
        db.close()

    def processAircraft(self, aircraft):
        hexcode = aircraft["hex"]
        # Check if this aircraft was already seen.
        self.cursor.execute(self.STMTS['select_aircraft_count'], (hexcode,))
        row_count = self.cursor.fetchone()
        if row_count[0] == 0:
            # Insert the new aircraft.
            log("Added Aircraft: " + hexcode)
            self.cursor.execute(self.STMTS['insert_aircraft'], (hexcode, self.time_now, self.time_now,))
        else:
            # Update the existing aircraft.
            self.cursor.execute(self.STMTS['update_aircraft_seen'], (self.time_now, hexcode,))
            log("Updating Aircraft: " + hexcode)
        # Get the ID of this aircraft.
        self.cursor.execute(self.STMTS['select_aircraft_id'], (hexcode,))
        row = self.cursor.fetchone()
        aircraft_id = row[0]
        log("\tFound Aircraft ID: " + str(aircraft_id))

        # Check that a flight is tied to this track.
        if 'flight'  in aircraft:
            self.processFlight(aircraft_id, aircraft)

    def processFlight(self, aircraft_id, aircraft):
        flight = aircraft["flight"].strip()
        # Check to see if the flight already exists in the database.
        self.cursor.execute(self.STMTS['select_flight_count'], (flight,))
        row_count = self.cursor.fetchone()
        if row_count[0] == 0:
            # If the flight does not exist in the database add it.
            params = (aircraft_id, flight, self.time_now, self.time_now,)
            self.cursor.execute(self.STMTS['insert_flight'], params)
            log("\t\tAdded Flight: " + flight)
        else:
            # If it already exists pdate the time it was last seen.
            params = (aircraft_id, self.time_now, flight,)
            self.cursor.execute(self.STMTS['update_flight_seen'], params)
            log("\t\tUpdated Flight: " + flight)
        # Get the ID of this flight.
        self.cursor.execute(self.STMTS['select_flight_id'], (flight,))
        row = self.cursor.fetchone()
        flight_id = row[0]

        # Check if position data is available.
        if (all (k in aircraft for k in self.position_keys) and aircraft["altitude"] != "ground"):
            self.processPositions(flight_id, aircraft)

    def processPositions(self, flight_id, aircraft):
        # Get the ID of this aircraft.
        hexcode = aircraft["hex"]
        self.cursor.execute(self.STMTS['select_aircraft_id'], (hexcode,))
        row = self.cursor.fetchone()
        aircraft_id = row[0]

        # Check that this message has not already been added to the database.
        params = (flight_id, aircraft["messages"],)
        self.cursor.execute(self.STMTS['select_position'], params)
        row = self.cursor.fetchone()

        if row == None or row[0] != aircraft["messages"]:
            # Add this position to the database.
            if 'squawk' in aircraft:
                params = (flight_id, self.time_now, aircraft["messages"], aircraft["squawk"],
                            aircraft["lat"], aircraft["lon"], aircraft["track"],
                            aircraft["nav_altitude"], aircraft["geom_rate"], aircraft["gs"], aircraft_id,)
                self.cursor.execute(self.STMTS['insert_position_sqwk'], params)
                log("\t\t\tInserted position w/ Squawk " + repr(params))
            else:
                params = (flight_id, self.time_now, aircraft["messages"], aircraft["lat"], aircraft["lon"],
                            aircraft["track"], aircraft["nav_altitude"], aircraft["geom_rate"], aircraft["gs"], aircraft_id,)
                self.cursor.execute(self.STMTS['insert_position'], params)
                log("\t\t\tInserted position w/o Squawk " + repr(params))
        else:
            log("\t\t\tMessage is the same")


if __name__ == "__main__":
    processor = FlightsProcessor(config)

    # Main run loop
    while True:
        # Read dump1090 aircraft.json.
        response = urlopen('http://127.0.0.1/dump1090/data/aircraft.json')
        data = json.load(response)

        processor.processAircraftList(data["aircraft"])

        log("Last Run: " + datetime.datetime.now().strftime("%Y/%m/%d %H:%M:%S"))
        time.sleep(15)


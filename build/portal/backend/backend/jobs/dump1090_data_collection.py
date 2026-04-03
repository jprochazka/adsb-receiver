import json
import logging

from datetime import datetime
from flask_apscheduler import APScheduler
from urllib.request import urlopen
from flask import current_app
from sqlalchemy import select
from backend.models import db, Aircraft, Flight, Position
from backend.aircraft_classification import classify_aircraft
from backend.opensky_classification import get_opensky_classification

scheduler = APScheduler()
now = None

class DataProcessor(object):

    # Log infromation to console
    def log(self, string):
        print(f'[{datetime.now().strftime("%Y/%m/%d %H:%M:%S")}] {string}') # uncomment to enable debug logging
        return

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

        self.log(f'Beginning to process {len(aircraft_data)} aircraft')
        for aircraft in aircraft_data:
            aircraft_id = self.process_aircraft(aircraft)
            if aircraft_id:
                self.process_flight(aircraft_id, aircraft)
        
        return

    # Process the aircraft
    def process_aircraft(self, aircraft):
        tracked = False
        aircraft_id = None

        try:
            existing_aircraft = db.session.execute(
                select(Aircraft).filter_by(icao=aircraft["hex"])
            ).scalar_one_or_none()
            if existing_aircraft:
                tracked = True
        except Exception as ex:
            logging.error(f'Error encountered while checking if aircraft {aircraft["hex"]} has already been added', exc_info=ex)
            return

        if tracked:
            self.log(f'Updating aircraft ICAO {aircraft["hex"]}')
            try:
                existing_aircraft.last_seen = str(now)
                aircraft_id = existing_aircraft.id
            except Exception as ex:
                logging.error(f'Error encountered while trying to update aircraft {aircraft["hex"]}', exc_info=ex)
                return
        else:
            self.log(f'Inserting aircraft ICAO {aircraft["hex"]}')
            try:
                new_aircraft = Aircraft(
                    icao=aircraft["hex"],
                    first_seen=str(now),
                    last_seen=str(now)
                )
                db.session.add(new_aircraft)
                db.session.flush()  # Get the ID without committing
                aircraft_id = new_aircraft.id
            except Exception as ex:
                logging.error(f'Error encountered while trying to insert aircraft {aircraft["hex"]}', exc_info=ex)
                return

        if 'flight' in aircraft:
            self.process_flight(aircraft_id, aircraft)
        else:
            self.process_positions(aircraft_id , None, aircraft)

        return aircraft_id

    # Process the flight
    def process_flight(self, aircraft_id, aircraft):
        flight_id = None
        
        if 'flight' in aircraft:
            flight = aircraft["flight"].strip()
            emitter_category = aircraft.get("category")
            message_type = aircraft.get("type")
            opensky_class, _, _ = get_opensky_classification(aircraft.get("hex"))
            aircraft_class = classify_aircraft(emitter_category, message_type, flight, opensky_class=opensky_class)

            tracked = False
            try:
                existing_flight = db.session.execute(
                    select(Flight).filter_by(flight=flight)
                ).scalar_one_or_none()
                if existing_flight:
                    tracked = True
            except Exception as ex:
                logging.error(f'Error encountered while checking if flight {flight} has already been added', exc_info=ex)
                return

            if tracked:
                self.log(f'  Updating flight {flight} assigned to aircraft ICAO {aircraft["hex"]}')
                try:
                    existing_flight.last_seen = str(now)
                    existing_flight.emitter_category = emitter_category
                    existing_flight.message_type = message_type
                    existing_flight.aircraft_class = aircraft_class
                    flight_id = existing_flight.id
                except Exception as ex:
                    logging.error(f'Error encountered while trying to update flight {flight}', exc_info=ex)
                    return
            else:
                self.log(f'Inserting flight {flight} assigned to aircraft ICAO {aircraft["hex"]}')
                try:
                    new_flight = Flight(
                        aircraft=aircraft_id,
                        flight=flight,
                        first_seen=str(now),
                        last_seen=str(now),
                        emitter_category=emitter_category,
                        message_type=message_type,
                        aircraft_class=aircraft_class
                    )
                    db.session.add(new_flight)
                    db.session.flush()  # Get the ID without committing
                    flight_id = new_flight.id
                except Exception as ex:
                    logging.error(f'Error encountered while trying to insert flight {flight}', exc_info=ex)
                    return

        else:
            self.log(f'  Aircraft ICAO {aircraft["hex"]} was not assigned a flight')

        self.process_positions(aircraft_id, flight_id, aircraft)

        return

    # Process positions
    def process_positions(self, aircraft_id, flight_id, aircraft):
        position_keys = ('lat', 'lon', 'alt_baro', 'gs', 'track', 'geom_rate', 'hex')
        if (all(key in aircraft for key in position_keys)):

            tracked = False
            try:
                existing_position = db.session.execute(
                    select(Position).filter_by(
                        flight=flight_id, 
                        message=aircraft["messages"]
                    )
                ).scalar_one_or_none()
                if existing_position:
                    tracked = True
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
                
                new_position = Position(
                    flight=flight_id,
                    time=str(now),
                    message=aircraft["messages"],
                    squawk=squawk,
                    latitude=aircraft["lat"],
                    longitude=aircraft["lon"],
                    track=aircraft["track"],
                    altitude=altitude,
                    vertical_rate=aircraft["geom_rate"],
                    speed=aircraft["gs"],
                    aircraft=aircraft_id
                )
                db.session.add(new_position)
            except Exception as ex:
                logging.error(f'Error encountered while inserting position data for message ID {aircraft["messages"]} related to flight {flight_id}', exc_info=ex)
                return

        else:
            self.log(f'  Data required to insert position data for Aircraft ICAO {aircraft["hex"]} is not present')

        return

def dump1090_data_collection_job():
    """Main data collection job function."""
    global now
    
    with current_app.app_context():
        processor = DataProcessor()

        # Setup and begin the data collection job
        processor.log("-- BEGINING FLIGHT RECORDER JOB")
        now = datetime.now()
        processor.process_all_aircraft()
        
        # Commit all changes
        try:
            db.session.commit()
            processor.log("-- Database changes committed successfully")
        except Exception as ex:
            db.session.rollback()
            logging.error("Error committing database changes", exc_info=ex)
        
        processor.log("-- FLIGHT RECORD JOB COMPLETE")
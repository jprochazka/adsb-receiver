import json
import logging

from datetime import datetime
from flask_apscheduler import APScheduler
from urllib.request import urlopen
from flask import current_app
from sqlalchemy import select
from backend.models import db, Dump978Aircraft, Dump978Flight, Dump978Position
from backend.jobs.aircraft_data_collection import (
    aircraft_altitude,
    aircraft_has_position_fields,
    aircraft_squawk,
    classified_flight_fields,
    log_job_message,
)

scheduler = APScheduler()
now = None

class UatDataProcessor(object):

    # Log information through the application logger.
    def log(self, string):
        log_job_message('dump978_data_collection', string)
        return

    # Read JSON supplied by dump978
    def read_json(self):
        self.log("Reading aircraft.json from dump978")
        try:
            raw_json = urlopen('http://127.0.0.1/dump978/data/aircraft.json')
            json_object = json.load(raw_json)
            return json_object
        except Exception as ex:
            logging.error("There was a problem consuming dump978 aircraft.json", exc_info=ex)
            return

    # Begin processing data retrieved from dump978
    def process_all_aircraft(self):
        data = self.read_json()
        if not data:
            return

        aircraft_data = data.get("aircraft", [])

        if len(aircraft_data) == 0:
            self.log(f'There is no UAT aircraft data to process at this time')
            return

        # dump978 retains stale entries — only process aircraft seen within 60 seconds
        recent = [a for a in aircraft_data if a.get("seen", 999) < 60]

        if len(recent) == 0:
            self.log(f'No UAT aircraft have been seen within the last 60 seconds')
            return

        self.log(f'Beginning to process {len(recent)} UAT aircraft')
        for aircraft in recent:
            self.process_aircraft(aircraft)

        return

    # Process the aircraft
    def process_aircraft(self, aircraft):
        tracked = False
        aircraft_id = None

        try:
            existing_aircraft = db.session.execute(
                select(Dump978Aircraft).filter_by(icao=aircraft["hex"])
            ).scalar_one_or_none()
            if existing_aircraft:
                tracked = True
        except Exception as ex:
            logging.error(f'Error encountered while checking if UAT aircraft {aircraft["hex"]} has already been added', exc_info=ex)
            return

        if tracked:
            self.log(f'Updating UAT aircraft ICAO {aircraft["hex"]}')
            try:
                existing_aircraft.last_seen = str(now)
                aircraft_id = existing_aircraft.id
            except Exception as ex:
                logging.error(f'Error encountered while trying to update UAT aircraft {aircraft["hex"]}', exc_info=ex)
                return
        else:
            self.log(f'Inserting UAT aircraft ICAO {aircraft["hex"]}')
            try:
                new_aircraft = Dump978Aircraft(
                    icao=aircraft["hex"],
                    first_seen=str(now),
                    last_seen=str(now)
                )
                db.session.add(new_aircraft)
                db.session.flush()
                aircraft_id = new_aircraft.id
            except Exception as ex:
                logging.error(f'Error encountered while trying to insert UAT aircraft {aircraft["hex"]}', exc_info=ex)
                return

        if 'flight' in aircraft:
            self.process_flight(aircraft_id, aircraft)
        else:
            self.process_positions(aircraft_id, None, aircraft)

        return aircraft_id

    # Process the flight
    def process_flight(self, aircraft_id, aircraft):
        flight_id = None

        if 'flight' in aircraft:
            flight, emitter_category, message_type, aircraft_class = classified_flight_fields(aircraft)

            tracked = False
            try:
                existing_flight = db.session.execute(
                    select(Dump978Flight).filter_by(flight=flight)
                ).scalar_one_or_none()
                if existing_flight:
                    tracked = True
            except Exception as ex:
                logging.error(f'Error encountered while checking if UAT flight {flight} has already been added', exc_info=ex)
                return

            if tracked:
                self.log(f'  Updating UAT flight {flight} assigned to aircraft ICAO {aircraft["hex"]}')
                try:
                    existing_flight.last_seen = str(now)
                    existing_flight.emitter_category = emitter_category
                    existing_flight.message_type = message_type
                    existing_flight.aircraft_class = aircraft_class
                    flight_id = existing_flight.id
                except Exception as ex:
                    logging.error(f'Error encountered while trying to update UAT flight {flight}', exc_info=ex)
                    return
            else:
                self.log(f'  Inserting UAT flight {flight} assigned to aircraft ICAO {aircraft["hex"]}')
                try:
                    new_flight = Dump978Flight(
                        aircraft=aircraft_id,
                        flight=flight,
                        first_seen=str(now),
                        last_seen=str(now),
                        emitter_category=emitter_category,
                        message_type=message_type,
                        aircraft_class=aircraft_class
                    )
                    db.session.add(new_flight)
                    db.session.flush()
                    flight_id = new_flight.id
                except Exception as ex:
                    logging.error(f'Error encountered while trying to insert UAT flight {flight}', exc_info=ex)
                    return

        else:
            self.log(f'  UAT aircraft ICAO {aircraft["hex"]} was not assigned a flight')

        self.process_positions(aircraft_id, flight_id, aircraft)

        return

    # Process positions
    def process_positions(self, aircraft_id, flight_id, aircraft):
        if not aircraft_has_position_fields(aircraft):
            self.log(f'  Data required to insert position data for UAT aircraft ICAO {aircraft["hex"]} is not present')
            return

        # dump978 may not supply a per-aircraft message counter; fall back to None
        # so the position is still recorded — duplicate suppression uses (flight, message)
        # and NULL message values are not deduplicated.
        message = aircraft.get("messages", None)

        if message is not None:
            tracked = False
            try:
                existing_position = db.session.execute(
                    select(Dump978Position).filter_by(
                        flight=flight_id,
                        message=message
                    )
                ).scalar_one_or_none()
                if existing_position:
                    tracked = True
            except Exception as ex:
                logging.error(f'Error encountered while checking if UAT position has already been added for message ID {message} related to flight {flight_id}', exc_info=ex)
                return

            if tracked:
                return

        squawk = aircraft_squawk(aircraft)
        altitude = aircraft_altitude(aircraft)

        try:
            if flight_id is None:
                self.log(f'  Inserting UAT position for aircraft ICAO {aircraft["hex"]}')
            else:
                self.log(f'  Inserting UAT position for aircraft ICAO {aircraft["hex"]} assigned flight {flight_id}')

            new_position = Dump978Position(
                flight=flight_id,
                time=str(now),
                message=message,
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
            logging.error(f'Error encountered while inserting UAT position data for message ID {message} related to flight {flight_id}', exc_info=ex)
            return

        return


def dump978_data_collection_job():
    """Main UAT data collection job function for dump978."""
    global now

    with current_app.app_context():
        processor = UatDataProcessor()

        processor.log("-- BEGINNING UAT FLIGHT RECORDER JOB")
        now = datetime.now()
        processor.process_all_aircraft()

        try:
            db.session.commit()
            processor.log("-- UAT database changes committed successfully")
        except Exception as ex:
            db.session.rollback()
            logging.error("Error committing UAT database changes", exc_info=ex)

        processor.log("-- UAT FLIGHT RECORD JOB COMPLETE")

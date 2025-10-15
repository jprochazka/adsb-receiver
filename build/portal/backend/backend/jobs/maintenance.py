import logging

from datetime import datetime, timedelta
from flask_apscheduler import APScheduler
from flask import current_app
from backend.models import db, Aircraft, Flight, Position, Setting
from sqlalchemy import select, delete

scheduler = APScheduler()
now = None

class MaintenanceProcessor(object):

    # Log infromation to console
    def log(self, string):
        #print(f'[{datetime.now().strftime("%Y/%m/%d %H:%M:%S")}] {string}') # uncomment to enable debug logging
        return

    # Begin maintenance
    def begin_maintenance(self):
        self.log("Getting maintenance settings from the database")
        purge_old_aircraft = False
        try:
            setting = db.session.execute(select(Setting).filter_by(name='purge_older_data')).scalar_one_or_none()
            if setting:
                purge_old_aircraft = setting.value.lower() in ['true', '1']
        except Exception as ex:
            logging.error(f"Error encountered while getting value for setting purge_older_data", exc_info=ex)
            return

        if purge_old_aircraft:
            cutoff_date = datetime.now() - timedelta(days=7300)  # ~20 years
            try:
                days_setting = db.session.execute(select(Setting).filter_by(name='days_to_save')).scalar_one_or_none()
                if days_setting:
                    days_to_save = int(days_setting.value)
                    cutoff_date = datetime.now() - timedelta(days=days_to_save)
            except Exception as ex:
                logging.error(f"Error encountered while getting value for setting days_to_save", exc_info=ex)
                return
            
            self.purge_aircraft(cutoff_date)
            self.purge_positions(cutoff_date)

        else:
            self.log("Maintenance is disabled")

        return

    # Remove aircraft not seen since the specified date
    def purge_aircraft(self, cutoff_date):
        try:
            # Convert cutoff_date to string for comparison
            cutoff_str = str(cutoff_date)
            old_aircraft_result = db.session.execute(
                select(Aircraft).filter(Aircraft.last_seen < cutoff_str)
            )
            aircraft_ids = [aircraft.id for aircraft in old_aircraft_result.scalars()]
        except Exception as ex:
            logging.error(f"Error encountered while getting aircraft IDs not seen since {cutoff_date}", exc_info=ex)
            return

        if len(aircraft_ids) > 0:
            self.log(f"Purging {len(aircraft_ids)} aircraft not seen since {cutoff_date}")
            
            try:
                # Delete related flights and positions first
                self.purge_flights_related_to_aircraft(aircraft_ids, cutoff_date)
                self.purge_positions_related_to_aircraft(aircraft_ids, cutoff_date)
                
                # Delete aircraft
                db.session.execute(
                    delete(Aircraft).where(Aircraft.id.in_(aircraft_ids))
                )
            except Exception as ex:
                logging.error(f"Error deleting aircraft not seen since {cutoff_date}", exc_info=ex)
                return

        return

    # Remove flights related to aircraft not seen since the specified date
    def purge_flights_related_to_aircraft(self, aircraft_ids, cutoff_date):
        try:
            db.session.execute(
                delete(Flight).where(Flight.aircraft.in_(aircraft_ids))
            )
        except Exception as ex:
            logging.error(f"Error deleting flights related to aircraft not seen since {cutoff_date}", exc_info=ex)
            return

        return

    # Remove positions related to aircraft not seen since the specified date
    def purge_positions_related_to_aircraft(self, aircraft_ids, cutoff_date):
        try:
            db.session.execute(
                delete(Position).where(Position.aircraft.in_(aircraft_ids))
            )
        except Exception as ex:
            logging.error(f"Error deleting positions related to aircraft not seen since {cutoff_date}", exc_info=ex)
            return

        return

    # Remove flights older than the specified date
    def purge_flights(self, cutoff_date):
        try:
            cutoff_str = str(cutoff_date)
            old_flights_result = db.session.execute(
                select(Flight).filter(Flight.last_seen < cutoff_str)
            )
            flight_ids = [flight.id for flight in old_flights_result.scalars()]
        except Exception as ex:
            logging.error(f"Error encountered while getting flight IDs not seen since {cutoff_date}", exc_info=ex)
            return

        if len(flight_ids) > 0:
            self.log(f"Purging {len(flight_ids)} flights not seen since {cutoff_date}")
            
            try:
                # Delete related positions first
                self.purge_positions_related_to_flights(flight_ids, cutoff_date)
                
                # Delete flights
                db.session.execute(
                    delete(Flight).where(Flight.id.in_(flight_ids))
                )
            except Exception as ex:
                logging.error(f"Error deleting flights older than the cut off date of {cutoff_date}", exc_info=ex)
                return

            return

    # Remove positions related to flights not seen since the specified date
    def purge_positions_related_to_flights(self, flight_ids, cutoff_date):
        try:
            db.session.execute(
                delete(Position).where(Position.flight.in_(flight_ids))
            )
        except Exception as ex:
            logging.error(f"Error deleting positions related to flights not seen since {cutoff_date}", exc_info=ex)
            return

        return

    # Remove positions older than the specified date
    def purge_positions(self, cutoff_date):
        try:
            cutoff_str = str(cutoff_date)
            db.session.execute(
                delete(Position).where(Position.time < cutoff_str)
            )
            self.log(f"Purged positions older than {cutoff_date}")
        except Exception as ex:
            logging.error(f"Error deleting positions older than the cut off date of {cutoff_date}", exc_info=ex)
            return

        return

def maintenance_job():
    """Main maintenance job function."""
    global now
    
    with current_app.app_context():
        processor = MaintenanceProcessor()

        # Setup and begin the maintenance job
        processor.log("-- BEGINNING PORTAL MAINTENANCE JOB")
        now = datetime.now()
        processor.begin_maintenance()
        
        # Commit all changes
        try:
            db.session.commit()
            processor.log("-- Database changes committed successfully")
        except Exception as ex:
            db.session.rollback()
            logging.error("Error committing database changes", exc_info=ex)
        
        processor.log("-- PORTAL MAINTENANCE JOB COMPLETE")
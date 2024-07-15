import logging

from datetime import datetime, timedelta
from flask_apscheduler import APScheduler
from backend.db import create_connection

scheduler = APScheduler()
connection = None
cursor = None
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
            cursor.execute("SELECT value FROM settings WHERE name = 'purge_older_data'")
            result = cursor.fetchone()[0]
            purge_old_aircraft = result.lower() in ['true', '1']
        except Exception as ex:
            logging.error(f"Error encountered while getting value for setting purge_older_data", exc_info=ex)
            return

        if purge_old_aircraft:
            cutoff_date = datetime.now() - timedelta(years = 20)
            try:
                cursor.execute("SELECT value FROM settings WHERE name = 'days_to_save'")
                days_to_save = cursor.fetchone()[0]
            except Exception as ex:
                logging.error(f"Error encountered while getting value for setting days_to_save", exc_info=ex)
                return
            cutoff_date = datetime.now() - timedelta(days = days_to_save)
            self.purge_aircraft(cutoff_date)
            self.purge_positions(cutoff_date)

        else:
            self.log("Maintenance is disabled")

            connection.commit()

        connection.close()

        return

    # Remove aircraft not seen since the specified date
    def purge_aircraft(self, cutoff_date):
        try:
            cursor.execute("SELECT id FROM aircraft WHERE last_seen < %s", (cutoff_date,))
            aircraft_ids = cursor.fetchall()
        except Exception as ex:
            logging.error(f"Error encountered while getting aircraft IDs not seen since {cutoff_date}", exc_info=ex)
            return

        if len(aircraft_ids) > 0:
            id = tuple(aircraft_ids)
            aircraft_id_params = {'id': id}

            try:
                cursor.execute("DELETE FROM aircraft WHERE id IN %(t)s", aircraft_id_params)
            except Exception as ex:
                logging.error(f"Error deleting aircraft not seen since {cutoff_date}", exc_info=ex)
                return

            self.purge_flights_related_to_aircraft(aircraft_id_params, cutoff_date)
            self.purge_positions_related_to_aircraft(aircraft_id_params, cutoff_date)

        return

    # Remove flights related to aircraft not seen since the specified date
    def purge_flights_related_to_aircraft(self, aircraft_id_params, cutoff_date):
        try:
            cursor.execute("DELETE FROM flights WHERE aircraft = %(t)s", aircraft_id_params)
        except Exception as ex:
            logging.error(f"Error deleting flights related to aircraft not seen since {cutoff_date}", exc_info=ex)
            return

        return

    # Remove positions related to aircraft not seen since the specified date
    def purge_positions_related_to_aircraft(self, aircraft_id_params, cutoff_date):
        try:
            cursor.execute("DELETE FROM positions WHERE aircraft = %(t)s", aircraft_id_params)
        except Exception as ex:
            logging.error(f"Error deleting positions related to aircraft not seen since {cutoff_date}", exc_info=ex)
            return

        return

    # Remove positions older than the specified date
    def purge_flights(self, cutoff_date):
        try:
            cursor.execute("SELECT id FROM flights WHERE last_seen < %s", (cutoff_date,))
            flight_ids = cursor.fetchall()
        except Exception as ex:
            logging.error(f"Error encountered while getting aircraft IDs not seen since {cutoff_date}", exc_info=ex)
            return

        if len(flight_ids) > 0:
            id = tuple(flight_ids)
            flight_id_params = {'id': id}

            try:
                cursor.execute("DELETE FROM flights WHERE id IN %(t)s", flight_id_params)
            except Exception as ex:
                logging.error(f"Error deleting flights older than the cut off date of {cutoff_date}", exc_info=ex)
                return

            self.purge_positions_related_to_flights(flight_id_params, cutoff_date)

            return

    # Remove positions related to aircraft not seen since the specified date
    def purge_positions_related_to_flights(self, flight_id_params, cutoff_date):
        try:
            cursor.execute("DELETE FROM positions WHERE flight = %(t)s", flight_id_params)
        except Exception as ex:
            logging.error(f"Error deleting positions related to flights not seen since {cutoff_date}", exc_info=ex)
            return

        return

    # Remove positions older than the specified date
    def purge_positions(self, cutoff_date):
        try:
            cursor.execute("DELETE FROM positions WHERE time < %s", (cutoff_date,))
        except Exception as ex:
            logging.error(f"Error deleting positions older than the cut off date of {cutoff_date}", exc_info=ex)
            return

        return

def maintenance_job():
    processor = MaintenanceProcessor()

    # Setup and begin the maintenance job
    processor.log("-- BEGINING PORTAL MAINTENANCE JOB")
    connection =  create_connection()
    cursor = connection.cursor()
    processor.begin_maintenance()
    processor.log("-- PORTAL MAINTENANCE JOB COMPLETE")
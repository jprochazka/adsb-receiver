import fcntl
import json
import logging
import MySQLdb
import os
import sqlite3
import time

from datetime import datetime, timedelta

class MaintenanceProcessor(object):

    # Log infromation to console
    def log(self, string):
        print(f'[{datetime.now().strftime("%Y/%m/%d %H:%M:%S")}] {string}') # uncomment to enable debug logging
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

    # Begin maintenance
    def begin_maintenance(self):
        self.log("Getting maintenance settings from the database")
        purge_old_aircraft = False
        try:
            cursor.execute("SELECT value FROM adsb_settings WHERE name = 'purge_older_data'")
            result = cursor.fetchone()[0]
            purge_old_aircraft = result.lower() in ['true', '1']
        except Exception as ex:
            logging.error(f"Error encountered while getting value for setting purge_older_data", exc_info=ex)
            return

        if purge_old_aircraft:
            cutoff_date = datetime.now() - timedelta(years = 20)
            try:
                cursor.execute("SELECT value FROM adsb_settings WHERE name = 'days_to_save'")
                days_to_save = cursor.fetchone()[0]
            except Exception as ex:
                logging.error(f"Error encountered while getting value for setting days_to_save", exc_info=ex)
                return
            cutoff_date = datetime.now() - timedelta(days = days_to_save)

        else:
            self.log("Maintenance is disabled")

            connection.commit()

        connection.close()

        return

    # Remove aircraft not seen since the specified date
    def purge_aircraft(self, cutoff_date):
        try:
            cursor.execute("SELECT id FROM adsb_aircraft WHERE lastSeen < %s", (cutoff_date,))
            aircraft_ids = cursor.fetchall()
        except Exception as ex:
            logging.error(f"Error encountered while getting aircraft IDs not seen since {cutoff_date}", exc_info=ex)
            return

        if len(aircraft_ids) > 0:
            id = tuple(aircraft_ids)
            aircraft_id_params = {'id': id}

            try:
                cursor.execute("DELETE FROM adsb_aircraft WHERE id IN %(t)s", aircraft_id_params)
            except Exception as ex:
                logging.error(f"Error deleting aircraft not seen since {cutoff_date}", exc_info=ex)
                return

            self.purge_flights_related_to_aircraft(aircraft_id_params, cutoff_date)
            self.purge_positions_related_to_aircraft(aircraft_id_params, cutoff_date)

        return

    # Remove flights related to aircraft not seen since the specified date
    def purge_flights_related_to_aircraft(self, aircraft_id_params, cutoff_date):
        try:
            cursor.execute("DELETE FROM adsb_flights WHERE aircraft = %(t)s", aircraft_id_params)
        except Exception as ex:
            logging.error(f"Error deleting flights related to aircraft not seen since {cutoff_date}", exc_info=ex)
            return

        return

    # Remove positions related to aircraft not seen since the specified date
    def purge_positions_related_to_aircraft(self, aircraft_id_params, cutoff_date):
        try:
            cursor.execute("DELETE FROM adsb_positions WHERE aircraft = %(t)s", aircraft_id_params)
        except Exception as ex:
            logging.error(f"Error deleting positions related to aircraft not seen since {cutoff_date}", exc_info=ex)
            return

        return

    # Remove positions older than the specified date
    def purge_flights(self, cutoff_date):
        try:
            cursor.execute("SELECT id FROM adsb_flights WHERE lastSeen < %s", (cutoff_date,))
            flight_ids = cursor.fetchall()
        except Exception as ex:
            logging.error(f"Error encountered while getting aircraft IDs not seen since {cutoff_date}", exc_info=ex)
            return

        if len(flight_ids) > 0:
            id = tuple(flight_ids)
            flight_id_params = {'id': id}

            try:
                cursor.execute("DELETE FROM adsb_flights WHERE id IN %(t)s", flight_id_params)
            except Exception as ex:
                logging.error(f"Error deleting flights older than the cut off date of {cutoff_date}", exc_info=ex)
                return

            self.purge_positions_related_to_flights(flight_id_params, cutoff_date)

            return

    # Remove positions related to aircraft not seen since the specified date
    def purge_positions_related_to_flights(self, flight_id_params, cutoff_date):
        try:
            cursor.execute("DELETE FROM adsb_positions WHERE flight = %(t)s", flight_id_params)
        except Exception as ex:
            logging.error(f"Error deleting positions related to flights not seen since {cutoff_date}", exc_info=ex)
            return

        return

    # Remove positions older than the specified date
    def purge_positions(self, cutoff_date):
        try:
            cursor.execute("DELETE FROM adsb_positions WHERE time < %s", (cutoff_date,))
        except Exception as ex:
            logging.error(f"Error deleting positions older than the cut off date of {cutoff_date}", exc_info=ex)
            return

        return

if __name__ == "__main__":
    processor = MaintenanceProcessor()

    processor.log("-- BEGINING PORTAL MAINTENANCE JOB")

    # Do not allow another instance of the job to run
    lock_file = open('/tmp/maintenance.py.lock','w')
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX|fcntl.LOCK_NB)
    except (IOError, OSError):
        processor.log("-- ANOTHER INSTANCE OF THIS JOB IS RUNNING")
        quit()

    # Set up database connection
    connection =  processor.create_connection()
    cursor = connection.cursor()

    # Begin maintenance job
    lock_file.write('%d\n'%os.getpid())
    processor.begin_maintenance()
    processor.log("-- PORTAL MAINTENANCE JOB COMPLETE")

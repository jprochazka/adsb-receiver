#!/usr/bin/python

import fcntl
import json
import logging
import os
import time
import yaml

from datetime import datetime, timedelta

config = yaml.safe_load(open("config.yml"))

class MaintenanceProcessor(object):

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

    # Begin maintenance 
    def begin_maintenance(self):
        connection = self.create_connection()
        self.cursor = connection.cursor()

        purge_old_aircraft = False
        try:
            self.cursor.execute("SELECT value FROM settings WHERE name 'purgeAircraft'")
            result = self.cursor.fetchone()[0]
            purge_old_aircraft = result.lower() in ['true', '1']
        except Exception as ex:
            logging.error(f"Error encountered while getting value for setting 'purgeAircraft'", exc_info=ex)
            return

        if purge_old_aircraft:
            cutoff_date = datetime.now() - timedelta(years = 20)
            try:
                self.cursor.execute("SELECT value FROM settings WHERE name 'purgeDaysOld'")
                days_to_save = self.cursor.fetchone()[0]
            except Exception as ex:
                logging.error(f"Error encountered while getting value for setting 'purgeDaysOld'", exc_info=ex)
                return
            cutoff_date = datetime.now() - timedelta(days = days_to_save)

            self.purge_aircraft(cutoff_date)
            self.purge_flights(cutoff_date)
            self.purge_positions(cutoff_date)

            connection.commit()
            
        connection.close()

        return

    # Remove aircraft not seen since the specified date
    def purge_aircraft(self, cutoff_date):
        try:
            self.cursor.execute("SELECT id FROM aircraft WHERE lastSeen < %s", (cutoff_date,))
            aircraft_ids = self.cursor.fetchall()
        except Exception as ex:
            logging.error(f"Error encountered while getting aircraft IDs not seen since '{cutoff_date}'", exc_info=ex)
            return

        if len(aircraft_ids) > 0:
            id = tuple(aircraft_ids)
            aircraft_id_params = {'id': id}

            try:
                self.cursor.execute("DELETE FROM aircraft WHERE id IN %(t)s", aircraft_id_params)
            except Exception as ex:
                logging.error(f"Error deleting aircraft not seen since '{cutoff_date}'", exc_info=ex)
                return
        
            self.purge_flights_related_to_aircraft(aircraft_id_params, cutoff_date)
            self.purge_positions_related_to_aircraft(aircraft_id_params, cutoff_date)

        return

    # Remove flights related to aircraft not seen since the specified date
    def purge_flights_related_to_aircraft(self, aircraft_id_params, cutoff_date):
        try:
            self.cursor.execute("DELETE FROM flights WHERE aircraft = %(t)s", aircraft_id_params)
        except Exception as ex:
            logging.error(f"Error deleting flights related to aircraft not seen since '{cutoff_date}'", exc_info=ex)
            return
        
        return

    # Remove positions related to aircraft not seen since the specified date
    def purge_positions_related_to_aircraft(self, aircraft_id_params, cutoff_date):
        try:
            self.cursor.execute("DELETE FROM positions WHERE aircraft = %(t)s", aircraft_id_params)
        except Exception as ex:
            logging.error(f"Error deleting positions related to aircraft not seen since '{cutoff_date}'", exc_info=ex)
            return
        
        return
    
    # Remove positions older than the specified date
    def purge_flights(self, cutoff_date):
        try:
            self.cursor.execute("SELECT id FROM flights WHERE lastSeen < %s", (cutoff_date,))
            flight_ids = self.cursor.fetchall()
        except Exception as ex:
            logging.error(f"Error encountered while getting aircraft IDs not seen since '{cutoff_date}'", exc_info=ex)
            return

        if len(flight_ids) > 0:
            id = tuple(flight_ids)
            flight_id_params = {'id': id}

            try:
                self.cursor.execute("DELETE FROM flights WHERE id IN %(t)s", flight_id_params)
            except Exception as ex:
                logging.error(f"Error deleting flights older than the cut off date of '{cutoff_date}'", exc_info=ex)
                return
            
            self.purge_positions_related_to_flights(flight_id_params, cutoff_date)

            return
    
    # Remove positions related to aircraft not seen since the specified date
    def purge_positions_related_to_flights(self, flight_id_params, cutoff_date):
        try:
            self.cursor.execute("DELETE FROM positions WHERE flight = %(t)s", flight_id_params)
        except Exception as ex:
            logging.error(f"Error deleting positions related to flights not seen since '{cutoff_date}'", exc_info=ex)
            return
        
        return

    # Remove positions older than the specified date
    def purge_positions(self, cutoff_date):
        try:
            self.cursor.execute("DELETE FROM positions WHERE time < %s", (cutoff_date,))
        except Exception as ex:
            logging.error(f"Error deleting positions older than the cut off date of '{cutoff_date}'", exc_info=ex)
            return
        
        return
    
if __name__ == "__main__":
    processor = MaintenanceProcessor()

    logging.info(f"Beginning maintenance job on {datetime.datetime.now().strftime("%Y/%m/%d %H:%M:%S")}")

    # Do not allow another instance of the job to run
    lock_file = open('/tmp/maintenance.py.lock','w')
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX|fcntl.LOCK_NB)
    except (IOError, OSError):
        logging.info('Another instance already running')
        quit()
    
    # Begin maintenance job
    lock_file.write('%d\n'%os.getpid())
    while True:
        processor.begin_maintenance()
        logging.info(f"Maintenance job ended on {datetime.datetime.now().strftime("%Y/%m/%d %H:%M:%S")}")
        time.sleep(15)
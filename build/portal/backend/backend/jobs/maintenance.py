import fcntl
import logging
import os
import yaml

from datetime import datetime, timedelta
from backend.db import create_connection

config = yaml.safe_load(open("config.yml"))

class MaintenanceProcessor(object):

    def begin_maintenance(self):

        if config['database']['maintenance']['purge_old_aircraft']:
            connection = create_connection()
            self.cursor = connection.cursor()

            days_to_save = config['database']['maintenance']['days_to_save'],
            cutoff_date = datetime.now() - timedelta(days = days_to_save)

            self.purge_aircraft(cutoff_date)

            connection.commit()
            connection.close()

        return

    # Remove aircraft not seen since the specified date
    def purge_aircraft(self, cutoff_date):
        try:
            self.cursor.execute("SELECT id FROM aircraft WHERE last_seen < %s", (cutoff_date,))
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
        
            self.purge_related_flights(aircraft_id_params, cutoff_date)
            self.purge_related_positions(aircraft_id_params, cutoff_date)

        return

    # Remove flights related to aircraft not seen since the specified date
    def purge_related_flights(self, aircraft_id_params, cutoff_date):
        try:
            self.cursor.execute("DELETE FROM flights WHERE aircraft = %(t)s", aircraft_id_params)
        except Exception as ex:
            logging.error(f"Error deleting flights related to aircraft not seen since '{cutoff_date}'", exc_info=ex)
            return
        
        return

    # Remove positions related to aircraft not seen since the specified date
    def purge_related_positions(self, aircraft_id_params, cutoff_date):
        try:
            self.cursor.execute("DELETE FROM positions WHERE aircraft = %(t)s", aircraft_id_params)
        except Exception as ex:
            logging.error(f"Error deleting positions related to aircraft not seen since '{cutoff_date}'", exc_info=ex)
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
    processor.begin_maintenance()
    logging.info(f"Maintenance job ended on {datetime.datetime.now().strftime("%Y/%m/%d %H:%M:%S")}")
    lock_file.flush()
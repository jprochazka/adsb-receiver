#!/usr/bin/python

import datetime
import fcntl
import json
import os
import time

# Do not allow another instance of the script to run.
lock_file = open('/tmp/flights.py.lock','w')

try:
    fcntl.flock(lock_file, fcntl.LOCK_EX|fcntl.LOCK_NB)
except (IOError, OSError):
    quit()

lock_file.write('%d\n'%os.getpid())
lock_file.flush()

while True:

    ## Read the configuration file.
    with open(os.path.dirname(os.path.realpath(__file__)) + '/config.json') as config_file:
        config = json.load(config_file)

    ## Import the needed database library and set up database connection.
    if config["database"]["type"] == "mysql":
        import MySQLdb
        db = MySQLdb.connect(host=config["database"]["host"], user=config["database"]["user"], passwd=config["database"]["passwd"], db=config["database"]["db"])

    if config["database"]["type"] == "sqlite":
        import sqlite3
        db = sqlite3.connect(config["database"]["db"])

    cursor = db.cursor()

    ## Get maintenance settings.

    purge_aircraft = False
    # MySQL and SQLite
    cursor.execute("SELECT value FROM settings WHERE name = 'purgeAircraft'")
    row = cursor.fetchone()
    if row:
        purge_aircraft = row

    purge_flights = False
    # MySQL and SQLite
    cursor.execute("SELECT value FROM settings WHERE name = 'purgeFlights'")
    row = cursor.fetchone()
    if row:
        purge_flights = row

    purge_positions = False
    # MySQL and SQLite
    cursor.execute("SELECT value FROM settings WHERE name = 'purgePositions'")
    row = cursor.fetchone()
    if row:
        purge_positions = row

    purge_days_old = False
    # MySQL and SQLite
    cursor.execute("SELECT value FROM settings WHERE name = 'purgeDaysOld'")
    row = cursor.fetchone()
    if row:
        purge_days_old = row

    ## Create the purge date from the age specified.

    if purge_days_old:
        purge_datetime = datetime.datetime.utcnow() - timedelta(days=purge_days_old)
        purge_date = purge_datetime.strftime("%Y/%m/%d %H:%M:%S")
    else:
        purge_datetime = None
        purge_date = None

    ## Remove aircraft not seen since the specified date.

    if purge_aircraft and purge_date:
        # MySQL
        if config["database"]["type"] == "mysql":
            cursor.execute("SELECT id FROM aircraft WHERE last_seen < %s", purge_date)
            rows = cursor.fetchall()
            for row in rows:
                cursor.execute("DELETE FROM positions WHERE aircraft = %s", row[0])
                cursor.execute("DELETE FROM flights WHERE aircraft = %s", row[0])
                cursor.execute("DELETE FROM aircraft WHERE id = %s", row[0])

        # SQLite
        if config["database"]["type"] == "sqlite":
            params = (purge_date,)
            cursor.execute("SELECT id FROM aircraft WHERE last_seen < ?", params)
            rows = cursor.fetchall()
            for row in rows:
                params = (row[0],)
                cursor.execute("DELETE FROM positions WHERE aircraft = ?", params)
                cursor.execute("DELETE FROM flights WHERE aircraft = ?", params)
                cursor.execute("DELETE FROM aircraft WHERE id = ?", params)

    ## Remove flights not seen since the specified date.

    if purge_flights and purge_date:
        # MySQL
        if config["database"]["type"] == "mysql":
            cursor.execute("SELECT id FROM flights WHERE last_seen < %s", purge_date)
            rows = cursor.fetchall()
            for row in rows:
                cursor.execute("DELETE FROM positions WHERE flight = %s", row[0])
                cursor.execute("DELETE FROM flights WHERE id = %s", row[0])

        #SQLite
        if config["database"]["type"] == "sqlite":
            params = (purge_date,)
            cursor.execute("SELECT id FROM flights WHERE last_seen < ?", params)
            rows = cursor.fetchall()
            for row in rows:
                params = (row[0],)
                cursor.execute("DELETE FROM positions WHERE flight = ?", params)
                cursor.execute("DELETE FROM flights WHERE id = ?", params)

    ## Remove positions older than the specified date.

    if purge_positions and purge_date:
        # MySQL
        if config["database"]["type"] == "mysql":
            cursor.execute("DELETE FROM positions WHERE time < %s", purge_date)

        #SQLite
        if config["database"]["type"] == "sqlite":
            params = (purge_date,)
            cursor.execute("DELETE FROM positions WHERE time < ?", params)

    ## Close the database connection.

    db.commit()
    db.close()

    ## Sleep until the next run.

    time.sleep(3600)

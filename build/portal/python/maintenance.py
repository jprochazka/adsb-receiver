#!/usr/bin/python

#================================================================================#
#                             ADS-B FEEDER PORTAL                                #
# ------------------------------------------------------------------------------ #
# Copyright and Licensing Information:                                           #
#                                                                                #
# The MIT License (MIT)                                                          #
#                                                                                #
# Copyright (c) 2015-2016 Joseph A. Prochazka                                    #
#                                                                                #
# Permission is hereby granted, free of charge, to any person obtaining a copy   #
# of this software and associated documentation files (the "Software"), to deal  #
# in the Software without restriction, including without limitation the rights   #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell      #
# copies of the Software, and to permit persons to whom the Software is          #
# furnished to do so, subject to the following conditions:                       #
#                                                                                #
# The above copyright notice and this permission notice shall be included in all #
# copies or substantial portions of the Software.                                #
#                                                                                #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR     #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,       #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE    #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER         #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,  #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE  #
# SOFTWARE.                                                                      #
#================================================================================#

import json
import os
import datetime

while true:

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

    # MySQL
    if config["database"]["type"] == "mysql":
        cursor.execute("SELECT value FROM adsb_settings WHERE name = %s", "purgeAircraft")
    # SQLite
    if config["database"]["type"] == "sqlite":
        params = ("purgeAircraft",)
        cursor.execute("SELECT value FROM adsb_settings WHERE name = ?", params)
    row = cursor.fetchone()
    purge_aircraft = row[0]

    # MySQL
    if config["database"]["type"] == "mysql":
        cursor.execute("SELECT value FROM adsb_settings WHERE name = %s", "purgeFlights")
    # SQLite
    if config["database"]["type"] == "sqlite":
        params = ("purgeFlights",)
        cursor.execute("SELECT value FROM adsb_settings WHERE name = ?", params)
    row = cursor.fetchone()
    purge_flights = row[0]

    # MySQL
    if config["database"]["type"] == "mysql":
        cursor.execute("SELECT value FROM adsb_settings WHERE name = %s", "purgePositions")
    # SQLite
    if config["database"]["type"] == "sqlite":
        params = ("purgePositions",)
        cursor.execute("SELECT value FROM adsb_settings WHERE name = ?", params)
    row = cursor.fetchone()
    purge_positions = row[0]

    # MySQL
    if config["database"]["type"] == "mysql":
        cursor.execute("SELECT value FROM adsb_settings WHERE name = %s", "purgeDaysOld")
    # SQLite
    if config["database"]["type"] == "sqlite":
        params = ("purgeDaysOld",)
        cursor.execute("SELECT value FROM adsb_settings WHERE name = ?", params)
    row = cursor.fetchone()
    purge_days_old = row[0]

    ## Create the purge date from the age specified.

    purge_datetime = datetime.datetime.utcnow() - timedelta(days=purge_days_old)
    purge_date = purge_datetime.strftime("%Y/%m/%d %H:%M:%S")

    ## Remove aircraft not seen since the specified date.

    if purge_aircraft == true:
        # MySQL
        if config["database"]["type"] == "mysql":
            cursor.execute("SELECT id FROM adsb_aircraft WHERE lastSeen < %s", purge_date)
            rows = cursor.fetchall()
            for row in rows:
                cursor.execute("DELETE FROM adsb_positions WHERE aircraft = %s", row[0])
                cursor.execute("DELETE FROM adsb_flights WHERE aircraft = %s", row[0])
                cursor.execute("DELETE FROM adsb_aircraft WHERE id = %s", row[0])

        # SQLite
        if config["database"]["type"] == "sqlite":
            params = (purge_date,)
            cursor.execute("SELECT id FROM adsb_aircraft WHERE lastSeen < ?", params)
            rows = cursor.fetchall()
            for row in rows:
                params = (row[0],)
                cursor.execute("DELETE FROM adsb_positions WHERE aircraft = ?", params)
                cursor.execute("DELETE FROM adsb_flights WHERE aircraft = ?", params)
                cursor.execute("DELETE FROM adsb_aircraft WHERE id = ?", params)

    ## Remove flights not seen since the specified date.

    if purge_flights == true:
        # MySQL
        if config["database"]["type"] == "mysql":
            cursor.execute("SELECT id FROM adsb_flights WHERE lastSeen < %s", purge_date)
            rows = cursor.fetchall()
            for row in rows:
                cursor.execute("DELETE FROM adsb_positions WHERE flight = %s", row[0])
                cursor.execute("DELETE FROM adsb_flights WHERE id = %s", row[0])

        #SQLite
        if config["database"]["type"] == "sqlite":
            params = (purge_date,)
            cursor.execute("SELECT id FROM adsb_flights WHERE lastSeen < ?", params)
            rows = cursor.fetchall()
            for row in rows:
                params = (row[0],)
                cursor.execute("DELETE FROM adsb_positions WHERE flight = ?", params)
                cursor.execute("DELETE FROM adsb_flights WHERE id = ?", params)

    ## Remove positions older than the specified date.

    if purge_positions == true:
        # MySQL
        if config["database"]["type"] == "mysql":
            cursor.execute("DELETE FROM adsb_positions WHERE time < %s", purge_date)

        #SQLite
        if config["database"]["type"] == "sqlite":
            params = (purge_date,)
             cursor.execute("DELETE FROM adsb_positions WHERE time < ?", params)

    ## Close the database connection.

    db.commit()
    db.close()

    ## Sleep until the next run.

    time.sleep(3600)

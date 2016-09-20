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

import datetime
import json
import time
import os

def log(string):
    #print(string) # uncomment to enable debug logging
    return

# Read the configuration file.
with open(os.path.dirname(os.path.realpath(__file__)) + '/config.json') as config_file:
    config = json.load(config_file)

# Import the needed database library.
if config["database"]["type"] == "mysql":
    import MySQLdb
else:
    import sqlite3


class NotificationsProcessor(object):
    def __init__(self, config):
        self.config = config
        self.dbType = config["database"]["type"]

    def setupDBStatements(self, formatSymbol):
        if hasattr(self, 'STMTS'):
            return
        mapping = { "s": formatSymbol }
        self.STMTS = {
            'select_notifications_count': "SELECT COUNT(*) FROM adsb_flightNotifications WHERE flight = %(s)s AND lastSeen < %(s)s" % mapping,
            'update_notifications_message':  "UPDATE adsb_flightNotifications SET lastSeen = %(s)s WHERE flight = %(s)s" % mapping
        }

    def connectDB(self):
        if self.dbType == "sqlite": ## Connect to a SQLite database.
            self.setupDBStatements("?")
            return sqlite3.connect(self.config["database"]["db"])
        elif self.dbType == "mysql": ## Connect to a MySQL database.
            self.setupDBStatements("%s")
            return MySQLdb.connect(host=self.config["database"]["host"],
                user=self.config["database"]["user"],
                passwd=self.config["database"]["passwd"],
                db=self.config["database"]["db"])

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


##############################################################
# TODO:                                                      #
#------------------------------------------------------------#
# When no flights are seen a JSON error is encountered.      #
# Send an email to the administrators when a flight is seen. #
# Send a tweet to Twitter when a flight is seen.             #
# Add support for MySQL.                                     #
# Add support for SQLite.                                    #
##############################################################


import json
import urllib2

from xml.dom import minidom


###############################################
## GATHER XML DATA


# Get the portal settings from the settings.xml file.
doc = minidom.parse("/var/www/html/data/settings.xml")
settings = doc.getElementsByTagName("setting")

# Get the portal administrators from the administrators.xml file.
doc = minidom.parse("/var/www/html/data/administrators.xml")
administrators = doc.getElementsByTagName("administrator")

# Get flights to send notifications for from the notifications.xml file.
doc = minidom.parse("/var/www/html/data/notifications.xml")
flights = doc.getElementsByTagName("flight")


###############################################
## SEND NOTIFICATION(S) IF FLIGHTS ARE FOUND


# Get notification JSON from the portal.
response = urllib2.urlopen("http://localhost/api/notifications.php?type=flights")
flights_seen = json.load(response)

for flight in flights:
    name = flight.getElementsByTagName("name")[0]
    lastMessageCount = flight.getElementsByTagName("lastMessageCount")[0]

    for i in flights_seen['tracking']:
        if name.firstChild.data.strip() == i['flight'] and lastMessageCount.firstChild.data.strip() < i['lastMessageCount']:
            print "Send emails..."
            print "Send tweet..."

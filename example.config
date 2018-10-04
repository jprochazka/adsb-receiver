#!/bin/bash

#####################################################################################
#                                  ADS-B RECEIVER                                   #
#####################################################################################
#                                                                                   #
# This script is not meant to be executed directly.                                 #
# Instead execute install.sh to begin the installation process.                     #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                   #
# Copyright (c) 2015-2016 Joseph A. Prochazka                                       #
#                                                                                   #
# Permission is hereby granted, free of charge, to any person obtaining a copy      #
# of this software and associated documentation files (the "Software"), to deal     #
# in the Software without restriction, including without limitation the rights      #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell         #
# copies of the Software, and to permit persons to whom the Software is             #
# furnished to do so, subject to the following conditions:                          #
#                                                                                   #
# The above copyright notice and this permission notice shall be included in all    #
# copies or substantial portions of the Software.                                   #
#                                                                                   #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR        #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,          #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE       #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER            #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,     #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE     #
# SOFTWARE.                                                                         #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

## RECEIVER AND OPERATING SYSTEM

# Allow scipts to update the operating system software installed on your device.

UPDATE_OPERATING_SYSTEM="true"

# You can save the current branch state if you altered any of the core files within
# the ADS-B Receiver Project respository cloned to your device by copying it to a
# new branch. You will need to specify an name for this new branch if you do decide
# to backup your changes to another branch.

BACKUP_BRANCH_STATE="false"
BACKUP_BRANCH_NAME=""

# Specify the receivers latitude and longitude as well as its altitude. This
# information can be obtained from https://www.swiftbyte.com/toolbox/geocode by
# simply supplying an address for this receiver.

RECEIVER_LATITUDE=""
RECEIVER_LONGITUDE=""
RECEIVER_ALTITUDE=""


## DECODERS

# ---------------------------------------------------------------------------------
#   DUMP1090
# ---------------------------------------------------------------------------------
#
# One of two dump1090 forks must be installed by these scripts. You are required to
# specify one of the compatably forks in order to complete setup. The two available
# options at this time are the following:
#
# mutability : dump1090-mutability : https://github.com/mutability/dump1090
# fa         : dump1090-fa         : https://github.com/flightaware/dump1090
#
# If dump1090-fa (fa) is selected PiAware must be installed as
# well in order for dump1090-fa to run properly.

DUMP1090_FORK="mutability"

# If set to true dump1090 will be upgraded to the latest available version.
#
# Some forks such as dump1090-mutability are not released by version but instead
# changes to made to the software are commited to the projects master branch with
# no release being made. With no way to gage whether or not improvments or
# additions have been made to the software you may from time to time have to
# download, build, and install the source in order to ensure you are running
# an up to date version of the software. Set this variable to true if you wish to
# force the reinstallation of dump1090 on your device.

DUMP1090_UPGRADE="true"

# Some setups will require you to specify the USB device dump1090 will be using.
# In particular when you are setting up more than one decoder on a single device.
# If you are only running the dump1090 decoder and not in cujunction with say
# dump978 on the same device then it is safe to leave this variable empty.
#
# This variable will be ignored if dump1090 is the only decoder installed.

DUMP1090_DEVICE_ID="0"

# OPTIONAL: You can optionally specify a Bing Maps API key in order to use maps
# provided by the Bing Maps service within the dump1090 map page. You can sign up
# for a Bing Maps API key at https://www.bingmapsportal.com.

DUMP1090_BING_MAPS_KEY=""

# OPTIONAL: Maximum range rings can be added to the dump109 map usings data
# obtained from Heywhatsthat.com. You will need to generate a new panorama for
# the receivers location before begining the installation. Note that the ability
# to download the JSON file making up the rings may expire over time on the
# Heywhatsthat.com website.

DUMP1090_HEYWHATSTHAT_INSTALL="false"

# In order to add these rings to your dump1090 map you will first need to visit
# http://www.heywhatsthat.com and generate a new panorama centered on the location
# of your receiver. You will need to supply the view id which is the series of
# letters and/or numbers after ?view= in the URL located near the top left hand
# corner of the page the panorama is displayed.

DUMP1090_HEYWHATSTHAT_ID=""

# Set the following variables to the altitude in meters for each Heywhatsthat.com
# maximum range ring which will be displayed on the dump1090 map.
#
# 3048 meters equals 10000 feet.
# 12192 meters equals 40000 feet.

DUMP1090_HEYWHATSTHAT_RING_ONE="3048"
DUMP1090_HEYWHATSTHAT_RING_TWO="12192"

# MUTABILITY ONLY: You can specify if dump1090-mutability will be allowed to listen
# on all IP addresses assigned to the device or only on the loopback address.'

DUMP1090_BIND_TO_ALL_IPS="true"

# MUTABILITY ONLY: You can specify the unit of measure used by dump1090-mutability.
# This can be set to either "metric" or "imperial".

DUMP1090_UNIT_OF_MEASUREMENT="imperial"

# ---------------------------------------------------------------------------------
#   DUMP978
# ---------------------------------------------------------------------------------

DUMP978_INSTALL="false"

# The dump978 source code is not versioned with fixes and changes to the source
# code directly commited to the master branch of the repoisitory when added. Since
# there is no version to go off of to judge whether or not changes have been made
# you must rebuild the binaries from source each time a change is made which you
# may need. Setting this option to true will download and rebuild the source code
# each time the installation is ran.

DUMP978_UPGRADE="true"

# When setting up dump978 along with another decoder such as dump978 on the same
# device you will be required specify the USB device dump1090 as well as dump978
# will be using.
#
# If installing dump978 on a device running dump1090 as well as dump978 the
# variable named DUMP1090_DEVICE_ID must be set as well.

DUMP978_DEVICE_ID="1"

## FEEDERS

# ---------------------------------------------------------------------------------
#   ADS-B Exchange
# ---------------------------------------------------------------------------------

ADSBEXCHANGE_INSTALL="false"
ADSBEXCHANGE_UPGRADE="false"

# ---------------------------------------------------------------------------------
#   ADSBHub
# ---------------------------------------------------------------------------------

ADSBHUB_INSTALL="false"

# The receiver name should be a unique name specific to this receiver which you can
# use to identify your receiver on the ADS-B Exchange MLAT status pages. This
# variable is required in order to setup the MLAT client to feed ADS-B Exchange
# properly.

ADSBEXCHANGE_RECEIVER_USERNAME="I_DID_NOT_READ_THE_COMMENTS"

# ---------------------------------------------------------------------------------
#   FLIGHTRADAR24 FEEDER CLIENT
# ---------------------------------------------------------------------------------
#
# The Flightradar24 Feeder Client requires the user to interact physically with the
# device during installation. If you are to choose to set this installation option
# to true then the interactive installation  mode will be automatically enabled
# for the entire installation process.

FLIGHTRADAR24_INSTALL="false"

# ---------------------------------------------------------------------------------
#   OPENSKY NETWORK FEEDER CLIENT
# ---------------------------------------------------------------------------------
#
# Installation includes the addition of the OpenSky Network apt repository to your
# device. After the repository has been added apt will be used to install and keep
# the client up to date.

OPENSKY_NETWORK_INSTALL="false"

# ---------------------------------------------------------------------------------
#   PIAWARE
# ---------------------------------------------------------------------------------
#
# Please note that if the FlightAware fork of dump1090 is chosen to be installed
# PiAware will be installed reguardless of the option set here.

PIAWARE_INSTALL="false"
PIAWARE_UPGRADE="true"

# The variables PIAWARE_FLIGHTAWARE_LOGIN and PIAWARE_FLIGHTAWARE_PASSWORD are
# optional and may be left empty. If you decide to leave these values empty you
# will need to manual claim this device as your on FlightAwares website.
# Information on claiming your device can be found at the following address:
#
# http://flightaware.com/adsb/piaware/claim

PIAWARE_FLIGHTAWARE_LOGIN=""
PIAWARE_FLIGHTAWARE_PASSWORD=""

# ---------------------------------------------------------------------------------
#   PLANEFINDER ADS-B CLIENT
# ---------------------------------------------------------------------------------
#
# After setup has completed the Plane Finder ADS-B Client should be installed and
# running however this script is only capable of installing the Plane Finder ADS-B
# Client. There are still a few steps left which you must manually do through the
# Plane Finder ADS-B Client itself after the setup process is complete.
#
# Visit the following URL: http://127.0.0.1:30053
#
# Use the following settings when asked for them.
#
# Data Format: Beast
# Tcp Address: 127.0.0.1
# Tcp Port: 30005

PLANEFINDER_INSTALL="false"
PLANEFINDER_UPGRADE="true"

# ---------------------------------------------------------------------------------
#   WEB PORTAL
# ---------------------------------------------------------------------------------
#
# If you wish to install the ADS-B Receiver Project portal set the following
# variable to true if not then set this variable to false.
#
# In order to complete the portal setup process you will still be required to visit
# the URL http://127.0.0.1/install/ in your favorite web browser. If the portal is
# ever updated you will need to visit the same URL to complete the upgrade as well.

WEBPORTAL_INSTALL="true"

# Set the following variable to true to keep your portal up to date each time the
# script are ran on this device.

WEBPORTAL_UPDATE="true"

# It is highly recomended that any device using a SD card for data storage does
# not enable the portal's advanced featires. Doing so may shorten the life of your
# storage device greatly.

WEBPORTAL_ADVANCED="false"

# If WEBPORTAL_ADVANCED is set to "true" the variable WEBPORTAL_DATABASE_ENGINE
# must be set as well. There are currently two database engine options available.
#
# mysql  : MySQL  : http://www.mysql.com/
# sqlite : SQLite : http://sqlite.org/

WEBPORTAL_DATABASE_ENGINE=""

# If you are using MySQL as your database engine you must specify if the database
# server will be hosted locally on this device or at a remote location.

WEBPORTAL_MYSQL_SERVER_LOCAL="true"

# If you are using MySQL you will also need to specify the hostname or address of
# the MySQL server you are going to use. If the MySQL server will be running
# locally on this device then the WEBPORTAL_MYSQL_SERVER_HOSTNAME value should
# be set to "localhost".

WEBPORTAL_MYSQL_SERVER_HOSTNAME="localhost"

# If the database to be used by the portal already exists set you will want to set
# the value of the variable WEBPORTAL_DATABASE_EXISTS to "true" in order to skip
# the database creation process.

WEBPORTAL_DATABASE_EXISTS="false"

# If the database which will be used by the portal does not exist you will need to
# supply administrative credentials the script can use to log into the database
# eengine in order to create the database.

WEBPORTAL_DATABASE_ADMIN_USER=""
WEBPORTAL_DATABASE_ADMIN_PASSWORD=""

# You will need to supply both the database name as well as the credentials needed
# to log into the database server even if the database does or does not exist yet.

WEBPORTAL_DATABASE_NAME=""
WEBPORTAL_DATABASE_USER=""
WEBPORTAL_DATABASE_PASSWORD=""


## EXTRAS

# ---------------------------------------------------------------------------------
#   ABOVETUSTIN
# ---------------------------------------------------------------------------------
#
# AboveTustin is a twitter bot which can be installed using these scripts. In order
# for AboveTustin to work properly make sure to fill in all of the following
# variables including proper working twitter keys, secrets, and tokens.

ABOVETUSTIN_INSTALL="false"

# Setting the following variable to true will download the latest copy of the files
# making up AboveTustin from the project's Git repository on GitHub. 

ABOVETUSTIN_UPGRADE="true"

# If no precompiled PhantomJS binary is available for download for use on your
# device the scripts are capable of building a binary from source. However doing so
# may take quite some time measurable in hours. Set this variable to true if you
# wish to allow the scripts to compile a binary if one is not available.

ABOVETUSTIN_COMPILE_IF_NEEDED="false"

# You will need to obtain tokens and keys from the Twitter developers site in order
# to send tweets to your Twitter account via the AboveTustin Twitter bot. You can
# sign up for a free Twitter developer account at https://dev.twitter.com.

TWITTER_ACCESS_TOKEN=""
TWITTER_ACCESS_TOKEN_SECRET=""
TWITTER_CONSUMER_KEY=""
TWITTER_CONSUMER_SECRET=""

# ---------------------------------------------------------------------------------
#   BEAST-SPLITTER
# ---------------------------------------------------------------------------------
#
# It is possible to allow these scripts to install the beast-splitter application
# on this device. The beast-splitter package makes it possible to feed data from
# devices such as the Mode-S Beast into dump1090. If you are not using a device
# such as the Mode-S Beast there is no reason to install this package.

BEASTSPLITTER_INSTALL="false"

# The beast-splitter source code is not versioned so setting the this variable to
# true will reinstall beast-splitter insuring that the most recent code commited
# to the master branch of the project is built and installed on this device.

BEASTSPLITTER_UPGRADE="false"

# If you decide to install beast-splitter you must specify the ports the
# application will both listen on and send data on while running. Be sure to set
# the listen port to one not already being used. The dump1090 application generally
# listens on port 30005 so this port should be changed in order not to conflict
# with dump1090. The majority of the time the connect port should be set to the
# port dump1090 listens for external data on by default being port 30104.

BEASTSPLITTER_LISTEN_PORT="30005"
BEASTSPLITTER_CONNECT_PORT="30104"

# ---------------------------------------------------------------------------------
#   DUCK DNS FREE DYNAMIC DNS HOSTING
# ---------------------------------------------------------------------------------
#
# These scripts are capable of setting up your receiver to use Duck DNS for dynamic
# DNS hosting. The script requires setting up an account on the Duck DNS website
# found at http://www.duckdns.org. You will need to setup a sub domain as well as
# obtain a key and supply it here in order to complete the setup process.
#
# Set the following variable to true in order to setup this option.

DUCKDNS_INSTALL="false"

# Set the following variable to true only if you wish to modify the current setup.

DUCKDNS_UPGRADE="false"

# supply the subdomain and key supplied to you by duckdns.org.

DUCKDNS_DOMAIN=""
DUCKDNS_TOKEN=""

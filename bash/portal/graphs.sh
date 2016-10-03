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

## VARIABLES

PROJECTROOTDIRECTORY="$PWD"
BUILDDIRECTORY="$PROJECTROOTDIRECTORY/build"
PORTALBUILDDIRECTORY="$BUILDDIRECTORY/portal"

## CHECK FOR PREREQUISITE PACKAGES

echo ""
echo -e "\e[95m  Setting up collectd performance graphs...\e[97m"
echo ""

## MODIFY THE DUMP1090-MUTABILITY INIT SCRIPT TO MEASURE AND RETAIN NOISE DATA

if [ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
    echo -e "\e[94m  Modifying the dump1090-mutability init script to add noise measurements...\e[97m"
    sudo sed -i 's/ARGS=""/ARGS="--measure-noise "/g' /etc/init.d/dump1090-mutability
    echo -e "\e[94m  Reloading the systemd manager configuration...\e[97m"
    sudo systemctl daemon-reload
    echo -e "\e[94m  Reloading dump1090-mutability...\e[97m"
    echo ""
    sudo /etc/init.d/dump1090-mutability force-reload
    echo ""
fi

## BACKUP AND REPLACE COLLECTD.CONF

# Check if the file /etc/collectd/collectd.conf exists and if so back it up.
if [ -f /etc/collectd/collectd.conf ]; then
    echo -e "\e[94m  Backing up the current collectd.conf file...\e[97m"
    sudo mv /etc/collectd/collectd.conf /etc/collectd/collectd.conf.back
fi
echo -e "\e[94m  Replacing the current collectd.conf file...\e[97m"
sudo tee -a /etc/collectd/collectd.conf > /dev/null <<EOF
# Config file for collectd(1).

##############################################################################
# Global                                                                     #
##############################################################################
Hostname "localhost"

#----------------------------------------------------------------------------#
# Added types for dump1090.                                                  #
# Make sure the path to dump1090.db is correct.                              #
#----------------------------------------------------------------------------#
TypesDB "$PORTALBUILDDIRECTORY/graphs/dump1090.db" "/usr/share/collectd/types.db"

#----------------------------------------------------------------------------#
# Interval at which to query values. This may be overwritten on a per-plugin #
# base by using the 'Interval' option of the LoadPlugin block:               #
#   <LoadPlugin foo>                                                         #
#       Interval 60                                                          #
#   </LoadPlugin>                                                            #
#----------------------------------------------------------------------------#
Interval 60
Timeout 2
ReadThreads 5
WriteThreads 1

##############################################################################
# Logging                                                                    #
##############################################################################
LoadPlugin syslog

<Plugin syslog>
	LogLevel info
</Plugin>

##############################################################################
# LoadPlugin section                                                         #
#----------------------------------------------------------------------------#
# Specify what features to activate.                                         #
##############################################################################
LoadPlugin rrdtool
LoadPlugin table
LoadPlugin interface
LoadPlugin memory
LoadPlugin cpu
LoadPlugin aggregation
LoadPlugin match_regex
LoadPlugin df
LoadPlugin disk
<LoadPlugin python>
	Globals true
</LoadPlugin>

##############################################################################
# Plugin configuration                                                       #
##############################################################################
<Plugin rrdtool>
	DataDir "/var/lib/collectd/rrd"
</Plugin>

#----------------------------------------------------------------------------#
# Configure the dump1090 python module.                                      #
#                                                                            #
# Each Instance block collects statistics from a separate named dump1090.    #
# The URL should be the base URL of the webmap, i.e. in the examples below,  #
# statistics will be loaded from http://localhost/dump1090/data/stats.json   #
#----------------------------------------------------------------------------#
<Plugin python>
	ModulePath "$PORTALBUILDDIRECTORY/graphs"
	LogTraces true
	Import "dump1090"
	<Module dump1090>
		<Instance localhost>
			URL "http://localhost/dump1090"
		</Instance>
	</Module>
</Plugin>

<Plugin table>
	<Table "/sys/class/thermal/thermal_zone0/temp">
		Instance localhost
		Separator " "
		<Result>
			Type gauge
			InstancePrefix "cpu_temp"
			ValuesFrom 0
		</Result>
	</Table>
</Plugin>

<Plugin "interface">
	Interface "eth0"
        Interface "wlan0"
</Plugin>

<Plugin "aggregation">
	<Aggregation>
		Plugin "cpu"
		Type "cpu"
		GroupBy "Host"
		GroupBy "TypeInstance"
		CalculateAverage true
	</Aggregation>
</Plugin>

<Plugin "df">
	MountPoint "/"
	IgnoreSelected false
	ReportReserved true
	ReportInodes true
</Plugin>

<Plugin "disk">
	Disk "mmcblk0"
	IgnoreSelected false
</Plugin>

<Chain "PostCache">
	<Rule>
		<Match regex>
		Plugin "^cpu\$"
			PluginInstance "^[0-9]+\$"
		</Match>
		<Target write>
			Plugin "aggregation"
		</Target>
		Target stop
	</Rule>
	Target "write"
</Chain>
EOF

## RELOAD COLLECTD

echo -e "\e[94m  Reloading collectd so the new configuration is used...\e[97m"
echo ""
sudo /etc/init.d/collectd force-reload
echo ""

## EDIT CRONTAB

echo -e "\e[94m  Making the make-collectd-graphs.sh script executable...\e[97m"
chmod +x $PORTALBUILDDIRECTORY/graphs/make-collectd-graphs.sh

# The next block is temporary in order to insure this file is
# deleted on older installation before the project renaming.
if [ -f /etc/cron.d/adsb-feeder-performance-graphs ]; then
    echo -e "\e[94m  Removing outdated performance graphs cron file...\e[97m"
    sudo rm -f /etc/cron.d/adsb-feeder-performance-graphs
fi

if [ -f /etc/cron.d/adsb-receiver-performance-graphs ]; then
    echo -e "\e[94m  Removing previously installed performance graphs cron file...\e[97m"
    sudo rm -f /etc/cron.d/adsb-receiver-performance-graphs
fi

echo -e "\e[94m  Adding performance graphs cron file...\e[97m"
sudo tee -a /etc/cron.d/adsb-receiver-performance-graphs > /dev/null <<EOF
# Updates the portal's performance graphs.
#
# Every 5 minutes new hourly graphs are generated.
# Every 10 minutes new six hour graphs are generated.
# At 2, 12, 22, 32, 42, and 52 minutes past the hour new 24 hour graphs are generated.
# At 4, 24, and 44 minuites past the hour new 7 day graphs are generated.
# At 6 minutes past the hour new 30 day graphs are generated.
# At 8 minutes past every 12th hour new 365 day graphs are generated.

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

*/5 * * * * root bash $PORTALBUILDDIRECTORY/graphs/make-collectd-graphs.sh 1h >/dev/null 2>&1
*/10 * * * * root bash $PORTALBUILDDIRECTORY/graphs/make-collectd-graphs.sh 6h >/dev/null 2>&1
2,12,22,32,42,52 * * * * root bash $PORTALBUILDDIRECTORY/graphs/make-collectd-graphs.sh 24h >/dev/null 2>&1
4,24,44 * * * * root bash $PORTALBUILDDIRECTORY/graphs/make-collectd-graphs.sh 7d >/dev/null 2>&1
6 * * *	* root bash $PORTALBUILDDIRECTORY/graphs/make-collectd-graphs.sh 30d >/dev/null 2>&1
8 */12 * * * root bash $PORTALBUILDDIRECTORY/graphs/make-collectd-graphs.sh 365d >/dev/null 2>&1
EOF

exit 0

#!/bin/bash

#####################################################################################
#                                   ADS-B FEEDER                                    #
#####################################################################################
#                                                                                   #
# This script is not meant to be executed directly.                                 #
# Instead execute install.sh to begin the installation process.                     #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                   #
# Copyright (c) 2015 Joseph A. Prochazka                                            #
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

BUILDDIR="${PWD}/build"

# Assign the Lighthttpd document root directory to a variable.
RAWDOCUMENTROOT=`/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root`
DOCUMENTROOT=`sed 's/.*"\(.*\)"[^"]*$/\1/' <<< $RAWDOCUMENTROOT`

## BACKUP AND REPLACE COLLECTD.CONF

echo -e "\033[33m"
echo "Backing up and replacing the current collectd.conf file..."
echo -e "\033[37m"
sudo mv /etc/collectd/collectd.conf /etc/collectd/collectd.conf.back
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
TypesDB "${BUILDDIR}/portal/graphs/dump1090.db" "/usr/share/collectd/types.db"

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
	ModulePath "${BUILDDIR}/portal/graphs"
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
        #Interface "wlan0"
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

echo -e "\033[33mReloading collectd so the new configuration is used..."
echo -e "\033[37m"
sudo /etc/init.d/collectd force-reload

## PLACE HTML FILES IN LIGHTTPD'S WWW ROOT

echo -e "\033[33m"
echo "Placing performance graph HTML file in Lighttpd's www root directory..."
echo -e "\033[37m"
sudo mkdir ${DOCUMENTROOT}/graphs
sudo cp -r $BUILDDIR/portal/graphs/html/* ${DOCUMENTROOT}/graphs/

## EDIT CRONTAB

echo -e "\033[33mAdding jobs to crontab..."
if [ -f /etc/cron.d/adsb-feeder-performance-graphs ]; then
    echo -e "Removing previously installed cron file..."
    sudo rm -f /etc/cron.d/adsb-feeder-performance-graphs
fi
echo -e "\033[37m"
chmod 755 $BUILDDIR/portal/graphs/make-collectd-graphs.sh
sudo tee -a /etc/cron.d/adsb-feeder-performance-graphs > /dev/null <<EOF
# Updates the portal's performance graphs.
#
# Every 5 minutes new hourly graphs are generated.
# Every 10 minutes new six hour graphs are generated.
# At 2, 12, 22, 32, 42, and 52 minutes past the hour new 24 hour graphs are generated.
# At 4, 24, and 44 minuites past the hour new 7 day graphs are generated.
# At 6 minutes past the hour new 30 day graphs are generated.
# At 8 minutes past every 12th hour new 365 day graphs are generated.

*/5 * * * * root bash ${BUILDDIR}/portal/graphs/make-collectd-graphs.sh 1h >/dev/null
*/10 * * * * root bash ${BUILDDIR}/portal/graphs/make-collectd-graphs.sh 6h >/dev/null
2,12,22,32,42,52 * * * * root bash ${BUILDDIR}/portal/graphs/make-collectd-graphs.sh 24h 180 >/dev/null
4,24,44 * * * * root bash ${BUILDDIR}/portal/graphs/make-collectd-graphs.sh 7d 1200 >/dev/null
6 * * *	* root bash ${BUILDDIR}/portal/graphs/make-collectd-graphs.sh 30d 5400 >/dev/null
8 */12 * * * root bash ${BUILDDIR}/portal/graphs/make-collectd-graphs.sh 365d 86400 >/dev/null
EOF

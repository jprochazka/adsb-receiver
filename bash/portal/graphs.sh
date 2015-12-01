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

BUILDDIR=${PWD}

## FUNCTIONS

# Function used to check if a package is install and if not install it.
function CheckPackage(){
    printf "\e[33mChecking if the package $1 is installed..."
    if [ $(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo -e "\033[31m [NOT INSTALLED]\033[37m"
        echo -e "\033[33mInstalling the package $1 and it's dependancies..."
        echo -e "\033[37m"
        sudo apt-get install -y $1;
        echo ""
        echo -e "\033[33mThe package $1 has been installed."
    else
        echo -e "\033[32m [OK]\033[37m"
    fi
}

clear

echo -e "\033[31m"
echo "-------------------------------------------"
echo " Now ready to install dump1090-portal."
echo "-------------------------------------------"
echo -e "\033[33mThe goal of the dump1090-portal portal project is to create a very"
echo "light weight easy to manage web interface for dump-1090 installations"
echo "This project is at the moment very young with only a few of the planned"
echo "featured currently available at this time."
echo ""
echo "https://github.com/jprochazka/dump1090-portal"
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

clear

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\033[33m"
echo "Installing packages needed to build and fulfill dependencies..."
echo -e "\033[37m"
CheckPackage collectd
CheckPackage rrdtool

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
TypesDB "${BUILDDIR}/portal/graphs/dump1090.db" "/usr/share/graphs/types.db"

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

echo -e "\033[33mReloading collectd so the new configuration is used..."
echo -e "\033[37m"
sudo /etc/init.d/collectd force-reload

## PLACE HTML FILES IN LIGHTTPD'S WWW ROOT

echo -e "\033[33m"
echo "Placing HTML file in Lighttpd's www root directory..."
echo -e "\033[37m"
sudo mkdir /var/www/html/graphs
sudo cp -r $BUILDDIR/portal/graphs/html/* /var/www/html/graphs/

## EDIT CRONTAB

echo -e "\033[33mAdding jobs to crontab..."
echo -e "\033[37m"
chmod 755 $BUILDDIR/portal/graphs/make-collectd-graphs.sh
sudo tee -a /etc/cron.d/feeder-performance-graphs > /dev/null <<EOF
*/5 * * * * root bash ${BUILDDIR}/portal/graphs/make-collectd-graphs.sh 1h >/dev/null
*/10 * * * * root bash ${BUILDDIR}/portal/graphs/make-collectd-graphs.sh 6h >/dev/null
2,12,22,32,42,52 * * * * root bash ${BUILDDIR}/portal/graphs/make-collectd-graphs.sh 24h 180 >/dev/null
4,24,44 * * * * root bash ${BUILDDIR}/portal/graphs/make-collectd-graphs.sh 7d 1200 >/dev/null
6 * * *	* root bash ${BUILDDIR}/portal/graphs/make-collectd-graphs.sh 30d 5400 >/dev/null
8 */12 * * * root bash ${BUILDDIR}/portal/graphs/make-collectd-graphs.sh 365d 86400 >/dev/null
EOF

echo -e "\033[33m"
echo "Installation and configuration of the performance graphs is now complete."
echo "Please look over the output generated to be sure no errors were encountered."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

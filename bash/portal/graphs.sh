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
# Copyright (c) 2015-2018 Joseph A. Prochazka                                       #
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

### VARIABLES

RECEIVER_ROOT_DIRECTORY="${PWD}"
RECEIVER_BUILD_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/build"
PORTAL_BUILD_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/portal"

COLLECTD_CONFIG="/etc/collectd/collectd.conf"
COLLECTD_CRON_FILE="/etc/cron.d/adsb-receiver-performance-graphs"
DUMP1090_MAX_RANGE_RRD="/var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_range-max_range.rrd"
DUMP1090_MESSAGES_LOCAL_RRD="/var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_messages-local_accepted.rrd"

### INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] && [[ -s "${RECEIVER_CONFIGURATION_FILE}" ]] ; then
    source ${RECEIVER_CONFIGURATION_FILE}
fi

### BEGIN SETUP

echo -e ""
echo -e "\e[95m  Setting up collectd performance graphs...\e[97m"
echo -e ""

## CONFIRM INSTALLED PACKAGES

if [[ -z "${DUMP1090_INSTALLED}" ]] || [[ -z "${DUMP1090_FORK}" ]] ; then
    echo -e "\e[94m  Checking which dump1090 fork is installed...\e[97m"
    if [[ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
        DUMP1090_FORK="mutability"
        DUMP1090_INSTALLED="true"
    fi
    if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
        DUMP1090_FORK="fa"
        DUMP1090_INSTALLED="true"
    fi
fi
if [[ -f "/etc/init.d/rtlsdr-ogn" ]] ; then
    RTLSDROGN_INSTALLED="true"
fi

## CONFIRM HARDWARE PLATFORM

if [[ -z "${HARDWARE_PLATFORM}" ]] ; then
    Check_Platform
    echo -e ""
fi

## MODIFY THE DUMP1090-MUTABILITY INIT SCRIPT TO MEASURE AND RETAIN NOISE DATA

if [[ "${DUMP1090_INSTALLED}" = "true" ]] && [[ "${DUMP1090_FORK}" = "mutability" ]] ; then
    echo -e "\e[94m  Modifying the dump1090-mutability configuration file to add noise measurements...\e[97m"
    EXTRA_ARGS=`GetConfig "EXTRA_ARGS" "/etc/default/dump1090-mutability"`
    EXTRA_ARGS=$(sed -e 's/^[[:space:]]*//' <<<"EXTRA_ARGS --measure-noise")
    ChangeConfig "EXTRA_ARGS" "${RECEIVER_LONGITUDE}" "/etc/default/dump1090-mutability"

    echo -e "\e[94m  Reloading the systemd manager configuration...\e[97m"
    sudo systemctl daemon-reload

    echo -e "\e[94m  Reloading dump1090-mutability...\e[97m"
    sudo service dump1090-mutability force-reload
fi

## BACKUP AND REPLACE COLLECTD.CONF

# Check if the collectd config file exists and if so back it up.
if [[ -f "${COLLECTD_CONFIG}" ]] ; then
    echo -e "\e[94m  Backing up the current collectd.conf file...\e[97m"
    sudo cp ${COLLECTD_CONFIG} ${COLLECTD_CONFIG}.bak
fi

# Generate new collectd config.
echo -e "\e[94m  Replacing the current collectd.conf file...\e[97m"
sudo tee ${COLLECTD_CONFIG} > /dev/null <<EOF
# Config file for collectd(1).

##############################################################################
# Global                                                                     #
##############################################################################
Hostname "localhost"

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

EOF

# Dump1090 specific values.
if [[ "${DUMP1090_INSTALLED}" = "true" ]] ; then
    sudo tee -a ${COLLECTD_CONFIG} > /dev/null <<EOF
#----------------------------------------------------------------------------#
# Added types for dump1090.                                                  #
# Make sure the path to dump1090.db is correct.                              #
#----------------------------------------------------------------------------#
TypesDB "${PORTAL_BUILD_DIRECTORY}/graphs/dump1090.db" "/usr/share/collectd/types.db"

EOF
fi

# Config for all installations.
sudo tee -a ${COLLECTD_CONFIG} > /dev/null <<EOF
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
LoadPlugin curl
<LoadPlugin python>
	Globals true
</LoadPlugin>

##############################################################################
# Plugin configuration                                                       #
##############################################################################
<Plugin rrdtool>
	DataDir "/var/lib/collectd/rrd"
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

<Plugin "interface">
        Interface "eth0"
        Interface "wlan0"
</Plugin>

EOF

# Raspberry Pi specific values.
if [[ "${HARDWARE_PLATFORM}" = "RPI" ]] ; then
    sudo tee -a ${COLLECTD_CONFIG} > /dev/null <<EOF
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

<Plugin "disk">
	Disk "mmcblk0"
	IgnoreSelected false
</Plugin>

EOF
# CHIP specific values.
elif [[ "${HARDWARE_PLATFORM}" = "CHIP" ]] ; then
    sudo tee -a ${COLLECTD_CONFIG} > /dev/null <<EOF
<Plugin table>
        <Table "/sys/class/hwmon/hwmon0/temp1_input">
                Instance localhost
                Separator " "
                <Result>
                        Type gauge
                        InstancePrefix "cpu_temp"
                        ValuesFrom 0
                </Result>
        </Table>
</Plugin>

<Plugin "disk">
        Disk "ubi0:rootfs"
        IgnoreSelected false
</Plugin>

EOF
fi

# Dump1090 specific values.
if [[ "${DUMP1090_INSTALLED}" = "true" ]] ; then
    sudo tee -a ${COLLECTD_CONFIG} > /dev/null <<EOF
#----------------------------------------------------------------------------#
# Configure the dump1090 python module.                                      #
#                                                                            #
# Each Instance block collects statistics from a separate named dump1090.    #
# The URL should be the base URL of the webmap, i.e. in the examples below,  #
# statistics will be loaded from http://localhost/dump1090/data/stats.json   #
#----------------------------------------------------------------------------#
<Plugin python>
        ModulePath "${PORTAL_BUILD_DIRECTORY}/graphs"
        LogTraces true
        Import "dump1090"
        <Module dump1090>
                <Instance localhost>
                        URL "http://localhost/dump1090"
                </Instance>
        </Module>
</Plugin>

EOF
fi

# RTLSDR-OGN specific values.
if [[ "${RTLSDROGN_INSTALLED}" = "true" ]] ; then
    sudo tee -a ${COLLECTD_CONFIG} > /dev/null <<EOF
#----------------------------------------------------------------------------#
# RTLSDR-OGN Graphs                                                          #
#----------------------------------------------------------------------------#
<Plugin curl>
  <Page "rtlsdr-ogn">
    URL "http://localhost:8080/"
    # OGN center Frequency
    <Match>
      Regex "<tr><td>RF.OGN.CenterFreq</td><td align=right><b>([0-9]*\\.[0-9]+) MHz</b></td></tr>"
      DSType "GaugeLast"
      Type "frequency"
      Instance "Center-Frequency-OGN"
    </Match>
    # GSM  center Frequency
    <Match>
      Regex "<tr><td>RF.GSM.CenterFreq</td><td align=right><b>([0-9]*\\.[0-9]+) MHz</b></td></tr>"
      DSType "GaugeLast"
      Type "frequency"
      Instance "Center-Frequency-GSM"
    </Match>
    # OGN Frequency Correction
    <Match>
      Regex "<tr><td>Frequency correction</td><td align=right><b>([\+\-][0-9]*\\.[0-9]+) ppm</b></td></tr>"
      DSType "GaugeLast"
      Type "frequency_offset"
      Instance "Frequency-Correction-OGN"
    </Match>
    # NTP Frequency Correction
    <Match>
      Regex "<tr><td>NTP freq. corr.</td><td align=right><b>([\+\-][0-9]*\\.[0-9]+) ppm</b></td></tr>"
      DSType "GaugeLast"
      Type "frequency_offset"
      Instance "Frequency-Correction-NTP"
    </Match>
    # OGN Gain
    <Match>
      Regex "<tr><td>RF.OGN.Gain</td><td align=right><b>([0-9]*\\.[0-9]+) dB</b></td></tr>"
      DSType "GaugeLast"
      Type "gauge"
      Instance "Gain-OGN"
    </Match>
    # GSM Gain
    <Match>
      Regex "<tr><td>RF.GSM.Gain</td><td align=right><b>([0-9]*\\.[0-9]+) dB</b></td></tr>"
      DSType "GaugeLast"
      Type "gauge"
      Instance "Gain-GSM"
    </Match>
  </Page>
</Plugin>
EOF
fi

# Remaining config for all installations.
sudo tee -a ${COLLECTD_CONFIG} > /dev/null <<EOF
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
sudo service collectd force-reload

## EDIT CRONTAB

if [[ ! -x "${PORTAL_BUILD_DIRECTORY}/graphs/make-collectd-graphs.sh" ]] ; then
    echo -e "\e[94m  Making the make-collectd-graphs.sh script executable...\e[97m"
    chmod +x ${PORTAL_BUILD_DIRECTORY}/graphs/make-collectd-graphs.sh
fi

# The next block is temporary in order to insure this file is
# deleted on older installation before the project renaming.
if [[ -f "/etc/cron.d/adsb-feeder-performance-graphs" ]] ; then
    echo -e "\e[94m  Removing outdated performance graphs cron file...\e[97m"
    sudo rm -f /etc/cron.d/adsb-feeder-performance-graphs
fi

if [[ -f "${COLLECTD_CRON_FILE}" ]] ; then
    echo -e "\e[94m  Removing previously installed performance graphs cron file...\e[97m"
    sudo rm -f ${COLLECTD_CRON_FILE}
fi

echo -e "\e[94m  Adding performance graphs cron file...\e[97m"
sudo tee ${COLLECTD_CRON_FILE} > /dev/null <<EOF
# Updates the portal's performance graphs.
#
# Every 5 minutes new hourly graphs are generated.
# Every 10 minutes new six hour graphs are generated.
# At 2, 12, 22, 32, 42, and 52 minutes past the hour new 24 hour graphs are generated.
# At 4, 24, and 44 minuites past the hour new 7 day graphs are generated.
# At 6 minutes past the hour new 30 day graphs are generated.
# At 8 minutes past every 12th hour new 365 day graphs are generated.

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

*/5 * * * * root bash ${PORTAL_BUILD_DIRECTORY}/graphs/make-collectd-graphs.sh 1h >/dev/null 2>&1
*/10 * * * * root bash ${PORTAL_BUILD_DIRECTORY}/graphs/make-collectd-graphs.sh 6h >/dev/null 2>&1
2,12,22,32,42,52 * * * * root bash ${PORTAL_BUILD_DIRECTORY}/graphs/make-collectd-graphs.sh 24h >/dev/null 2>&1
4,24,44 * * * * root bash ${PORTAL_BUILD_DIRECTORY}/graphs/make-collectd-graphs.sh 7d >/dev/null 2>&1
6 * * *	* root bash ${PORTAL_BUILD_DIRECTORY}/graphs/make-collectd-graphs.sh 30d >/dev/null 2>&1
8 */12 * * * root bash ${PORTAL_BUILD_DIRECTORY}/graphs/make-collectd-graphs.sh 365d >/dev/null 2>&1
EOF

# Update max_range.rrd to remove the 500 km / ~270 nmi limit.
if [ -f "/var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_range-max_range.rrd" ]; then
    if [[ `rrdinfo ${DUMP1090_MAX_RANGE_RRD} | grep -c "ds\[value\].max = 1.0000000000e+06"` -eq 0 ]] ; then
        echo -e "\e[94m  Removing 500km/270mi limit from max_range.rrd...\e[97m"
        sudo rrdtool tune ${DUMP1090_MAX_RANGE_RRD} --maximum "value:1000000"
    fi
fi

# Increase size of weekly messages table to 8 days
if [ -f ${DUMP1090_MESSAGES_LOCAL_RRD} ]; then
    if [[ `rrdinfo ${DUMP1090_MESSAGES_LOCAL_RRD} | grep -c "rra\[6\]\.rows = 1260"` -eq 1 ]] ; then
        echo -e "\e[94m  Increasing weekly table size to 8 days in messages-local_accepted.rrd...\e[97m"
        sudo rrdtool tune ${DUMP1090_MESSAGES_LOCAL_RRD} 'RRA#6:=1440' 'RRA#7:=1440' 'RRA#8:=1440'
    fi
fi

### SETUP COMPLETE

# Return to the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY}

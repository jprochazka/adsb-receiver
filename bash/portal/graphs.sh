#!/bin/bash

### VARIABLES

collectd_config="/etc/collectd/collectd.conf"
collectd_cron_file="/etc/cron.d/adsb-receiver-performance-graphs"
dump1090_max_range_rrd_database="/var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_range-max_range.rrd"
dump1090_messages_local_rrd_database="/var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_messages-local_accepted.rrd"


### INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh


### BEGIN SETUP

echo -e ""
echo -e "\e[95m  Setting up collectd performance graphs...\e[97m"
echo -e ""


CheckPackage collectd-core
CheckPackage rrdtool

## CONFIRM INSTALLED PACKAGES

echo -e "\e[94m  Checking which dump1090 fork is installed...\e[97m"
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
    dump1090_fork="fa"
    dump1090_is_installed="true"
fi


## BACKUP AND REPLACE COLLECTD.CONF

# Check if the collectd config file exists and if so back it up.
if [[ -f "${collectd_config}" ]] ; then
    echo -e "\e[94m  Backing up the current collectd.conf file...\e[97m"
    sudo cp ${collectd_config} ${collectd_config}.bak
fi

# Generate new collectd config.
echo -e "\e[94m  Replacing the current collectd.conf file...\e[97m"
sudo tee ${collectd_config} > /dev/null <<EOF
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
if [[ "${dump1090_is_installed}" = "true" ]] ; then
    sudo tee -a ${collectd_config} > /dev/null <<EOF
#----------------------------------------------------------------------------#
# Added types for dump1090.                                                  #
# Make sure the path to dump1090.db is correct.                              #
#----------------------------------------------------------------------------#
TypesDB "${RECEIVER_BUILD_DIRECTORY}/portal/graphs/dump1090.db" "/usr/share/collectd/types.db"

EOF
fi

# Config for all installations.
sudo tee -a ${collectd_config} > /dev/null <<EOF
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
LoadPlugin cpufreq
LoadPlugin thermal
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
        ReportInodes true
</Plugin>

<Plugin "interface">
        Interface "eth0"
        Interface "wlan0"
</Plugin>

EOF

# Device  specific values.
# Raspberry Pi: b03112

if [[ "${RECEIVER_CPU_REVISION}" = "b03112" ]] ; then
    sudo tee -a ${collectd_config} > /dev/null <<EOF
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
fi

# Dump1090 specific values.
if [[ "${dump1090_is_installed}" = "true" ]] ; then
    sudo tee -a ${collectd_config} > /dev/null <<EOF
#----------------------------------------------------------------------------#
# Configure the dump1090-tools python module.                                #
#                                                                            #
# Each Instance block collects statistics from a separate named dump1090.    #
# The URL should be the base URL of the webmap, i.e. in the examples below,  #
# statistics will be loaded from http://localhost/dump1090/data/stats.json   #
#----------------------------------------------------------------------------#
<Plugin python>
        ModulePath "${RECEIVER_BUILD_DIRECTORY}/portal/graphs"
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

# Remaining config for all installations.
sudo tee -a ${collectd_config} > /dev/null <<EOF
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

echo -e "\e[94m  Making the make-collectd-graphs.sh script executable...\e[97m"
chmod +x ${RECEIVER_BUILD_DIRECTORY}/portal/graphs/make-collectd-graphs.sh

if [[ -f "${collectd_cron_file}" ]] ; then
    echo -e "\e[94m  Removing previously installed performance graphs cron file...\e[97m"
    sudo rm -f ${collectd_cron_file}
fi

echo -e "\e[94m  Adding performance graphs cron file...\e[97m"
sudo tee ${collectd_cron_file} > /dev/null <<EOF
# Updates the portal's performance graphs.
#
# Every 5 minutes new hourly graphs are generated.
# Every 10 minutes new six hour graphs are generated.
# At 2, 12, 22, 32, 42, and 52 minutes past the hour new 24 hour graphs are generated.
# At 4, 24, and 44 minuites past the hour new 7 day graphs are generated.
# At 6 minutes past the hour new 30 day graphs are generated.
# At 8 minutes past every 12th hour new 365 day graphs are generated.

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

*/5 * * * * root bash ${RECEIVER_BUILD_DIRECTORY}/portal/graphs/make-collectd-graphs.sh 1h >/dev/null 2>&1
*/10 * * * * root bash ${RECEIVER_BUILD_DIRECTORY}/portal/graphs/make-collectd-graphs.sh 6h >/dev/null 2>&1
2,12,22,32,42,52 * * * * root bash ${RECEIVER_BUILD_DIRECTORY}/portal/graphs/make-collectd-graphs.sh 24h >/dev/null 2>&1
4,24,44 * * * * root bash ${RECEIVER_BUILD_DIRECTORY}/portal/graphs/make-collectd-graphs.sh 7d >/dev/null 2>&1
6 * * *	* root bash ${RECEIVER_BUILD_DIRECTORY}/portal/graphs/make-collectd-graphs.sh 30d >/dev/null 2>&1
8 */12 * * * root bash ${RECEIVER_BUILD_DIRECTORY}/portal/graphs/make-collectd-graphs.sh 365d >/dev/null 2>&1
EOF

# Update max_range.rrd to remove the 500 km / ~270 nmi limit.
if [ -f "/var/lib/collectd/rrd/localhost/dump1090-localhost/dump1090_range-max_range.rrd" ]; then
    if [[ `rrdinfo ${dump1090_max_range_rrd_database} | grep -c "ds\[value\].max = 1.0000000000e+06"` -eq 0 ]] ; then
        echo -e "\e[94m  Removing 500km/270mi limit from max_range.rrd...\e[97m"
        sudo rrdtool tune ${dump1090_max_range_rrd_database} --maximum "value:1000000"
    fi
fi

# Increase size of weekly messages table to 8 days
if [ -f ${dump1090_messages_local_rrd_database} ]; then
    if [[ `rrdinfo ${dump1090_messages_local_rrd_database} | grep -c "rra\[6\]\.rows = 1260"` -eq 1 ]] ; then
        echo -e "\e[94m  Increasing weekly table size to 8 days in messages-local_accepted.rrd...\e[97m"
        sudo rrdtool tune ${dump1090_messages_local_rrd_database} 'RRA#6:=1440' 'RRA#7:=1440' 'RRA#8:=1440'
    fi
fi


### SETUP COMPLETE

# Return to the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY}
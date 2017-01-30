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

RECEIVER_ROOT_DIRECTORY="${PWD}"
RECEIVER_BASH_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/bash"
RECEIVER_BUILD_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/build"
BINARIES_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/binaries"

# Feeder specific variables.

MLAT_CLIENT_GITBHUB_URL="https://github.com/mutability/mlat-client.git"
MLAT_CLIENT_BUILD_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/mlat-client"

FEEDER_NAME="adsbexchange"
COMPONENT_BUILD_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/${FEEDER_NAME}"

FEEDER_BEAST_DST_HOST="feed.adsbexchange.com"
FEEDER_BEAST_DST_PORT="30005"
FEEDER_BEAST_SRC_HOST="127.0.0.1"
FEEDER_BEAST_SRC_PORT="30005"

FEEDER_MLAT_DST_HOST="feed.adsbexchange.com"
FEEDER_MLAT_DST_PORT="31090"
FEEDER_MLAT_SRC_HOST="127.0.0.1"
FEEDER_MLAT_SRC_PORT="30005"

FEEDER_MLAT_RETURN_PORT="30104"

## INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

# Source the automated install configuration file if this is an automated installation.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
    source ${RECEIVER_CONFIGURATION_FILE}
fi

## BEGIN SETUP

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    clear
    echo -e "\n\e[91m  ${ADSB_PROJECTTITLE}"
fi
echo -e ""
echo -e "\e[92m  Setting up the ADS-B Exchange feed..."
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    whiptail --backtitle "${ADSB_PROJECTTITLE}" --title "ADS-B Exchange Feed Setup" --yesno "ADS-B Exchange is a co-op of ADS-B/Mode S/MLAT feeders from around the world, and the world’s largest source of unfiltered flight data.\n\n  http://www.adsbexchange.com/how-to-feed/\n\nContinue setting up the ADS-B Exchange feed?" 12 78
    if [[ $? -eq 1 ]] ; then
        # Setup has been halted by the user.
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo -e ""
        echo -e "\e[93m  ------------------------------------------------------------------------------"
        echo -e "\e[92m  ADS-B Exchange feed setup halted.\e[39m"
        echo -e ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
    fi
fi

## CHECK FOR AND REMOVE ANY OLD STYLE ADB-B EXCHANGE SETUPS IF ANY EXIST

echo -e "\e[95m  Checking for and removing any old style ADS-B Exchange setups if any exist...\e[97m"
echo -e ""
# Check if the old style ${FEEDER_NAME}-maint.sh line exists in /etc/rc.local.
echo -e "\e[94m  Checking for any preexisting older style setups...\e[97m"
if [[ `grep -cFx "${COMPONENT_BUILD_DIRECTORY}/${FEEDER_NAME}-maint.sh &" /etc/rc.local` -gt 0 ]] ; then
    # Kill any currently running instances of the ${FEEDER_NAME}-maint.sh script.
    echo -e "\e[94m  Checking for any running ${FEEDER_NAME}-maint.sh processes...\e[97m"
    PIDS=`ps -efww | grep -w "${COMPONENT_BUILD_DIRECTORY}/${FEEDER_NAME}-maint.sh &" | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [[ -n "${PIDS}" ]] ; then
        echo -e "\e[94m  -Killing any running ${FEEDER_NAME}-maint.sh processes...\e[97m"
        echo -e ""
        sudo kill ${PIDS} 2>&1
        sudo kill -9 ${PIDS} 2>&1
        echo -e ""
    fi
    # Remove the old line from /etc/rc.local.
    echo -e "\e[94m  Removing the old ${FEEDER_NAME}-maint.sh startup line from /etc/rc.local...\e[97m"
    sudo sed -i /$${COMPONENT_BUILD_DIRECTORY}\/${FEEDER_NAME}-maint.sh &/d /etc/rc.local 2>&1
fi
echo -e ""

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo -e ""
CheckPackage curl
CheckPackage build-essential
CheckPackage debhelper
CheckPackage python-dev
CheckPackage python3-dev
CheckPackage netcat

## CONFIRM DERIVED VALUES

# Ask for the receivers latitude and longitude.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # Explain to the user that the receiver's latitude and longitude is required.
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Receiver Latitude and Longitude" --msgbox "Your receivers latitude and longitude are required for distance calculations to work properly. You will now be asked to supply the latitude and longitude for your receiver. If you do not have this information you get it by using the web based \"Geocode by Address\" utility hosted on another of my websites.\n\n  https://www.swiftbyte.com/toolbox/geocode" 13 78

    # Ask the user for the mlat user name for this receiver.
    FEEDER_USERNAME_TITLE="Receiver MLAT Username"
    while [[ -z "${FEEDER_USERNAME}" ]] ; do
        FEEDER_USERNAME=$(whiptail --backtitle "${ADSB_PROJECTTITLE}" --backtitle "${BACKTITLETEXT}" --title "${FEEDER_USERNAME_TITLE}" --nocancel --inputbox "\nPlease enter a name for this receiver.\n\nIf you have more than one receiver, this name should be unique.\nExample: \"username-01\", \"username-02\", etc." 12 78 -- "${ADSBEXCHANGE_RECEIVER_USERNAME}" 3>&1 1>&2 2>&3)
        FEEDER_USERNAME_TITLE="Receiver Name (REQUIRED)"
    done

    # Ask the user to confirm the receivers latitude, this will be prepopulated by the latitude assigned dump1090-mutability.
    RECEIVER_LATITUDE_TITLE="Receiver Latitude"
    while [[ -z "${RECEIVER_LATITUDE}" ]] ; do
        if [[ -s /etc/default/dump1090-mutability ]] && [[ `grep -c "^LAT" "/etc/default/dump1090-mutability"` -gt 0 ]] ; then
            RECEIVER_LATITUDE=$(grep "^LAT" "/etc/default/dump1090-mutability" | awk '{print $3}')
            RECEIVER_LATITUDE_SOURCE=", the value below is configured in Dump1090"
        fi
        RECEIVER_LATITUDE=$(whiptail --backtitle "${ADSB_PROJECTTITLE}" --backtitle "${BACKTITLETEXT}" --title "${RECEIVER_LATITUDE_TITLE}" --nocancel --inputbox "\nPlease confirm your receiver's latitude${RECEIVER_LATITUDE_SOURCE}:\n" 10 78 -- "${RECEIVER_LATITUDE}" 3>&1 1>&2 2>&3)
        RECEIVER_LATITUDE_TITLE="Receiver Latitude (REQUIRED)"
    done

    # Ask the user to confirm the receivers longitude, this will be prepopulated by the longitude assigned dump1090-mutability.
    RECEIVER_LONGITUDE_TITLE="Receiver Longitude"
    while [[ -z "${RECEIVER_LONGITUDE}" ]] ; do
        if [[ -s /etc/default/dump1090-mutability ]] && [[ `grep -c "^LON" "/etc/default/dump1090-mutability"` -gt 0 ]] ; then
            RECEIVER_LONGITUDE=$(grep "^LON" "/etc/default/dump1090-mutability" | awk '{print $3}')
            RECEIVER_LONGITUDE_SOURCE=", the value below is configured in Dump1090"
        fi
        RECEIVER_LONGITUDE=$(whiptail --backtitle "${ADSB_PROJECTTITLE}" --backtitle "${BACKTITLETEXT}" --title "${RECEIVER_LONGITUDE_TITLE}" --nocancel --inputbox "\nEnter your receiver's longitude${RECEIVER_LONGITUDE_SOURCE}:\n" 10 78 -- "${RECEIVER_LONGITUDE}" 3>&1 1>&2 2>&3)
        RECEIVER_LONGITUDE_TITLE="Receiver Longitude (REQUIRED)"
    done

    # Ask the user to confirm the receivers altitude, this will be prepopulated by the altitude returned from the Google Maps API.
    RECEIVER_ALTITUDE_TITLE="Receiver Altitude"
    while [[ -z "${RECEIVER_ALTITUDE}" ]] ; do
        if [[ -n "${RECEIVER_LATITUDE}" ]] && [[ -n "${RECEIVER_LONGITUDE}" ]] ; then
            RECEIVER_ALTITUDE=$(curl -s https://maps.googleapis.com/maps/api/elevation/json?locations=${RECEIVER_LATITUDE},${RECEIVER_LONGITUDE} | python -c "import json,sys;obj=json.load(sys.stdin);print obj['results'][0]['elevation'];" | awk '{printf("%.2f\n", $1)}')
            RECEIVER_ALTITUDE_SOURCE=", the below value is obtained from google but should be increased to reflect your antennas height above ground level"
        fi
        RECEIVER_ALTITUDE=$(whiptail --backtitle "${ADSB_PROJECTTITLE}" --backtitle "${BACKTITLETEXT}" --title "${RECEIVER_ALTITUDE_TITLE}" --nocancel --inputbox "\nEnter your receiver's altitude${RECEIVER_ALTITUDE_SOURCE}:\n" 11 78 -- "${RECEIVER_ALTITUDE}" 3>&1 1>&2 2>&3)
        RECEIVER_ALTITUDE_TITLE="Receiver Altitude (REQUIRED)"
    done
else
    echo -e "\e[92m  Automated installation of this script is not yet supported...\e[39m"
    echo -e ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

# Confirm that all required information has been obtained for BEAST feed.
if [[ -n "${FEEDER_BEAST_DST_HOST}" ]] && [[ -n "${FEEDER_BEAST_DST_HOST}" ]] && [[ -n "${FEEDER_BEAST_DST_HOST}" ]] && [[ -n "${FEEDER_BEAST_DST_HOST}" ]] ; then
    FEEDER_BEAST_ENABLED="true"
else
    FEEDER_BEAST_ENABLED="false"
fi

# Confirm that all required information has been obtained for MLAT feed.
if [[ -n "${FEEDER_MLAT_DST_HOST}" ]] && [[ -n "${FEEDER_MLAT_DST_HOST}" ]] && [[ -n "${FEEDER_MLAT_DST_HOST}" ]] && [[ -n "${FEEDER_MLAT_DST_HOST}" ]] ; then
    FEEDER_MLAT_ENABLED="true"
else
    FEEDER_MLAT_ENABLED="false"
fi

# Establish if MLAT results should be fed back into local dump1090 instance.
if  [[ -n "${FEEDER_MLAT_RETURN_PORT}" ]] ; then
    FEEDER_MLAT_RETURN_RESULTS="--results beast,connect,${FEEDER_MLAT_SRC_HOST}:${FEEDER_MLAT_RETURN_PORT}"
else
    FEEDER_MLAT_RETURN_RESULTS=""
fi

## DOWNLOAD OR UPDATE THE MLAT-CLIENT SOURCE

if [[ ${FEEDER_MLAT_ENABLED} = "true" ]] ; then
    echo -e ""
    echo -e "\e[95m  Preparing the mlat-client Git repository...\e[97m"
    echo -e ""
    if [[ -d "${MLAT_CLIENT_BUILD_DIRECTORY}" ]] && [[ -d "${MLAT_CLIENT_BUILD_DIRECTORY}/.git" ]] ; then
        # A directory with a git repository containing the source code already exists.
        echo -e "\e[94m  Entering the mlat-client git repository directory...\e[97m"
        cd ${MLAT_CLIENT_BUILD_DIRECTORY} 2>&1
        echo -e "\e[94m  Updating the local mlat-client git repository...\e[97m"
        echo -e ""
        git pull 2>&1
    else
        # A directory containing the source code does not exist in the build directory.
        echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
        cd ${RECEIVER_BUILD_DIRECTORY} 2>&1
        echo -e "\e[94m  Cloning the mlat-client git repository locally...\e[97m"
        echo -e ""
        git clone ${MLAT_CLIENT_GITBHUB_URL} 2>&1
    fi

    ## BUILD AND INSTALL THE MLAT-CLIENT PACKAGE

    echo -e ""
    echo -e "\e[95m  Building and installing the mlat-client package...\e[97m"
    echo -e ""
    if [[ ! "${PWD}" = "${MLAT_CLIENT_BUILD_DIRECTORY}" ]] ; then
        echo -e "\e[94m  Entering the mlat-client git repository directory...\e[97m"
        echo -e ""
        cd ${MLAT_CLIENT_BUILD_DIRECTORY} 2>&1
    fi
    # Build binary package.
    echo -e "\e[94m  Building the mlat-client package...\e[97m"
    echo -e ""
    dpkg-buildpackage -b -uc 2>&1
    echo -e ""
    # Install binary package.
    echo -e "\e[94m  Installing the mlat-client package...\e[97m"
    echo -e ""
    sudo dpkg -i ${RECEIVER_BUILD_DIRECTORY}/mlat-client_${MLATCLIENTVERSION}*.deb 2>&1
    echo -e ""
    # Create binary archive directory.
    if [[ ! -d "${BINARIES_DIRECTORY}" ]] ; then
        echo -e "\e[94m  Creating archive directory...\e[97m"
        echo -e ""
        mkdir -vp ${BINARIES_DIRECTORY} 2>&1
        echo -e ""
    fi
    # Archive binary package.
    echo -e "\e[94m  Archiving the mlat-client package...\e[97m"
    echo -e ""
    mv -v -f ${RECEIVER_BUILD_DIRECTORY}/mlat-client_* ${BINARIES_DIRECTORY} 2>&1
    echo -e ""

    # Check that the mlat-client package was installed successfully.
    echo -e ""
    echo -e "\e[94m  Checking that the mlat-client package was installed properly...\e[97m"
    echo -e ""
    if [[ $(dpkg-query -W -f='${STATUS}' mlat-client 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
        # If the mlat-client package could not be installed halt setup.
        echo -e ""
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  UNABLE TO INSTALL A REQUIRED PACKAGE."
        echo -e "  SETUP HAS BEEN TERMINATED!"
        echo -e ""
        echo -e "\e[93mThe package \"mlat-client\" could not be installed.\e[39m"
        echo -e ""
        echo -e "\e[93m  ------------------------------------------------------------------------------"
        echo -e "\e[92m  ADS-B Exchange feed setup halted.\e[39m"
        echo -e ""
        if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
            read -p "Press enter to continue..." CONTINUE
        fi
        exit 1
    fi
fi

## CREATE THE SCRIPT TO EXECUTE AND MAINTAIN NETCAT AND MLAT-CLIENT FEEDS ADS-B EXCHANGE

echo -e ""
echo -e "\e[95m  Creating maintenance for the netcat and mlat-client feeds...\e[97m"
echo -e ""

# Create the feeder directory in the build directory if it does not exist.
echo -e "\e[94m  Checking for the ${FEEDER_NAME} build directory...\e[97m"
if [[ ! -d "${COMPONENT_BUILD_DIRECTORY}" ]] ; then
    echo -e "\e[94m  Creating the ${FEEDER_NAME} build directory...\e[97m"
    mkdir -vp ${COMPONENT_BUILD_DIRECTORY} 2>&1
fi
echo -e ""

if [[ ${FEEDER_BEAST_ENABLED} = "true" ]] ; then
    # Create netcat maint script.
    echo -e "\e[94m  Creating the file ${FEEDER_NAME}-netcat_maint.sh...\e[97m"
    tee ${COMPONENT_BUILD_DIRECTORY}/${FEEDER_NAME}-netcat_maint.sh > /dev/null <<EOF
#! /bin/bash
while true
  do
    /bin/nc ${FEEDER_BEAST_SRC_HOST} ${FEEDER_BEAST_SRC_PORT} | /bin/nc ${FEEDER_BEAST_DST_HOST} ${FEEDER_BEAST_DST_PORT}
    sleep 30
  done
EOF
fi

if [[ ${FEEDER_MLAT_ENABLED} = "true" ]] ; then
    # Create MLAT maint script.
    echo -e "\e[94m  Creating the file ${FEEDER_NAME}-mlat_maint.sh...\e[97m"
    tee ${COMPONENT_BUILD_DIRECTORY}/${FEEDER_NAME}-mlat_maint.sh > /dev/null <<EOF
#! /bin/bash
while true
  do
    /usr/bin/mlat-client --input-type dump1090 --input-connect ${FEEDER_MLAT_SRC_HOST}:${FEEDER_MLAT_SRC_PORT} --lat ${RECEIVER_LATITUDE} --lon ${RECEIVER_LONGITUDE} --alt ${RECEIVER_ALTITUDE} --user ${FEEDER_USERNAME} --server ${FEEDER_MLAT_DST_HOST}:${FEEDER_MLAT_DST_PORT} --no-udp ${FEEDER_MLAT_RETURN_RESULTS}
    sleep 30
  done
EOF
    echo -e ""
fi

if [[ ${FEEDER_BEAST_ENABLED} = "true" ]] ; then
    # Set permissions on netcat script.
    echo -e "\e[94m  Setting file permissions for ${FEEDER_NAME}-netcat_maint.sh...\e[97m"
    sudo chmod +x ${COMPONENT_BUILD_DIRECTORY}/${FEEDER_NAME}-netcat_maint.sh 2>&1
fi

if [[ ${FEEDER_MLAT_ENABLED} = "true" ]] ; then
    # Set permissions on MLAT script.
    echo -e "\e[94m  Setting file permissions for ${FEEDER_NAME}-mlat_maint.sh...\e[97m"
    sudo chmod +x ${COMPONENT_BUILD_DIRECTORY}/${FEEDER_NAME}-mlat_maint.sh 2>&1
    echo -e ""
fi

if [[ ${FEEDER_BEAST_ENABLED} = "true" ]] ; then
    # Add netcat script to startup.
    echo -e "\e[94m  Checking if the netcat startup line is contained within the file /etc/rc.local...\e[97m"
    if [[ `grep -cFx "${COMPONENT_BUILD_DIRECTORY}/${FEEDER_NAME}-netcat_maint.sh &" /etc/rc.local` -eq 0 ]] ; then
        echo -e "\e[94m  Adding the netcat startup line to the file /etc/rc.local...\e[97m"
        lnum=($(sed -n '/exit 0/=' /etc/rc.local))
        ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i ${COMPONENT_BUILD_DIRECTORY}/${FEEDER_NAME}-netcat_maint.sh &\n" /etc/rc.local
        echo -e ""
    fi
fi

if [[ ${FEEDER_MLAT_ENABLED} = "true" ]] ; then
    # Add MLAT script to startup.
    echo -e "\e[94m  Checking if the mlat-client startup line is contained within the file /etc/rc.local...\e[97m"
    if [[ `grep -cFx "${COMPONENT_BUILD_DIRECTORY}/${FEEDER_NAME}-mlat_maint.sh &" /etc/rc.local` -eq 0 ]] ; then
        echo -e "\e[94m  Adding the mlat-client startup line to the file /etc/rc.local...\e[97m"
        lnum=($(sed -n '/exit 0/=' /etc/rc.local))
        ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i ${COMPONENT_BUILD_DIRECTORY}/${FEEDER_NAME}-mlat_maint.sh &\n" /etc/rc.local
        echo -e ""
    fi
    echo -e ""
fi

## START THE NETCAT FEED AND MLAT-CLIENT

echo -e ""
echo -e "\e[95m  Starting the netcat and mlat-client feeds...\e[97m"
echo -e ""

if [[ ${FEEDER_BEAST_ENABLED} = "true" ]] ; then
    # Kill any currently running instances of the feeder netcat_maint.sh script.
    echo -e "\e[94m  Checking for any running ${FEEDER_NAME}-netcat_maint.sh processes...\e[97m"
    PIDS=`ps -efww | grep -w "${FEEDER_NAME}-netcat_maint.sh" | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [[ -n "${PIDS}" ]] ; then
        echo -e "\e[94m   Killing any running ${FEEDER_NAME}-netcat_maint.sh processes...\e[97m"
        sudo kill ${PIDS} 2>&1
        sudo kill -9 ${PIDS} 2>&1
    fi
    PIDS=`ps -efww | grep -w "/bin/nc ${FEEDER_BEAST_DST_HOST}" | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [[ -n "${PIDS}" ]] ; then
        echo -e "\e[94m   Killing any running netcat processes...\e[97m"
        sudo kill ${PIDS} 2>&1
        sudo kill -9 ${PIDS} 2>&1
    fi
    echo -e ""
fi

if [[ ${FEEDER_MLAT_ENABLED} = "true" ]] ; then
    # Kill any currently running instances of the feeder mlat_maint.sh script.
    echo -e "\e[94m  Checking for any running ${FEEDER_NAME}-mlat_maint.sh processes...\e[97m"
    PIDS=`ps -efww | grep -w "${FEEDER_NAME}-mlat_maint.sh" | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [[ -n "${PIDS}" ]] ; then
        echo -e "\e[94m   Killing any running ${FEEDER_NAME}-mlat_maint.sh processes...\e[97m"
        sudo kill ${PIDS} 2>&1
        sudo kill -9 ${PIDS} 2>&1
    fi
    PIDS=`ps -efww | grep -w "mlat-client --input-type .* --server ${FEEDER_MLAT_DST_HOST}" | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [[ -n "${PIDS}" ]] ; then
        echo -e "\e[94m   Killing any running mlat-client processes...\e[97m"
        sudo kill ${PIDS} 2>&1
        sudo kill -9 ${PIDS} 2>&1
    fi
    echo -e ""
fi

if [[ ${FEEDER_BEAST_ENABLED} = "true" ]] ; then
    # Start netcat script.
    echo -e "\e[94m  Executing the ${FEEDER_NAME}-netcat_maint.sh script...\e[97m"
    sudo nohup ${COMPONENT_BUILD_DIRECTORY}/${FEEDER_NAME}-netcat_maint.sh > /dev/null 2>&1 &
fi

if [[ ${FEEDER_MLAT_ENABLED} = "true" ]] ; then
    # Start MLAT script.
    echo -e "\e[94m  Executing the ${FEEDER_NAME}-mlat_maint.sh script...\e[97m"
    sudo nohup ${COMPONENT_BUILD_DIRECTORY}/${FEEDER_NAME}-mlat_maint.sh > /dev/null 2>&1 &
    echo -e ""
fi

### SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  ADS-B Exchange feed setup is complete.\e[39m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

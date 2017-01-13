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

FEEDER_NAME="adsbexchange"
MLAT_CLIENT_BUILD_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/mlat-client"
ADSB_EXCHANGE_BUILD_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/${FEEDER_NAME}"

ADSB_EXCHANGE_BEAST_SRC_HOST="127.0.0.1"
ADSB_EXCHANGE_BEAST_SRC_PORT="30005"
ADSB_EXCHANGE_BEAST_DST_HOST="feed.adsbexchange.com"
ADSB_EXCHANGE_BEAST_DST_PORT="30005"

ADSB_EXCHANGE_MLAT_SRC_HOST="127.0.0.1"
ADSB_EXCHANGE_MLAT_SRC_PORT="30005"
ADSB_EXCHANGE_MLAT_DST_HOST="feed.adsbexchange.com"
ADSB_EXCHANGE_MLAT_DST_PORT="31090"
ADSB_EXCHANGE_MLAT_RETURN_PORT="30104"

## INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

## BEGIN SETUP

clear
echo -e "\n\e[91m  ${ADSB_PROJECTTITLE}"
echo ""
echo -e "\e[92m  Setting up the ADS-B Exchange feed..."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo ""
whiptail --backtitle "${ADSB_PROJECTTITLE}" --title "ADS-B Exchange Feed Setup" --yesno "ADS-B Exchange is a co-op of ADS-B/Mode S/MLAT feeders from around the world, and the world’s largest source of unfiltered flight data.\n\n  http://www.adsbexchange.com/how-to-feed/\n\nContinue setting up the ADS-B Exchange feed?" 12 78
CONTINUESETUP=$?
if [[ "${CONTINUESETUP}" = 1 ]] ; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  ADS-B Exchange feed setup halted.\e[39m"
    echo ""
    if [[ ! -z ${VERBOSE} ]] ; then
        read -p "Press enter to continue..." CONTINUE
    fi
    exit 1
fi

## CHECK FOR AND REMOVE  ANY OLD STYLE ADB-B EXCHANGE SETUPS IF ANY EXIST

echo -e "\e[95m  Checking for and removing any old style ADS-B Exchange setups if any exist...\e[97m"
echo ""
# Check if the old style ${FEEDER_NAME}-maint.sh line exists in /etc/rc.local.
echo -e "\e[94m  Checking for any preexisting older style setups...\e[97m"
if grep -Fxq "${ADSB_EXCHANGE_BUILD_DIRECTORY}/${FEEDER_NAME}-maint.sh &" /etc/rc.local; then
    # Kill any currently running instances of the ${FEEDER_NAME}-maint.sh script.
    echo -e "\e[94m  Checking for any running ${FEEDER_NAME}-maint.sh processes...\e[97m"
    PIDS=`ps -efww | grep -w "${ADSB_EXCHANGE_BUILD_DIRECTORY}/${FEEDER_NAME}-maint.sh &" | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [[ ! -z "${PIDS}" ]] ; then
        echo -e "\e[94m  Killing any running ${FEEDER_NAME}-maint.sh processes...\e[97m"
        echo ""
        sudo kill ${PIDS}
        sudo kill -9 ${PIDS}
        echo ""
    fi
    # Remove the old line from /etc/rc.local.
    echo -e "\e[94m  Removing the old ${FEEDER_NAME}-maint.sh startup line from /etc/rc.local...\e[97m"
    sudo sed -i /$${ADSB_EXCHANGE_BUILD_DIRECTORY}\/${FEEDER_NAME}-maint.sh &/d /etc/rc.local
fi
echo ""

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo ""
CheckPackage curl
CheckPackage build-essential
CheckPackage debhelper
CheckPackage python-dev
CheckPackage python3-dev
CheckPackage netcat

## DOWNLOAD OR UPDATE THE MLAT-CLIENT SOURCE

echo ""
echo -e "\e[95m  Preparing the mlat-client Git repository...\e[97m"
echo ""
if [[ -d ${MLAT_CLIENT_BUILD_DIRECTORY} ]] && [[ -d ${MLAT_CLIENT_BUILD_DIRECTORY}/.git ]] ; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the mlat-client git repository directory...\e[97m"
    cd ${MLAT_CLIENT_BUILD_DIRECTORY}
    echo -e "\e[94m  Updating the local mlat-client git repository...\e[97m"
    echo ""
    git pull
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}
    echo -e "\e[94m  Cloning the mlat-client git repository locally...\e[97m"
    echo ""
    git clone https://github.com/mutability/mlat-client.git
fi

## BUILD AND INSTALL THE MLAT-CLIENT PACKAGE

echo ""
echo -e "\e[95m  Building and installing the mlat-client package...\e[97m"
echo ""
if [[ ! "${PWD}" = ${MLAT_CLIENT_BUILD_DIRECTORY} ]] ; then
    echo -e "\e[94m  Entering the mlat-client git repository directory...\e[97m"
    echo ""
    cd ${MLAT_CLIENT_BUILD_DIRECTORY}
fi
echo -e "\e[94m  Building the mlat-client package...\e[97m"
echo ""
dpkg-buildpackage -b -uc
echo ""
echo -e "\e[94m  Installing the mlat-client package...\e[97m"
echo ""
sudo dpkg -i ${RECEIVER_BUILD_DIRECTORY}/mlat-client_${MLATCLIENTVERSION}*.deb
echo ""
if [[ ! -d "${BINARIES_DIRECTORY}" ]] ; then
    echo -e "\e[94m  Creating archive directory...\e[97m"
    echo ""
    mkdir -v ${BINARIES_DIRECTORY} 2>&1
    echo ""
fi
echo -e "\e[94m  Archiving the mlat-client package...\e[97m"
echo ""
mv -v -f ${RECEIVER_BUILD_DIRECTORY}/mlat-client_* ${BINARIES_DIRECTORY} 2>&1
echo ""

# Check that the mlat-client package was installed successfully.
echo ""
echo -e "\e[94m  Checking that the mlat-client package was installed properly...\e[97m"
if [[ $(dpkg-query -W -f='${STATUS}' mlat-client 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
    # If the mlat-client package could not be installed halt setup.
    echo ""
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  UNABLE TO INSTALL A REQUIRED PACKAGE."
    echo -e "  SETUP HAS BEEN TERMINATED!"
    echo ""
    echo -e "\e[93mThe package \"mlat-client\" could not be installed.\e[39m"
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  ADS-B Exchange feed setup halted.\e[39m"
    echo ""
    if [[ ${RECEIVER_AUTOMATED_INSTALL} = "false" ]] ; then
        read -p "Press enter to continue..." CONTINUE
    fi
    exit 1
fi

## CREATE THE SCRIPT TO EXECUTE AND MAINTAIN MLAT-CLIENT AND NETCAT TO FEED ADS-B EXCHANGE

echo ""
echo -e "\e[95m  Creating maintenance for both the mlat-client and netcat feeds...\e[97m"
echo ""

# Ask the user for the user name for this receiver.
RECEIVER_NAME_TITLE="Receiver Name"
while [[ -z ${RECEIVER_NAME} ]] ; do
    RECEIVER_NAME=$(whiptail --backtitle "${ADSB_PROJECTTITLE}" --backtitle "${BACKTITLETEXT}" --title "${RECEIVER_NAME_TITLE}" --nocancel --inputbox "\nPlease enter a name for this receiver.\n\nIf you have more than one receiver, this name should be unique.\nExample: \"username-01\", \"username-02\", etc." 12 78 3>&1 1>&2 2>&3)
    RECEIVER_NAME_TITLE="Receiver Name (REQUIRED)"
done

# Ask the user to confirm the receivers latitude, this will be prepopulated by the latitude assigned dump1090-mutability.
RECEIVER_LATITUDE_TITLE="Receiver Latitude"
while [[ -z ${RECEIVER_LATITUDE} ]] ; do
    DUMP1090_LATITUDE=$(GetConfig "LAT" "/etc/default/dump1090-mutability")
    RECEIVER_LATITUDE=$(whiptail --backtitle "${ADSB_PROJECTTITLE}" --backtitle "${BACKTITLETEXT}" --title "${RECEIVER_LATITUDE_TITLE}" --nocancel --inputbox "\nEnter your receiver's latitude." 9 78 "${DUMP1090_LATITUDE=}" 3>&1 1>&2 2>&3)
    RECEIVER_LATITUDE_TITLE="Receiver Latitude (REQUIRED)"
done

# Ask the user to confirm the receivers longitude, this will be prepopulated by the longitude assigned dump1090-mutability.
RECEIVER_LONGITUDE_TITLE="Receiver Longitude"
while [[ -z ${RECEIVER_LONGITUDE} ]] ; do
    DUMP1090_LONGITUDE=$(GetConfig "LON" "/etc/default/dump1090-mutability")
    RECEIVER_LONGITUDE=$(whiptail --backtitle "${ADSB_PROJECTTITLE}" --backtitle "${BACKTITLETEXT}" --title "${RECEIVER_LONGITUDE_TITLE}" --nocancel --inputbox "\nEnter your receiver's longitude." 9 78 "${DUMP1090_LONGITUDE}" 3>&1 1>&2 2>&3)
    RECEIVER_LONGITUDE_TITLE="Receiver Longitude (REQUIRED)"
done

# Ask the user to confirm the receivers altitude, this will be prepopulated by the altitude returned from the Google Maps API.
RECEIVER_ALTITUDE_TITLE="Receiver Altitude"
while [[ -z ${RECEIVER_ALTITUDE} ]] ; do
    DERIVED_ALTITUDE=$(curl -s https://maps.googleapis.com/maps/api/elevation/json?locations=${RECEIVER_LATITUDE},${RECEIVER_LONGITUDE} | python -c "import json,sys;obj=json.load(sys.stdin);print obj['results'][0]['elevation'];")
    RECEIVER_ALTITUDE=$(whiptail --backtitle "${ADSB_PROJECTTITLE}" --backtitle "${BACKTITLETEXT}" --title "${RECEIVER_ALTITUDE_TITLE}" --nocancel --inputbox "\nEnter your receiver's altitude." 9 78 "${DERIVED_ALTITUDE}" 3>&1 1>&2 2>&3)
    RECEIVER_ALTITUDE_TITLE="Receiver Altitude (REQUIRED)"
done

# Create the feeder directory in the build directory if it does not exist.
echo -e "\e[94m  Checking for the ${FEEDER_NAME} build directory...\e[97m"
if [[ ! -d "${ADSB_EXCHANGE_BUILD_DIRECTORY}" ]] ; then
    echo -e "\e[94m  Creating the ${FEEDER_NAME} build directory...\e[97m"
    mkdir ${ADSB_EXCHANGE_BUILD_DIRECTORY}
    echo -e ""
fi

echo -e "\e[94m  Creating the file ${FEEDER_NAME}-netcat_maint.sh...\e[97m"
tee ${ADSB_EXCHANGE_BUILD_DIRECTORY}/${FEEDER_NAME}-netcat_maint.sh > /dev/null <<EOF
#! /bin/sh
while true
  do
    /bin/nc ${ADSB_EXCHANGE_BEAST_SRC_HOST} ${ADSB_EXCHANGE_BEAST_SRC_PORT} | /bin/nc ${ADSB_EXCHANGE_BEAST_DST_HOST} ${ADSB_EXCHANGE_BEAST_DST_PORT}
    sleep 30
  done
EOF

echo -e "\e[94m  Creating the file ${FEEDER_NAME}-mlat_maint.sh...\e[97m"
tee ${ADSB_EXCHANGE_BUILD_DIRECTORY}/${FEEDER_NAME}-mlat_maint.sh > /dev/null <<EOF
#! /bin/sh
while true
  do
    /usr/bin/mlat-client --input-type dump1090 --input-connect ${ADSB_EXCHANGE_MLAT_SRC_HOST}:${ADSB_EXCHANGE_MLAT_SRC_PORT} --lat ${RECEIVER_LATITUDE} --lon ${RECEIVER_LONGITUDE} --alt ${RECEIVER_ALTITUDE} --user ${RECEIVER_NAME} --server ${ADSB_EXCHANGE_MLAT_DST_HOST}:${ADSB_EXCHANGE_MLAT_DST_PORT} --no-udp --results beast,connect,${ADSB_EXCHANGE_MLAT_SRC_HOST}:${ADSB_EXCHANGE_MLAT_RETURN_PORT}
    sleep 30
  done
EOF

echo -e "\e[94m  Setting file permissions for ${FEEDER_NAME}-netcat_maint.sh...\e[97m"
sudo chmod +x ${ADSB_EXCHANGE_BUILD_DIRECTORY}/${FEEDER_NAME}-netcat_maint.sh

echo -e "\e[94m  Setting file permissions for ${FEEDER_NAME}-mlat_maint.sh...\e[97m"
sudo chmod +x ${ADSB_EXCHANGE_BUILD_DIRECTORY}/${FEEDER_NAME}-mlat_maint.sh

echo -e "\e[94m  Checking if the netcat startup line is contained within the file /etc/rc.local...\e[97m"
if ! grep -Fxq "${ADSB_EXCHANGE_BUILD_DIRECTORY}/${FEEDER_NAME}-netcat_maint.sh &" /etc/rc.local; then
    echo -e "\e[94m  Adding the netcat startup line to the file /etc/rc.local...\e[97m"
    lnum=($(sed -n '/exit 0/=' /etc/rc.local))
    ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i ${ADSB_EXCHANGE_BUILD_DIRECTORY}/${FEEDER_NAME}-netcat_maint.sh &\n" /etc/rc.local
fi

echo -e "\e[94m  Checking if the mlat-client startup line is contained within the file /etc/rc.local...\e[97m"
if ! grep -Fxq "${ADSB_EXCHANGE_BUILD_DIRECTORY}/${FEEDER_NAME}-mlat_maint.sh &" /etc/rc.local; then
    echo -e "\e[94m  Adding the mlat-client startup line to the file /etc/rc.local...\e[97m"
    lnum=($(sed -n '/exit 0/=' /etc/rc.local))
    ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i ${ADSB_EXCHANGE_BUILD_DIRECTORY}/${FEEDER_NAME}-mlat_maint.sh &\n" /etc/rc.local
fi

## START THE NETCAT FEED AND MLAT-CLIENT

echo ""
echo -e "\e[95m  Starting both the netcat and mlat-client feeds...\e[97m"
echo ""

# Kill any currently running instances of the feeder netcat_maint.sh script.
echo -e "\e[94m  Checking for any running ${FEEDER_NAME}-netcat_maint.sh processes...\e[97m"
PIDS=`ps -efww | grep -w "${FEEDER_NAME}-netcat_maint.sh" | awk -vpid=$$ '$2 != pid { print $2 }'`
if [[ ! -z "${PIDS}" ]] ; then
    echo -e "\e[94m  Killing any running ${FEEDER_NAME}-netcat_maint.sh processes...\e[97m"
    sudo kill ${PIDS}
    sudo kill -9 ${PIDS}
fi
PIDS=`ps -efww | grep -w "/bin/nc ${ADSB_EXCHANGE_BEAST_DST_HOST}" | awk -vpid=$$ '$2 != pid { print $2 }'`
if [[ ! -z "${PIDS}" ]] ; then
    echo -e "\e[94m  Killing any running netcat processes...\e[97m"
    sudo kill ${PIDS}
    sudo kill -9 ${PIDS}
fi

# Kill any currently running instances of the feeder mlat_maint.sh script.
echo -e "\e[94m  Checking for any running ${FEEDER_NAME}-mlat_maint.sh processes...\e[97m"
PIDS=`ps -efww | grep -w "${FEEDER_NAME}-mlat_maint.sh" | awk -vpid=$$ '$2 != pid { print $2 }'`
if [[ ! -z "${PIDS}" ]] ; then
    echo -e "\e[94m  Killing any running ${FEEDER_NAME}-mlat_maint.sh processes...\e[97m"
    sudo kill ${PIDS}
    sudo kill -9 ${PIDS}
fi
PIDS=`ps -efww | grep -w "mlat-client --input-type .* --server ${ADSB_EXCHANGE_MLAT_DST_HOST}" | awk -vpid=$$ '$2 != pid { print $2 }'`
if [[ ! -z "${PIDS}" ]] ; then
    echo -e "\e[94m  Killing any running mlat-client processes...\e[97m"
    sudo kill ${PIDS}
    sudo kill -9 ${PIDS}
fi

echo -e "\e[94m  Executing the ${FEEDER_NAME}-netcat_maint.sh script...\e[97m"
sudo nohup ${ADSB_EXCHANGE_BUILD_DIRECTORY}/${FEEDER_NAME}-netcat_maint.sh > /dev/null 2>&1 &

echo -e "\e[94m  Executing the ${FEEDER_NAME}-mlat_maint.sh script...\e[97m"
sudo nohup ${ADSB_EXCHANGE_BUILD_DIRECTORY}/${FEEDER_NAME}-mlat_maint.sh > /dev/null 2>&1 &

### SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  ADS-B Exchange feed setup is complete.\e[39m"
echo ""
if [[ ${RECEIVER_AUTOMATED_INSTALL} = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

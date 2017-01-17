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
# Copyright (c) 2015-2017 Joseph A. Prochazka                                       #
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
RECEIVER_BASH_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/bash"
RECEIVER_BUILD_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/build"

# Component pecific variables.

FEEDER_BUILD_DIRECTORY="$PROJECTROOTDIRECTORY/build/generic-feeder"

MLAT_CLIENT_BUILD_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/mlat-client"

FEEDER_NAME=""
FEEDER_BUILD_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/${FEEDER_NAME}"

FEEDER_BEAST_DST_HOST=""
FEEDER_BEAST_DST_PORT="30004"
FEEDER_BEAST_SRC_HOST="127.0.0.1"
FEEDER_BEAST_SRC_PORT="30005"

FEEDER_MLAT_DST_HOST=""
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

if [[ ${RECEIVER_AUTOMATED_INSTALL} = "false" ]] ; then
    clear
    echo -e "\n\e[91m  ${ADSB_PROJECTTITLE}"
fi
echo -e ""
echo -e "\e[92m  Setting up the Generic Feeder..."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo -e ""
whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Generic Feeder Setup" --yesno "Some useful text goes here.\n\n  Continue setting up the Generic Feeder?" 12 78
CONTINUESETUP=$?
if [ "$CONTINUESETUP" = 1 ]; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo -e ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  Generic Feeder setup halted.\e[39m"
    echo -e ""
    if [[ ! -z ${VERBOSE} ]] ; then
        read -p "Press enter to continue..." CONTINUE
    fi
    exit 1
fi

## CHECK FOR AND REMOVE ANY OLD STYLE ADB-B EXCHANGE SETUPS IF ANY EXIST

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo -e ""
CheckPackage curl
CheckPackage build-essential
CheckPackage debhelper
CheckPackage python-dev
CheckPackage python3-dev
CheckPackage netcat

## DOWNLOAD OR UPDATE THE MLAT-CLIENT SOURCE

## BUILD AND INSTALL THE MLAT-CLIENT PACKAGE

# Check that the mlat-client package was installed successfully.

## CREATE THE SCRIPT TO EXECUTE AND MAINTAIN MLAT-CLIENT AND NETCAT TO FEED ADS-B EXCHANGE

### CONFIGURATION

if [[ -n "${FEEDER_NAME}" ]] ; then
    FEEDER_BEAST_SCRIPT="feeder-${FEEDER_NAME}-beast_maint.sh"
else
    FEEDER_BEAST_SCRIPT="feeder-generic-beast_maint.sh"
fi

    # Create the adsbexchange directory in the build directory if it does not exist.
    echo -e "\e[94m  Checking for the generic feeder build directory...\e[97m"
    if [ ! -d "${FEEDER_BUILD_DIRECTORY}" ]; then
        echo -e "\e[94m  Creating the generic feeder build directory...\e[97m"
        mkdir ${FEEDER_BUILD_DIRECTORY}
    fi

echo -e "\e[94m  Creating the file ${FEEDER_BEAST_SCRIPT}...\e[97m"
tee ${FEEDER_BUILD_DIRECTORY}/${FEEDER_BEAST_SCRIPT} > /dev/null <<EOF
#! /bin/bash
while true
  do
    /bin/nc ${FEEDER_BEAST_SRC_HOST} ${FEEDER_BEAST_SRC_PORT} | /bin/nc ${FEEDER_BEAST_DST_HOST} ${FEEDER_BEAST_DST_PORT}
    sleep 30
  done
EOF

    echo -e "\e[94m  Setting file permissions for ${FEEDER_BEAST_SCRIPT}...\e[97m"
    sudo chmod +x ${FEEDER_BUILD_DIRECTORY}/${FEEDER_BEAST_SCRIPT}


    echo -e "\e[94m  Checking if the netcat startup line is contained within the file /etc/rc.local...\e[97m"
    if ! grep -Fxq "${FEEDER_BUILD_DIRECTORY}/${FEEDER_BEAST_SCRIPT} &" /etc/rc.local; then
        echo -e "\e[94m  Adding the netcat startup line to the file /etc/rc.local...\e[97m"
        lnum=($(sed -n '/exit 0/=' /etc/rc.local))
        ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i ${FEEDER_BUILD_DIRECTORY}/${FEEDER_BEAST_SCRIPT} &\n" /etc/rc.local
    fi

## START THE MLAT-CLIENT AND NETCAT FEED

echo -e ""
echo -e "\e[95m  Starting netcat feeds...\e[97m"
echo -e ""

    # Kill any currently running instances of the ${FEEDER_BEAST_SCRIPT} script.
    echo -e "\e[94m  Checking for any running ${FEEDER_BEAST_SCRIPT} processes...\e[97m"
    PIDS=`ps -efww | grep -w "${FEEDER_BEAST_SCRIPT}" | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [ ! -z "$PIDS" ]; then
        echo -e "\e[94m  Killing any running ${FEEDER_BEAST_SCRIPT} processes...\e[97m"
        sudo kill $PIDS
        sudo kill -9 $PIDS
    fi
    PIDS=`ps -efww | grep -w "/bin/nc ${FEEDER_BEAST_DST_HOST}" | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [ ! -z "$PIDS" ]; then
        echo -e "\e[94m  Killing any running netcat processes...\e[97m"
        sudo kill $PIDS
        sudo kill -9 $PIDS
    fi

    # Kill any currently running instances of the adsbexchange-mlat_maint.sh script.

    echo -e "\e[94m  Executing the ${FEEDER_BEAST_SCRIPT} script...\e[97m"
    sudo nohup ${FEEDER_BUILD_DIRECTORY}/${FEEDER_BEAST_SCRIPT} > /dev/null 2>&1 &

### SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  Generic Feeder setup is complete.\e[39m"
echo -e ""
if [[ ${RECEIVER_AUTOMATED_INSTALL} = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

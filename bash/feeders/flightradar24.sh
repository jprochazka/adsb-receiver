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
# Copyright (c) 2015-2024, Joseph A. Prochazka                                      #
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

### INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

### BEGIN SETUP

clear
echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
echo -e ""
echo -e "\e[92m  Setting up FlightRadar24 feeder client..."
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""

# Check for existing component install.
if [[ $(dpkg-query -W -f='${STATUS}' fr24feed 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
    COMPONENT_FIRST_INSTALL="true"
fi

# Confirm component installation.
CONTINUE_SETUP=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "FlightRadar24 feeder client Setup" --yesno "The FlightRadar24 feeder client takes data from a local dump1090 instance and shares this with FlightRadar24 using the fr24feed package, for more information please see their website:\n\n  https://www.flightradar24.com/share-your-data\n\nContinue setup by installing the FlightRadar24 feeder client?" 13 78 3>&1 1>&2 2>&3)
if [[ ${CONTINUE_SETUP} -eq 1 ]] ; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo -e ""
    echo -e "\e[93m  ------------------------------------------------------------------------------"
    echo -e "\e[92m  FlightRadar24 feeder client setup halted.\e[39m"
    echo -e ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

### START INSTALLATION

echo -e ""
echo -e "\e[95m  Begining the FlightRadar24 feeder client installation process...\e[97m"
echo -e ""

# Create the component build directory if it does not exist.
if [[ ! -d ${RECEIVER_BUILD_DIRECTORY}/flightradar24 ]] ; then
    echo -e "\e[94m  Creating the FlightRadar24 feeder client build directory...\e[97m"
    echo ""
    mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/flightradar24
    echo ""
fi

# Change to the component build directory.
echo -e "\e[94m  Entering the FlightRadar24 feeder client build directory...\e[97m"
cd ${RECEIVER_BUILD_DIRECTORY}/flightradar24 2>&1
echo ""

## Download the official Flightradar24 installation script.

echo -e "\e[95m  Beginning the Flightradar24 client installation...\e[97m"
echo -e ""

echo -e "\e[94m  Downloading the Flightradar24 client installation script...\e[97m"
echo ""
wget -v https://fr24.com/install.sh

echo -e "\e[94m  Executing the Flightradar24 client installation script...\e[97m"
echo ""
sudo bash ${RECEIVER_BUILD_DIRECTORY}/flightradar24/install.sh
echo ""

# Check that the component package was installed successfully.
echo -e "\e[94m  Checking that the FlightRadar24 feeder client package was installed properly...\e[97m"

if [[ $(dpkg-query -W -f='${STATUS}' fr24feed 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
    # If the component package could not be installed halt setup.
    echo -e ""
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  UNABLE TO INSTALL A REQUIRED PACKAGE."
    echo -e "  SETUP HAS BEEN TERMINATED!"
    echo -e ""
    echo -e "\e[93mThe package \"fr24feed\" could not be installed.\e[39m"
    echo -e ""
    echo -e "\e[93m  ------------------------------------------------------------------------------"
    echo -e "\e[92m  FlightRadar24 feeder client setup halted.\e[39m"
    echo -e ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

## COMPONENT POST INSTALL ACTIONS

# If sharing to other networks alongside Flightradar24 disable MLAT.
echo -e "\e[94m  Flightradar24 asks that MLAT be disabled if sharing with other networks...\e[97m"
ChangeConfig "mlat" "no" "/etc/fr24feed.ini"
ChangeConfig "mlat-without-gps" "no" "/etc/fr24feed.ini"
echo -e "\e[94m  Restarting the Flightradar24 client...\e[97m"
sudo systemctl restart fr24feed

### SETUP COMPLETE

# Return to the project root directory.
echo -e "\e[94m  Returning to ${RECEIVER_PROJECT_TITLE} root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  FlightRadar24 feeder client setup is complete.\e[39m"
echo -e ""
read -p "Press enter to continue..." CONTINUE

exit 0

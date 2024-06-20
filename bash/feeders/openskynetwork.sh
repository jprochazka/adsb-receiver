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
echo -e "\e[92m  Setting up OpenSky Network feeder client..."
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""

# Confirm component installation.
CONTINUE_SETUP=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "OpenSky Network feeder client Setup" --yesno "The OpenSky Network is a community-based receiver network which continuously collects air traffic surveillance data. Unlike other networks, OpenSky keeps the collected data forever and makes it accessible to researchers. For more information  please see their website:\n\n  https://opensky-network.org/\n\nContinue setup by installing the OpenSky Network feeder client?" 13 78 3>&1 1>&2 2>&3)
if [[ ${CONTINUE_SETUP} -eq 1 ]] ; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo -e ""
    echo -e "\e[93m  ------------------------------------------------------------------------------"
    echo -e "\e[92m  OpenSky Network feeder client setup halted.\e[39m"
    echo -e ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

### ADD THE OPENSKY NETWORK APT REPOSITORY TO THE SYSTEM IF IT DOES NOT ALREADY EXIST

echo -e "\e[95m  Setting up the OpenSky Network apt repository if it has not yet been setup...\e[97m"
echo ""

if ! grep -q "^deb .*opensky." /etc/apt/sources.list /etc/apt/sources.list.d/*; then
    echo -e "\e[94m  The OpenSky Network apt repository is not set up...\e[97m"
    CheckPackage apt-transport-https
    echo -e "\e[94m  Downloading the OpenSky Network apt repository GPG key...\e[97m"
    wget -O - https://opensky-network.org/files/firmware/opensky.gpg.pub | sudo apt-key add -
    echo -e "\e[94m  Adding the OpenSky Network apt repository...\e[97m"
    sudo bash -c "echo deb https://opensky-network.org/repos/debian opensky custom > /etc/apt/sources.list.d/opensky.list"
else
    echo -e "\e[94m  The OpenSky Network apt repository already exists in /etc/apt/sources.list.d/...\e[97m"
fi
echo ""

### INSTALL THE OPENSKY NETWORK FEEDER PACKAGE USING APT

echo -e "\e[95m  Installing the OpenSky Network fedder package...\e[97m"
echo ""

echo -e "\e[94m  Downloading the latest package lists for all enabled repositories and PPAs...\e[97m"
echo ""
sudo apt-get update
echo ""
echo -e "\e[94m  Installing the OpenSky Network fedder package using apt...\e[97m"
CheckPackage opensky-feeder

### SETUP COMPLETE

# Return to the project root directory.
echo -e "\e[94m  Returning to ${RECEIVER_PROJECT_TITLE} root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  OpenSky Network feeder client setup is complete.\e[39m"
echo -e ""
read -p "Press enter to continue..." CONTINUE

exit 0

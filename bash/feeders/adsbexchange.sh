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
# Copyright (c) 2016-2024, Joseph A. Prochazka                                      #
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

clear
echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
echo -e ""
echo -e "\e[92m  Setting up the ADS-B Exchange feed..."
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""
CONTINUE_SETUP=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "ADS-B Exchange Feed Setup" --yesno "ADS-B Exchange is a co-op of ADS-B/Mode S/MLAT feeders from around the world, and the world’s largest source of unfiltered flight data.\n\n  http://www.adsbexchange.com/how-to-feed/\n\nContinue setting up the ADS-B Exchange feed?" 18 78 3>&1 1>&2 2>&3)
if [[ ${CONTINUE_SETUP} -eq 1 ]] ; then
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

## DOWNLOAD AND EXECUTE THE INSTALL SCRIPT

# Explain the process.
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "ADS-B Exchange Feed Setup" --msgbox "Scripts supplied by ADS-B Exchange will be used in order to install or upgrade this system. Interaction with the script exececuted will be required in order to complete the installation." 10 78

echo -e "\e[95m  Preparing to execute the ${ACTION_TO_PERFORM} script...\e[97m"
echo ""

# Create the build directory if needed then enter it.
if [ ! -d "${RECEIVER_BUILD_DIRECTORY}/adsbexchange" ]; then
    echo -e "\e[94m  Creating the ADSBExchange build directory...\e[97m"
    mkdir ${RECEIVER_BUILD_DIRECTORY}/adsbexchange
fi
echo -e "\e[94m  Entering the ADSBExchange build directory...\e[97m"
cd ${RECEIVER_BUILD_DIRECTORY}/adsbexchange

# Determine if the feeder is already installed or not.
ACTION_TO_PERFORM="install"
if [[ -f /lib/systemd/system/adsbexchange-mlat.service && -f /lib/systemd/system/adsbexchange-feed.service ]]; then
    ACTION_TO_PERFORM="upgrade"
fi

# Begin the install or upgrade process.
echo -e "\e[94m  Downloading the ${ACTION_TO_PERFORM} script...\e[97m"
echo ""
if [[ "${ACTION_TO_PERFORM}" = "install" ]]; then
    wget -O ${RECEIVER_BUILD_DIRECTORY}/adsbexchange/feed-${ACTION_TO_PERFORM}.sh https://www.adsbexchange.com/feed.sh
else
    wget -O ${RECEIVER_BUILD_DIRECTORY}/adsbexchange/feed-${ACTION_TO_PERFORM}.sh https://www.adsbexchange.com/feed-update.sh
fi

echo -e "\e[94m  Making the ${ACTION_TO_PERFORM} script executable...\e[97m"
chmod -x ${RECEIVER_BUILD_DIRECTORY}/adsbexchange/feed-${ACTION_TO_PERFORM}.sh
echo -e "\e[94m  Executing the ${ACTION_TO_PERFORM} script...\e[97m"
echo ""
sudo bash ${RECEIVER_BUILD_DIRECTORY}/adsbexchange/feed-${ACTION_TO_PERFORM}.sh

## ADS-B EXCHANGE FEED SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
echo -e "\e[92m  ADS-B Exchange feed setup is complete.\e[39m"
echo ""
read -p "Press enter to continue..." CONTINUE

exit 0

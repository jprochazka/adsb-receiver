#!/bin/bash

#####################################################################################
#                                   ADS-B RECEIVER                                  #
#####################################################################################
#                                                                                   #
#  A set of scripts created to automate the process of installing the software      #
#  needed to setup a Mode S decoder as well as feeders which are capable of         #
#  sharing your ADS-B results with many of the most popular ADS-B aggregate sites.  #
#                                                                                   #
#  Project Hosted On GitHub: https://github.com/jprochazka/adsb-receiver            #
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

PROJECT_ROOT_DIRECTORY="$PWD"
BASH_DIRECTORY="$PROJECT_ROOT_DIRECTORY/bash"
BUILD_DIRECTORY="$PROJECT_ROOT_DIRECTORY/build"

## INCLUDE EXTERNAL SCRIPTS

source $BASH_DIRECTORY/variables.sh
source $BASH_DIRECTORY/functions.sh

DOMAIN=""
TOKEN=""

## BEGIN SETUP

clear
echo -e "\n\e[91m  $ADSB_PROJECTTITLE"
echo ""
echo -e "\e[92m  Setting up the Duck DNS dynamic DNS update script..."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo ""
whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Duck DNS Dynamic DNS" --yesno "Duck DNS is a free dynamic DNS service hosted on Amazon VPC.\n\nPLEASE NOTE:\n\nBefore continuing this setup it is recommended that you visit the Duck DNS website and signup for then setup a sub domain which will be used by this device. You will need both the domain and token supplied to you after setting up your account.\n\nhttp://www.duckdns.org\n\nContinue with Duck DNS update script setup?" 18 78
CONTINUESETUP=$?
if [ $CONTINUESETUP = 1 ]; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  Duck DNS dynamic DNS setup halted.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

echo -e "\e[95m  Setting up Duck DNS dynamic DNS on this device...\e[97m"
echo ""

# Ask the user for the user name for this receiver.
DOMAIN_TITLE="Duck DNS Domain"
while [[ -z $DOMAIN ]]; do
    DOMAIN=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --backtitle "$BACKTITLETEXT" --title "$DOMAIN_TITLE" --nocancel --inputbox "\nPlease enter the Duck DNS domain you selected after registering.\nIf you do not have one yet visit http://www.ducknds.org to obtain one." 9 78 3>&1 1>&2 2>&3)
    DOMAIN_TITLE="Duck DNS Domain (REQUIRED)"
done

# Ask the user for the user name for this receiver.
TOKEN_TITLE="Duck DNS Token"
while [[ -z $TOKEN ]]; do
    TOKEN=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --backtitle "$BACKTITLETEXT" --title "$TOKEN_TITLE" --nocancel --inputbox "\nPlease enter your Duck DNS token." 8 78 3>&1 1>&2 2>&3)
    TOKEN_TITLE="Duck DNS Token (REQUIRED)"
done

# Check that the required packages are installed.
CheckPackage cron
CheckPackage curl

# Create a duckdns directory within the build directory if it does not already exist.
if [ ! -d $BUILD_DIRECTORY/duckdns ]; then
    echo -e "\e[94m  Creating the directory $BUILD_DIRECTORY/duckdns...\e[97m"
    mkdir $BUILD_DIRECTORY/duckdns
fi

# Create then set permissions on the file duck.sh.
echo -e "\e[94m  Creating the Duck DNS update script...\e[97m"
tee $BUILD_DIRECTORY/duckdns/duck.sh > /dev/null <<EOF
echo url="https://www.duckdns.org/update?domains=$DOMAIN&token=$TOKEN&ip=" | curl -k -o $BUILD_DIRECTORY/duckdns/duck.log -K -
EOF

echo -e "\e[94m  Setting execute permissions for only this user on the Duck DNS update script...\e[97m"
chmod 700 $BUILD_DIRECTORY/duckdns/duck.sh

# Add job to the users crontab if it does not exist.
echo -e "\e[94m  Adding the Duck DNS update command to your crontab if it does not exist already...\e[97m"
COMMAND="$BUILD_DIRECTORY/duckdns/duck.sh >/dev/null 2>&1"
JOB="*/5 * * * * $COMMAND"

# Should only add the job if the COMMAND does not already exist in the users crontab.
(crontab -l | grep -v -F "$COMMAND" ; echo "$JOB") | crontab -

# The following command should remove the job from the users crontab.
#(crontab -l | grep -v -F "$COMMAND" ) | crontab -

# Run the Duck DNS update script for the first time..
echo -e "\e[94m  Executing the Duck DNS update script...\e[97m"
echo ""
$BUILD_DIRECTORY/duckdns/duck.sh
echo ""

## DUCK DNS SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd $PROJECT_ROOT_DIRECTORY

echo ""
echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
echo -e "\e[92m  Duck DNS dynamic DNS setup is complete.\e[39m"
echo ""
read -p "Press enter to continue..." CONTINUE

#exit 0

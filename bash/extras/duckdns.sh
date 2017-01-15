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

### INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] && [[ -s "${RECEIVER_CONFIGURATION_FILE}" ]] ; then
    source ${RECEIVER_CONFIGURATION_FILE}
fi

### BEGIN SETUP

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    clear
    echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
fi
echo -e ""
echo -e "\e[92m  Setting up the Duck DNS dynamic DNS update script..."
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Duck DNS Dynamic DNS" --yesno "Duck DNS is a free dynamic DNS service hosted on Amazon VPC.\n\nPLEASE NOTE:\n\nBefore continuing this setup it is recommended that you visit the Duck DNS website and signup for then setup a sub domain which will be used by this device. You will need both the domain and token supplied to you after setting up your account.\n\nhttp://www.duckdns.org\n\nContinue with Duck DNS update script setup?" 18 78
    if [[ $? -eq 1 ]] ; then
        # Setup has been halted by the user.
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo -e ""
        echo -e "\e[93m  ------------------------------------------------------------------------------"
        echo -e "\e[92m  Duck DNS dynamic DNS setup halted.\e[39m"
        echo -e ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
    fi
fi

echo -e "\e[95m  Setting up Duck DNS dynamic DNS on this device...\e[97m"
echo -e ""

### CHECK FOR PREREQUISITE PACKAGES

# Check that the required packages are installed.
echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo -e ""
CheckPackage cron
CheckPackage curl

### CONFIRM SETTINGS

# Confirm settings with user.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # Ask for the user sub domain to be assigned to this device.
    DUCKDNS_DOMAIN_TITLE="Duck DNS Sub Domain"
    while [[ -z ${DOMAIN} ]]; do
        DUCKDNS_DOMAIN=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${DUCKDNS_DOMAIN_TITLE}" --nocancel --inputbox "\nPlease enter the Duck DNS sub domain you selected after registering.\nIf you do not have one yet visit http://www.ducknds.org to obtain one." 9 78 3>&1 1>&2 2>&3)
        DUCKDNS_DOMAIN_TITLE="Duck DNS Sub Domain (REQUIRED)"
    done
    # Ask for the Duck DNS token to be assigned to this receiver.
    DUCKDNS_TOKEN_TITLE="Duck DNS Token"
    while [[ -z ${TOKEN} ]]; do
        DUCKDNS_TOKEN=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${DUCKDNS_TOKEN_TITLE}" --nocancel --inputbox "\nPlease enter your Duck DNS token." 8 78 3>&1 1>&2 2>&3)
        DUCKDNS_TOKEN_TITLE="Duck DNS Token (REQUIRED)"
    done
fi

### PROJECT BUILD DIRECTORY

# Create the build directory if it does not already exist.
if [[ ! -d ${RECEIVER_BUILD_DIRECTORY} ]] ; then
    echo -e "\e[94m  Creating the ADS-B Receiver Project build directory...\e[97m"
    mkdir -v ${RECEIVER_BUILD_DIRECTORY} 2>&1
fi

# Create a duckdns directory within the build directory if it does not already exist.
if [[ ! -d ${RECEIVER_BUILD_DIRECTORY}/duckdns ]] ; then
    echo -e "\e[94m  Creating the directory ${RECEIVER_BUILD_DIRECTORY}/duckdns...\e[97m"
    mkdir -v ${RECEIVER_BUILD_DIRECTORY}/duckdns 2>&1
fi

### DOWNLOAD SOURCE

### BUILD AND INSTALL

# Create then set permissions on the file duck.sh.
echo -e "\e[94m  Creating the Duck DNS update script...\e[97m"
tee ${RECEIVER_BUILD_DIRECTORY}/duckdns/duck.sh > /dev/null <<EOF
echo url="https://www.duckdns.org/update?domains=${DOMAIN}&token=${TOKEN}&ip=" | curl -k -o ${RECEIVER_BUILD_DIRECTORY}/duckdns/duck.log -K -
EOF

echo -e "\e[94m  Setting execute permissions for only this user on the Duck DNS update script...\e[97m"
chmod -v 700 ${RECEIVER_BUILD_DIRECTORY}/duckdns/duck.sh 2>&1

### CREATE SCRIPTS

# Add job to the users crontab if it does not exist.
echo -e "\e[94m  Adding the Duck DNS update command to your crontab if it does not exist already...\e[97m"
COMMAND="${RECEIVER_BUILD_DIRECTORY}/duckdns/duck.sh >/dev/null 2>&1"
JOB="*/5 * * * * ${COMMAND}"

# Should only add the job if the COMMAND does not already exist in the users crontab.
(crontab -l | grep -v -F "${COMMAND}" ; echo "${JOB}") | crontab -

# The following command should remove the job from the users crontab.
#(crontab -l | grep -v -F "${COMMAND}" ) | crontab -

### START SCRIPTS

# Run the Duck DNS update script for the first time..
echo -e "\e[94m  Executing the Duck DNS update script...\e[97m"
echo -e ""
${RECEIVER_BUILD_DIRECTORY}/duckdns/duck.sh 2>&1
echo -e ""

### SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  Duck DNS dynamic DNS setup is complete.\e[39m"
echo -e ""
if [[ ${RECEIVER_AUTOMATED_INSTALL} = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

#exit 0

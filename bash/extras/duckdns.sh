#!/bin/bash

## INCLUDE EXTERNAL SCRIPTS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh


## BEGIN SETUP

clear
echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
echo ""
echo -e "\e[92m  Setting up Duck DNS..."
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo ""
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Duck DNS Dynamic DNS" --yesno "Duck DNS is a free dynamic DNS service hosted on Amazon VPC.\n\nPLEASE NOTE:\n\nBefore continuing this setup it is recommended that you visit the Duck DNS website and signup for then setup a sub domain which will be used by this device. You will need both the domain and token supplied to you after setting up your account.\n\n  http://www.duckdns.org\n\nContinue with Duck DNS update script setup?" 18 78; then
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo ""
    echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
    echo -e "\e[92m  Duck DNS setup halted.\e[39m"
    echo ""
    read -p "Press enter to continue..." discard
    exit 1
fi

echo -e "\e[95m  Setting up Duck DNS on this device...\e[97m"
echo ""


## CHECK FOR PREREQUISITE PACKAGES

# Check that the required packages are installed
echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo ""
CheckPackage cron
CheckPackage curl
exho ""


## CONFIRM SETTINGS

# Ask for the user sub domain to be assigned to this device
domain_title="Duck DNS Sub Domain"
while [[ -z $domain ]] ; do
    domain=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title $domain_title --nocancel --inputbox "\nPlease enter the Duck DNS sub domain you selected after registering.\nIf you do not have one yet visit http://www.ducknds.org to obtain one." 9 78 3>&1 1>&2 2>&3)
    domain_title="Duck DNS Sub Domain (REQUIRED)"
done

# Ask for the Duck DNS token to be assigned to this receiver
token_title="Duck DNS Token"
while [[ -z "${DUCKDNS_TOKEN}" ]] ; do
    token=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title $token_title --nocancel --inputbox "\nPlease enter your Duck DNS token." 8 78 3>&1 1>&2 2>&3)
    token_title="Duck DNS Token (REQUIRED)"
done


## PROJECT BUILD DIRECTORY

# Create the build directory if it does not already exist
if [[ ! -d $RECEIVER_BUILD_DIRECTORY ]]; then
    echo -e "\e[94m  Creating the ADS-B Receiver Project build directory...\e[97m"
    mkdir -vp $RECEIVER_BUILD_DIRECTORY 2>&1
fi

# Create a component directory within the build directory if it does not already exist
if [[ ! -d $RECEIVER_BUILD_DIRECTORY/duckdns ]]; then
    echo -e "\e[94m  Creating the directory ${RECEIVER_BUILD_DIRECTORY}/duckdns...\e[97m"
    echo ""
    mkdir -vp $RECEIVER_BUILD_DIRECTORY/duckdns 2>&1
    echo ""
fi


## CREATE SCRIPT

# Create then set permissions on the file duck.sh
echo -e "\e[94m  Creating the Duck DNS update script...\e[97m"
tee $RECEIVER_BUILD_DIRECTORY/duckdns/duck.sh > /dev/null <<EOF
echo url="https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip=" | curl -k -o $RECEIVER_BUILD_DIRECTORY/duckdns/duck.log
EOF

echo -e "\e[94m  Setting execute permissions for only this user on the Duck DNS update script...\e[97m"
echo ""
chmod -v 700 $RECEIVER_BUILD_DIRECTORY/duckdns/duck.sh 2>&1
echo ""


## ADD TO CRON

echo -e "\e[94m  Adding the DuckDNS cron file...\e[97m"
sudo tee /etc/cron.d/duckdns_ip_address_update > /dev/null <<EOF
# Updates IP address with duckdns.org
*/5 * * * * $RECEIVER_BUILD_DIRECTORY/duckdns/duck.sh >/dev/null 2>&1
EOF
echo ""


## START SCRIPTS

echo -e "\e[95m  Starting Duck DNS...\e[97m"
echo ""

# Kill any currently running instance
  pid=`ps -efww | grep -w "duck.sh " | awk -vpid=$$ '$2 != pid { print $2 }'`
  if [[ -n $pid ]]; then
        echo -e "\e[94m  Killing the duck.sh process...\e[97m"
        echo ""
        sudo kill $pid 2>&1
        sudo kill -9 $pid 2>&1
        echo ""
    fi
done

# Run the Duck DNS update script for the first time
echo -e "\e[94m  Executing the Duck DNS update script...\e[97m"
echo ""
$RECEIVER_BUILD_DIRECTORY/duckdns/duck.sh 2>&1
echo ""


## SETUP COMPLETE

# Return to the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd $RECEIVER_ROOT_DIRECTORY 2>&1

echo ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  Duck DNS setup is complete.\e[39m"
echo ""
read -p "Press enter to continue..." discard

exit 0

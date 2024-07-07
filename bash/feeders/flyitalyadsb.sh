#!/bin/bash

## INCLUDE EXTERNAL SCRIPTS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh


## BEGIN SETUP

clear
echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
echo -e ""
echo -e "\e[92m  Setting up the Fly Italy ADS-B feeder client..."
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""

# Confirm component installation.
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Fly Italy ADS-B feeder client Setup" --yesno "The Fly Italy ADS-B feeder client takes data from a local dump1090 instance and shares this with Fly Italy ADS-B. for more information please see their website:\n\n  https://flyitalyadsb.com/come-condividere-la-propria-antenna/\n\nContinue setup by installing the Fly Italy ADS-B feeder client?" 13 78 3>&1 1>&2 2>&3; then
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo -e ""
    echo -e "\e[93m  ------------------------------------------------------------------------------"
    echo -e "\e[92m  Fly Italy ADS-B feeder client setup halted.\e[39m"
    echo -e ""
    read -p "Press enter to continue..." discard
    exit 1
fi


## START FEEDER

echo -e ""
echo -e "\e[95m  Begining the Fly Italy ADS-B feeder client installation process...\e[97m"
echo -e ""

# Create the component build directory if it does not exist
if [[ ! -d $RECEIVER_BUILD_DIRECTORY/flyitalyadsb ]]; then
    echo -e "\e[94m  Creating the Fly Italy ADS-B feeder client build directory...\e[97m"
    echo ""
    mkdir -vp $RECEIVER_BUILD_DIRECTORY/flyitalyadsb
    echo ""
fi

# Change to the component build directory
echo -e "\e[94m  Entering the Fly Italy ADS-B feeder client build directory...\e[97m"
cd $RECEIVER_BUILD_DIRECTORY/flyitalyadsb 2>&1
echo ""

# Download the official Fly Italy ADS-B feeder installation script
echo -e "\e[95m  Beginning the Fly Italy ADS-B feeder client installation...\e[97m"
echo -e ""

echo -e "\e[94m  Downloading the Fly Italy ADS-B feeder client installation script...\e[97m"
echo ""
wget -v https://raw.githubusercontent.com/flyitalyadsb/fly-italy-adsb/master/install.sh

echo -e "\e[94m  Executing the Fly Italy ADS-B feeder client installation script...\e[97m"
echo ""
sudo bash $RECEIVER_BUILD_DIRECTORY/flyitalyadsb/install.sh
echo ""


## INSTALL UPDATER

if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Install The Fly Italy ADS-B Updater" --yesno "It is recommended that the Fly Italy ADS-B updater be installed as well.\n\nWould you like to install the updater at this time?" 12 78;
    # Download the official Fly Italy ADS-B feeder updater script
    echo -e "\e[95m  Beginning the Fly Italy ADS-B feeder updater installation...\e[97m"
    echo -e ""

    echo -e "\e[94m  Downloading the Fly Italy ADS-B feeder updater installation script...\e[97m"
    echo ""
    wget -v wget https://raw.githubusercontent.com/flyitalyadsb/mlat-client/master/scripts/install_updater.sh

    echo -e "\e[94m  Executing the Fly Italy ADS-B feeder updater installation script...\e[97m"
    echo ""
    sudo bash $RECEIVER_BUILD_DIRECTORY/flyitalyadsb/install_updater.sh
    echo ""
fi


## POST INSTALLATION INFORMATION

whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Fly Italy ADS-B Feeder Setup Complete" --msgbox "To check the status of your installation vist https://flyitalyadsb.com/stato-ricevitore/.\n\nFor information on configuring your Fly Italy ADS-B feeder visit https://flyitalyadsb.com/configurazione-script/" 12 78

## SETUP COMPLETE

# Return to the project root directory
echo -e "\e[94m  Returning to ${RECEIVER_PROJECT_TITLE} root directory...\e[97m"
cd $RECEIVER_ROOT_DIRECTORY 2>&1

echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  Fly Italy ADS-B feeder client setup is complete.\e[39m"
echo -e ""
read -p "Press enter to continue..." discard

exit 0

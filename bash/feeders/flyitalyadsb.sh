#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
LogProjectTitle
LogTitleHeading "Setting up the Fly Italy ADS-B client"
LogTitleMessage "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "Fly Italy ADS-B feeder client Setup" \
              --yesno "The Fly Italy ADS-B feeder client takes data from a local dump1090 instance and shares this with Fly Italy ADS-B. for more information please see their website:\n\n  https://flyitalyadsb.com/come-condividere-la-propria-antenna/\n\nContinue setup by installing the Fly Italy ADS-B feeder client?" \
              13 78; then
    echo ""
    LogAlertHeading "INSTALLATION HALTED"
    LogAlertMessage "Setup has been halted at the request of the user"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "Fly Italy ADS-B client setup halted"
    echo ""
    exit 1
fi


## DOWNLOAD AND EXECUTE THE PROPER FLY ITALY ADS-B CLIENT SCRIPT

LogHeading "Begining the Fly Italy ADS-B client installation process"

LogMessage "Informing the user of how the installation process will work"
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "Fly Italy ADS-B Client Setup" \
         --msgbox "Scripts supplied by airplanes.live will be used in order to install or upgrade this system. Interaction with the script exececuted will be required in order to complete the installation." \
         10 78

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/flyitalyadsb ]]; then
    LogMessage "Creating the Fly Italy ADS-B build directory"
    echo ""
    mkdir -v $RECEIVER_BUILD_DIRECTORY/flyitalyadsb 2>&1 | tee -a $RECEIVER_LOG_FILE
    echo ""
fi
LogMessage "Entering the Fly Italy ADS-B build directory"
cd $RECEIVER_BUILD_DIRECTORY/flyitalyadsb

LogMessage "Downloading the Fly Italy ADS-B installation script"
echo ""
wget -v -O $RECEIVER_BUILD_DIRECTORY/flyitalyadsb/install.sh https://raw.githubusercontent.com/flyitalyadsb/fly-italy-adsb/master/install.sh 2>&1 | tee -a $RECEIVER_LOG_FILE
LogMessage "Executing the Fly Italy ADS-B feeder installation script"
echo ""
sudo bash $RECEIVER_BUILD_DIRECTORY/flyitalyadsb/install.sh

LogMessage "Asking if the user wishes to install the Fly Italy ADS-B updater"
if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
            --title "Install The Fly Italy ADS-B Updater" \
            --yesno "It is recommended that the Fly Italy ADS-B updater be installed as well.\n\nWould you like to install the updater at this time?" \
            12 78; then
    LogMessage "Downloading the Fly Italy ADS-B updater script"
    echo ""
    wget -v -O $RECEIVER_BUILD_DIRECTORY/flyitalyadsb/install_updater.sh https://raw.githubusercontent.com/flyitalyadsb/mlat-client/master/scripts/install_updater.sh 2>&1 | tee -a $RECEIVER_LOG_FILE
    LogMessage "Executing the Fly Italy ADS-B feeder updater script"
    echo ""
    sudo bash $RECEIVER_BUILD_DIRECTORY/flyitalyadsb/install_updater.sh
fi


## POST INSTALLATION OPERATIONS

LogHeading "Performing post installation operations"

LogMessage "Informing user as to how to check client status"
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "Fly Italy ADS-B Feeder Setup Complete" \
         --msgbox "To check the status of your installation vist https://flyitalyadsb.com/stato-ricevitore/.\n\nFor information on configuring your Fly Italy ADS-B feeder visit https://flyitalyadsb.com/configurazione-script/" \
         12 78


## SETUP COMPLETE

LogMessage "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
LogTitleMessage "------------------------------------------------------------------------------"
LogTitleHeading "Fly Italy ADS-B client setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

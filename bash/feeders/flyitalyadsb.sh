#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
log_project_title
log_title_heading "Setting up the Fly Italy ADS-B client"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "Fly Italy ADS-B feeder client Setup" \
              --yesno "The Fly Italy ADS-B feeder client takes data from a local dump1090 instance and shares this with Fly Italy ADS-B. for more information please see their website:\n\n  https://flyitalyadsb.com/come-condividere-la-propria-antenna/\n\nContinue setup by installing the Fly Italy ADS-B feeder client?" \
              13 78; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "Fly Italy ADS-B client setup halted"
    echo ""
    exit 1
fi


## DOWNLOAD AND EXECUTE THE PROPER FLY ITALY ADS-B CLIENT SCRIPT

log_heading "Begining the Fly Italy ADS-B client installation process"

log_message "Informing the user of how the installation process will work"
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "Fly Italy ADS-B Client Setup" \
         --msgbox "Scripts supplied by Fly Italy ADS-B will be used in order to install or upgrade this system. Interaction with the script exececuted will be required in order to complete the installation." \
         10 78
if [[ ! -d $RECEIVER_BUILD_DIRECTORY/flyitalyadsb ]]; then
    log_message "Creating the Fly Italy ADS-B build directory"
    echo ""
    mkdir -v $RECEIVER_BUILD_DIRECTORY/flyitalyadsb 2>&1 | tee -a $RECEIVER_LOG_FILE
    echo ""
fi
log_message "Entering the Fly Italy ADS-B build directory"
cd $RECEIVER_BUILD_DIRECTORY/flyitalyadsb

log_message "Downloading the Fly Italy ADS-B installation script"
echo ""
wget -v -O $RECEIVER_BUILD_DIRECTORY/flyitalyadsb/install.sh https://raw.githubusercontent.com/flyitalyadsb/fly-italy-adsb/master/install.sh 2>&1 | tee -a $RECEIVER_LOG_FILE
log_message "Executing the Fly Italy ADS-B feeder installation script"
echo ""
sudo bash $RECEIVER_BUILD_DIRECTORY/flyitalyadsb/install.sh

log_message "Asking if the user wishes to install the Fly Italy ADS-B updater"
if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
            --title "Install The Fly Italy ADS-B Updater" \
            --yesno "It is recommended that the Fly Italy ADS-B updater be installed as well.\n\nWould you like to install the updater at this time?" \
            12 78; then
    log_message "Downloading the Fly Italy ADS-B updater script"
    echo ""
    wget -v -O $RECEIVER_BUILD_DIRECTORY/flyitalyadsb/install_updater.sh https://raw.githubusercontent.com/flyitalyadsb/mlat-client/master/scripts/install_updater.sh 2>&1 | tee -a $RECEIVER_LOG_FILE
    log_message "Executing the Fly Italy ADS-B feeder updater script"
    echo ""
    sudo bash $RECEIVER_BUILD_DIRECTORY/flyitalyadsb/install_updater.sh
fi


## POST INSTALLATION OPERATIONS

log_heading "Performing post installation operations"

log_message "Informing user as to how to check client status"
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "Fly Italy ADS-B Feeder Setup Complete" \
         --msgbox "To check the status of your installation vist https://flyitalyadsb.com/stato-ricevitore/.\n\nFor information on configuring your Fly Italy ADS-B feeder visit https://flyitalyadsb.com/configurazione-script/" \
         12 78


## SETUP COMPLETE

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "Fly Italy ADS-B client setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

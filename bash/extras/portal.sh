#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
log_project_title
log_title_heading "Setting up the ADS-B Portal"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "ADS-B Portal Setup" \
              --yesno "ADS-B Portal is a web-based interface for viewing and managing ADS-B data.\n\n  http://www.adsbreceiver.org/\n\nContinue setting up the ADS-B Portal?" \
              18 78; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "ADS-B Portal setup halted"
    echo ""
    exit 1
fi

## Execute the portal setup script in the portal directory

## SETUP COMPLETE

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "ADS-B Portal setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0
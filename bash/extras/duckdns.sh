#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
log_project_title
log_title_heading "Setting up Duck DNS"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "Duck DNS Dynamic DNS" \
              --yesno "Duck DNS is a free dynamic DNS service hosted on Amazon VPC.\n\nPLEASE NOTE:\n\nBefore continuing this setup it is recommended that you visit the Duck DNS website and signup for then setup a sub domain which will be used by this device. You will need both the domain and token supplied to you after setting up your account.\n\n  http://www.duckdns.org\n\nContinue with Duck DNS update script setup?" \
              18 78; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "Duck DNS setup halted"
    echo ""
    exit 1
fi


## CHECK FOR PREREQUISITE PACKAGES

log_heading "Installing packages needed to fulfill PlaneFinder client dependencies"

check_package cron
check_package curl


## GATHER REQUIRED INFORMATION FROM THE USER

log_heading "Gather information required to configure Duck DNS support"

log_message "Asking the user for the sub domain to be assigned to this device"
duckdns_domain_title="Duck DNS Sub Domain"
while [[ -z $duckdns_domain ]]; do
    duckdns_domain=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                      --title "${duckdns_domain_title}" \
                      --inputbox "\nPlease enter the Duck DNS sub domain you selected after registering.\nIf you do not have one yet visit http://www.ducknds.org to obtain one." \
                      9 78 3>&1 1>&2 2>&3)
    if [[ $duckdns_domain == 0 ]]; then
        log_alert_heading "INSTALLATION HALTED"
        log_alert_message "Setup has been halted due to lack of required information"
        echo ""
        log_title_message "------------------------------------------------------------------------------"
        log_title_heading "Duck DNS decoder setup halted"
        exit 1
    fi
    duckdns_domain_title="Duck DNS Sub Domain (REQUIRED)"
done

log_message "Asking the user for the Duck DNS token"
duckdns_token_title="Duck DNS Token"
while [[ -z $duckdns_token ]]; do
    duckdns_token=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                     --title "${duckdns_token_title}" \
                     --inputbox "\nPlease enter your Duck DNS token." \
                     8 78 3>&1 1>&2 2>&3)
    if [[ $duckdns_domain == 0 ]]; then
        log_alert_heading "INSTALLATION HALTED"
        log_alert_message "Setup has been halted due to lack of required information"
        echo ""
        log_title_message "------------------------------------------------------------------------------"
        log_title_heading "Duck DNS setup halted"
        exit 1
    fi
    duckdns_token_title="Duck DNS Token (REQUIRED)"
done


## CREATE THE DUCK DNS SCRIPT

log_heading "Creating the Duck DNS script"

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/duckdns ]]; then
    log_message "Creating the Duck DNS build directory"
    echo ""
    mkdir -v $RECEIVER_BUILD_DIRECTORY/duckdns 2>&1 | tee -a $RECEIVER_LOG_FILE
    echo ""
fi

log_message "Creating the Duck DNS update script"
tee $RECEIVER_BUILD_DIRECTORY/duckdns/duck.sh > /dev/null <<EOF
echo url="https://www.duckdns.org/update?domains=${duckdns_domain}&token=${duckdns_token}&ip=" | curl -k -o $RECEIVER_BUILD_DIRECTORY/duckdns/duck.log
EOF

log_message "Adding execute permissions for only this user to the Duck DNS update script"
echo ""
chmod -v 700 $RECEIVER_BUILD_DIRECTORY/duckdns/duck.sh 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""

log_message "Creating the Duck DNS cron file"
sudo tee /etc/cron.d/duckdns_ip_address_update > /dev/null <<EOF
# Updates IP address with duckdns.org
*/5 * * * * $RECEIVER_BUILD_DIRECTORY/duckdns/duck.sh >/dev/null 2>&1
EOF

log_message "Executing the Duck DNS update script"
echo ""
$RECEIVER_BUILD_DIRECTORY/duckdns/duck.sh
echo ""


## SETUP COMPLETE

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "Duck DNS setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

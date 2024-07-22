#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
LogProjectTitle
LogTitleHeading "Setting up Duck DNS"
LogTitleMessage "------------------------------------------------------------------------------"
echo ""
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "Duck DNS Dynamic DNS" \
              --yesno "Duck DNS is a free dynamic DNS service hosted on Amazon VPC.\n\nPLEASE NOTE:\n\nBefore continuing this setup it is recommended that you visit the Duck DNS website and signup for then setup a sub domain which will be used by this device. You will need both the domain and token supplied to you after setting up your account.\n\n  http://www.duckdns.org\n\nContinue with Duck DNS update script setup?" \
              18 78; then
    LogAlertHeading "INSTALLATION HALTED"
    LogAlertMessage "Setup has been halted at the request of the user"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "Duck DNS setup halted"
    echo ""
    exit 1
fi


## CHECK FOR PREREQUISITE PACKAGES

LogHeading "Installing packages needed to fulfill PlaneFinder client dependencies"

CheckPackage cron
CheckPackage curl


## GATHER REQUIRED INFORMATION FROM THE USER

LogHeading "Gather information required to configure Duck DNS support"

LogMessage "Asking the user for the sub domain to be assigned to this device"
domain_title="Duck DNS Sub Domain"
while [[ -z $domain ]] ; do
    domain=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                      --title $domain_title \
                      --inputbox "\nPlease enter the Duck DNS sub domain you selected after registering.\nIf you do not have one yet visit http://www.ducknds.org to obtain one." \
                      9 78)
    if [[ $domain == 0 ]]; then
        LogAlertHeading "INSTALLATION HALTED"
        LogAlertMessage "Setup has been halted due to lack of required information"
        echo ""
        LogTitleMessage "------------------------------------------------------------------------------"
        LogTitleHeading "Duck DNS decoder setup halted"
        exit 1
    fi
    domain_title="Duck DNS Sub Domain (REQUIRED)"
done

LogMessage "Asking the user for the Duck DNS token"
token_title="Duck DNS Token"
while [[ -z "${DUCKDNS_TOKEN}" ]] ; do
    token=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                     --title $token_title \
                     --inputbox "\nPlease enter your Duck DNS token." \
                     8 78)
    if [[ $domain == 0 ]]; then
        LogAlertHeading "INSTALLATION HALTED"
        LogAlertMessage "Setup has been halted due to lack of required information"
        echo ""
        LogTitleMessage "------------------------------------------------------------------------------"
        LogTitleHeading "Duck DNS setup halted"
        exit 1
    fi
    token_title="Duck DNS Token (REQUIRED)"
done


## CREATE THE DUCK DNS SCRIPT

LogHeading "Creating the Duck DNS script"

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/duckdns ]]; then
    LogMessage "Creating the Duck DNS build directory"
    echo ""
    mkdir -vp $RECEIVER_BUILD_DIRECTORY/duckdns
    echo ""
fi

LogMessage "Creating the Duck DNS update script"
tee $RECEIVER_BUILD_DIRECTORY/duckdns/duck.sh > /dev/null <<EOF
echo url="https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip=" | curl -k -o $RECEIVER_BUILD_DIRECTORY/duckdns/duck.log
EOF

LogMessage "Adding execute permissions for only this user to the Duck DNS update script"
echo ""
chmod -v 700 $RECEIVER_BUILD_DIRECTORY/duckdns/duck.sh
echo ""

LogMessage "Creating the Duck DNS cron file"
sudo tee /etc/cron.d/duckdns_ip_address_update > /dev/null <<EOF
# Updates IP address with duckdns.org
*/5 * * * * $RECEIVER_BUILD_DIRECTORY/duckdns/duck.sh >/dev/null 2>&1
EOF
echo ""

LogMessage "Executing the Duck DNS update script"
echo ""
$RECEIVER_BUILD_DIRECTORY/duckdns/duck.sh
echo ""


## SETUP COMPLETE

LogMessage "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
LogTitleMessage "------------------------------------------------------------------------------"
LogTitleHeading "Duck DNS setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

#!/bin/bash

# MUST USE "OFFICIAL" AIRNAV RADAR RBFEEDER BINARIES
# -------------------------------------------------------------------------------------
# According to the AirNav Radar rbfeeder GitHub Issue Tracker any binaries built using
# their source code repository not built by AirNav Radar themselves will not be able to
# connect to their services.


## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
log_project_title
log_title_heading "Setting up the AirNav Radar client"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "AirNav Radar feeder client Setup" \
              --yesno "The AirNav Radar feeder client takes data from a local dump1090 and dump978 instances and shares this with AirNav Radar using the rbfeeder package. More information on sharing data with AirNave Radar can be found here:\n\n  https://www.airnavradar.com/sharing-data\n\nContinue setup by installing the rbfeeder client?" \
              13 78; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "AirNav Radar client setup halted"
    echo ""
    exit 1
fi


## CHECK FOR PREREQUISITE PACKAGES

log_heading "Installing packages needed to fulfill AirNav Radar rbfeeder dependencies"

check_package dirmngr


## ADD THE APT REPOSITORY

log_heading "Adding the rb24 apt repository"

log_message "Importing the key"
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 1D043681

log_message "Removing the old source list"
/bin/rm -f /etc/apt/sources.list.d/rb24.list

log_message "Setting repository based on distribution"
distro="bookworm"
case $RECEIVER_OS_CODE_NAME in
    bullseye | jammy)
        echo 'deb https://apt.rb24.com/ bullseye main' > /etc/apt/sources.list.d/rb24.list
        ;;
    bookworm)
        echo 'deb https://apt.rb24.com/ bookworm main' > /etc/apt/sources.list.d/rb24.list
        ;;
    noble)
        distro="trixie"
        ;;
esac
log_message "Setting repository distribution to ${distro}"


## UPDATE APT REPOSITORY AND INSTALL RBFEEDER

log_heading "Updating apt repositories"
apt update -y

log_heading "Installing rbfeeder"
check_package rbfeeder


## POST INSTALLATION OPERATIONS

log_heading "Performing post installation operations"

log_message "Asking for pre-existing sharing-key"
sharing_key=$(whiptail --backtitle "AirNav Radar Feeder Client Setup" \
                            --title "Enter Pre-Existing Sharing-Key" \
                            --inputbox "\nEnter your sharing-key or leave blank if you do not have one." \
                            8 78 \
                            "" 3>&1 1>&2 2>&3)
exit_status=$?
if [[ $exit_status != 0 ]]; then
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted due to user intervention"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "AirNav Radar Feeder Client setup halted"
    exit 1
fi

if [[ -n "${sharing_key}" ]] ; then
    log_message "Attempting to set sharing-key to ${sharing_key}"
    sudo rbfeeder --setkey $sharing_key
fi

wait_time=5
log_message "Waiting ${wait_time} seconds before continuing "
echo -n "Waiting for $wait_time seconds: "
for ((i=0; i<wait_time; i++)); do
  echo -n "."
  sleep 1
done

log_message "Attempting to retreive sharing-key from AirNav Radar"
real_sharing_key=`sudo rbfeeder --showkey`
log_message "Sharing-key set to ${real_sharing_key}"


## SETUP COMPLETE

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "AirNav Radar client setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

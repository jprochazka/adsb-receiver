#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
log_project_title
log_title_heading "Setting up the OpenSky Network client"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "OpenSky Network feeder client Setup" \
              --yesno "The OpenSky Network is a community-based receiver network which continuously collects air traffic surveillance data. Unlike other networks, OpenSky keeps the collected data forever and makes it accessible to researchers. For more information  please see their website:\n\n  https://opensky-network.org/\n\nContinue setup by installing the OpenSky Network feeder client?" \
              13 78; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "OpenSky Network client setup halted"
    echo ""
    exit 1
fi


## CHECK FOR PREREQUISITE PACKAGES

log_heading "Installing packages needed to fulfill OpenSky Network client dependencies"

check_package apt-transport-https


## ADD THE OPENSKY NETWORK APT REPOSITORY TO THE SYSTEM IF IT DOES NOT ALREADY EXIST

log_heading "Setting up the OpenSky Network apt repository if it has not yet been setup...\e[97m"

opensky_repo_url="https://opensky-network.org/repos/debian"
opensky_repo_suite="opensky"
opensky_repo_component="custom"

log_message "Checking if the OpenSky Network apt repository is set up"
if ! grep -Rqs "^deb .*opensky." /etc/apt/sources.list.d /etc/apt/sources.list 2>/dev/null; then
    log_message "The OpenSky Network apt repository is not set up"

    log_message "Checking OpenSky repository availability"
    if ! curl -fsSL "${opensky_repo_url}/dists/${opensky_repo_suite}/Release" >/dev/null 2>&1; then
        log_alert_heading "INSTALLATION HALTED"
        log_alert_message "Unable to verify OpenSky apt repository metadata at ${opensky_repo_url}"
        log_alert_message "Setup has been terminated"
        echo ""
        log_title_message "------------------------------------------------------------------------------"
        log_title_heading "OpenSky Network client setup halted"
        echo ""
        exit 1
    fi

    if [[ ! -d $RECEIVER_BUILD_DIRECTORY/openskynetwork ]]; then
        log_message "Creating the OpenSky Network build directory"
        echo ""
        mkdir -v $RECEIVER_BUILD_DIRECTORY/openskynetwork 2>&1 | log_pipe
        echo ""
    fi
    log_message "Entering the OpenSky Network build directory"
    cd $RECEIVER_BUILD_DIRECTORY/openskynetwork

    log_message "Downloading and adding the OpenSky Network apt repository GPG key"
    echo ""
    wget -v -O $RECEIVER_BUILD_DIRECTORY/openskynetwork/opensky.gpg.pub https://opensky-network.org/files/firmware/opensky.gpg.pub 2>&1 | log_pipe
    sudo install -d -m 0755 /etc/apt/keyrings
    sudo gpg --dearmor -o /etc/apt/keyrings/opensky.gpg $RECEIVER_BUILD_DIRECTORY/openskynetwork/opensky.gpg.pub 2>&1 | log_pipe
    sudo chmod 0644 /etc/apt/keyrings/opensky.gpg
    echo ""
    log_message "Adding the OpenSky Network apt repository"
    echo "deb [signed-by=/etc/apt/keyrings/opensky.gpg] ${opensky_repo_url} ${opensky_repo_suite} ${opensky_repo_component}" | sudo tee /etc/apt/sources.list.d/opensky.list > /dev/null
else
    log_message "The OpenSky Network apt repository is already set up"
fi


## INSTALL THE OPENSKY NETWORK FEEDER PACKAGE USING APT

log_heading "Installing the OpenSky Network feeder package"

log_message "Downloading the latest package lists for all enabled repositories and PPAs"
echo ""
sudo apt-get update 2>&1 | log_pipe
echo ""
log_message "Installing the OpenSky Network fedder package using apt"
echo ""
sudo apt-get install -y opensky-feeder 2>&1 | log_pipe
echo ""


## SETUP COMPLETE

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "OpenSky Network client setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

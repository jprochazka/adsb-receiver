#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
LogProjectTitle
LogTitleHeading "Setting up the OpenSky Network client"
LogTitleMessage "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "OpenSky Network feeder client Setup" \
              --yesno "The OpenSky Network is a community-based receiver network which continuously collects air traffic surveillance data. Unlike other networks, OpenSky keeps the collected data forever and makes it accessible to researchers. For more information  please see their website:\n\n  https://opensky-network.org/\n\nContinue setup by installing the OpenSky Network feeder client?" \
              13 78; then
    echo ""
    LogAlertHeading "INSTALLATION HALTED"
    LogAlertMessage "Setup has been halted at the request of the user"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "OpenSky Network client setup halted"
    echo ""
    exit 1
fi


## CHECK FOR PREREQUISITE PACKAGES

LogHeading "Installing packages needed to fulfill OpenSky Network client dependencies"

CheckPackage apt-transport-https


## ADD THE OPENSKY NETWORK APT REPOSITORY TO THE SYSTEM IF IT DOES NOT ALREADY EXIST

LogHeading "Setting up the OpenSky Network apt repository if it has not yet been setup...\e[97m"

LogMessage "Checking if the OpenSky Network apt repository is set up"
if ! grep -q "^deb .*opensky." /etc/apt/sources.list /etc/apt/sources.list.d/*; then
    LogMessage "The OpenSky Network apt repository is not set up"

    if [[ ! -d $RECEIVER_BUILD_DIRECTORY/openskynetwork ]]; then
        LogMessage "Creating the OpenSky Network build directory"
        echo ""
        mkdir -v $RECEIVER_BUILD_DIRECTORY/openskynetwork 2>&1 | tee -a $RECEIVER_LOG_FILE
        echo ""
    fi
    LogMessage "Entering the OpenSky Network build directory"
    cd $RECEIVER_BUILD_DIRECTORY/openskynetwork

    LogMessage "Downloading and adding the OpenSky Network apt repository GPG key"
    echo ""
    wget -v -O $RECEIVER_BUILD_DIRECTORY/openskynetwork/opensky.gpg.pub https://opensky-network.org/files/firmware/opensky.gpg.pub 2>&1 | tee -a $RECEIVER_LOG_FILE
    wget -q -O - https://opensky-network.org/files/firmware/opensky.gpg.pub | sudo apt-key add - 2>&1 | tee -a $RECEIVER_LOG_FILE
    echo ""
    LogMessage "Adding the OpenSky Network apt repository"
    sudo bash -c "echo deb https://opensky-network.org/repos/debian opensky custom > /etc/apt/sources.list.d/opensky.list"
else
    LogMessage "The OpenSky Network apt repository is already set up"
fi


## INSTALL THE OPENSKY NETWORK FEEDER PACKAGE USING APT

LogHeading "Installing the OpenSky Network feeder package"

LogMessage "Downloading the latest package lists for all enabled repositories and PPAs"
echo ""
sudo apt-get update 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""
LogMessage "Installing the OpenSky Network fedder package using apt"
echo ""
sudo apt-get install opensky-feeder
echo ""


## SETUP COMPLETE

LogMessage "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
LogTitleMessage "------------------------------------------------------------------------------"
LogTitleHeading "OpenSky Network client setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

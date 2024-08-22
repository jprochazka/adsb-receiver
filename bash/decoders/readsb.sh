#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
log_project_title
log_title_heading "Setting up the Readsb decoder"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "Readsb Decoder Setup" \
              --yesno "Readsb is a Mode-S/ADSB/TIS decoder for RTLSDR, BladeRF, Modes-Beast and GNS5894 devices.\n\nRepository: https://github.com/wiedehopf/readsb\n\nWould you like to begin the setup process now?" \
              14 78; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "Readsb decoder setup halted"
    echo ""
    exit 1
fi


## GATHER REQUIRED INFORMATION FROM THE USER

ask_for_device_assignments "readsb"
if [[ $? -ne 0 ]] ; then
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted due to lack of required information"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "Readsb decoder setup halted"
    exit 1
fi


## CHECK FOR PREREQUISITE PACKAGES

log_heading "Installing packages needed to fulfill FlightAware Dump1090 decoder dependencies"

check_package build-essential
check_package debhelper
check_package git
check_package fakeroot
check_package libncurses-dev
check_package librtlsdr-dev
check_package libusb-1.0-0-dev
check_package libzstd1
check_package libzstd-dev
check_package pkg-config
check_package zlib1g
check_package zlib1g-dev


## BLACKLIST UNWANTED RTL-SDR MODULES

log_heading "Blacklist unwanted RTL-SDR kernel modules."

blacklist_modules


## CLONE OR PULL THE READSB DECODER SOURCE

log_heading "Preparing the Readsb Git repository"

if [[ -d $RECEIVER_BUILD_DIRECTORY/readsb/readsb && -d $RECEIVER_BUILD_DIRECTORY/readsb/readsb/.git ]]; then
    log_message "Entering the Readsb git repository directory"
    cd $RECEIVER_BUILD_DIRECTORY/readsb/readsb
    log_message "Pulling the Readsb git repository"
    echo ""
    git pull 2>&1 | tee -a $RECEIVER_LOG_FILE
else
    log_message "Creating the Readsb Project build directory"
    echo ""
    mkdir -v $RECEIVER_BUILD_DIRECTORY/readsb 2>&1 | tee -a $RECEIVER_LOG_FILE
    echo ""
    log_message "Entering the Readsb Project build directory"
    cd $RECEIVER_BUILD_DIRECTORY/readsb
    log_message "Cloning the readsb git repository"
    echo ""
    git clone https://github.com/wiedehopf/readsb.git 2>&1 | tee -a $RECEIVER_LOG_FILE
fi


## BUILD AND INSTALL THE DUMP1090-FA PACKAGE

log_heading "Building the FlightAware dump1090-fa package"

log_message "Entering the dump1090 Git repository"
cd $RECEIVER_BUILD_DIRECTORY/readsb
log_message "Setting build options"
export DEB_BUILD_OPTIONS=noddebs
log_message "Building the Readsb Debian package"
echo ""
dpkg-buildpackage -b -Prtlsdr -ui -uc -us
echo ""
log_message "Installing the Readsb Debian package"
echo ""
sudo dpkg -i $RECEIVER_BUILD_DIRECTORY/readsb/readsb_*.deb

log_message "Checking that the Readsb Debian package was installed"
if [[ $(dpkg-query -W -f='${STATUS}' readsb 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    echo ""
    log_alert_message "The Readsb Debian package failed to install"
    log_alert_message "Setup has been terminated"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "Readsb decoder setup halted"
    echo ""
    read -p "Press enter to continue..." discard
    exit 1
fi

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/package-archive ]]; then
    log_message "Creating the Debian package archive directory"
    echo ""
    mkdir -v $RECEIVER_BUILD_DIRECTORY/package-archive 2>&1 | tee -a $RECEIVER_LOG_FILE
    echo ""
fi
log_message "Copying the Readsb Debian package into the Debian package archive directory"
echo ""
cp -vf $RECEIVER_BUILD_DIRECTORY/readsb/*.deb $RECEIVER_BUILD_DIRECTORY/package-archive/ 2>&1 | tee -a $RECEIVER_LOG_FILE


## CONFIGURATION

assign_devices_to_decoders


## POST INSTALLATION OPERATIONS

log_heading "Performing post installation operations"

log_message "Unsetting build options"
unset DEB_BUILD_OPTIONS


## SETUP COMPLETE

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "Readsb decoder setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0
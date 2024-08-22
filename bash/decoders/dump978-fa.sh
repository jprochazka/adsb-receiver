#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
log_project_title
log_title_heading "Setting up the FlightAware Dump978 decoder"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "FlightAware Dump978 Setup" \
              --yesno "This is the FlightAware 978MHz UAT decoder. It is a reimplementation in C++, loosely based on the demodulator from https://github.com/mutability/dump978.\n\n  https://github.com/flightaware/dump978\n\nContinue setup by installing dump978-fa?" \
              14 78; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "FlightAware Dump978 decoder setup halted"
    echo ""
    exit 1
fi


## GATHER REQUIRED INFORMATION FROM THE USER

ask_for_device_assignments "dump978-fa"
if [[ $? -ne 0 ]] ; then
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted due to lack of required information"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "ACARSDEC decoder setup halted"
    exit 1
fi


## CHECK FOR PREREQUISITE PACKAGES

log_heading "Installing packages needed to fulfill FlightAware Dump978 decoder dependencies"

check_package build-essential
check_package debhelper
check_package libboost-filesystem-dev
check_package libboost-program-options-dev
check_package libboost-regex-dev
check_package libboost-system-dev
check_package libsoapysdr-dev
check_package lighttpd
check_package soapysdr-module-rtlsdr


## BLACKLIST UNWANTED RTL-SDR MODULES

log_heading "Blacklist unwanted RTL-SDR kernel modules"

blacklist_modules


## CLONE OR PULL THE FLIGHTAWARE DUMP978 DECODER SOURCE

log_heading "Preparing the FlightAware Dump978 Git repository"

if [[ -d $RECEIVER_BUILD_DIRECTORY/dump978-fa/dump978 && -d $RECEIVER_BUILD_DIRECTORY/dump978-fa/dump978/.git ]]; then
    log_message "Entering the FlightAware dump978 git repository directory"
    cd $RECEIVER_BUILD_DIRECTORY/dump978-fa/dump978
    log_message "Pulling the dump1090 git repository"
    echo ""
    git pull 2>&1 | tee -a $RECEIVER_LOG_FILE
else
    log_message "Creating the FlightAware dump978 Project build directory"
    echo ""
    mkdir -v $RECEIVER_BUILD_DIRECTORY/dump978-fa 2>&1 | tee -a $RECEIVER_LOG_FILE
    echo ""
    log_message "Entering the ADS-B Receiver Project build directory"
    cd $RECEIVER_BUILD_DIRECTORY/dump978-fa
    log_message "Cloning the FlightAware dump978 git repository"
    echo ""
    git clone https://github.com/flightaware/dump978.git 2>&1 | tee -a $RECEIVER_LOG_FILE
fi


## BUILD AND INSTALL THE DUMP978-FA and SKYAWARE978 PACKAGES

log_heading "Building the FlightAware dump978-fa and skyaware978 packages"

log_message "Entering the dump978 Git repository"
cd $RECEIVER_BUILD_DIRECTORY/dump978-fa/dump978

log_message "Building the dump978-fa package"
echo ""
dpkg-buildpackage -b 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""

log_message "Installing the dump978-fa Debian package"
echo ""
sudo dpkg -i $RECEIVER_BUILD_DIRECTORY/dump978-fa/dump978-fa_*.deb 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""
log_message "Installing the skyaware978 Debian package"
echo ""
sudo dpkg -i $RECEIVER_BUILD_DIRECTORY/dump978-fa/skyaware978_*.deb 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""

log_message "Checking that the dump978-fa Debian package was installed"
if [[ $(dpkg-query -W -f='${STATUS}' dump978-fa 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    echo ""
    log_alert_message "The dump978-fa Debian package failed to install"
    log_alert_message "Setup has been terminated"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "FlightAware Dump978 decoder setup halted"
    echo ""
    read -p "Press enter to continue..." discard
    exit 1
fi

log_message "Checking that the skyaware978 Debian package was installed"
if [[ $(dpkg-query -W -f='${STATUS}' skyaware978 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    echo ""
    log_alert_message "The skyaware978 Debian package failed to install"
    log_alert_message "Setup has been terminated"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "FlightAware Dump978 decoder setup halted"
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
log_message "Copying the dump978-fa Debian package into the Debian package archive directory"
echo ""
cp -vf $RECEIVER_BUILD_DIRECTORY/dump978-fa/dump978-fa_*.deb $RECEIVER_BUILD_DIRECTORY/package-archive/ 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""
log_message "Copying the skyaware978 Debian package into the Debian package archive directory"
echo ""
cp -vf $RECEIVER_BUILD_DIRECTORY/dump978-fa/skyaware978_*.deb $RECEIVER_BUILD_DIRECTORY/package-archive/ 2>&1 | tee -a $RECEIVER_LOG_FILE


## CONFIGURATION

assign_devices_to_decoders


## SETUP COMPLETE

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "FlightAware Dump978 decoder setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

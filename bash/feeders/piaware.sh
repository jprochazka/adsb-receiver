#!/bin/bash

# THE FLIGHTAWARE PIAWARE CLIENT SETUP SCRIPT

# JPROCHAZKA/PIAWARE_BUILDER REPOSITORY
# -------------------------------------------------------------------------------------
# I submitted a fix to support Debian Trixie and Ubuntu Noble Numbat to FlightAware's
# piaware_builder repository. Until the changes are merged into their Git reposiory
# the installation will be done using the fork I created along with the branch which
# contains the changes needed in order to build the package.
#
# https://github.com/flightaware/piaware_builder/pull/26


## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
log_project_title
log_title_heading "Setting up the FlightAware PiAware client"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "FlightAware PiAware client Setup" \
              --yesno "The FlightAware PiAware client takes data from a local dump1090 instance and shares this with FlightAware using the piaware package, for more information please see their website:\n\n  https://www.flightaware.com/adsb/piaware/\n\nContinue setup by installing the FlightAware PiAware client?" \
              13 78; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "FlightAware PiAware client setup halted"
    echo ""
    exit 1
fi


## CHECK FOR PREREQUISITE PACKAGES

log_heading "Installing packages needed to fulfill FlightAware PiAware client dependencies"

check_package autoconf
check_package build-essential
check_package chrpath
check_package debhelper
check_package devscripts
check_package git
check_package itcl3
check_package libboost-filesystem-dev
check_package libboost-program-options-dev
check_package libboost-regex-dev
check_package libboost-system-dev
check_package libssl-dev
check_package net-tools
check_package openssl
check_package patchelf
check_package python3-build
check_package python3-dev
check_package python3-pip
check_package python3-setuptools
check_package python3-venv
check_package python3-wheel
check_package tcl-dev
check_package tcl-tls
check_package tcl8.6-dev
check_package tcllib
check_package tclx8.4
check_package zlib1g-dev

if [[ "${RECEIVER_OS_CODE_NAME}" == "noble" ]]; then
    check_package python3-filelock
    check_package python3-pyasyncore
fi


## CLONE OR PULL THE PIAWARE_BUILDER GIT REPOSITORY

log_heading "Preparing the FlightAware piaware_builder Git repository"

if [[ -d $RECEIVER_BUILD_DIRECTORY/piaware_builder && -d $RECEIVER_BUILD_DIRECTORY/piaware_builder/.git ]]; then
    log_message "Entering the piaware_builder git repository directory"
    cd $RECEIVER_BUILD_DIRECTORY/piaware_builder
    log_message "Updating the local piaware_builder git repository"
    echo ""
    git pull 2>&1 | tee -a $RECEIVER_LOG_FILE
else
    log_message "Creating the FlightAware piaware_builder build directory"
    echo ""
    mkdir -v $RECEIVER_BUILD_DIRECTORY/piaware_builder 2>&1 | tee -a $RECEIVER_LOG_FILE
    echo ""
    log_message "Entering the ADS-B Receiver Project build directory"
    cd $RECEIVER_BUILD_DIRECTORY
    log_message "Cloning the piaware_builder git repository locally"
    echo ""

    # --- START TEMPORARY NOBLE FIX ---
    if [[ "${RECEIVER_OS_CODE_NAME}" == "noble" ]]; then
        git clone -b trixie https://github.com/jprochazka/piaware_builder.git 2>&1 | tee -a $RECEIVER_LOG_FILE
    else
        git clone https://github.com/flightaware/piaware_builder.git 2>&1 | tee -a $RECEIVER_LOG_FILE
    fi

    #git clone https://github.com/flightaware/piaware_builder.git 2>&1 | tee -a $RECEIVER_LOG_FILE
    # --- END TEMPORARY NOBLE FIX ---
fi


## BUILD AND INSTALL THE PIAWARE CLIENT PACKAGE

log_heading "Beginning the FlightAware PiAware installation process"

log_message "Entering the piaware_builder git repository directory"
cd $RECEIVER_BUILD_DIRECTORY/piaware_builder

log_message "Determining which piaware_builder build strategy should be use"
distro="bookworm"
case $RECEIVER_OS_CODE_NAME in
    bullseye | jammy)
        distro="bullseye"
        ;;
    bookworm)
        distro="bookworm"
        ;;
    noble)
        distro="trixie"
        ;;
esac
log_message "Setting distribution to build for to ${distro}"

log_message "Executing the FlightAware PiAware client build script"
echo ""
./sensible-build.sh $distro 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""
log_message "Entering the FlightAware PiAware client build directory"
cd $RECEIVER_BUILD_DIRECTORY/piaware_builder/package-${distro}
log_message "Building the FlightAware PiAware client package"
echo ""
dpkg-buildpackage -b 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""
log_message "Installing the FlightAware PiAware client package"
echo ""
sudo dpkg -i $RECEIVER_BUILD_DIRECTORY/piaware_builder/piaware_*.deb 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""

log_message "Checking that the FlightAware PiAware client package was installed properly"
if [[ $(dpkg-query -W -f='${STATUS}' piaware 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
    log_alert_heading "INSTALLATION HALTED"
    echo ""
    log_alert_message "FlightAware PiAware package installation failed"
    log_alert_message "Setup has been terminated"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "FlightAware PiAware client setup failed"
    echo ""
    read -p "Press enter to continue..." discard
    exit 1
else
    if [[ ! -d $RECEIVER_BUILD_DIRECTORY/package-archive ]]; then
        log_message "Creating the package archive directory"
        echo ""
        mkdir -v $RECEIVER_BUILD_DIRECTORY/package-archive 2>&1 | tee -a $RECEIVER_LOG_FILE
        echo ""
    fi
    log_message "Copying the FlightAware PiAware client binary package into the archive directory"
    echo ""
    cp -vf $RECEIVER_BUILD_DIRECTORY/piaware_builder/*.deb $RECEIVER_BUILD_DIRECTORY/package-archive/ 2>&1 | tee -a $RECEIVER_LOG_FILE
fi


## POST INSTALLATION OPERATIONS

log_heading "Performing post installation operations"

log_message "Displaying the message informing the user on how to claim their device"
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "Claiming Your PiAware Device" \
         --msgbox "FlightAware requires you claim your feeder online using the following URL:\n\n  http://flightaware.com/adsb/piaware/claim\n\nTo claim your device simply visit the address listed above." \
         12 78


## SETUP COMPLETE

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "FlightAware PiAware client setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

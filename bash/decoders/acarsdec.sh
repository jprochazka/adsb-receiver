#!/bin/bash

# THE ACARSDECO DECODER SETUP SCRIPT

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
log_project_title ${RECEIVER_PROJECT_TITLE}
log_title_heading "Setting up the ACARSDEC decoder"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "ACARSDEC decoder Setup" \
              --yesno "Continue setup?" \
              13 78; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "ACARSDEC decoder setup halted"
    echo ""
    exit 1
fi


## PRE INSTALLATION OPERATIONS

device=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                    --title "Device Type" \
                    --menu "Choose an option" \
                    25 78 16 \
                    "RTL-SDR" "" \
                    "AirSpy" "" \
                    "SDRPlay" "")
exit_status=$?
if [[ $exitstatus == 1 ]]; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "ACARSDEC decoder setup halted"
    echo ""
    exit 1
fi


## CHECK FOR PREREQUISITE PACKAGES

log_heading "Installing packages needed to fulfill dependencies for FlightAware PiAware client"

check_package cmake
check_package libjansson-dev
check_package libpaho-mqtt-dev
check_package libsndfile-dev
check_package libsqlite3-dev
check_package libusb-1.0-0-dev
check_package libxml2-dev
check_package pkg-config
check_package zlib1g-dev

case "${device}" in
    "RTL-SDR")
        check_package librtlsdr-dev
        ;;
    "AirSpy")
        check_package libairspy-dev
        ;;
    "SDRPlay")
        check_package libmirisdr-dev
        ;;
esac


## CLONE OR PULL THE LIBACARS GIT REPOSITORY

log_heading "Preparing the libacars Git repository"

if [[ -d $RECEIVER_BUILD_DIRECTORY/libacars && -d $RECEIVER_BUILD_DIRECTORY/libacars/.git ]]; then
    log_message "Entering the libacars git repository directory"
    cd $RECEIVER_BUILD_DIRECTORY/libacars
    log_message "Updating the local libacars git repository"
    echo ""
    git pull
else
    log_message "Entering the libacars build directory"
    cd $RECEIVER_BUILD_DIRECTORY
    log_message "Cloning the libacars git repository locally"
    echo ""
    git clone https://github.com/szpajder/libacars.git
fi
echo ""


## BUILD AND INSTALL THE LIBACARS LIBRARY

log_heading "Building the libacars library"

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/libacars/build ]]; then
    log_message "Creating the libacars build directory"
    echo ""
        mkdir -vp $RECEIVER_BUILD_DIRECTORY/libacars/build
    echo ""
fi
if [[ -n "$(ls -A $RECEIVER_BUILD_DIRECTORY/libacars/build 2>/dev/null)" ]]
    log_message "Deleting all files currently residing in the libacars build directory"
    rm -rf $RECEIVER_BUILD_DIRECTORY/libacars/build/*
fi
log_message "Entering the libacars build directory"
cd $RECEIVER_BUILD_DIRECTORY/libacars/build
log_message "Executing cmake"
echo ""
cmake ../
echo ""
log_message "Executing make"
echo ""
make
echo ""
log_message "Executing make install"
echo ""
sudo make install
echo ""
log_message "Running ldconfig"
echo ""
sudo ldconfig
echo ""


## CLONE OR PULL THE ACARSDEC GIT REPOSITORY

log_heading "Preparing the ACARSDEC Git repository"

if [[ -d $RECEIVER_BUILD_DIRECTORY/acarsdec && -d $RECEIVER_BUILD_DIRECTORY/acarsdec/.git ]]; then
    log_message "Entering the ACARSDEC git repository directory"
    cd $RECEIVER_BUILD_DIRECTORY/acarsdec
    log_message "Updating the local ACARSDEC git repository"
    echo ""
    git pull
else
    log_message "Entering the build directory"
    cd $RECEIVER_BUILD_DIRECTORY
    log_message "Cloning the ACARSDEC git repository locally"
    echo ""
    git clone https://github.com/TLeconte/acarsdec.git
fi
echo ""


## BUILD AND INSTALL THE ACARSDEC BINARY

log_heading "Building the ACARSDEC binary"

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/acarsdec/build ]]; then
    log_message "Creating the ACARSDEC build directory"
    echo ""
        mkdir -vp $RECEIVER_BUILD_DIRECTORY/acarsdec/build
    echo ""
fi
if [[ -n "$(ls -A $RECEIVER_BUILD_DIRECTORY/acarsdec/build 2>/dev/null)" ]]
    log_message "Deleting all files currently residing in the ACARSDEC build directory"
    rm -rf $RECEIVER_BUILD_DIRECTORY/acarsdec/build/*
fi
log_message "Entering the ACARSDEC build directory"
cd $RECEIVER_BUILD_DIRECTORY/acarsdec/build

log_message "Executing cmake"
echo ""
case "${device}" in
    "RTL-SDR")
        cmake .. -Drtl=ON
        ;;
    "AirSpy")
        cmake .. -Dairspy=ON
        ;;
    "SDRPlay")
        cmake .. -Dsdrplay=ON
        ;;
esac
echo ""

log_message "Executing make"
echo ""
make
echo ""
log_message "Executing make install"
echo ""
sudo make install
echo ""


## CLONE OR PULL THE ACARSDEC GIT REPOSITORY

log_heading "Preparing the acarsserv Git repository"

if [[ -d $RECEIVER_BUILD_DIRECTORY/acarsserv && -d $RECEIVER_BUILD_DIRECTORY/acarsserv/.git ]]; then
    log_message "Entering the acarsserv git repository directory"
    cd $RECEIVER_BUILD_DIRECTORY/acarsserv
    log_message "Updating the local acarsserv git repository"
    echo ""
    git pull
else
    log_message "Entering the build directory"
    cd $RECEIVER_BUILD_DIRECTORY
    log_message "Cloning the acarsserv git repository locally"
    echo ""
    git clone https://github.com/TLeconte/acarsserv.git
fi
echo ""


## BUILD AND INSTALL THE ACARSDEC BINARY

log_heading "Building the ACARSDEC binary"

log_message "Entering the acarsserv build directory"
cd $RECEIVER_BUILD_DIRECTORY/acarsserv
log_message "Executing make"
echo ""
make -f Makefile


## RUN ACARSDECO AND ACARSSERV

# TODO: Create a way to run the decoder and server automatically.


## SETUP COMPLETE

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "ACARSDEC decoder setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0
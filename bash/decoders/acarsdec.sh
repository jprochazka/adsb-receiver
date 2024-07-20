#!/bin/bash

# THE ACARSDECO DECODER SETUP SCRIPT

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
LogProjectName ${RECEIVER_PROJECT_TITLE}
LogTitleHeading "Setting up the ACARSDEC decoder"
LogTitleMessage "------------------------------------------------------------------------------"
echo ""

if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "ACARSDEC decoder Setup" --yesno "Continue setup?" 13 78; then
    LogAlertHeading "INSTALLATION HALTED"
    LogAlertMessage "Setup has been halted at the request of the user"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "ACARSDEC decoder setup halted"
    echo ""
    exit 1
fi


## PRE INSTALLATION OPERATIONS

# TODO: Ask which device to build the ACARSDEC decoder for


## CHECK FOR PREREQUISITE PACKAGES

LogHeading "Installing packages needed to fulfill dependencies for FlightAware PiAware client"

CheckPackage cmake
CheckPackage zlib1g-dev
CheckPackage libxml2-dev
CheckPackage libjansson-dev
CheckPackage libusb-1.0-0-dev
CheckPackage pkg-config
CheckPackage libsndfile-dev
CheckPackage libpaho-mqtt-dev

CheckPackage librtlsdr-dev
CheckPackage libairspy-dev
CheckPackage libmirisdr-dev


## CLONE OR PULL THE LIBACARS GIT REPOSITORY

LogHeading "Preparing the libacars Git repository"

if [[ -d $RECEIVER_BUILD_DIRECTORY/libacars && -d $RECEIVER_BUILD_DIRECTORY/libacars/.git ]]; then
    LogMessage "Entering the libacars git repository directory"
    cd $RECEIVER_BUILD_DIRECTORY/libacars
    LogMessage "Updating the local libacars git repository"
    echo ""
    git pull
else
    LogMessage "Entering the libacars build directory"
    cd $RECEIVER_BUILD_DIRECTORY
    LogMessage "Cloning the libacars git repository locally"
    echo ""
    git clone https://github.com/szpajder/libacars.git
fi
echo ""


## BUILD AND INSTALL THE LIBACARS LIBRARY

LogHeading "Building the libacars library"

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/libacars/build ]]; then
    LogMessage "Creating the libacars build directory"
    echo ""
        mkdir -vp $RECEIVER_BUILD_DIRECTORY/libacars/build
    echo ""
fi
if [[ -n "$(ls -A $RECEIVER_BUILD_DIRECTORY/libacars/build 2>/dev/null)" ]]
    LogMessage "Deleting all files currently residing in the libacars build directory"
    rm -rf $RECEIVER_BUILD_DIRECTORY/libacars/build/*
fi
LogMessage "Entering the libacars build directory"
cd $RECEIVER_BUILD_DIRECTORY/libacars/build
LogMessage "Executing cmake"
echo ""
cmake ../
echo ""
LogMessage "Executing make"
echo ""
make
echo ""
LogMessage "Executing make install"
echo ""
sudo make install
echo ""
LogMessage "Running ldconfig"
echo ""
sudo ldconfig
echo ""


## CLONE OR PULL THE ACARSDEC GIT REPOSITORY

LogHeading "Preparing the ACARSDEC Git repository"

if [[ -d $RECEIVER_BUILD_DIRECTORY/acarsdec && -d $RECEIVER_BUILD_DIRECTORY/acarsdec/.git ]]; then
    LogMessage "Entering the ACARSDEC git repository directory"
    cd $RECEIVER_BUILD_DIRECTORY/acarsdec
    LogMessage "Updating the local ACARSDEC git repository"
    echo ""
    git pull
else
    LogMessage "Entering the ACARSDEC build directory"
    cd $RECEIVER_BUILD_DIRECTORY
    LogMessage "Cloning the ACARSDEC git repository locally"
    echo ""
    git clone https://github.com/TLeconte/acarsdec.git
fi
echo ""


## BUILD AND INSTALL THE ACARSDEC BINARY

LogHeading "Building the ACARSDEC binary"

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/acarsdec/build ]]; then
    LogMessage "Creating the ACARSDEC build directory"
    echo ""
        mkdir -vp $RECEIVER_BUILD_DIRECTORY/acarsdec/build
    echo ""
fi
if [[ -n "$(ls -A $RECEIVER_BUILD_DIRECTORY/acarsdec/build 2>/dev/null)" ]]
    LogMessage "Deleting all files currently residing in the ACARSDEC build directory"
    rm -rf $RECEIVER_BUILD_DIRECTORY/acarsdec/build/*
fi
LogMessage "Entering the ACARSDEC build directory"
cd $RECEIVER_BUILD_DIRECTORY/acarsdec/build
LogMessage "Executing cmake"
echo ""

# TODO: Choose the proper parameters depending on the chosen device

cmake .. -Drtl=ON or -Dairspy=ON or -Dsdrplay=ON
echo ""
LogMessage "Executing make"
echo ""
make
echo ""
LogMessage "Executing make install"
echo ""
sudo make install
echo ""

# TODO: Configure the application to run


## SETUP COMPLETE

LogMessage "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
LogTitleMessage "------------------------------------------------------------------------------"
LogTitleHeading "ACARSDEC decoder setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0
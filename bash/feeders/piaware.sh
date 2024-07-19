#!/bin/bash

# THE FLIGHTAWARE PIAWARE CLIENT SETUP SCRIPT

# TCLTLS-REBUILD
# -----------------------------------------------------------------------------------
# Along with PiAware, a version of tcltls maintained by FlightAware can be installed.
# This package is only needed for Debian Buster and possibly Ubuntu Focal Fossa. Once 
# these releases pass their end of life date the scripting will be removed.
#
# Debian Buster's end of life occured June 30, 2024 and is no longer supported.
# Ubuntu Focal Fossa's end of life is scheduled for April 2025.


## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
LogProjectName ${RECEIVER_PROJECT_TITLE}
LogTitleHeading "Setting up the FlightAware PiAware Client"
LogTitleMessage "------------------------------------------------------------------------------"
echo ""

if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "FlightAware PiAware client Setup" --yesno "The FlightAware PiAware client takes data from a local dump1090 instance and shares this with FlightAware using the piaware package, for more information please see their website:\n\n  https://www.flightaware.com/adsb/piaware/\n\nContinue setup by installing the FlightAware PiAware client?" 13 78 3>&1 1>&2 2>&3; then
    LogAlertHeading "INSTALLATION HALTED"
    LogAlertMessage "Setup has been halted at the request of the user"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "ADS-B Receiver Portal setup halted"
    echo ""
    exit 1
fi


## CHECK FOR PREREQUISITE PACKAGES

LogHeading "Installing packages needed to fulfill dependencies for FlightAware PiAware client"

CheckPackage build-essential
CheckPackage git
CheckPackage devscripts
CheckPackage debhelper
CheckPackage tcl8.6-dev
CheckPackage autoconf
CheckPackage python3-dev
CheckPackage python3-venv
CheckPackage python3-setuptools
CheckPackage zlib1g-dev
CheckPackage openssl
CheckPackage libboost-system-dev
CheckPackage libboost-program-options-dev
CheckPackage libboost-regex-dev
CheckPackage libboost-filesystem-dev
CheckPackage patchelf
CheckPackage python3-pip
CheckPackage python3-setuptools
CheckPackage python3-wheel
CheckPackage net-tools
CheckPackage tclx8.4
CheckPackage tcllib
CheckPackage itcl3
CheckPackage libssl-dev
CheckPackage tcl-dev
CheckPackage chrpath

if [[ "${RECEIVER_OS_CODE_NAME}" == "noble" ]]; then
    CheckPackage python3-pyasyncore
fi

if [[ "${RECEIVER_OS_CODE_NAME}" == "focal" ]]; then
    CheckPackage python3-dev
else
    CheckPackage tcl-tls
    CheckPackage python3-build
fi

echo ""


## CLONE OR PULL THE TCLTLS REBUILD GIT REPOSITORY

if [[ "${RECEIVER_OS_CODE_NAME}" == "focal" ]]; then

    LogHeading "Preparing the FlightAware tcltls-rebuild Git repository"

    if [[ -d $RECEIVER_BUILD_DIRECTORY/tcltls-rebuild && -d $RECEIVER_BUILD_DIRECTORY/tcltls-rebuild/.git ]]; then
        LogMessage "Entering the tcltls-rebuild git repository directory"
        cd $RECEIVER_BUILD_DIRECTORY/tcltls-rebuild
        LogMessage "Updating the local tcltls-rebuild git repository"
        echo ""
        git pull
    else
        LogMessage "Entering the ADS-B Receiver Project build directory"
        cd $RECEIVER_BUILD_DIRECTORY
        LogMessage "Cloning the tcltls-rebuild git repository locally"
        echo ""
        git clone https://github.com/flightaware/tcltls-rebuild
    fi
    echo ""


    ## BUILD AND INSTALL THE TCLTLS-REBUILD PACKAGE

    LogHeading "Beginning the FlightAware tcltls-rebuild installation process"

    LogMessage "Checking if the FlightAware tcltls-rebuild is required"

    LogMessage "Entering the tcltls-rebuild source directory"
    cd $RECEIVER_BUILD_DIRECTORY/tcltls-rebuild/tcltls-1.7.22
    LogMessage "Building the tcltls-rebuild package"
    echo ""
    dpkg-buildpackage -b
    echo ""
    LogMessage "Installing the tcltls-rebuild package"
    echo ""
    sudo dpkg -i $RECEIVER_BUILD_DIRECTORY/tcltls-rebuild/tcl-tls_1.7.22-2+fa1_*.deb
    echo ""

    LogMessage "Checking that the FlightAware tcltls-rebuild package was installed properly"
    if [[ $(dpkg-query -W -f='${STATUS}' tcltls 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
        echo ""
        LogAlertHeading "INSTALLATION HALTED"
        echo ""
        LogAlertMessage "FlightAware tcltls-rebuild package installation failed"
        LogAlertMessage "Setup has been terminated"
        echo ""
        LogTitleMessage "------------------------------------------------------------------------------"
        LogTitleHeading "FlightAware PiAware client setup failed"
        echo ""
        read -p "Press enter to continue..." discard
        exit 1
    else
        if [[ ! -d $RECEIVER_BUILD_DIRECTORY/package-archive ]]; then
            LogMessage "Creating the package archive directory"
            echo ""
            mkdir -vp $RECEIVER_BUILD_DIRECTORY/package-archive
            echo ""
        fi
        LogMessage "Copying the FlightAware tcltls-rebuild binary package into the archive directory"
        echo ""
        cp -vf $RECEIVER_BUILD_DIRECTORY/tcltls-rebuild/*.deb $RECEIVER_BUILD_DIRECTORY/package-archive/
        echo ""
    fi

fi


## CLONE OR PULL THE PIAWARE_BUILDER GIT REPOSITORY

LogHeading "Preparing the FlightAware piaware_builder Git repository"

if [[ -d $RECEIVER_BUILD_DIRECTORY/piaware_builder && -d $RECEIVER_BUILD_DIRECTORY/piaware_builder/.git ]]; then
    LogMessage "Entering the piaware_builder git repository directory"
    cd $RECEIVER_BUILD_DIRECTORY/piaware_builder
    LogMessage "Updating the local piaware_builder git repository"
    echo ""
    git pull
else
    LogMessage "Entering the ADS-B Receiver Project build directory"
    cd $RECEIVER_BUILD_DIRECTORY
    LogMessage "Cloning the piaware_builder git repository locally"
    echo ""
    git clone https://github.com/flightaware/piaware_builder.git
fi
echo ""


## BUILD AND INSTALL THE PIAWARE CLIENT PACKAGE

LogHeading "Beginning the FlightAware PiAware installation process"

LogMessage "Entering the piaware_builder git repository directory"
cd $RECEIVER_BUILD_DIRECTORY/piaware_builder

LogMessage "Determining which piaware_builder build strategy should be use"
distro="bookworm"
case $RECEIVER_OS_CODE_NAME in
    focal)
        distro="buster"
        ;;
    bullseye | jammy)
        distro="bullseye"
        ;;
    bookworm | noble)
        distro="bookworm"
        ;;
esac

LogMessage "Executing the FlightAware PiAware client build script"
echo ""
./sensible-build.sh $distro
echo ""
LogMessage "Entering the FlightAware PiAware client build directory"
cd $RECEIVER_BUILD_DIRECTORY/piaware_builder/package-${distro}
LogMessage "Building the FlightAware PiAware client package"
echo ""
dpkg-buildpackage -b
echo ""
LogMessage "Installing the FlightAware PiAware client package"
echo ""
sudo dpkg -i $RECEIVER_BUILD_DIRECTORY/piaware_builder/piaware_*.deb 2>&1
echo ""

LogMessage "Checking that the FlightAware PiAware client package was installed properly"
if [[ $(dpkg-query -W -f='${STATUS}' piaware 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
    echo ""
    LogAlertHeading "INSTALLATION HALTED"
    echo ""
    LogAlertMessage "FlightAware PiAware package installation failed"
    LogAlertMessage "Setup has been terminated"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "FlightAware PiAware client setup failed"
    echo ""
    read -p "Press enter to continue..." discard
    exit 1
else
    if [[ ! -d $RECEIVER_BUILD_DIRECTORY/package-archive ]]; then
        LogMessage "Creating the package archive directory"
        echo ""
        mkdir -vp $RECEIVER_BUILD_DIRECTORY/package-archive
        echo ""
    fi
    LogMessage "Copying the FlightAware PiAware client binary package into the archive directory"
    echo ""
    cp -vf $RECEIVER_BUILD_DIRECTORY/piaware_builder/*.deb $RECEIVER_BUILD_DIRECTORY/package-archive/
    echo ""
fi


## POST INSTALLATION OPERATIONS

LogHeading "Performing post installation operations"

LogMessage "Displaying the message informing the user on how to claim their device"
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Claiming Your PiAware Device" --msgbox "FlightAware requires you claim your feeder online using the following URL:\n\n  http://flightaware.com/adsb/piaware/claim\n\nTo claim your device simply visit the address listed above." 12 78


## SETUP COMPLETE

LogMessage "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
LogTitleMessage "------------------------------------------------------------------------------"
LogTitleHeading "FlightAware PiAware client setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0
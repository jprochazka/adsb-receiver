#!/bin/bash

#####################################################################################
#                                  ADS-B RECEIVER                                   #
#####################################################################################
#                                                                                   #
# This script is not meant to be executed directly.                                 #
# Instead execute install.sh to begin the installation process.                     #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                   #
# Copyright (c) 2015-2024, Joseph A. Prochazka                                      #
#                                                                                   #
# Permission is hereby granted, free of charge, to any person obtaining a copy      #
# of this software and associated documentation files (the "Software"), to deal     #
# in the Software without restriction, including without limitation the rights      #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell         #
# copies of the Software, and to permit persons to whom the Software is             #
# furnished to do so, subject to the following conditions:                          #
#                                                                                   #
# The above copyright notice and this permission notice shall be included in all    #
# copies or substantial portions of the Software.                                   #
#                                                                                   #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR        #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,          #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE       #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER            #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,     #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE     #
# SOFTWARE.                                                                         #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

### VARIABLES

RECEIVER_ROOT_DIRECTORY="${PWD}"
RECEIVER_BASH_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/bash"
RECEIVER_BUILD_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/build"

### INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

## SET INSTALLATION VARIABLES

# Source the automated install configuration file if this is an automated installation.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] && [[ -s "${RECEIVER_CONFIGURATION_FILE}" ]] ; then
    source ${RECEIVER_CONFIGURATION_FILE}
fi

### BEGIN SETUP

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    clear
    echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
fi
echo ""
echo -e "\e[92m  Setting up FlightAware PiAware client..."
echo ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo ""

# Check for existing component install.
if [[ $(dpkg-query -W -f='${STATUS}' piaware 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
    COMPONENT_FIRST_INSTALL="true"
fi

# Confirm component installation.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # Interactive install.
    CONTINUE_SETUP=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "FlightAware PiAware client Setup" --yesno "The FlightAware PiAware client takes data from a local dump1090 instance and shares this with FlightAware using the piaware package, for more information please see their website:\n\n  https://www.flightaware.com/adsb/piaware/\n\nContinue setup by installing the FlightAware PiAware client?" 13 78 3>&1 1>&2 2>&3)
    if [[ ${CONTINUE_SETUP} -eq 1 ]] ; then
        # Setup has been halted by the user.
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo ""
        echo -e "\e[93m  ------------------------------------------------------------------------------"
        echo -e "\e[92m  FlightAware PiAware client setup halted.\e[39m"
        echo ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
    fi
else
    # Warn that automated installation is not supported.
    echo -e "\e[92m  Automated installation of this script is not yet supported...\e[39m"
    echo ""
    exit 1
fi

### CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to fulfill dependencies for FlightAware PiAware client...\e[97m"
echo ""

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
CheckPackage python3-wheel
CheckPackage python3-build
CheckPackage python3-pip
CheckPackage net-tools
CheckPackage tclx8.4
CheckPackage tcllib
CheckPackage tcl-tls
CheckPackage itcl3

### STOP ANY RUNNING SERVICES

# Attempt to stop using systemd.
if [[ "`sudo systemctl status piaware 2>&1 | egrep -c "Active: active (running)"`" -gt 0 ]] ; then
    echo -e "\e[94m  Stopping the FlightAware PiAware client service...\e[97m"
    sudo systemctl stop piaware 2>&1
fi

### START INSTALLATION

echo ""
echo -e "\e[95m  Begining the FlightAware PiAware client installation process...\e[97m"
echo ""

if [[ -d ${RECEIVER_BUILD_DIRECTORY}/piaware_builder ]] && [[ -d ${RECEIVER_BUILD_DIRECTORY}/piaware_builder/.git ]] ; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the piaware_builder git repository directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/piaware_builder 2>&1
    echo -e "\e[94m  Updating the local piaware_builder git repository...\e[97m"
    echo ""
    git pull 2>&1
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY} 2>&1
    echo -e "\e[94m  Cloning the piaware_builder git repository locally...\e[97m"
    echo ""
    git clone https://github.com/flightaware/piaware_builder.git 2>&1
fi

## BUILD AND INSTALL THE COMPONENT PACKAGE

echo ""
echo -e "\e[95m  Building and installing the FlightAware PiAware client package...\e[97m"
echo ""

# Change to the component build directory.
if [[ ! ${PWD} = ${RECEIVER_BUILD_DIRECTORY}/piaware_builder ]] ; then
    echo -e "\e[94m  Entering the piaware_builder git repository directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/piaware_builder 2>&1
fi

# Execute build script.
DIST="bookworm"
case ${RECEIVER_OS_CODE_NAME} in
    stretch | xenial)
        $DIST="strech"
        ;;
    buster | bionic | focal)
        $DIST="buster"
        ;;
    bookworm | jammy | nobel)
        $DIST="bookworm"
        ;;
esac

echo -e "\e[94m  Executing the FlightAware PiAware client build script...\e[97m"
echo ""
./sensible-build.sh ${DIST}
echo ""

# Change to build script directory.
echo -e "\e[94m  Entering the FlightAware PiAware client build directory...\e[97m"
cd ${RECEIVER_BUILD_DIRECTORY}/piaware_builder/package-${DIST} 2>&1

# Build binary package.
echo -e "\e[94m  Building the FlightAware PiAware client package...\e[97m"
echo ""
dpkg-buildpackage -b 2>&1
echo ""

# Install binary package.
echo -e "\e[94m  Installing the FlightAware PiAware client package...\e[97m"
echo ""
sudo dpkg -i ${RECEIVER_BUILD_DIRECTORY}/piaware_builder/piaware_*.deb 2>&1
echo ""

# Check that the component package was installed successfully.
echo -e "\e[94m  Checking that the FlightAware PiAware client package was installed properly...\e[97m"

if [[ $(dpkg-query -W -f='${STATUS}' piaware 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
    # If the component package could not be installed halt setup.
    echo ""
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  UNABLE TO INSTALL A REQUIRED PACKAGE."
    echo -e "  SETUP HAS BEEN TERMINATED!"
    echo ""
    echo -e "\e[93mThe package \"piaware\" could not be installed.\e[39m"
    echo ""
    echo -e "\e[93m  ------------------------------------------------------------------------------"
    echo -e "\e[92m  FlightAware PiAware client setup halted.\e[39m"
    echo ""
    if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
        read -p "Press enter to continue..." CONTINUE
    fi
    exit 1
else
    # Create binary package archive directory.
    if [[ ! -d "${RECEIVER_BUILD_DIRECTORY}/package-archive" ]] ; then
        echo -e "\e[94m  Creating package archive directory...\e[97m"
        echo ""
        mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/package-archive 2>&1
        echo ""
    fi

    # Archive binary package.
    echo -e "\e[94m  Moving the FlightAware PiAware client binary package into the archive directory...\e[97m"
    echo ""
    cp -vf ${RECEIVER_BUILD_DIRECTORY}/piaware_builder/*.deb ${RECEIVER_BUILD_DIRECTORY}/package-archive/ 2>&1
    echo ""
fi

## COMPONENT POST INSTALL ACTIONS

# Instruct the user as to how they can claim their receiver online.
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Claiming Your PiAware Device" --msgbox "FlightAware requires you claim your feeder online using the following URL:\n\n  http://flightaware.com/adsb/piaware/claim\n\nTo claim your device simply visit the address listed above." 12 78

### SETUP COMPLETE

# Return to the project root directory.
echo -e "\e[94m  Returning to ${RECEIVER_PROJECT_TITLE} root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  FlightAware PiAware client setup is complete.\e[39m"
echo ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0


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
# Copyright (c) 2015-2017, Joseph A. Prochazka                                      #
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

# Component specific variables.
COMPONENT_NAME="FlightAware PiAware client"
COMPONENT_PROVIDER="FlightAware"
COMPONENT_PACKAGE_NAME="piaware"
COMPONENT_WEBSITE="https://www.flightaware.com/adsb/piaware/"
COMPONENT_GITHUB_URL="https://github.com/flightaware/piaware_builder.git"
COMPONENT_BUILD_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/piaware_builder"

# Component service script variables.
COMPONENT_SERVICE_NAME="piaware"

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
echo -e ""
echo -e "\e[92m  Setting up ${COMPONENT_NAME}..."
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""

# Check for existing component install.
if [[ $(dpkg-query -W -f='${STATUS}' ${COMPONENT_PACKAGE_NAME} 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
    COMPONENT_FIRST_INSTALL="true"
fi

# Confirm component installation.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # Interactive install.
    CONTINUE_SETUP=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${COMPONENT_NAME} Setup" --yesno "The ${COMPONENT_NAME} takes data from a local dump1090 instance and shares this with ${COMPONENT_PROVIDER} using the ${COMPONENT_PACKAGE_NAME} package, for more information please see their website:\n\n  ${COMPONENT_WEBSITE}\n\nContinue setup by installing the ${COMPONENT_NAME}?" 13 78 3>&1 1>&2 2>&3)
    if [[ ${CONTINUE_SETUP} -eq 1 ]] ; then
        # Setup has been halted by the user.
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo -e ""
        echo -e "\e[93m  ------------------------------------------------------------------------------"
        echo -e "\e[92m  ${COMPONENT_NAME} setup halted.\e[39m"
        echo -e ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
    fi
else
    # Warn that automated installation is not supported.
    echo -e "\e[92m  Automated installation of this script is not yet supported...\e[39m"
    echo -e ""
    exit 1
fi

### CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to fulfill dependencies for ${COMPONENT_NAME}...\e[97m"
echo -e ""

# Required by install script.
CheckPackage git
CheckPackage build-essential
# Required by component.
CheckPackage debhelper
CheckPackage tcl8.6-dev
CheckPackage autoconf
CheckPackage python3-dev
CheckPackage python3-venv
CheckPackage virtualenv
CheckPackage dh-systemd
CheckPackage zlib1g-dev
CheckPackage tclx8.4
CheckPackage tcllib
CheckPackage tcl-tls
CheckPackage itcl3

### STOP ANY RUNNING SERVICES

# Attempt to stop using systemd.
if [[ "`sudo systemctl status ${COMPONENT_SERVICE_NAME} 2>&1 | egrep -c "Active: active (running)"`" -gt 0 ]] ; then
    echo -e "\e[94m  Stopping the ${COMPONENT_NAME} service...\e[97m"
    sudo systemctl stop ${COMPONENT_SERVICE_NAME} 2>&1
fi

### START INSTALLATION

echo -e ""
echo -e "\e[95m  Begining the ${COMPONENT_NAME} installation process...\e[97m"
echo -e ""

if [[ -d "${COMPONENT_BUILD_DIRECTORY}" ]] && [[ -d "${COMPONENT_BUILD_DIRECTORY}/.git" ]] ; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the piaware_builder git repository directory...\e[97m"
    cd ${COMPONENT_BUILD_DIRECTORY} 2>&1
    echo -e "\e[94m  Updating the local piaware_builder git repository...\e[97m"
    echo -e ""
    git pull 2>&1
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY} 2>&1
    echo -e "\e[94m  Cloning the piaware_builder git repository locally...\e[97m"
    echo -e ""
    git clone ${COMPONENT_GITHUB_URL} 2>&1
fi

## BUILD AND INSTALL THE COMPONENT PACKAGE

echo -e ""
echo -e "\e[95m  Building and installing the ${COMPONENT_NAME} package...\e[97m"
echo -e ""

# Change to the component build directory.
if [[ ! "${PWD}" = "${COMPONENT_BUILD_DIRECTORY}" ]] ; then
    echo -e "\e[94m  Entering the piaware_builder git repository directory...\e[97m"
    cd ${COMPONENT_BUILD_DIRECTORY} 2>&1
fi

# Dummy test for consistency with other feeder install scripts.
if [[ -n "${CPU_ARCHITECTURE}" ]] ; then
    # Execute build script.
    echo -e "\e[94m  Executing the ${COMPONENT_NAME} build script...\e[97m"
    echo -e ""
    ./sensible-build.sh jessie
    echo -e ""

    # Change to build script directory.
    echo -e "\e[94m  Entering the ${COMPONENT_NAME} build directory...\e[97m"
    cd ${COMPONENT_BUILD_DIRECTORY}/package-jessie 2>&1
    echo -e ""

    # Build binary package.
    echo -e "\e[94m  Building the ${COMPONENT_NAME} package...\e[97m"
    echo -e ""
    dpkg-buildpackage -b 2>&1
    echo -e ""

    # Install binary package.
    echo -e "\e[94m  Installing the ${COMPONENT_NAME} package...\e[97m"
    echo -e ""
    sudo dpkg -i ${COMPONENT_BUILD_DIRECTORY}/${COMPONENT_PACKAGE_NAME}_*.deb 2>&1
    echo -e ""

    # Check that the component package was installed successfully.
    echo -e ""
    echo -e "\e[94m  Checking that the ${COMPONENT_NAME} package was installed properly...\e[97m"
    echo -e ""

    if [[ $(dpkg-query -W -f='${STATUS}' ${COMPONENT_PACKAGE_NAME} 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
        # If the component package could not be installed halt setup.
        echo -e ""
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  UNABLE TO INSTALL A REQUIRED PACKAGE."
        echo -e "  SETUP HAS BEEN TERMINATED!"
        echo -e ""
        echo -e "\e[93mThe package \"${COMPONENT_PACKAGE_NAME}\" could not be installed.\e[39m"
        echo -e ""
        echo -e "\e[93m  ------------------------------------------------------------------------------"
        echo -e "\e[92m  ${COMPONENT_NAME} setup halted.\e[39m"
        echo -e ""
        if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
            read -p "Press enter to continue..." CONTINUE
        fi
        exit 1
    else
        # Create binary package archive directory.
        if [[ ! -d "${RECEIVER_BUILD_DIRECTORY}/package-archive" ]] ; then
            echo -e "\e[94m  Creating package archive directory...\e[97m"
            echo -e ""
            mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/package-archive 2>&1
            echo -e ""
        fi

        # Archive binary package.
        echo -e "\e[94m  Moving the ${COMPONENT_NAME} binary package into the archive directory...\e[97m"
        echo -e ""
        mv -vf ${COMPONENT_BUILD_DIRECTORY}/${COMPONENT_PACKAGE_NAME}_*.deb ${RECEIVER_BUILD_DIRECTORY}/package-archive 2>&1
        echo -e ""

        # Archive changelog.
        echo -e "\e[94m  Moving the ${COMPONENT_NAME} changes file into the archive directory...\e[97m"
        echo -e ""
        mv -vf ${COMPONENT_BUILD_DIRECTORY}/${COMPONENT_PACKAGE_NAME}_*.changes ${RECEIVER_BUILD_DIRECTORY}/package-archive 2>&1
        echo -e ""
    fi
fi

## COMPONENT POST INSTALL ACTIONS

# Confirm if the user is able to claim their PiAware instance online.
FLIGHTAWARE_LOCAL_CREDENTIALS=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Claim Your PiAware Device" --yesno "Although it is possible to configure your FlightAware credentials locally, these will be stored in plaintext which represents a security risk that should be avoided.\n\nFlightAware recommends claiming your feeder online using the following page:\n\n  http://flightaware.com/adsb/piaware/claim\n\nWill you be able to access the FlightAware website from the same public IP address as the feeder will be sending data from?" 16 78 3>&1 1>&2 2>&3)

if [[ "${FLIGHTAWARE_LOCAL_CREDENTIALS}" -eq "1" ]] ; then
    # Ask for the users FlightAware login.
    FLIGHTAWARE_LOGIN=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Your FlightAware Login" --nocancel --inputbox "\nEnter your FlightAware login.\nLeave this blank to manually claim your PiAware device." 9 78 3>&1 1>&2 2>&3)
    if [[ ! "${FLIGHTAWARE_LOGIN}" = "" ]] ; then
        # If the user supplied their FlightAware login continue with the device claiming process.
        FLIGHTAWARE_PASSWORD1_TITLE="Your FlightAware Password"
        while [[ -z "${FLIGHTAWARE_PASSWORD1}" ]] ; do
            FLIGHTAWARE_PASSWORD1=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${FLIGHTAWARE_PASSWORD1_TITLE}" --nocancel --passwordbox "\nEnter your FlightAware password." 8 78 3>&1 1>&2 2>&3)
        done
        FLIGHTAWARE_PASSWORD2_TITLE="Confirm Your FlightAware Password"
        while [[ -z "${FLIGHTAWARE_PASSWORD2}" ]] ; do
            FLIGHTAWARE_PASSWORD2=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${FLIGHTAWARE_PASSWORD2_TITLE}" --nocancel --passwordbox "\nConfirm your FlightAware password." 8 78 3>&1 1>&2 2>&3)
        done
        while [[ ! "${FLIGHTAWARE_PASSWORD1}" = "${FLIGHTAWARE_PASSWORD2}" ]] ; do
            FLIGHTAWARE_PASSWORD1=""
            FLIGHTAWARE_PASSWORD2=""
            # Display an error message if the passwords did not match.
            whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Claim Your PiAware Device" --msgbox "Passwords did not match.\nPlease enter your password again." 9 78
            FLIGHTAWARE_PASSWORD1_TITLE="Your FlightAware Password (REQUIRED)"
            while [[ -z "${FLIGHTAWARE_PASSWORD1}" ]] ; do
                FLIGHTAWARE_PASSWORD1=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${FLIGHTAWARE_PASSWORD1_TITLE}" --nocancel --passwordbox "\nEnter your FlightAware password." 8 78 3>&1 1>&2 2>&3)
            done
            FLIGHTAWARE_PASSWORD2_TITLE="Confirm Your FlightAware Password (REQUIRED)"
            while [[ -z "${FLIGHTAWARE_PASSWORD2}" ]] ; do
                FLIGHTAWARE_PASSWORD2=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${FLIGHTAWARE_PASSWORD2_TITLE}" --nocancel --passwordbox "\nConfirm your FlightAware password." 8 78 3>&1 1>&2 2>&3)
            done
        done
    else
        # Display a message to the user stating they need to manually claim their device.
        whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Claim Your PiAware Device" --msgbox "Please supply your ${COMPONENT_PROVIDER} login in order to claim this device, after supplying this you will ask you to enter your password for verification.\n\nIf you decide not to provide a login and password at this time you should still be able to claim your feeder by visting the following site:\n\n  http://flightaware.com/adsb/piaware/claim" 13 78
    fi
fi

# Dummy test for consistency with other feeder install scripts.
if [[ -n "${CPU_ARCHITECTURE}" ]] ; then
    if [[ -n "${FLIGHTAWARE_LOGIN}" ]] && [[ -n "${FLIGHTAWARE_PASSWORD1}" ]] ; then
        # Set the supplied user name in the configuration.
        echo -e "\e[94m  Setting the flightaware-user setting using piaware-config...\e[97m"
        echo -e ""
        sudo piaware-config flightaware-user ${FLIGHTAWARE_LOGIN}
        echo -e ""

        # Set the supplied password in the configuration.
        echo -e "\e[94m  Setting the flightaware-password setting using piaware-config...\e[97m"
        echo -e ""
        sudo piaware-config flightaware-password ${FLIGHTAWARE_PASSWORD1}
        echo -e ""

        # (re)start the component service.
        if [[ "`sudo systemctl status ${COMPONENT_SERVICE_NAME} 2>&1 | egrep -c "Active: active (running)"`" -gt 0 ]] ; then
            echo -e "\e[94m  Restarting the ${COMPONENT_NAME} service...\e[97m"
            sudo systemctl restart ${COMPONENT_SERVICE_NAME} 2>&1
        else
            echo -e "\e[94m  Starting the ${COMPONENT_NAME} service...\e[97m"
            sudo systemctl start ${COMPONENT_SERVICE_NAME} 2>&1
        fi
        echo -e ""
    fi
fi

### SETUP COMPLETE

# Return to the project root directory.
echo -e "\e[94m  Returning to ${RECEIVER_PROJECT_TITLE} root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  ${COMPONENT_NAME} setup is complete.\e[39m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

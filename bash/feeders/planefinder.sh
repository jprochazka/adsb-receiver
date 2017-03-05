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
COMPONENT_NAME="PlaneFinder ADS-B Client"
COMPONENT_PROVIDER="PlaneFinder"
COMPONENT_PACKAGE_NAME="pfclient"
COMPONENT_WEBSITE="https://planefinder.net/sharing/client"
COMPONENT_GITHUB_URL=""
COMPONENT_BUILD_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/planefinder"
RECEIVER_IP_ADDRESS=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`

# Component service script variables.

### INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

# Source the automated install configuration file if this is an automated installation.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
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

# Confirm component installation.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # Interactive install.
    CONTINUE_SETUP=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${COMPONENT_NAME} Setup" --yesno "The ${COMPONENT_NAME} is an easy and accurate way to share your ADS-B and MLAT data with Plane Finder. It comes with a beautiful user interface that helps you explore and interact with your data in realtime.\n\n  https://planefinder.net/sharing/client\n\nContinue setup by installing ${COMPONENT_NAME}?" 13 78 3>&1 1>&2 2>&3)
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
    echo -e "\e[92m  Automated installation of ${COMPONENT_NAME} not yet supported...\e[39m"
    echo -e ""
    exit 1
fi

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo -e ""
if [[ "${CPU_ARCHITECTURE}" = "x86_64" ]] ; then
    if [[ $(dpkg --print-foreign-architectures $1 2>/dev/null | grep -c "i386") -eq 0 ]] ; then
        echo -e "\e[94m  Adding the i386 architecture...\e[97m"
        sudo dpkg --add-architecture i386 2>&1
        echo -e "\e[94m  Downloading latest package lists for enabled repositories and PPAs...\e[97m"
        echo -e ""
        sudo apt-get update
        echo -e ""
    fi
    CheckPackage libc6:i386
else
    CheckPackage libc6
fi
CheckPackage wget

### STOP ANY RUNNING SERVICES

### START INSTALLATION

echo -e ""
echo -e "\e[95m  Begining the installation process...\e[97m"
echo -e ""

# Create the component build directory if it does not exist.
if [[ ! -d "${COMPONENT_BUILD_DIRECTORY}" ]] ; then
    echo -e "\e[94m  Creating ${COMPONENT_NAME} build directory...\e[97m"
    mkdir -vp ${COMPONENT_BUILD_DIRECTORY}
fi

# Change to the comonent build directory.
if [[ ! "${PWD}" = "${COMPONENT_BUILD_DIRECTORY}" ]] ; then
    echo -e "\e[94m  Entering ${COMPONENT_NAME} build directory...\e[97m"
    cd ${COMPONENT_BUILD_DIRECTORY} 2>&1
fi

# Download the appropriate package depending on the devices architecture.
if [[ "${CPU_ARCHITECTURE}" = "armv7l" ]] || [[ "${CPU_ARCHITECTURE}" = "armv6l" ]] ; then
    # ARM achitecture detected.
    echo -e "\e[94m  Downloading ${COMPONENT_NAME} v${PLANEFINDER_CLIENT_VERSION_ARM} for ARM devices...\e[97m"
    echo -e ""
    wget --no-check-certificate https://client.planefinder.net/${COMPONENT_PACKAGE_NAME}_${PLANEFINDER_CLIENT_VERSION_ARM}_armhf.deb -O ${COMPONENT_BUILD_DIRECTORY}/${COMPONENT_PACKAGE_NAME}_${PLANEFINDER_CLIENT_VERSION_ARM}_armhf.deb
else
    # Otherwise assume i386.
    echo -e "\e[94m  Downloading ${COMPONENT_NAME} v${PLANEFINDER_CLIENT_VERSION_I386} for i386 devices...\e[97m"
    echo -e ""
    wget --no-check-certificate https://client.planefinder.net/${COMPONENT_PACKAGE_NAME}_${PLANEFINDER_CLIENT_VERSION_I386}_i386.deb -O ${COMPONENT_BUILD_DIRECTORY}/${COMPONENT_PACKAGE_NAME}_${PLANEFINDER_CLIENT_VERSION_I386}_i386.deb
fi

## INSTALL THE COMPONENT PACKAGE

echo -e ""
echo -e "\e[95m  Installing ${COMPONENT_NAME} package...\e[97m"
echo -e ""

# Install the proper package depending on the devices architecture.
if [[ "${CPU_ARCHITECTURE}" = "armv7l" ]] || [[ "${CPU_ARCHITECTURE}" = "armv6l" ]] || [[ "${CPU_ARCHITECTURE}" = "aarch64" ]] ; then
    # ARM achitecture detected.
    echo -e "\e[94m  Installing ${COMPONENT_NAME} v${PLANEFINDER_CLIENT_VERSION_ARM} package for ARM devices...\e[97m"
    echo -e ""
    sudo dpkg -i ${COMPONENT_BUILD_DIRECTORY}/${COMPONENT_PACKAGE_NAME}_${PLANEFINDER_CLIENT_VERSION_ARM}_armhf.deb 2>&1
else
    # Otherwise assume i386.
    echo -e "\e[94m  Installing ${COMPONENT_NAME} v${PLANEFINDER_CLIENT_VERSION_I386} package for i386 devices...\e[97m"
    if [[ `lsb_release -si` = "Debian" ]] ; then
        # Force architecture if this is Debian.
        echo -e "\e[94m  NOTE: dpkg executed with added flag --force-architecture.\e[97m"
        echo -e ""
        sudo dpkg -i --force-architecture ${COMPONENT_BUILD_DIRECTORY}/${COMPONENT_PACKAGE_NAME}_${PLANEFINDER_CLIENT_VERSION_I386}_i386.deb 2>&1
    else
        echo -e ""
        sudo dpkg -i ${COMPONENT_BUILD_DIRECTORY}/${COMPONENT_PACKAGE_NAME}_${PLANEFINDER_CLIENT_VERSION_I386}_i386.deb 2>&1
    fi
fi

# Dummy test for consistency with other feeder install scripts.
if [[ -n "${CPU_ARCHITECTURE}" ]] ; then
    # Check that the component package was installed successfully.
    echo -e ""
    echo -e "\e[94m  Checking that the ${COMPONENT_PACKAGE_NAME} package was installed properly...\e[97m"
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
        echo -e "\e[94m  Moving ${COMPONENT_NAME} binary package into the archive directory...\e[97m"
        echo -e ""
        mv -vf ${COMPONENT_BUILD_DIRECTORY}/${COMPONENT_PACKAGE_NAME}_*.deb ${RECEIVER_BUILD_DIRECTORY}/package-archive 2>&1
        echo -e ""
    fi
fi

## DISPLAY FINAL SETUP INSTRUCTIONS WHICH CONNOT BE HANDLED BY THIS SCRIPT

whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${COMPONENT_NAME} Setup Instructions" --msgbox "At this point ${COMPONENT_NAME} should be installed and running howeverThis script is only capable of installing ${COMPONENT_NAME}. There are stilla few steps left which you must manually do through ${COMPONENT_NAME} at the following URL:\n\n  http://${RECEIVER_IP_ADDRESS}:30053\n\nThe follow the instructions supplied by ${COMPONENT_NAME}.\n\nUse the following settings when asked for them.\n\nData Format: Beast\nTcp Address: 127.0.0.1\nTcp Port: 30005" 20 78

### SETUP COMPLETE

# Return to the project root directory.
echo -e "\e[94m  Entering the ${RECEIVER_PROJECT_TITLE} root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  ${COMPONENT_NAME} setup is complete.\e[39m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

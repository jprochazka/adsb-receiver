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
echo -e "\e[92m  Setting up PlaneFinder ADS-B Client..."
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""

# Check for existing component install.
if [[ $(dpkg-query -W -f='${STATUS}' pfclient 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
    COMPONENT_FIRST_INSTALL="true"
fi

# Confirm component installation.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # Interactive install.
    CONTINUE_SETUP=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "PlaneFinder ADS-B Client Setup" --yesno "The PlaneFinder ADS-B Client is an easy and accurate way to share your ADS-B and MLAT data with Plane Finder. It comes with a beautiful user interface that helps you explore and interact with your data in realtime.\n\n  https://planefinder.net/sharing/client\n\nContinue setup by installing PlaneFinder ADS-B Client?" 13 78 3>&1 1>&2 2>&3)
    if [[ ${CONTINUE_SETUP} -eq 1 ]] ; then
        # Setup has been halted by the user.
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo -e ""
        echo -e "\e[93m  ------------------------------------------------------------------------------"
        echo -e "\e[92m  PlaneFinder ADS-B Client setup halted.\e[39m"
        echo -e ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
    fi
else
    # Warn that automated installation is not supported.
    echo -e "\e[92m  Automated installation of PlaneFinder ADS-B Client is not yet supported...\e[39m"
    echo -e ""
    exit 1
fi

### CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to fulfill dependencies for PlaneFinder ADS-B Client...\e[97m"
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
echo -e "\e[95m  Begining the PlaneFinder ADS-B Client installation process...\e[97m"
echo -e ""

# Create the component build directory if it does not exist.
if [[ ! -d ${RECEIVER_BUILD_DIRECTORY}/planefinder ]] ; then
    echo -e "\e[94m  Creating the PlaneFinder ADS-B Client build directory...\e[97m"
    echo ""
    mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/planefinder
fi

# Change to the component build directory.
if [[ ! ${PWD} = ${RECEIVER_BUILD_DIRECTORY}/planefinder ]] ; then
    echo -e "\e[94m  Entering the PlaneFinder ADS-B Client build directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/planefinder 2>&1
fi

## BUILD AND INSTALL THE COMPONENT PACKAGE

echo -e ""
echo -e "\e[95m  Building and installing the PlaneFinder ADS-B Client package...\e[97m"
echo -e ""

## DOWNLOAD OR UPDATE THE COMPONENT SOURCE

# Download the appropriate package depending on the devices architecture.
if [[ "${CPU_ARCHITECTURE}" = "armv7l" ]] || [[ "${CPU_ARCHITECTURE}" = "armv6l" ]] ; then
    # ARM achitecture detected.
    echo -e "\e[94m  Downloading the PlaneFinder ADS-B Client v${PLANEFINDER_CLIENT_VERSION_ARM} package for ARM devices...\e[97m"
    echo -e ""
    wget --no-check-certificate https://client.planefinder.net/pfclient_${PLANEFINDER_CLIENT_VERSION_ARM}_armhf.deb -O ${RECEIVER_BUILD_DIRECTORY}/planefinder/pfclient_${PLANEFINDER_CLIENT_VERSION_ARM}_armhf.deb
else
    # Otherwise assume i386.
    echo -e "\e[94m  Downloading the PlaneFinder ADS-B Client v${PLANEFINDER_CLIENT_VERSION_I386} package for i386 devices...\e[97m"
    echo -e ""
    wget --no-check-certificate https://client.planefinder.net/pfclient_${PLANEFINDER_CLIENT_VERSION_I386}_i386.deb -O ${RECEIVER_BUILD_DIRECTORY}/planefinder/pfclient_${PLANEFINDER_CLIENT_VERSION_I386}_i386.deb
fi

## INSTALL THE COMPONENT PACKAGE

# Install the proper package depending on the devices architecture.
if [[ "${CPU_ARCHITECTURE}" = "armv7l" ]] || [[ "${CPU_ARCHITECTURE}" = "armv6l" ]] || [[ "${CPU_ARCHITECTURE}" = "aarch64" ]] ; then
    # ARM achitecture detected.
    echo -e "\e[94m  Installing the PlaneFinder ADS-B Client v${PLANEFINDER_CLIENT_VERSION_ARM} package for ARM devices...\e[97m"
    echo -e ""
    sudo dpkg -i ${RECEIVER_BUILD_DIRECTORY}/planefinder/pfclient_${PLANEFINDER_CLIENT_VERSION_ARM}_armhf.deb 2>&1
else
    # Otherwise assume i386.
    echo -e "\e[94m  Installing the PlaneFinder ADS-B Client v${PLANEFINDER_CLIENT_VERSION_I386} package for i386 devices...\e[97m"
    if [[ `lsb_release -si` = "Debian" ]] ; then
        # Force architecture if this is Debian.
        echo -e "\e[94m  NOTE: dpkg executed with added flag --force-architecture.\e[97m"
        echo -e ""
        sudo dpkg -i --force-architecture ${RECEIVER_BUILD_DIRECTORY}/planefinder/pfclient_${PLANEFINDER_CLIENT_VERSION_I386}_i386.deb 2>&1
    else
        echo -e ""
        sudo dpkg -i ${RECEIVER_BUILD_DIRECTORY}/planefinder/pfclient_${PLANEFINDER_CLIENT_VERSION_I386}_i386.deb 2>&1
    fi
fi

# Dummy test for consistency with other feeder install scripts.
if [[ -n "${CPU_ARCHITECTURE}" ]] ; then
    # Check that the component package was installed successfully.
    echo -e ""
    echo -e "\e[94m  Checking that the PlaneFinder ADS-B Client package was installed properly...\e[97m"

    if [[ $(dpkg-query -W -f='${STATUS}' pfclient 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
        # If the component package could not be installed halt setup.
        echo -e ""
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  UNABLE TO INSTALL A REQUIRED PACKAGE."
        echo -e "  SETUP HAS BEEN TERMINATED!"
        echo -e ""
        echo -e "\e[93mThe package \"pfclient\" could not be installed.\e[39m"
        echo -e ""
        echo -e "\e[93m  ------------------------------------------------------------------------------"
        echo -e "\e[92m  PlaneFinder ADS-B Client setup halted.\e[39m"
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
        echo -e "\e[94m  Moving the PlaneFinder ADS-B Client binary package into the archive directory...\e[97m"
        echo -e ""
        mv -vf ${RECEIVER_BUILD_DIRECTORY}/planefinder/pfclient_*.deb ${RECEIVER_BUILD_DIRECTORY}/package-archive 2>&1
        echo -e ""
    fi
fi

## COMPONENT POST INSTALL ACTIONS

# Display final setup instructions which cannot be handled by this script.
RECEIVER_IP_ADDRESS=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "PlaneFinder ADS-B Client Setup Instructions" --msgbox "At this point the PlaneFinder ADS-B Client should be installed and running; however this script is only capable of installing the PlaneFinder ADS-B Client. There are still a few steps left which you must manually do through the PlaneFinder ADS-B Client at the following URL:\n\n  http://${RECEIVER_IP_ADDRESS}:30053\n\nThe follow the instructions supplied by the PlaneFinder ADS-B Client.\n\nUse the following settings when asked for them.\n\nData Format: Beast\nTcp Address: 127.0.0.1\nTcp Port: 30005" 20 78

### SETUP COMPLETE

# Return to the project root directory.
echo -e "\e[94m  Returning to ${RECEIVER_PROJECT_TITLE} root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  PlaneFinder ADS-B Client setup is complete.\e[39m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

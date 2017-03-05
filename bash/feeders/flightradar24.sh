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
COMPONENT_NAME="FlightRadar24 feeder client"
COMPONENT_PROVIDER="FlightRadar24"
COMPONENT_PACKAGE_NAME="fr24feed"
COMPONENT_WEBSITE="https://www.flightradar24.com/share-your-data"
COMPONENT_GITHUB_URL=""
COMPONENT_BUILD_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/flightradar24"

# Component service script variables.
COMPONENT_SERVICE_NAME="fr24feed"

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
if [[ $(dpkg-query -W -f='${STATUS}' fr24feed 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
    COMPONENT_FIRST_INSTALL="true"
fi

# Confirm component installation.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # Interactive install.
    CONTINUE_SETUP=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${COMPONENT_NAME} setup" --yesno "The ${COMPONENT_NAME} takes data from a local dump1090 instance and will automatically share this with Flightradar24, you can track flights locally on your device or via their website:\n\n  http://www.flightradar24.com/share-your-data\n\nContinue setup by installing the ${COMPONENT_NAME}?" 13 78 3>&1 1>&2 2>&3)
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
    CheckPackage libudev1:i386
    CheckPackage zlib1g:i386
    CheckPackage libusb-1.0-0:i386
    CheckPackage libstdc++6:i386
else
    CheckPackage libc6
    CheckPackage libudev1
    CheckPackage zlib1g
    CheckPackage libusb-1.0-0
    CheckPackage libstdc++6
fi
CheckPackage wget

### STOP ANY RUNNING SERVICES

# Attempt to stop using systemd.
if [[ "`sudo systemctl status fr24feed 2>&1 | egrep -c "Active: active (running)"`" -gt 0 ]] ; then
    echo -e "\e[94m  Stopping the ${COMPONENT_NAME} service...\e[97m"
    sudo systemctl stop fr24feed 2>&1
fi

### START INSTALLATION

echo -e ""
echo -e "\e[95m  Begining the installation process...\e[97m"
echo -e ""

# Create the component build directory if it does not exist.
if [[ ! -d "${COMPONENT_BUILD_DIRECTORY}" ]] ; then
    echo -e "\e[94m  Creating the ${COMPONENT_NAME} build directory...\e[97m"
    mkdir -vp ${COMPONENT_BUILD_DIRECTORY}
fi

# Change to the comonent build directory.
if [[ ! "${PWD}" = "${COMPONENT_BUILD_DIRECTORY}" ]] ; then
    echo -e "\e[94m  Entering the ${COMPONENT_NAME} build directory...\e[97m"
    cd ${COMPONENT_BUILD_DIRECTORY} 2>&1
fi

# Download the appropriate package depending on the devices architecture.
if [[ "${CPU_ARCHITECTURE}" = "armv7l" ]] || [[ "${CPU_ARCHITECTURE}" = "armv6l" ]] || [[ "${CPU_ARCHITECTURE}" = "aarch64" ]] ; then
    # ARM achitecture detected.
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${COMPONENT_NAME} setup instructions" --msgbox "This script will now download and execute the official ${COMPONENT_NAME} setup script, please follow the instructions provided and supply the required information when ask for by the script.\n\nOnce finished the ADS-B Receiver Project scripts will continue." 11 78

    echo -e "\e[94m  Downloading the ${COMPONENT_NAME} installation script for ARM...\e[97m"
    echo -e ""
    wget --no-check-certificate https://repo.feed.flightradar24.com/install_fr24_rpi.sh -O ${COMPONENT_BUILD_DIRECTORY}/install_fr24_rpi.sh
else
    # Otherwise assume i386.
    echo -e "\e[94m  Downloading the ${COMPONENT_NAME} v${FLIGHTRADAR24_CLIENT_VERSION_I386} package for i386 devices...\e[97m"
    echo -e ""
    wget --no-check-certificate https://feed.flightradar24.com/linux/fr24feed_${FLIGHTRADAR24_CLIENT_VERSION_I386}_i386.deb -O ${COMPONENT_BUILD_DIRECTORY}/fr24feed_${FLIGHTRADAR24_CLIENT_VERSION_I386}_i386.deb
fi

## INSTALL THE COMPONENT PACKAGE

echo -e "\e[95m  Installing the ${COMPONENT_NAME} package...\e[97m"
echo -e ""

# Install the proper package depending on the devices architecture.
if [[ "${CPU_ARCHITECTURE}" = "armv7l" ]] || [[ "${CPU_ARCHITECTURE}" = "armv6l" ]] || [[ "${CPU_ARCHITECTURE}" = "aarch64" ]] ; then
    # ARM achitecture detected.
    echo -e "\e[94m  Executing the ${COMPONENT_NAME} installation script...\e[97m"
    echo -e ""
    sudo bash ${COMPONENT_BUILD_DIRECTORY}/install_fr24_rpi.sh
else
    # Otherwise assume i386.
    echo -e "\e[94m  Installing the ${COMPONENT_NAME} v${FLIGHTRADAR24_CLIENT_VERSION_I386} package for i386 devices...\e[97m"
    if [[ `lsb_release -si` = "Debian" ]] ; then
        # Force architecture if this is Debian.
        echo -e "\e[94m  NOTE: dpkg executed with added flag --force-architecture.\e[97m"
        echo -e ""
        sudo dpkg -i --force-architecture ${COMPONENT_BUILD_DIRECTORY}/fr24feed_${FLIGHTRADAR24_CLIENT_VERSION_I386}_i386.deb 2>&1
    else
        echo -e ""
        sudo dpkg -i ${COMPONENT_BUILD_DIRECTORY}/fr24feed_${FLIGHTRADAR24_CLIENT_VERSION_I386}_i386.deb 2>&1
    fi
fi

# Dummy test for consistency with other feeder install scripts.
if [[ -n "${CPU_ARCHITECTURE}" ]] ; then
    # Check that the component package was installed successfully.
    echo -e ""
    echo -e "\e[94m  Checking that the fr24feed package was installed properly...\e[97m"
    echo -e ""

    if [[ $(dpkg-query -W -f='${STATUS}' fr24feed 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
        # If the component package could not be installed halt setup.
        echo -e ""
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  UNABLE TO INSTALL A REQUIRED PACKAGE."
        echo -e "  SETUP HAS BEEN TERMINATED!"
        echo -e ""
        echo -e "\e[93mThe package \"fr24feed\" could not be installed.\e[39m"
        echo -e ""
        echo -e "\e[93m  ------------------------------------------------------------------------------"
        echo -e "\e[92m  ${COMPONENT_NAME} setup halted.\e[39m"
        echo -e ""
        if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
            read -p "Press enter to continue..." CONTINUE
        fi
        exit 1
    elif [[ ! "${CPU_ARCHITECTURE}" = "armv7l" ]] && [[ ! "${CPU_ARCHITECTURE}" = "armv6l" ]] && [[ ! "${CPU_ARCHITECTURE}" = "aarch64" ]] ; then
        # Create binary package archive directory.
        if [[ ! -d "${RECEIVER_BUILD_DIRECTORY}/package-archive" ]] ; then
            echo -e "\e[94m  Creating package archive directory...\e[97m"
            echo -e ""
            mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/package-archive 2>&1
            echo -e ""
        fi

        # Archive binary package.
        echo -e "\e[94m  Archiving the fr24feed package...\e[97m"
        echo -e ""
        mv -vf ${COMPONENT_BUILD_DIRECTORY}/fr24feed_*.deb ${RECEIVER_BUILD_DIRECTORY}/package-archive 2>&1
        echo -e ""

        # Check for component first install
        if [[ "${COMPONENT_FIRST_INSTALL}" = "true" ]] ; then
            # Run signup script if first install.
            echo -e "\e[94m  Starting fr24feed signup wizard...\e[97m"
            echo -e ""
            fr24feed --signup
            echo -e ""
        fi

        # Update config file permissions
        echo -e "\e[94m  Updating configuration file permissions...\e[97m"
        echo -e ""
        sudo chmod a+rw /etc/fr24feed.ini 2>&1
        echo -e ""

        # (re)start the component service.
        if [[ "`sudo systemctl status fr24feed 2>&1 | egrep -c "Active: active (running)"`" -gt 0 ]] ; then
            echo -e "\e[94m  Restarting the fr24feed service...\e[97m"
            sudo systemctl restart fr24feed 2>&1
        else
            echo -e "\e[94m  Starting the fr24feed service...\e[97m"
            sudo systemctl start fr24feed 2>&1
        fi
        echo -e ""
    fi
fi

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

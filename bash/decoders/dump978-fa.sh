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
# Copyright (c) 2015-2024 Joseph A. Prochazka                                       #
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

### INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

### BEGIN SETUP

clear
echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
echo ""
echo -e "\e[92m  Setting up dump978-fa..."
echo ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo ""
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump978-fa Setup" --yesno "This is the FlightAware 978MHz UAT decoder. It is a reimplementation in C++, loosely based on the demodulator from https://github.com/mutability/dump978.\n\n  https://github.com/flightaware/dump978\n\nContinue setup by installing dump978-fa?" 14 78
if [[ $? -eq 1 ]] ; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo ""
    echo -e "\e[93m  ------------------------------------------------------------------------------"
    echo -e "\e[92m  Dump978-fa setup halted.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo ""
CheckPackage build-essential
CheckPackage debhelper
CheckPackage libboost-system-dev
CheckPackage libboost-program-options-dev
CheckPackage libboost-regex-dev
CheckPackage libboost-filesystem-dev
CheckPackage libsoapysdr-dev
CheckPackage soapysdr-module-rtlsdr
echo ""

## BLACKLIST UNWANTED RTL-SDR MODULES

BlacklistModules

## DOWNLOAD OR UPDATE THE DUMP978-FA SOURCE

echo -e "\e[95m  Preparing the dump978-fa Git repository...\e[97m"
echo ""
if [[ -d "${RECEIVER_BUILD_DIRECTORY}/dump978-fa/dump978" ]] && [[ -d "${RECEIVER_BUILD_DIRECTORY}/dump978-fa/dump978/.git" ]] ; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the dump978-fa git repository directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/dump978-fa/dump978 2>&1
    echo -e "\e[94m  Updating the local dump978-fa git repository...\e[97m"
    echo ""
    git pull
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Creating the ADS-B Receiver Project build directory...\e[97m"
    echo ""
    mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/dump978-fa
    echo ""
    echo -e "\e[94m  Entering the dump978-fa build directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/dump978-fa 2>&1
    echo -e "\e[94m  Cloning the dump978-fa git repository locally...\e[97m"
    echo ""
    git clone https://github.com/flightaware/dump978.git
fi
echo ""

## BUILD AND INSTALL THE DUMP978-FA PACKAGE

echo -e "\e[95m  Building and installing the dump978-fa package...\e[97m"
echo ""
echo -e "\e[94m  Entering the dump978-fa git repository directory...\e[97m"
cd ${RECEIVER_BUILD_DIRECTORY}/dump978-fa/dump978 2>&1
echo -e "\e[94m  Building the dump978-fa package...\e[97m"
echo ""
dpkg-buildpackage -b
echo ""
echo -e "\e[94m  Entering the dump978-fa build directory...\e[97m"
cd ${RECEIVER_BUILD_DIRECTORY}/dump978-fa 2>&1
echo -e "\e[94m  Installing the dump978-fa package...\e[97m"
echo ""
sudo dpkg -i ${RECEIVER_BUILD_DIRECTORY}/dump978-fa/dump978-fa_${DUMP978_FA_VERSION}_*.deb
echo ""
echo -e "\e[94m  Installing the skyaware978 package...\e[97m"
echo ""
sudo dpkg -i ${RECEIVER_BUILD_DIRECTORY}/dump978-fa/skyaware978_${DUMP978_FA_VERSION}_*.deb

# Check that the package was installed.
echo ""
echo -e "\e[94m  Checking that the dump978-fa package was installed properly...\e[97m"
if [[ $(dpkg-query -W -f='${STATUS}' dump978-fa 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
    # If the dump978-fa package could not be installed halt setup.
    echo ""
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  UNABLE TO INSTALL A REQUIRED PACKAGE."
    echo -e "  SETUP HAS BEEN TERMINATED!"
    echo ""
    echo -e "\e[93mThe package \"dump978-fa\" could not be installed.\e[39m"
    echo ""
    echo -e "\e[93m  ------------------------------------------------------------------------------"
    echo -e "\e[92m  Dump978-fa setup halted.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

# Create binary package archive directory.
if [[ ! -d "${RECEIVER_BUILD_DIRECTORY}/package-archive" ]] ; then
    echo -e "\e[94m  Creating package archive directory...\e[97m"
    echo -e ""
    mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/package-archive 2>&1
    echo -e ""
fi

# Archive binary package.
echo -e "\e[94m  Moving the dump978-fa binary package into the archive directory...\e[97m"
echo ""
cp -vf ${RECEIVER_BUILD_DIRECTORY}/dump978-fa/*.deb ${RECEIVER_BUILD_DIRECTORY}/package-archive/ 2>&1
echo ""

### CONFIGURATION

# Check if the dump1090-fa package is installed.
echo -e "\e[94m  Checking if the dump1090-fa package is installed...\e[97m"
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
    # Check if dump978-fa has already been configured.
    echo -e "\e[94m  Checking if the dump978-fa package has been configured...\e[97m"
    if grep -wq "driver=rtlsdr,serial=" /etc/default/dump978-fa; then
        echo -e "\e[94m  This dump978-fa installation appears to have been configured...\e[97m"
    else
        whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "RTL-SDR Dongle Assignments" --msgbox "It appears one of the dump1090 packages has been installed on this device. In order to run dump978 in tandem with dump1090 you will need to specifiy which RTL-SDR dongle each decoder is to use.\n\nKeep in mind in order to run both decoders on a single device you will need to have two separate RTL-SDR devices connected to your device." 12 78
        # Ask the user which USB device is to be used for dump1090.
        DUMP1090_DEVICE_SERIAL=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump1090 RTL-SDR Dongle" --nocancel --inputbox "\nEnter the serial number for your dump1090 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
        while [[ -z "${DUMP1090_DEVICE_SERIAL}" ]] ; do
            DUMP1090_DEVICE_SERIAL=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump1090 RTL-SDR Dongle (REQUIRED)" --nocancel --inputbox "\nEnter the serial number for your dump1090 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
        done
        # Ask the user which USB device is to be use for dump978.
        DUMP978_DEVICE_SERIAL=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump978 RTL-SDR Dongle" --nocancel --inputbox "\nEnter the serial number for your dump978 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
        while [[ -z "${DUMP978_DEVICE_SERIAL}" ]] ; do
            DUMP978_DEVICE_SERIAL=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump978 RTL-SDR Dongle (REQUIRED)" --nocancel --inputbox "\nEnter the serial number for your dump978 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
        done

        # Assign the specified RTL-SDR dongle to dump978-fa.
        echo -e "\e[94m  Assigning RTL-SDR dongle \"${DUMP978_DEVICE_SERIAL}\" to dump978-fa...\e[97m"
        sudo sed -i -e "s/driver=rtlsdr/driver=rtlsdr,serial=${DUMP978_DEVICE_SERIAL}/g" /etc/default/dump978-fa
        echo -e "\e[94m  Restarting dump978-fa...\e[97m"
        sudo service dump978-fa force-reload

        # Assign the specified RTL-SDR dongle to dump1090-fa.
        if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
            echo -e "\e[94m  Assigning RTL-SDR dongle \"${DUMP1090_DEVICE_SERIAL}\" to dump1090-fa...\e[97m"
            ChangeConfig "RECEIVER_SERIAL" ${DUMP1090_DEVICE_SERIAL} "/etc/default/dump1090-fa"
            echo -e "\e[94m  Restarting dump1090-fa...\e[97m"
            sudo service dump1090-fa force-reload
        fi
    fi
fi

### SETUP COMPLETE

# Return to the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  Dump978-fa setup is complete.\e[39m"
echo ""
read -p "Press enter to continue..." CONTINUE

exit 0

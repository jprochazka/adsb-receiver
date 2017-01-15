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
# Copyright (c) 2015-2016 Joseph A. Prochazka                                       #
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

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] && [[ -s "${RECEIVER_CONFIGURATION_FILE}" ]] ; then
    source ${RECEIVER_CONFIGURATION_FILE}
fi

### BEGIN SETUP

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    clear
    echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
fi
echo ""
echo -e "\e[92m  Setting up Beast-Splitter..."
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Beast-Splitter Setup" --yesno "This is a helper utility for the Mode-S Beast.\n\nThe Beast provides a single data stream over a (USB) serial port. If you have more than one thing that wants to read that data stream, you need something to redistribute the data. This is what beast-splitter does.\n\n  https://github.com/flightaware/beast-splitter\n\nContinue beast-splitter setup?" 15 78
    if [[ $? -eq 1 ]] ; then
        # Setup has been halted by the user.
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo ""
        echo -e "\e[93m  ------------------------------------------------------------------------------"
        echo -e "\e[92m  Beast-Splitter setup halted.\e[39m"
        echo ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
    fi
fi

echo -e "\e[95m  Setting up Beast-Splitter on this device...\e[97m"
echo ""

### CHECK FOR PREREQUISITE PACKAGES

# Check that the required packages are installed.
echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo ""
CheckPackage build-essential
CheckPackage debhelper
CheckPackage libboost-system-dev
CheckPackage libboost-program-options-dev
CheckPackage libboost-regex-dev
CheckPackage dh-systemd

### CONFIRM SETTINGS

# Confirm settings with user.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # Ask the beast-splitter listen port.
    if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
        BEASTSPLITTER_LISTEN_PORT_TITLE="Listen Port"
        while [[ -z ${BEASTSPLITTER_LISTEN_PORT} ]]; do
            BEASTSPLITTER_LISTEN_PORT=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${BEASTSPLITTER_LISTEN_PORT}_TITLE" --nocancel --inputbox "\nPlease enter the port Beast-Splitter will listen on.\nThis must be a port which is currently not in use." 10 78 "30005" 3>&1 1>&2 2>&3)
            BEASTSPLITTER_LISTEN_PORT_TITLE="Listen Port (REQUIRED)"
        done
    fi
    # Ask the beast-splitter connect port.
    if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
        BEASTSPLITTER_CONNECT_PORT_TITLE="Connect Port"
        while [[ -z ${BEASTSPLITTER_CONNECT_PORT} ]]; do
            BEASTSPLITTER_CONNECT_PORT=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${BEASTSPLITTER_CONNECT_PORT}_TITLE" --nocancel --inputbox "\nPlease enter the port Beast-Splitter will connect to.\nThis is generally port 30104 on dump1090." 10 78 "30104" 3>&1 1>&2 2>&3)
            BEASTSPLITTER_CONNECT_PORT_TITLE="Connect Port (REQUIRED)"
        done
    fi
fi

### PROJECT BUILD DIRECTORY

# Create the build directory if it does not already exist.
if [[ ! -d ${RECEIVER_BUILD_DIRECTORY} ]] ; then
    echo -e "\e[94m  Creating the ADS-B Receiver Project build directory...\e[97m"
    mkdir -v -p ${RECEIVER_BUILD_DIRECTORY} 2>&1
fi

### DOWNLOAD SOURCE

echo ""
echo -e "\e[95m  Downloading and configuring Beast-Splitter...\e[97m"
echo ""

echo -e "\e[94m  Checking if the Git repository has been cloned...\e[97m"
if [[ -d ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter ]] && [[ -d ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter/.git ]] ; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the local Beast-Splitter git repository directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter
    echo -e "\e[94m  Updating the local Beast-Splitter git repository...\e[97m"
    echo ""
    git pull
    echo ""
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/beast-splitter
    echo -e "\e[94m  Cloning the Beast-Splitter git repository locally...\e[97m"
    echo ""
    git clone https://github.com/flightaware/beast-splitter.git
    echo ""
fi

### BUILD AND INSTALL

echo ""
echo -e "\e[95m  Building and installing the Beast-Splitter package...\e[97m"
echo ""
if [[ ! "${PWD}" = ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter ]] ; then
    echo -e "\e[94m  Entering the Beast-Splitter git repository directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter
fi
echo -e "\e[94m  Executing the Beast-Splitter build script...\e[97m"
echo ""
dpkg-buildpackage -b
echo ""
echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
cd ${RECEIVER_BUILD_DIRECTORY}/beast-splitter
echo -e "\e[94m  Installing the Beast-Splitter package...\e[97m"
sudo dpkg -i beast-splitter_*.deb

### CREATE SCRIPTS

echo -e "\e[94m  Creating the file beast-splitter_maint.sh...\e[97m"
tee ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter_maint.sh > /dev/null <<EOF
#! /bin/sh
while true
  do
    sleep 30
    beast-splitter --serial /dev/beast --listen ${BEASTSPLITTER_LISTEN_PORT}:R --connect localhost:${BEASTSPLITTER_CONNECT_PORT}:R
  done
EOF

echo -e "\e[94m  Setting file permissions for beast-splitter_maint.sh...\e[97m"
sudo chmod +x ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter_maint.sh

echo -e "\e[94m  Checking if the Beast-Splitter startup line is contained within the file /etc/rc.local...\e[97m"
if ! grep -Fxq "${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter_maint.sh &" /etc/rc.local; then
    echo -e "\e[94m  Adding the Beast-Splitter startup line to the file /etc/rc.local...\e[97m"
    lnum=($(sed -n '/exit 0/=' /etc/rc.local))
    ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter_maint.sh &\n" /etc/rc.local
fi

### START SCRIPTS

echo ""
echo -e "\e[95m  Starting Beast-Splitter...\e[97m"
echo ""

# Kill any currently running instances of the beast-splitter_maint.sh and beast-splitter scripts.
PROCS="beast-splitter_maint.sh beast-splitter"
for PROC in ${PROCS} ; do
    echo -e "\e[94m  Checking for any running ${PROC} processes...\e[97m"
    PIDS=`ps -efww | grep -w "${PROC} " | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [[ -n "${PIDS}" ]] ; then
        echo -e "\e[94m  Killing any running ${PROC} processes...\e[97m"
        sudo kill ${PIDS} 2>&1
        sudo kill -9 ${PIDS} 2>&1
    fi
    unset PIDS
done

# Start the beast-splitter_maint.sh script.
echo -e "\e[94m  Executing the beast-splitter_maint.sh script...\e[97m"
echo ""
sudo nohup ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter_maint.sh > /dev/null 2>&1 &
echo ""

### SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  Beast-Splitter setup is complete.\e[39m"
echo ""
if [[ ${RECEIVER_AUTOMATED_INSTALL} = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

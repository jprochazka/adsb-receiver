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

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

## BEGIN SETUP

clear
echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
echo -e ""
echo -e "\e[92m  Setting up beast-splitter..."
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Beast-Splitter Setup" --yesno "beast-splitter is a helper utility for the Mode-S Beast.\n\nThe Beast provides a single data stream over a (USB) serial port. If you have more than one thing that wants to read that data stream, you need something to redistribute the data. This is what beast-splitter does.\n\n  https://github.com/flightaware/beast-splitter\n\nContinue beast-splitter setup?" 15 78
if [[ $? -eq 1 ]] ; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo -e ""
    echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
    echo -e "\e[92m  beast-splitter setup halted.\e[39m"
    echo -e ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

## GATHER CONFIGURATION OPTIONS

whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Enable Beast Splitter" --defaultno --yesno "By default Beast Splitter is disabled. Would you like to enable Beast Splitter now?" 8 65
if [[ $? -eq 0 ]]; then
    enabled="true"
else
    enabled="false"
fi
input_options=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Input Options for Beast Splitter" --nocancel --inputbox "Enter the option telling Beast Splitter where to read data from. You should provide one of the following either --net or --serial.\n\nExamples:\n--serial /dev/beast\n--net remotehost:remoteport" 8 78 3>&1 1>&2 2>&3)
output_options=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Output Options for Beast Splitter" --nocancel --inputbox "Enter the option to tell Beast Splitter where to send output data. You can do so by establishing an outgoing connection or accepting inbound connections.\\Examples:\n--connect remotehost:remoteport\n --listen remotehost:remoteport" 8 78 3>&1 1>&2 2>&3)

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Checking that the required packages are installed...\e[97m"
echo -e ""
CheckPackage build-essential
CheckPackage debhelper
CheckPackage libboost-system-dev
CheckPackage libboost-program-options-dev
CheckPackage libboost-regex-dev
echo ""

## DOWNLOAD SOURCE

echo -e "\e[95m  Downloading the beast-splitter repository from GitHub...\e[97m"
echo -e ""

echo -e "\e[94m  Checking if the Git repository has already been cloned...\e[97m"
if [[ -d ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter && -d ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter/.git ]] ; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the local beast-splitter git repository directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter 2>&1
    echo -e "\e[94m  Updating the local beast-splitter git repository...\e[97m"
    echo -e ""
    git pull 2>&1
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Creating the beast-splitter build directory...\e[97m"
    echo ""
    mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/beast-splitter 2>&1
    echo ""
    echo -e "\e[94m  Entering the beast-splitter build directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/beast-splitter 2>&1
    echo -e "\e[94m  Cloning the beast-splitter git repository locally...\e[97m"
    echo -e ""
    git clone https://github.com/flightaware/beast-splitter.git 2>&1
fi
echo ""

## BUILD AND INSTALL

echo -e "\e[95m  Building and installing the beast-splitter package...\e[97m"
echo -e ""

echo -e "\e[94m  Entering the beast-splitter git repository directory...\e[97m"
cd ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter 2>&1

echo -e "\e[94m  Executing the beast-splitter build script...\e[97m"
echo -e ""
dpkg-buildpackage -b 2>&1
echo -e ""

echo -e "\e[94m  Entering the beast-splitter build directory...\e[97m"
cd ${RECEIVER_BUILD_DIRECTORY}/beast-splitter 2>&1

echo -e "\e[94m  Installing the beast-splitter package...\e[97m"
echo ""
sudo dpkg -i beast-splitter_*.deb 2>&1
echo ""

# Archive binary package.
if [[ ! -d ${RECEIVER_BUILD_DIRECTORY}/package-archive ]] ; then
    echo -e "\e[94m  Creating package archive directory...\e[97m"
    echo ""
    mkdir -vp  ${RECEIVER_BUILD_DIRECTORY}/package-archive 2>&1
    echo ""
fi
echo -e "\e[94m  Moving the beast-splitter package into the archive directory...\e[97m"
echo ""
cp -vp ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/*.deb ${RECEIVER_BUILD_DIRECTORY}/package-archive/ 2>&1
echo ""

## CONFIGURE BEAST SPLITTER

echo -e "\e[94m  Configuring beast-splitter...\e[97m"
ChangeConfig "ENABLED" $enabled "/etc/default/beast-splitter"
ChangeConfig "INPUT_OPTIONS" $input_options "/etc/default/beast-splitter"
ChangeConfig "OUTPUT_OPTIONS" $output_options "/etc/default/beast-splitter"

## SETUP COMPLETE

# Return to the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  beast-splitter setup is complete.\e[39m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

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

## VARIABLES

PROJECTROOTDIRECTORY="$PWD"
BASHDIRECTORY="$PROJECTROOTDIRECTORY/bash"
BUILDDIRECTORY="$PROJECTROOTDIRECTORY/build"
PLANEFINDERBUILDDIRECTORY="$PROJECTROOTDIRECTORY/build/planefinder"
DEVICEIPADDRESS=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`

## INCLUDE EXTERNAL SCRIPTS

source $BASHDIRECTORY/variables.sh
source $BASHDIRECTORY/functions.sh

## BEGIN SETUP

clear
echo -e "\n\e[91m  THE ADS-B RECIEVER PROJECT VERSION $PROJECTVERSION"
echo ""
echo -e "\e[92m  Setting up the Plane Finder ADS-B Client..."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo ""
whiptail --title "Plane Finder ADS-B Client Setup" --yesno "The Plane Finder ADS-B Client is an easy and accurate way to share your ADS-B and MLAT data with Plane Finder. It comes with a beautiful user interface that helps you explore and interact with your data in realtime.\n\n  https://planefinder.net/sharing/client\n\nContinue setup by installing the Plane Finder ADS-B Client?" 13 78
CONTINUESETUP=$?
if [ $CONTINUESETUP = 1 ]; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  Plane Finder ADS-B Client setup halted.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo ""
if [[ `uname -m` == "x86_64" ]]; then
    if [[ `lsb_release -si` == "Debian" ]] && [ $(dpkg --print-foreign-architectures $1 2>/dev/null | grep -c "i386") -eq 0 ]; then
        echo -e "\e[94m  Adding the i386 architecture...\e[97m"
        sudo dpkg --add-architecture i386
        echo -e "\e[94m  Downloading latest package lists for enabled repositories and PPAs...\e[97m"
        echo ""
        sudo apt-get update
        echo ""
    fi
    CheckPackage libc6:i386
else
    CheckPackage libc6
fi
CheckPackage wget

## DOWNLOAD THE PLANEFINDER ADS-B CLIENT PACKAGE

echo ""
echo -e "\e[95m  Downloading the Plane Finder ADS-B Client package...\e[97m"
echo ""
# Create the planefinder build directory if it does not exist.
if [ ! -d $PLANEFINDERBUILDDIRECTORY ]; then
    echo -e "\e[94m  Creating the Plane Finder ADS-B Client build directory...\e[97m"
    mkdir $PLANEFINDERBUILDDIRECTORY
fi
# Download the appropriate package depending on the devices architecture.
if [[ `uname -m` == "armv7l" ]] || [[ `uname -m` == "armv6l" ]]; then
    echo -e "\e[94m  Downloading the Plane Finder ADS-B Client v$PFCLIENTVERSIONARM for ARM devices...\e[97m"
    echo ""
    wget http://client.planefinder.net/pfclient_${PFCLIENTVERSIONARM}_armhf.deb -O $PLANEFINDERBUILDDIRECTORY/pfclient_${PFCLIENTVERSIONARM}_armhf.deb
else
    echo -e "\e[94m  Downloading the Plane Finder ADS-B Client v$PFCLIENTVERSIONI386 for I386 devices...\e[97m"
    echo ""
    wget http://client.planefinder.net/pfclient_${PFCLIENTVERSIONI386}_i386.deb -O $PLANEFINDERBUILDDIRECTORY/pfclient_${PFCLIENTVERSIONI386}_i386.deb
fi

## INSTALL THE PLANEFINDER ADS-B CLIENT PACKAGE

echo ""
echo -e "\e[95m  Installing the Plane Finder ADS-B Client package...\e[97m"
echo ""
echo -e "\e[94m  Entering the Plane Finder ADS-B Client build directory...\e[97m"
cd $PLANEFINDERBUILDDIRECTORY
# Install the proper package depending on the devices architecture.
if [[ `uname -m` == "armv7l" ]] || [[ `uname -m` == "armv6l" ]]; then
    echo -e "\e[94m  Installing the Plane Finder ADS-B Client v$PFCLIENTVERSIONARM for ARM devices package...\e[97m"
    echo ""
    sudo dpkg -i $PLANEFINDERBUILDDIRECTORY/pfclient_${PFCLIENTVERSIONARM}_armhf.deb
else
    echo -e "\e[94m  Installing the Plane Finder ADS-B Client v$PFCLIENTVERSIONI386 for I386 devices package...\e[97m"
    if [[ `lsb_release -si` == "Debian" ]]; then
        # Force architecture if this is Debian.
        echo -e "\e[94m  NOTE: dpkg executed with added flag --force-architecture.\e[97m"
        echo ""
        sudo dpkg -i --force-architecture $PLANEFINDERBUILDDIRECTORY/pfclient_${PFCLIENTVERSIONI386}_i386.deb
    else
        echo ""
        sudo dpkg -i $PLANEFINDERBUILDDIRECTORY/pfclient_${PFCLIENTVERSIONI386}_i386.deb
    fi
fi
# Check that the Plane Finder ADS-B Client package was installed successfully.
echo ""
echo -e "\e[94m  Checking that the pfclient package was installed properly...\e[97m"
if [ $(dpkg-query -W -f='${STATUS}' pfclient 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    # If the pfclient package could not be installed halt setup.
    echo ""
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  UNABLE TO INSTALL A REQUIRED PACKAGE."
    echo -e "  SETUP HAS BEEN TERMINATED!"
    echo ""
    echo -e "\e[93mThe package \"pfclient\" could not be installed.\e[39m"
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  Plane Finder ADS-B Client setup halted.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

## DISPLAY FINAL SETUP INSTRUCTIONS WHICH CONNOT BE HANDLED BY THIS SCRIPT

whiptail --title "Plane Finder ADS-B Client Setup Instructions" --msgbox "At this point the Plane Finder ADS-B Client should be installed and running howeverThis script is only capable of installing the Plane Finder ADS-B Client. There are stilla few steps left which you must manually do through the Plane Finder ADS-B Client itself.\n\nVisit the following URL: http://${DEVICEIPADDRESS}:30053\n\nThe follow the instructions supplied by the Plane Finder ADS-B Client.\n\nUse the following settings when asked for them.\n\nData Format: Beast\nTcp Address: 127.0.0.1\nTcp Port: 30005" 20 78

## PLANE FINDER ADS-B CLIENT SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd $PROJECTROOTDIRECTORY

echo ""
echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
echo -e "\e[92m  Plane Finder ADS-B Client setup is complete.\e[39m"
echo ""
read -p "Press enter to continue..." CONTINUE

exit 0

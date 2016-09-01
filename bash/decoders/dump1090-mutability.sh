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

### VARIABLES

PROJECTROOTDIRECTORY="$PWD"
BASHDIRECTORY="$PROJECTROOTDIRECTORY/bash"
BUILDDIRECTORY="$PROJECTROOTDIRECTORY/build"
DUMP1090BUILDDIRECTORY="$PROJECTROOTDIRECTORY/build/dump1090"

### INCLUDE EXTERNAL SCRIPTS

source $BASHDIRECTORY/variables.sh
source $BASHDIRECTORY/functions.sh

## BEGIN SETUP

clear
echo -e "\n\e[91m  THE ADS-B RECIEVER PROJECT VERSION $PROJECTVERSION"
echo ""
echo -e "\e[92m  Setting up dump1090-mutability..."
echo -e "\e[93m------------------------------------------------------------------------------\e[96m"
echo ""
echo " Dump 1090 is a Mode S decoder specifically designed for RTLSDR devices."
echo " Dump1090-mutability is a fork of MalcolmRobb's version of dump1090 that adds"
echo " new functionality and is designed to be built as a Debian/Raspbian package."
echo ""
echo " https://github.com/mutability/dump1090"
echo -e "\e[39m"
read -p "Press enter to continue..." CONTINUE

## CHECK FOR PREREQUISITE PACKAGES

echo ""
echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo ""
CheckPackage git
CheckPackage curl
CheckPackage build-essential
CheckPackage debhelper
CheckPackage cron
CheckPackage rtl-sdr
CheckPackage librtlsdr-dev
CheckPackage libusb-1.0-0-dev
CheckPackage pkg-config
CheckPackage lighttpd
CheckPackage fakeroot

## DOWNLOAD OR UPDATE THE DUMP1090-MUTABILITY SOURCE

echo ""
echo -e "\e[95m  Preparing the dump1090-mutability Git repository...\e[97m"
echo ""
if [ -d $DUMP1090BUILDDIRECTORY ] && [ -d $DUMP1090BUILDDIRECTORY/.git ]; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the dump1090-mutability git repository directory...\e[97m"
    cd $DUMP1090BUILDDIRECTORY
    echo -e "\e[94m  Updating the local dump1090-mutability git repository...\e[97m"
    echo ""
    git pull
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
    cd $BUILDDIRECTORY
    echo -e "\e[94m  Cloning the dump1090-mutability git repository locally...\e[97m"
    echo ""
    git clone https://github.com/mutability/dump1090.git
    echo ""
fi

## BUILD THE DUMP1090-MUTABILITY PACKAGE

echo ""
echo -e "\e[95m  Building the dump1090-mutability package...\e[97m"
echo ""
if [ ! $PWD = $DUMP1090BUILDDIRECTORY ]; then
    echo -e "\e[94m  Entering the dump1090-mutability git repository directory...\e[97m"
    cd $DUMP1090BUILDDIRECTORY
fi
echo -e "\e[94m  Building the dump1090-mutability package...\e[97m"
echo ""
dpkg-buildpackage -b

## INSTALL THE DUMP1090-MUTABILITY PACKAGE

echo ""
echo -e "\e[95m  Installing the dump1090-mutability package...\e[97m"
echo ""
echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
cd $BUILDDIRECTORY
echo -e "\e[94m  Installing the dump1090-mutability package...\e[97m"
echo ""
sudo dpkg -i dump1090-mutability_1.15~dev_*.deb

## CHECK THAT THE PACKAGE INSTALLED

if [ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    # If the dump1090-mutability package could not be installed halt setup.
    echo ""
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m
    echo -e "  UNABLE TO INSTALL A REQUIRED PACKAGE."
    echo -e "  SETUP HAS BEEN TERMINATED!"
    echo ""
    echo -e "\e[93mThe package \"dump1090-mutability\" could not be installed.\e[39m"
    echo ""
    #kill -9 `ps --pid $$ -oppid=`; exit
    exit 1
fi

## DUMP1090-MUTABILITY POST INSTALLATION CONFIGURATION

# Set the receiver's latitude and longitude if it is not already set in the dump1090-mutibility configuration file.
echo ""
echo -e "\e[95m  Begining post installation configuration...\e[97m"
echo ""
if [[ `GetConfig "LAT" "/etc/default/dump1090-mutability"` == "" ]] || [[ `GetConfig "LON" "/etc/default/dump1090-mutability"` == "" ]]; then
    whiptail --title "Receiver Latitude and Longitude" --msgbox "" 8 78
    RECEIVERLATITUDE=$(whiptail --title "Receiver Latitude" --nocancel --inputbox "Enter your receiver's latitude." 8 78 3>&1 1>&2 2>&3)
    RECEIVERLONGITUDE=$(whiptail --title "Receiver Longitude" --nocancel --inputbox "Enter your receeiver's longitude." 8 78 3>&1 1>&2 2>&3)
    echo -e "\e[94m  Setting the receiver's latitude to $RECEIVERLATITUDE...\e[97m"
    ChangeConfig "LAT" $RECEIVERLATITUDE "/etc/default/dump1090-mutability"
    echo -e "\e[94m  Setting the receiver's longitude to $RECEIVERLONGITUDE...\e[97m"
    ChangeConfig "LON" $RECEIVERLONGITUDE "/etc/default/dump1090-mutability"
fi

# Ask if dump1090-mutability should bind on all IP addresses.
if (whiptail --title "Bind To All IP Addresses" --yesno "" 8 78) then
    ChangeConfig "NET_BIND_ADDRESS" "0.0.0.0" "/etc/default/dump1090-mutability"
fi

# Download Heywhatsthat.com maximum range rings.
if [ ! -f /usr/share/dump1090-mutability/html/upintheair.json ] && (whiptail --title "Heywhaststhat.com Maimum Range Rings" --yesno "" 8 78); then
    HEYWHATSTHATID=$(whiptail --title "Heywhatsthat.com Panarama ID" --nocancel --inputbox "Enter your Heywhatsthat.com panarama ID." 8 78 3>&1 1>&2 2>&3)
    HEYWHATSTHATRINGONE=$(whiptail --title "Heywhatsthat.com Panarama ID" --nocancel --inputbox "Enter the first ring's altitude in meters.\n(default 3048 meters or 10000 feet)" 8 78 "3048" 3>&1 1>&2 2>&3)
    HEYWHATSTHATRINGTWO=$(whiptail --title "Heywhatsthat.com Panarama ID" --nocancel --inputbox "Enter the second ring's altitude in meters.\n(default 12192 meters or 40000 feet)" 8 78 "12192" 3>&1 1>&2 2>&3)
    echo "\e[94m  Downloading JSON data pertaining to the supplied panorama ID...\e[97m"
    sudo wget -O /usr/share/dump1090-mutability/html/upintheair.json "http://www.heywhatsthat.com/api/upintheair.json?id=${HEYWHATSTHATID}&refraction=0.25&alts=$HEYWHATSTHATRINGONE,$HEYWHATSTHATRINGTWO"
fi

# Reload dump1090-mutability to ensure all changes take effect.
echo "\e[94m  Reloading dump1090-mutability...\e[97m"
sudo /etc/init.d/dump1090-mutability force-reload

## DUMP1090-MUTABILITY SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd $PROJECTROOTDIRECTORY

echo ""
echo -e "\e[93m------------------------------------------------------------------------------"
echo -e "\e[92m  Dump1090-mutability setup is complete.\e[39m"
echo ""
read -p "Press enter to continue..." CONTINUE

exit 0

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
DUMP1090BUILDDIRECTORY="$BUILDDIRECTORY/dump1090-fa"

## INCLUDE EXTERNAL SCRIPTS

source $BASHDIRECTORY/variables.sh
source $BASHDIRECTORY/functions.sh

## BEGIN SETUP

clear
echo -e "\n\e[91m   $ADSB_PROJECTTITLE"
echo ""
echo -e "\e[92m  Setting up dump1090-fa..."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo ""
whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Dump1090-fa Setup" --yesno "Dump 1090 is a Mode-S decoder specifically designed for RTL-SDR devices. Dump1090-fa is a fork of the dump1090-mutability version of dump1090 that is specifically designed for FlightAware's PiAware software.\n\nIn order to use this version of dump1090 FlightAware's PiAware software must be installed as well.\n\n  https://github.com/flightaware/dump1090\n\nContinue setup by installing dump1090-fa?" 14 78
CONTINUESETUP=$?
if [ $CONTINUESETUP = 1 ]; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  Dump1090-fa setup halted.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

## CHECK FOR PREREQUISITE PACKAGES

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
CheckPackage dh-systemd

## DOWNLOAD OR UPDATE THE DUMP1090-FA SOURCE

echo ""
echo -e "\e[95m  Preparing the dump1090-fa Git repository...\e[97m"
echo ""
if [ -d $DUMP1090BUILDDIRECTORY/dump1090 ] && [ -d $DUMP1090BUILDDIRECTORY/dump1090/.git ]; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the dump1090-fa git repository directory...\e[97m"
    cd $DUMP1090BUILDDIRECTORY/dump1090
    echo -e "\e[94m  Updating the local dump1090-fa git repository...\e[97m"
    echo ""
    git pull
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
    mkdir -p $DUMP1090BUILDDIRECTORY
    cd $DUMP1090BUILDDIRECTORY
    echo -e "\e[94m  Cloning the dump1090-fa git repository locally...\e[97m"
    echo ""
    git clone https://github.com/flightaware/dump1090.git
    echo ""
fi

## BUILD AND INSTALL THE DUMP1090-FA PACKAGE

echo ""
echo -e "\e[95m  Building and installing the dump1090-fa package...\e[97m"
echo ""
if [ ! $PWD = $DUMP1090BUILDDIRECTORY/dump1090 ]; then
    echo -e "\e[94m  Entering the dump1090-fa git repository directory...\e[97m"
    cd $DUMP1090BUILDDIRECTORY/dump1090
fi
echo -e "\e[94m  Building the dump1090-fa package...\e[97m"
echo ""
dpkg-buildpackage -b
echo ""
echo -e "\e[94m  Entering the dump1090-fa build directory...\e[97m"
cd $DUMP1090BUILDDIRECTORY
echo -e "\e[94m  Installing the dump1090-fa package...\e[97m"
echo ""
sudo dpkg -i dump1090-fa_${PIAWAREVERSION}_*.deb

# Check that the package was installed.
echo ""
echo -e "\e[94m  Checking that the dump1090-fa package was installed properly...\e[97m"
if [ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    # If the dump1090-fa package could not be installed halt setup.
    echo ""
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  UNABLE TO INSTALL A REQUIRED PACKAGE."
    echo -e "  SETUP HAS BEEN TERMINATED!"
    echo ""
    echo -e "\e[93mThe package \"dump1090-fa\" could not be installed.\e[39m"
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  Dump1090-fa setup halted.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

## DUMP1090-FA POST INSTALLATION CONFIGURATION

# Download Heywhatsthat.com maximum range rings.
if [ ! -f /usr/share/dump1090-fa/html/upintheair.json ] && (whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Heywhaststhat.com Maimum Range Rings" --yesno "Maximum range rings can be added to dump1090-fa usings data obtained from Heywhatsthat.com. In order to add these rings to your dump1090-fa map you will first need to visit http://www.heywhatsthat.com and generate a new panarama centered on the location of your receiver. Once your panarama has been generated a link to the panarama will be displayed in the up left hand portion of the page. You will need the view id which is the series of letters and/or numbers after \"?view=\" in this URL.\n\nWould you like to add heywatsthat.com maximum range rings to your map?" 16 78); then
    HEYWHATSTHATID_TITLE="Heywhatsthat.com Panarama ID"
    while [[ -z $HEYWHATSTHATID ]]; do
        HEYWHATSTHATID=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$HEYWHATSTHATID_TITLE" --nocancel --inputbox "\nEnter your Heywhatsthat.com panarama ID." 8 78 3>&1 1>&2 2>&3)
        HEYWHATSTHATID_TITLE="Heywhatsthat.com Panarama ID (REQUIRED)"
    done
    HEYWHATSTHATRINGONE_TITLE="Heywhatsthat.com First Ring Altitude"
    while [[ -z $HEYWHATSTHATRINGONE ]]; do
        HEYWHATSTHATRINGONE=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$HEYWHATSTHATRINGONE_TITLE" --nocancel --inputbox "\nEnter the first ring's altitude in meters.\n(default 3048 meters or 10000 feet)" 8 78 "3048" 3>&1 1>&2 2>&3)
        HEYWHATSTHATRINGONE_TITLE="Heywhatsthat.com First Ring Altitude (REQUIRED)"
    done
    HEYWHATSTHATRINGTWO_TITLE="Heywhatsthat.com Second Ring Altitude"
    while [[ -z $HEYWHATSTHATRINGTWO ]]; do
        HEYWHATSTHATRINGTWO=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$HEYWHATSTHATRINGTWO_TITLE" --nocancel --inputbox "\nEnter the second ring's altitude in meters.\n(default 12192 meters or 40000 feet)" 8 78 "12192" 3>&1 1>&2 2>&3)
        HEYWHATSTHATRINGTWO_TITLE="Heywhatsthat.com Second Ring Altitude (REQUIRED)"
    done
    echo -e "\e[94m  Downloading JSON data pertaining to the supplied panorama ID...\e[97m"
    echo ""
    sudo wget -O /usr/share/dump1090-fa/html/upintheair.json "http://www.heywhatsthat.com/api/upintheair.json?id=${HEYWHATSTHATID}&refraction=0.25&alts=$HEYWHATSTHATRINGONE,$HEYWHATSTHATRINGTWO"
fi

## DUMP1090-FA SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd $PROJECTROOTDIRECTORY

echo ""
echo -e "\e[93m----------------------------------------------------------------------------------------------------"
echo -e "\e[92m  Dump1090-fa setup is complete.\e[39m"
echo ""
read -p "Press enter to continue..." CONTINUE

exit 0

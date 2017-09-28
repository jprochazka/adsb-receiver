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

## VAARIABLES

PROJECTROOTDIRECTORY="$PWD"
BASHDIRECTORY="$PROJECTROOTDIRECTORY/bash"
BUILDDIRECTORY="$PROJECTROOTDIRECTORY/build"
PIAWAREBUILDDIRECTORY="$PROJECTROOTDIRECTORY/build/piaware_builder"

## INCLUDE EXTERNAL SCRIPTS

source $BASHDIRECTORY/variables.sh
source $BASHDIRECTORY/functions.sh

## BEGIN SETUP

clear
echo -e "\n\e[91m  $ADSB_PROJECTTITLE"
echo ""
echo -e "\e[92m  Setting up FlightAware's PiAware..."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo ""
whiptail --backtitle "$ADSB_PROJECTTITLE" --title "PiAware Setup" --yesno "PiAware is a package used to forward data read from an ADS-B receiver to FlightAware. It does this using a program, piaware, while aided by other support programs.\n\n  https://github.com/flightaware/piaware\n\nContinue setup by installing FlightAware's PiAware?" 13 78
CONTINUESETUP=$?
if [ $CONTINUESETUP = 1 ]; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  Dump1090-mutability setup halted.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo ""
CheckPackage git
CheckPackage build-essential
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

## DOWNLOAD OR UPDATE THE PIAWARE_BUILDER SOURCE

echo ""
echo -e "\e[95m  Preparing the piaware_builder Git repository...\e[97m"
echo ""
if [ -d $PIAWAREBUILDDIRECTORY ] && [ -d $PIAWAREBUILDDIRECTORY/.git ]; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the piaware_builder git repository directory...\e[97m"
    cd $PIAWAREBUILDDIRECTORY
    echo -e "\e[94m  Updating the local piaware_builder git repository...\e[97m"
    echo ""
    git pull
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
    cd $BUILDDIRECTORY
    echo -e "\e[94m  Cloning the piaware_builder git repository locally...\e[97m"
    echo ""
    git clone https://github.com/flightaware/piaware_builder.git
fi

## BUILD AND INSTALL THE PIAWARE PACKAGE

echo ""
echo -e "\e[95m  Building and installing the PiAware package...\e[97m"
echo ""
if [ ! $PWD = $PIAWAREBUILDDIRECTORY ]; then
    echo -e "\e[94m  Entering the piaware_builder git repository directory...\e[97m"
    cd $PIAWAREBUILDDIRECTORY
fi
echo -e "\e[94m  Executing the PiAware build script...\e[97m"
echo ""
./sensible-build.sh jessie
echo ""
echo -e "\e[94m  Entering the PiAware build directory...\e[97m"
cd $PIAWAREBUILDDIRECTORY/package-jessie
echo -e "\e[94m  Building the PiAware package...\e[97m"
echo ""
dpkg-buildpackage -b
echo ""
echo -e "\e[94m  Installing the PiAware package...\e[97m"
echo ""
sudo dpkg -i $PIAWAREBUILDDIRECTORY/piaware_*.deb

# Check that the PiAware package was installed successfully.
echo ""
echo -e "\e[94m  Checking that the piaware package was installed properly...\e[97m"
if [ $(dpkg-query -W -f='${STATUS}' piaware 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    # If the piaware package could not be installed halt setup.
    echo ""
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  UNABLE TO INSTALL A REQUIRED PACKAGE."
    echo -e "  SETUP HAS BEEN TERMINATED!"
    echo ""
    echo -e "\e[93mThe package \"piaware\" could not be installed.\e[39m"
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  PiAware setup halted.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

# Move the .deb package into another directory simply to keep it for historical reasons.
if [ ! -d $PIAWAREBUILDDIRECTORY/packages ]; then
    echo -e "\e[94m  Making the PiAware package archive directory...\e[97m"
    mkdir $PIAWAREBUILDDIRECTORY/packages
fi
echo -e "\e[94m  Moving the PiAware package into the package archive directory...\e[97m"
mv $PIAWAREBUILDDIRECTORY/piaware_*.deb $PIAWAREBUILDDIRECTORY/packages/
echo -e "\e[94m  Moving the PiAware package changes file into the package archive directory...\e[97m"
mv $PIAWAREBUILDDIRECTORY/piaware_*.changes $PIAWAREBUILDDIRECTORY/packages/

## INSTRUCTIONS TO CLAIM THE RECIEVER

whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Claim Your PiAware Device" --msgbox "IMPORTANT!!!/n/nYou will need to claim this PiAware device manually by visiting the following URL.\n\nhttp://flightaware.com/adsb/piaware/claim." 10 78

## PIAWARE SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd $PROJECTROOTDIRECTORY

echo ""
echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
echo -e "\e[92m  PiAware setup is complete.\e[39m"
echo ""
read -p "Press enter to continue..." CONTINUE

exit 0

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
PIAWAREBUILDDIRECTORY="$PROJECTROOTDIRECTORY/build/dump1090"

### INCLUDE EXTERNAL SCRIPTS

source $BASHDIRECTORY/variables.sh
source $BASHDIRECTORY/functions.sh

## BEGIN SETUP

clear
echo -e "\n\e[91m  THE ADS-B RECIEVER PROJECT VERSION $PROJECTVERSION"
echo ""
echo -e "\e[92m  Setting up FLightAware's PiAware..."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo ""
whiptail --title "PiAware Setup" --yesno "PiAware is a package used to forward data read from an ADS-B receiver to FlightAware. It does this using a program, piaware, while aided by other support programs.\n\n  https://github.com/flightaware/piaware\n\nContinue setup by installing FlightAware's PiAware?" 14 78
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
    echo ""
fi

exit 0


## BUILD THE PIAWARE PACKAGE

echo -e "\033[33m"
echo "Building the PiAware package..."
echo -e "\033[37m"
./sensible-build.sh jessie
cd $PIAWAREDIR/package-jessie
dpkg-buildpackage -b

## INSTALL THE PIAWARE PACKAGE

echo -e "\033[33m"
echo "Installing the PiAware package..."
echo -e "\033[37m"
sudo dpkg -i $PIAWAREDIR/piaware_*.deb

# Move the .deb package into another directory simply to keep it for historical reasons.
if [ ! -d $PIAWAREDIR/packages ]; then
    mkdir $PIAWAREDIR/packages
fi
mv $PIAWAREDIR/piaware_*.deb $PIAWAREDIR/packages/
mv $PIAWAREDIR/piaware_*.changes $PIAWAREDIR/packages/

## CHECK THAT THE PACKAGE INSTALLED

if [ $(dpkg-query -W -f='${STATUS}' piaware 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    echo "\033[31m"
    echo "#########################################"
    echo "# INSTALLATION HALTED!                  #"
    echo "# UNABLE TO INSTALL A REQUIRED PACKAGE. #"
    echo "#########################################"
    echo ""
    echo "The piaware package did not install properly!"
    echo -e "\033[33m"
    echo "This script has exited due to the error encountered."
    echo "Please read over the above output in order to determine what went wrong."
    echo ""
    kill -9 `ps --pid $$ -oppid=`; exit
fi

## CONFIGURE FLIGHTAWARE

echo -e "\033[31m"
echo "CLAIM YOUR PIAWARE DEVICE"
echo -e "\033[33m"
echo "Please supply your FlightAware login in order to claim this device."
echo "After supplying your login PiAware will ask you to enter your password for verification."
echo "If you decide not to supply a login and password you should still be able to claim your"
echo "feeder by visting the page http://flightaware.com/adsb/piaware/claim."
echo -e "\033[37m"
read -p "Your FlightAware Login: " FALOGIN
read -p "Your FlightAware Password: " FAPASSWD1
read -p "Repeat Your FlightAware Password: " FAPASSWD2

# Check that the supplied passwords match.
while [ $FAPASSWD1 != $FAPASSWD2 ]; do
    echo -e "\033[33m"
    echo "The supplied passwords did not match."
    echo -e "\033[37m"
    read -p "Your FlightAware Password: " FAPASSWD1
    read -p "Repeat Your FlightAware Password: " FAPASSWD2
done
echo ""

# Set the supplied user name and password in the configuration.
sudo piaware-config flightaware-user $FALOGIN
sudo piaware-config flightaware-password $FAPASSWD1

echo -e "\e[33m"
echo "Restarting PiAware to ensure all changes are applied..."
echo -e "\033[37m"
sudo /etc/init.d/piaware restart

echo -e "\033[33m"
echo "Installation and configuration of PiAware is now complete."
echo "Please look over the output generated to be sure no errors were encountered."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

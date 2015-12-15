#!/bin/bash

#####################################################################################
#                                   ADS-B FEEDER                                    #
#####################################################################################
#                                                                                   #
# This script is not meant to be executed directly.                                 #
# Instead execute install.sh to begin the installation process.                     #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                   #
# Copyright (c) 2015 Joseph A. Prochazka                                            #
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

BUILDDIR=${PWD}

## FUNCTIONS

# Function used to check if a package is install and if not install it.
ATTEMPT=1
function CheckPackage(){
    if (( $ATTEMPT > 5 )); then
        echo -e "\033[33mSCRIPT HALETED! \033[31m[FAILED TO INSTALL PREREQUISITE PACKAGE]\033[37m"
        echo ""
        exit 1
    fi
    printf "\e[33mChecking if the package $1 is installed..."
    if [ $(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        if (( $ATTEMPT > 1 )); then
            echo -e "\033[31m [PREVIOUS INSTALLATION FAILED]\033[37m"
            echo -e "\033[33mAttempting to Install the package $1 again in 5 seconds (ATTEMPT $ATTEMPT OF 5)..."
            sleep 5
        else
            echo -e "\033[31m [NOT INSTALLED]\033[37m"
            echo -e "\033[33mInstalling the package $1..."
        fi
        echo -e "\033[37m"
        ATTEMPT=$((ATTEMPT+1))
        sudo apt-get install -y $1;
        echo ""
        CheckPackage $1
    else
        echo -e "\033[32m [OK]\033[37m"
        ATTEMPT=0
    fi
}

clear

echo -e "\033[31m"
echo "-------------------------------"
echo " Now ready to install PiAware."
echo "-------------------------------"
echo -e "\033[33mPiAware is a package used to forward data read from an ADS-B receiver to FlightAware."
echo "It does this using a program, piaware, aided by some support programs."
echo ""
echo "piaware        - establishes an encrypted session to FlightAware and forwards data"
echo "piaware-config - used to configure piaware like with a FlightAware username and password"
echo "piaware-status - used to check the status of piaware"
echo "faup1090       - run by piaware to connect to dump1090 or some other program producing beast-style ADS-B data and translate between its format and FlightAware's"
echo "fa-mlat-client - run by piaware to gather data for multilateration"
echo ""
echo "https://github.com/flightaware/piaware"
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\033[33m"
echo "Installing packages needed to build and fulfill dependencies..."
echo -e "\033[37m"
CheckPackage git
CheckPackage build-essential
CheckPackage debhelper
CheckPackage tcl8.5-dev
CheckPackage autoconf
CheckPackage python3-dev
CheckPackage python-virtualenv

# libz-dev appears to have been replaced by zlib1g-dev at least in Ubuntu Vivid Vervet...
# Will need to check if this is the case with Raspbian and Debian as well.
#CheckPackage libz-dev
CheckPackage zlib1g-dev

CheckPackage tclx8.4
CheckPackage tcllib
CheckPackage tcl-tls
CheckPackage itcl3

## DOWNLOAD THE PIAWARE SOURCE

echo -e "\033[33m"
echo "Downloading the source code for PiAware Builder..."
echo -e "\033[37m"
git clone https://github.com/flightaware/piaware_builder.git
cd $BUILDDIR/piaware_builder
git checkout tags/v2.1-3

## BUILD THE PIAWARE PACKAGE

echo -e "\033[33m"
echo "Building the PiAware package..."
echo -e "\033[37m"
./sensible-build.sh
cd $BUILDDIR/piaware_builder/package
dpkg-buildpackage -b

## INSTALL THE PIAWARE PACKAGE

echo -e "\033[33m"
echo "Installing the PiAware package..."
echo -e "\033[37m"
sudo dpkg -i $BUILDDIR/piaware_builder/piaware_2.1-3_*.deb

## CHECK THAT THE PACKAGE INSTALLED

if [ $(dpkg-query -W -f='${Status}' piaware 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    echo "\033[31m"
    echo "The piaware package did not install properly!"
    echo -e "\033[33m"
    echo "This script has exited due to the error encountered."
    echo "Please read over the above output in order to determine what went wrong."
    echo ""
    exit 1
fi

## CONFIGURE FLIGHTAWARE

echo -e "\033[33m"
echo "Please supply your FlightAware login in order to claim this device."
echo "After supplying your login PiAware will ask you to enter your password for verification."
echo -e "\033[37m"
read -p "Your FlightAware Login: " FALOGIN
sudo piaware-config -user $FALOGIN -password

echo -e "\033[33m"
echo "PiAware now sends MLAT results to port 30104 by default. This change is to try to avoid accidentally"
echo "feeding MLAT results to a Dump 1090 that is not MLAT-aware and may forward the results on unexpectedly."
echo "Dump 1090 from Mutability should be MLAT-aware meaning it should be safe to remap the MLAT port back to"
echo "it's original port number which saves having to manually configure Dump 1090 later if you decide you"
echo "would like to feed MLAT data to Dump 1090. This choice is left up to you."
echo -e "\033[37m"
read -p "Remap the MLAT port to 30004 in PiAware?: [Y/n] " MLATPORT

if [[ ! $CONTINUE =~ ^[Nn]$ ]]; then
    echo -e "\033[33m"
    printf "Remapping MLAT results to use port 30004..."
    sudo piaware-config -mlatResultsFormat beast,connect,localhost:30004
    echo -e "\033[32m [OK]"
fi

echo -e "\e[33m"
echo "Restarting PiAware to ensure all changes are applied..."
echo -e "\033[37m"
sudo /etc/init.d/piaware restart

echo -e "\033[33m"
echo "Installation and configuration of PiAware is now complete."
echo "Please look over the output generated to be sure no errors were encountered."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

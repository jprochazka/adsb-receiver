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


########################################
# ADD PHANTOMJSVERSION TO VARIABLES.SH #
########################################


## VARIABLES

PROJECTROOTDIRECTORY="$PWD"
BUILDDIRECTORY="$PROJECTROOTDIRECTORY/build"
PHANTOMJSBUILDDIRECTORY="$BUILDDIRECTORY/phantomjs"

## INCLUDE EXTERNAL SCRIPTS

source $BASHDIRECTORY/variables.sh
source $BASHDIRECTORY/functions.sh

## BEGIN SETUP

clear
echo -e "\n\e[91m  $ADSB_PROJECTTITLE"
echo ""
echo -e "\e[92m  Setting up AboveTustin..."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo ""
whiptail --backtitle "$ADSB_PROJECTTITLE" --title "PiAware Setup" --yesno "AboveTustin is an ADS-B Twitter Bot. Uses dump1090-mutability to track airplanes and then tweets whenever an airplane flies overhead.\n\n  https://github.com/kevinabrandon/AboveTustin\n\nContinue setting up AboveTustin?" 13 78
CONTINUESETUP=$?
if [ $CONTINUESETUP = 1 ]; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  AboveTustin setup halted.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

ADDCONTRIB=""
BUILDPHANTOMJS=""
PHANTOMJSEXISTS="false"

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo ""
# These packages are only needed if the user decided to build PhantomJS.
CheckPackage build-essential
CheckPackage g++

# These ackages are required even if the user chooses to download the binary.
CheckPackage libstdc++6
CheckPackage glibc
CheckPackage flex
CheckPackage bison
CheckPackage gperf
CheckPackage ruby
CheckPackage perl
CheckPackage libsqlite3-dev
CheckPackage libfontconfig1
CheckPackage libfontconfig1-dev
CheckPackage libicu-dev
CheckPackage libfreetype6
CheckPackage libssl-dev
CheckPackage libpng-dev
CheckPackage libjpeg-dev
CheckPackage python
CheckPackage libx11-dev
CheckPackage libxext-dev

# The package ttf-mscorefonts-installer requires contrib be added to the repositories contained in /etc/apt/sources.list.
# This package appears to be optional but without it the images generated may not look as good.
if [ $ADDCONTRIB = "" ]; then

    # THIS LINE NEEDS TO BE CHANGED TO WORK ON ALL DEBIAN FLAVORS!!!
    sudo sed -i '/deb http:\/\/ftp.us.debian.org\/debian\/wheezy main/s/$/ contrib/' file.sh

    sudo apt-get update
    CheckPackage ttf-mscorefonts-installer
fi

## SETUP PHANTOMJS



# Check if the PhantomJS binary already exists and it is the correct version.
if [ -f /usr/bin/phantomjs ] && [ `/usr/bin/phantomjs --version` = $PHANTOMJSVERSION ]; then
    PHANTOMJSEXISTS="true"
fi

# DOWNLOAD THE PHANTOMJS BINARY

# BUILD PHANTOMJS

# Download the source code.
echo ""
echo -e "\e[95m  Preparing the PhantomJS Git repository...\e[97m"
echo ""
if [ -d $PHANTOMJSBUILDDIRECTORY ] && [ -d $PHANTOMJSBUILDDIRECTORY/.git ]; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the PhantomJS git repository directory...\e[97m"
    cd $PHANTOMJSBUILDDIRECTORY
    echo -e "\e[94m  Updating the local PhantomJS git repository...\e[97m"
    echo ""
    git pull --all
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
    cd $BUILDDIRECTORY
    echo -e "\e[94m  Cloning the PhantomJS git repository locally...\e[97m"
    echo ""
    git clone git://github.com/ariya/phantomjs.git
    echo ""
fi

if [ ! $PWD = $PHANTOMJSBUILDDIRECTORY ]; then
    echo -e "\e[94m  Entering the PhantomJS Git repository directory...\e[97m"
    cd $PHANTOMJSBUILDDIRECTORY
fi

echo -e "\e[94m  Checking out the branch $PHANTOMJSVERSION...\e[97m"
echo ""
git checkout $PHANTOMJSVERSION
echo ""
echo -e "\e[94m  Initializing Git submodules...\e[97m"
echo ""
git submodule init
echo ""
echo -e "\e[94m  Updating Git submodules...\e[97m"
echo ""
git submodule update

# Compile and link the code.
if [[ `uname -m` == "armv7l" ]] || [[ `uname -m` == "armv6l" ]] || [[ `uname -m` == "aarch64" ]]; then
    # Limit the amount of processors being used on Raspberry Pi devices.
    echo ""
    echo -e "\e[94m  Building PhantomJS... (Job has been limited to using only 2 processors.)\e[97m"
    python build.py -j 2
else
    echo ""
    echo -e "\e[94m  Building PhantomJS...\e[97m"
    python build.py
fi

# MOVE THE PHANTOMJS BINARY AND SET THE PROPER PERMISSIONS

echo ""
echo -e "\e[94m  Moving the phantomjs binary into the directory /usr/bin...\e[97m"
sudo cp phantomjs /usr/bin
echo -e "\e[94m  Making the phantomjs binary executable...\e[97m"
sudo chmod +x /usr/bin/phantomjs

## SETUP SELENIUM

sudo pip install -U selenium

## INSTALL THE PYTHON TWITTER PLUGIN

sudo pip install twitter

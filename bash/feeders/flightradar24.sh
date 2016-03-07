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

## VARIABLES

BUILDDIR=$PWD

source ../bash/variables.sh
source ../bash/functions.sh

## INFORMATIVE MESSAGE ABOUT THIS SOFTWARE

clear

echo -e "\033[31m"
echo "-----------------------------------------------------"
echo " Now ready to install the flightradar24 Pi24 Client."
echo "-----------------------------------------------------"
echo -e "\033[33mThe Flightradar24's Pi24 client can track flights within"
echo "200-400 miles and will automatically share data with Flightradar24. You"
echo "can track flights directly off your Pi24 device or via Flightradar24.com"
echo ""
echo "http://www.flightradar24.com/raspberry-pi"
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\033[33m"
echo "Installing packages needed to build and fulfill dependencies..."
echo -e "\033[37m"
if [[ `uname -m` == "x86_64" ]]; then
    if [[ `lsb_release -si` == "Debian" ]] && [ $(dpkg --print-foreign-architectures $1 2>/dev/null | grep -c "i386") -eq 0 ]; then
        echo -e "\033[33mAdding i386 Architecture..."
        sudo dpkg --add-architecture i386
        echo "Downloading latest package lists for enabled repositories and PPAs..."
        echo -e "\033[37m"
        sudo apt-get update
        echo ""
    fi
    CheckPackage libc6:i386
    CheckPackage libudev1:i386
    CheckPackage zlib1g:i386
    CheckPackage libusb-1.0-0:i386
    CheckPackage libstdc++6:i386:i386
else
    CheckPackage libc6
    CheckPackage libudev1
    CheckPackage zlib1g
    CheckPackage libusb-1.0-0
    CheckPackage libstdc++6
fi
CheckPackage wget


if [[ `uname -m` == "armv7l" ]]; then

    ## ARMV71 INSTALLATION

    echo -e "\033[31m"
    echo "------------------------------------------------------"
    echo " MAKE SURE TO READ THROUGH THE FOLLOWING INSTRUCTIONS"
    echo "------------------------------------------------------"
    echo -e "\033[33m"
    echo "This script will now download and execute the script provided by Flightradar24."
    echo "You will be asked for your email address, the latitude and longitude of your"
    echo "receiver as well as its altitude above sea level."
    echo ""
    echo "Latitude and longitude can be calculated by address by my website."
    echo "https://www.swiftbyte.com/toolbox/geocode"
    echo ""
    echo "As for distance abocve sea level I used heywhatsthat.com information."
    echo ""
    echo "once the Flightradar24 script has completed this script will once again take over."
    echo -e "\033[37m"
    read -p "Press enter to continue..." CONTINUE

    ## DOWNLOAD AND EXECUTE THE FLIGHTRADAR24 SCRIPT

    sudo bash -c "$(wget -O - http://repo.feed.flightradar24.com/install_fr24_rpi.sh)"

    ## START THE FLIGHTAWARE24 CLIENT

    echo -e "\033[33m"
    echo "Starting the flightradar24 feeder client..."
    echo -e "\033[37m"
    sudo service fr24feed start
else

    ## I386 INSTALLATION

    echo -e "\033[33m"
    echo "Downloading the Flightradar24 feeder client package..."
    echo -e "\033[37m"
    wget http://feed.flightradar24.com/linux/fr24feed_${FR24CLIENTVERSIONI386}_i386.deb -O $BUILDDIR/fr24feed_${FR24CLIENTVERSIONI386}_i386.deb

    echo -e "\033[33m"
    echo "Installing the Flightradar24 feeder client package..."
    echo -e "\033[37m"
    if [[ `lsb_release -si` == "Debian" ]]; then
        # Force architecture if this is Debian.
        sudo dpkg -i --force-architecture $BUILDDIR/fr24feed_${FR24CLIENTVERSIONI386}_i386.deb
    else
        sudo dpkg -i $BUILDDIR/fr24feed_${FR24CLIENTVERSIONI386}_i386.deb
    fi

    ## CHECK THAT THE PACKAGE INSTALLED

    if [ $(dpkg-query -W -f='${STATUS}' fr24feed 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo "\033[31m"
        echo "#########################################"
        echo "# INSTALLATION HALTED!                  #"
        echo "# UNABLE TO INSTALL A REQUIRED PACKAGE. #"
        echo "#########################################"
        echo ""
        echo "The fr24feed package did not install properly!"
        echo -e "\033[33m"
        echo "This script has exited due to the error encountered."
        echo "Please read over the above output in order to determine what went wrong."
        echo ""
        kill -9 `ps --pid $$ -oppid=`; exit
    fi
fi


## INSTALLATION COMPLETE

echo -e "\033[33m"
echo "Installation and configuration of flightradar24 feeder client is now complete."
echo "Please look over the output generated to be sure no errors were encountered."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

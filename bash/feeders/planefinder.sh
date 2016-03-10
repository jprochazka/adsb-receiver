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
echo " Now ready to install the Plane Finder ADS-B Client."
echo "-----------------------------------------------------"
echo -e "\033[33mThe Plane Finder ADS-B Client is an easy and accurate way"
echo "to share your ADS-B and MLAT data with Plane Finder. It comes with a"
echo "beautiful user interface that helps you explore and interact with your"
echo "data in realtime."
echo ""
echo "https://planefinder.net/sharing/client"
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
else
    CheckPackage libc6
fi
CheckPackage wget

## DOWNLOAD THE PLANEFINDER ADS-B CLIENT PACKAGE

echo -e "\033[33m"
echo "Downloading the Plane Finder ADS-B Client package..."
echo -e "\033[37m"
if [[ `uname -m` == "armv7l" ]] || [[ `uname -m` == "armv6l" ]]; then
    wget http://client.planefinder.net/pfclient_${PFCLIENTVERSIONARM}_armhf.deb -O $BUILDDIR/pfclient_${PFCLIENTVERSIONARM}_armhf.deb
else
    wget http://client.planefinder.net/pfclient_${PFCLIENTVERSIONI386}_i386.deb -O $BUILDDIR/pfclient_${PFCLIENTVERSIONI386}_i386.deb
fi

## INSTALL THE PLANEFINDER ADS-B CLIENT PACKAGE

echo -e "\033[33m"
echo "Installing the Plane Finder ADS-B Client package..."
echo -e "\033[37m"
if [[ `uname -m` == "armv7l" ]] || [[ `uname -m` == "armv6l" ]]; then
    sudo dpkg -i $BUILDDIR/pfclient_${PFCLIENTVERSIONARM}_armhf.deb
else
    if [[ `lsb_release -si` == "Debian" ]]; then
        # Force architecture if this is Debian.
        sudo dpkg -i --force-architecture $BUILDDIR/pfclient_${PFCLIENTVERSIONI386}_i386.deb
    else
        sudo dpkg -i $BUILDDIR/pfclient_${PFCLIENTVERSIONI386}_i386.deb
    fi
fi

## CHECK THAT THE PACKAGE INSTALLED

if [ $(dpkg-query -W -f='${STATUS}' pfclient 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    echo "\033[31m"
    echo "#########################################"
    echo "# INSTALLATION HALTED!                  #"
    echo "# UNABLE TO INSTALL A REQUIRED PACKAGE. #"
    echo "#########################################"
    echo ""
    echo "The pfclient package did not install properly!"
    echo -e "\033[33m"
    echo "This script has exited due to the error encountered."
    echo "Please read over the above output in order to determine what went wrong."
    echo ""
    kill -9 `ps --pid $$ -oppid=`; exit
fi

## DISPLAY FINAL SETUP INSTRUCTIONS WHICH CONNOT BE HANDLED BY THIS SCRIPT

echo -e "\033[31m"
echo "------------------------------------------------------"
echo " MAKE SURE TO READ THROUGH THE FOLLOWING INSTRUCTIONS"
echo "------------------------------------------------------"
echo -e "\033[33m"
echo "First off please look over the output generated to be sure no errors were encountered."
echo ""
echo "At this point the Plane Finder ADS-B Client should be installed and running however"
echo "This script is only capable of installing the Plane Finder ADS-B Client. There are still"
echo "a few steps left which you must manually do through the Plane Finder ADS-B Client itself"
echo ""
echo "Visit http://${HOSTNAME}:30053 in your favorite web browser."
echo ""
echo "You will be asked to enter the email address associated with your Plane Finder account."
echo "You will also be asked to enter the latitude and longitude of your receiver."
echo "If you do not know the coordinates you can look them up using one of two page I created to do so."
echo ""
echo "To look up coordinates using a street address goto https://www.swiftbyte.com/toolbox/geocode."
echo "To look up coordinates using your IP address goto https://www.swiftbyte.com/toolbox/myip."
echo ""
echo "Once this information has been entered and submitted your share code will be emailed to you."
echo ""
echo "Next you will also be asked to choose the data format to use as well as network information"
echo "pertaining to Dump 1090. THe following is the information which should be supplied."
echo ""
echo "Data Format: Beast"
echo "Tcp Address: 127.0.0.1"
echo "Tcp Port:    30005"
echo ""
echo "After entering this information click the complete configuration button to do exactly that."
echo "Once you have successfully completed these steps you can continue on with the installation"
echo "of any other features you have choosen for this set of scripts to install."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

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
function CheckPackage(){
    printf "\e[33mChecking if the package $1 is installed..."
    if [ $(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo -e "\033[31m [NOT INSTALLED]\033[37m"
        echo -e "\033[33mInstalling the package $1 and it's dependancies..."
        echo -e "\033[37m"
        sudo apt-get install -y $1;
        echo ""
        echo -e "\033[33mThe package $1 has been installed."
    else
        echo -e "\033[32m [OK]\033[37m"
    fi
}

clear

echo -e "\033[31m"
echo "-------------------------------------------"
echo " Now ready to install dump1090-mutability."
echo "-------------------------------------------"
echo -e "\033[33mDump 1090 is a Mode S decoder specifically designed for RTLSDR devices."
echo "Dump1090-mutability is a fork of MalcolmRobb's version of dump1090 that adds new"
echo "functionality and is designed to be built as a Debian/Raspbian package."
echo ""
echo "https://github.com/mutability/dump1090"
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\033[33m"
echo "Installing packages needed to build and fulfill dependencies..."
echo -e "\033[37m"
CheckPackage git
CheckPackage curl
CheckPackage build-essential
CheckPackage debhelper
CheckPackage librtlsdr-dev
CheckPackage libusb-1.0-0-dev
CheckPackage pkg-config
CheckPackage lighttpd

## DOWNLOAD THE DUMP1090-MUTABILITY SOURCE

echo -e "\033[33m"
echo "Downloading the source code for dump1090-mutability..."
echo -e "\033[37m"
git clone https://github.com/mutability/dump1090.git

## BUILD THE DUMP1090-MUTABILITY PACKAGE

echo -e "\033[33m"
echo "Building the dump1090-mutability package..."
echo -e "\033[37m"
cd $BUILDDIR/dump1090
dpkg-buildpackage -b

## INSTALL THE DUMP1090-MUTABILITY PACKAGE

echo -e "\033[33m"
echo "Installing the dump1090-mutability package..."
echo -e "\033[37m"
cd $BUILDDIR
sudo dpkg -i dump1090-mutability_1.15~dev_*.deb

## START DUMP1090-MUTABILITY

echo -e "\033[33m"
echo "Starting dump1090-mutability..."
echo -e "\033[37m"
sudo /etc/init.d/dump1090-mutability start

## CONFIGURE LIGHTTPD

echo -e "\033[33m"
echo "Configuring lighttpd..."
echo -e "\033[37m"
sudo lighty-enable-mod dump1090
sudo /etc/init.d/lighttpd force-reload

## START DUMP1090-MUTABILITY

echo -e "\033[33m"
echo "Startng dump1090-mutability..."
echo -e "\033[37m"
sudo /etc/init.d/dump1090-mutability start

## DISPLAY MESSAGE STATING DUMP1090-MUTABILITY SETUP IS COMPLETE

echo -e "\033[33m"
echo "Installation of dump-1090-mutability is now complete."
echo "Please look over the output generated to be sure no errors were encountered."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

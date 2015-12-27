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
CheckPackage rtl-sdr
CheckPackage librtlsdr-dev
CheckPackage libusb-1.0-0-dev
CheckPackage pkg-config
CheckPackage lighttpd

## DOWNLOAD OR UPDATE THE DUMP1090-MUTABILITY SOURCE

# Check if the git repository already exists locally.
if [ -d "$BUILDDIR/dump1090" ] && [ -d $BUILDDIR/dump1090/.git ]; then
    # A directory with a git repository containing the source code exists.
    echo -e "\033[33m"
    echo "Updating the local dump1090-mutability git repository..."
    echo -e "\033[37m"
    cd $BUILDDIR/dump1090
    git pull origin master
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\033[33m"
    echo "Cloning the dump1090-mutability git repository locally..."
    echo -e "\033[37m"
    git clone https://github.com/mutability/dump1090.git
fi

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

## CHECK THAT THE PACKAGE INSTALLED

if [ $(dpkg-query -W -f='${Status}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    echo "\033[31m"
    echo "The dump1090-mutability package did not install properly!"
    echo -e "\033[33m"
    echo "This script has exited due to the error encountered."
    echo "Please read over the above output in order to determine what went wrong."
    echo ""
    exit 1
fi

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

## HEYWHATSTHAT.COM TERRAIN LIMIT RINGS

echo -e "\033[33m"
echo "Dump1090-mutability is able to display terrain limit rings using data obtained."
echo "from the website http://www.heywhatsthat.com. Some work will be required on your"
echo "part including visiting http://www.heywhatsthat.com and generating a new"
echo "panorama set to your location."
echo -e "\033[37m"
read -p "Do you wish to add terrain limit rings to the dump1090 map? [Y/n] " ADDTERRAINRINGS

if [[ ! $ADDTERRAINRINGS =~ ^[Nn]$ ]]; then 
    echo -e "\033[31m"
    echo "READ THE FOLLOWING INSTRUCTION CAREFULLY!"
    echo ""
    echo -e "\033[33m"
    echo "To set up terrain limit rings you will need to first generate a panorama on the website"
    echo "heywhatsthat.com. To do so visit the following URL:"
    echo ""
    echo "  http://www.heywhatsthat.com"
    echo ""
    echo "Once the webpage has loaded click on the tab titled New panorama. Fill out the required"
    echo "information in the form to the left of the map."
    echo ""
    echo "After submitting the form your request will be put into a queue to be generated shortly."
    echo "You will be informed when the generation of your panorama has been completed."
    echo ""
    echo "Once generated visit your newly created panorama. Near the top left of the page you will"
    echo "see a URL displayed which will point you to your newly created panorama. Within this URL's"
    echo "query string you will see ?view=XXXXXXXX where XXXXXXXX is the identifier for this panorama."
    echo "Enter below the letters and numbers making up the view identifier displayed there."
    echo ""
    echo "Positions for terrain rings for both 10,000 and 40,000 feet will be downloaded by this"
    echo "script once the panorama has been generated and you are ready to continue."
    echo -e "\033[37m"
    read -p "Your heywhatsthat.com view identifier: " HEYWHATSTHATVIEWID

    # Download the generated panoramas JSON data.
    echo -e "\033[33m"
    echo "Downloading JSON data pertaining to the panorama ID you supplied..."
    echo -e "\033[37m"
    sudo wget -O /usr/share/dump1090-mutability/html/upintheair.json "http://www.heywhatsthat.com/api/upintheair.json?id=${HEYWHATSTHATVIEWID}&refraction=0.25&alts=3048,12192"
fi

## DISPLAY MESSAGE STATING DUMP1090-MUTABILITY SETUP IS COMPLETE

echo -e "\033[33m"
echo "Installation of dump-1090-mutability is now complete."
echo "Please look over the output generated to be sure no errors were encountered."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

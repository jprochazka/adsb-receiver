#!/bin/bash

#####################################################################################
#                                   ADS-B FEEDER                                    #
#####################################################################################
#                                                                                   #
#  A set of scripts created to automate the process of installing the software      #
#  needed to setup a Mode S decoder as well as feeders which are capable of         #
#  sharing your ADS-B results with many of the most popular ADS-B aggregate sites.  #
#                                                                                   #
#  Project Hosted On GitHub: https://github.com/jprochazka/adsb-feeder              #
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

SCRIPTDIR=${PWD}

## FUNCTIONS

# Function used to check if a package is install and if not install it.
function CheckPackage(){
    printf "\e[33mChecking if the package $1 is installed..."
    if [ $(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo -e "\033[31m [NOT INSTALLED]\033[37m"
        echo -e "\033[33mInstalling the package $1..."
        echo -e "\033[37m"
        sudo apt-get install -y $1;
        echo ""
        echo -e "\033[33mThe package $1 has been installed."
    else
        echo -e "\033[32m [OK]\033[37m"
    fi
}

clear

## DISPLAY INSTALLATION OPTIONS

echo -e "\033[31m"
echo "##################################"
echo "     ADS-B Feeder Installation    "
echo "##################################"
echo -e "\033[33m"
echo "  MODE S DECODER SELECTION"
echo ""
echo "It is recommended that dump1090-mutability be selected as your mode s decoder."
echo "However you are more than welcome to choose to install the MalcolmRobb version is you so desire."
echo "If the MalcolmRobb version is selected not all installation features will be available to you."
echo ""
echo "Dump1090 (mutability):  https://github.com/mutability/dump1090"
echo "Dump1090 (MalcolmRobb): https://github.com/MalcolmRobb/dump1090"
echo ""
echo "  1) Dump1090 (mutability)"
echo "  2) Dump1090 (MalcolmRobb)"
echo "  3) Exit"
echo -e "\033[37m"
read -r -p "Choose an installation option. [1] " DECODER

# If option 3 (Exit) was selected exit this script.
if [[ $DECODER == '3' ]]; then
    clear
    echo ""
    echo "Installation exited."
    echo ""
    exit
fi

clear

echo -e "\033[31m"
echo "##################################"
echo "     ADS-B Feeder Installation    "
echo "##################################"
echo -e "\033[33m"
echo "  DATA SHARING OPTIONS"
echo ""
echo "Please select the site with which you wish to share the data collected by your new ADS-B feeder."
echo "This script will setup the software needed to feed the selected sites during this installation."
echo ""
echo "FlightAware:    http://flightaware.com/"
echo "Plane Finder:   https://planefinder.net"
echo "ADS-B Exchange: http://adsbexchange.com/"
echo ""
echo "  1) Share data with FlightAware."
echo "  2) Share data with Plane Finder."
echo "  3) Share data with FlightAware and Plane Finder."
echo "  4) Share data with FlightAware and ADS-B Exchange."
echo "  5) Share data with FlightAware, Plane Finder and ADS-B Exchange."
echo "  6) Do not share data with any external sites."
echo "  7) Exit"
echo -e "\033[37m"
read -r -p "Choose an installation option. [1] " FEED

# If option 7 (Exit) was selected exit this script.
if [[ $FEED == '7' ]]; then
    clear
    echo ""
    echo "Installation exited."
    echo ""
    exit
fi

clear

# If the MalcolmRobb version of Dump1090 was selected skip additional features.
if [[ $DECODER != '2' ]]; then

    echo -e "\033[31m"
    echo "##################################"
    echo "     ADS-B Feeder Installation    "
    echo "##################################"
    echo -e "\033[33m"
    echo "  ADDITIONAL FEATURES"
    echo ""
    echo "This script is capable of installing a few additional features of it's own."
    echo "Below is a list of additional features currently available for installation by this script."
    echo "Look for more features to be added in the near future!"
    echo ""
    echo "The ADS-B Feeder Project:  https://github.com/jprochazka/adsb-feeder"
    echo ""
    echo "  1) Install web based performance graphs."
    echo "  2) Do not install any additional features."
    echo "  3) Exit"
    echo -e "\033[37m"
    read -r -p "Choose an installation option. [1] " FEATURES

    # If option 3 (Exit) was selected exit this script.
    if [[ $FEATURES == '3' ]]; then
        clear
        echo ""
        echo "Installation exited."
        echo ""
        exit
    fi

    clear

fi

## EXPLAIN WHAT IS TO BE DONE

echo -e "\033[31m"
echo "-------------------------------------"
echo " Installation is now ready to begin."
echo "-------------------------------------"
echo -e "\033[33mThe following will be installed or configured on this system."
echo ""
if [[ $DECODER == '' ]] || [[ $DECODER == '1' ]]; then echo "  Dump 1090 (mutability):        https://github.com/mutability/dump1090"; fi
if [[ $DECODER == '2' ]]; then echo "  Dump 1090 (MalcolmRobb):       https://github.com/MalcolmRobb/dump1090"; fi
if [[ $FEED == '' ]] || [[ $FEED == '1' ]] || [[ $FEED == '3' ]] || [[ $FEED == '4' ]] || [[ $FEED == '5' ]]; then echo "  PiAware by FlightAware:        https://github.com/flightaware/piaware"; fi
if [[ $FEED == '2' ]] || [[ $FEED == '3' ]] || [[ $FEED == '5' ]]; then echo "  Plane Finder ADS-B Client:     https://planefinder.net/sharing/client"; fi
if [[ $FEED == '4' ]] || [[ $FEED == '5' ]]; then echo "  ADS-B Exchange via PiAware:    http://www.adsbexchange.com/how-to-feed/"; fi
if [[ $FEATURES == '' ]] || [[ $FEATURES == "1" ]]; then echo "  Collectd Graphs for Dump1090:  https://github.com/jprochazka/adsb-feeder"; fi
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

clear

BUILDDIR="$SCRIPTDIR/build"

## GET THE LATEST LISTS OF PACKAGES AVAILABLE IN REPOSITORIES AND PPAS

echo -e "\033[33m"
echo "Downloading latest package lists for enabled repositories and PPAs..."
echo -e "\033[37m"
sudo apt-get update

clear

## ASK IF THE USER WISHES TO UPDATE THIER SYSTEM AT THIS TIME

echo -e "\033[31m"
echo "-------------------------------------"
echo " Check for system updates."
echo "-------------------------------------"
echo -e "\033[33mIt is recommended that you update your system before continuing the installation."
echo "This script can do this for you at this time if you like."
echo -e "\033[37m"
read -p "Update system before continuing installation? [Y/n] " UPDATE

if [[ ! $UPDATE =~ ^[Nn]$ ]]; then

    ## UPDATE INSTALLED PACKAGES

    # Install any available updates using the command apt-get update.
    echo -e "\033[33m"
    echo "Downloading and installing the latest updates for your operating system..."
    echo -e "\033[37m"
    sudo apt-get -y upgrade
    echo -e "\033[33m"
    echo "Your system should now be up to date."
    echo -e "\033[37m"
    read -p "Press enter to continue..." CONTINUE

    ## UPDATE THIS RASPBERRY PI FIRMWARE IF THE USER APPROVES THIS STEP

    if [[ `uname -m` == "armv7l" ]]; then

        clear

        # Ask the user if this is running on a Raspberry Pi and if so do they want to update it's firmware.
        echo -e "\033[31m"
        echo "-------------------------------------"
        echo " Check for firmware updates."
        echo "-------------------------------------"
        echo -e "\033[33mIf this is a Raspberry Pi this script can update the firmware now as well."
        echo "If you choose to update your Raspberry Pi firmware this script will check for the existance"
        echo "of the package rpi-update and install it if it is not install already. After confirming that"
        echo "rpi-update is installed it will be used to update your firmware."
        echo -e "\033[37m"
        read -p "Is this a Raspberry Pi and if so do you want to update the firmware now? [y/N] " FIRMWARE

        # If the user chose yes check for and install the package rpi-update and use it to update this devices firmware.
        if [[ $FIRMWARE =~ ^[Yy]$ ]]; then

            CheckPackage rpi-update
            echo -e "\033[33m"
            echo "Updating Raspberry Pi firmware..."
            echo -e "\033[37m"
            sudo rpi-update
            echo -e "\033[33m"
            echo "Your Raspberry Pi firmware is now up to date."
            echo "If in fact your firmware was update it is recommended that you restart your device now."
            echo "After the reboot execute this script again to enter the installation process once more."
            echo -e "\033[37m"
            read -p "Would you like to reboot your device now? [y/N] " REBOOT

	    if [[ $REBOOT =~ ^[Yy]$ ]]; then
                sudo reboot
            fi
        fi
    fi
fi

clear

#####################
## MODE S DECODERS
##

## INSTALL DUMP1090-MUTABILITY

if [[ $DECODER == '' ]] || [[ $DECODER == '1' ]]; then

    cd $BUILDDIR

    echo -e "\033[33mExecuting the dump1090-mutability installation script..."
    echo -e "\033[37m"
    chmod 755 $SCRIPTDIR/bash/decoders/dump1090-mutability.sh
    $SCRIPTDIR/bash/decoders/dump1090-mutability.sh

    clear

fi

## INSTALL DUMP1090-MALCOLMROBB

if [[ $DECODER == '2' ]]; then

    cd $BUILDDIR

    echo -e "\033[33mExecuting the dump1090-MalcolmRobb installation script..."
    echo -e "\033[37m"
    chmod 755 $SCRIPTDIR/bash/decoders/dump1090-malcolmrobb.sh
    $SCRIPTDIR/bash/decoders/dump1090-malcolmrobb.sh

    clear

fi

clear

##################
## SITE FEEDERS
##

## INSTALL PIAWARE

if [[ $FEED == '' ]] || [[ $FEED == '1' ]] || [[ $FEED == '3' ]] || [[ $FEED == '4' ]] || [[ $FEED == '5' ]]; then

    cd $BUILDDIR

    echo -e "\033[33mExecuting the PiAware installation script..."
    echo -e "\033[37m"
    chmod 755 $SCRIPTDIR/bash/feeders/piaware.sh
    $SCRIPTDIR/bash/feeders/piaware.sh

fi

## INSTALL THE PLANE FINDER ADS-B CLIENT

if [[ $FEED == '2' ]] || [[ $FEED == '3' ]] || [[ $FEED == '5' ]]; then

    cd $BUILDDIR

    echo -e "\033[33mExecuting the Plane Finder ADS=B Client installation script..."
    echo -e "\033[37m"
    chmod 755 $SCRIPTDIR/bash/feeders/planefinder.sh
    $SCRIPTDIR/bash/feeders/planefinder.sh

fi

## FEED ADS-B EXCHANGE USING PIAWARE

if [[ $FEED == '4' ]] || [[ $FEED == '5' ]]; then

    cd $BUILDDIR

    echo -e "\033[33mExecuting the ADS-B Exchange installation script..."
    echo -e "\033[37m"
    chmod 755 $SCRIPTDIR/bash/feeders/adsbexchange.sh
    $SCRIPTDIR/bash/feeders/adsbexchange.sh

fi

#########################
## ADDITIONAL FEATURES
##

## INSTALL AND CONFIGURE COLLECTD AND GRAPH MAKER

if [[ $FEATURES == '' ]] || [[ $FEATURES == '1' ]]; then

    cd $BUILDDIR

    echo -e "\033[33mExecuting the collectd installation script..."
    echo -e "\033[37m"
    chmod 755 $SCRIPTDIR/bash/features/collectd.sh
    $SCRIPTDIR/bash/features/collectd.sh

    clear

fi

## SAY GOODBYE AND EXIT THE SCRIPT

cd $PWD

clear

echo -e "\033[31m"
echo "##################################"
echo "     ADS-B Feeder Installation    "
echo "##################################"
echo -e "\033[33m"
echo "  INSTALLATION COMPLETE"
echo ""
echo "I hope you enjoyed using this software to install and configure your new or revialized ADS-B feeder."
echo "If you ran into any issues using this script feel free to report them on the project site hosted on GitHub."
echo ""
echo "https://github.com/jprochazka/adsb-feeder."
echo ""
echo "Good luck and happy tracking!"
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

clear

exit

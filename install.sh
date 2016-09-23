#!/bin/bash

#####################################################################################
#                                   ADS-B RECEIVER                                  #
#####################################################################################
#                                                                                   #
#  A set of scripts created to automate the process of installing the software      #
#  needed to setup a Mode S decoder as well as feeders which are capable of         #
#  sharing your ADS-B results with many of the most popular ADS-B aggregate sites.  #
#                                                                                   #
#  Project Hosted On GitHub: https://github.com/jprochazka/adsb-receiver            #
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

## INCLUDE EXTERNAL SCRIPTS

source $BASHDIRECTORY/variables.sh
source $BASHDIRECTORY/functions.sh

## MORE VARIABLES

export ADSB_PROJECTTITLE="The ADS-B Receiver Project v$PROJECTVERSION"
TERMINATEDMESSAGE="\e[91m  ANY FURTHER SETUP AND/OR INSTALLATION REQUESTS HAVE BEEN TERMINIATED\e[39m"

## CHECK IF THIS IS THE FIRST RUN USING THE IMAGE RELEASE

if [ -f $PROJECTROOTDIRECTORY/image ]; then
    # Execute image setup script..
    chmod +x $BASHDIRECTORY/image.sh
    $BASHDIRECTORY/image.sh
    if [ $? -ne 0 ]; then
        echo ""
        echo -e $TERMINATEDMESSAGE
        echo ""
        exit 1
    fi
    exit 0
fi

## FUNCTIONS

# UPDATE REPOSITORY PACKAGE LISTS
function AptUpdate() {
    clear
    echo -e "\n\e[91m  $ADSB_PROJECTTITLE"
    echo ""
    echo -e "\e[92m  Downloading the latest package lists for all enabled repositories and PPAs..."
    echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[97m"
    echo ""
    sudo apt-get update
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  Finished downloading and updating package lists.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
}

function CheckWhiptail() {
    clear
    echo -e "\n\e[91m  $ADSB_PROJECTTITLE"
    echo ""
    echo -e "\e[92m  Checking to make sure the whiptail package is installed..."
    echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[97m"
    echo ""
    CheckPackage whiptail
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  The whiptail package is installed.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
}


function UpdateRepository() {
## UPDATE THIS REPOSITORY
    clear
    echo -e "\n\e[91m  $ADSB_PROJECTTITLE"
    echo ""
    echo -e "\e[92m  Pulling the latest version of the ADS-B Receiver Project repository..."
    echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[97m"
    echo ""
    CheckPackage git
    echo -e "\e[94m  Pulling the latest git repository...\e[97m"
    echo ""
    git pull
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  Finished pulling the latest version of the ADS-B Receiver Project repository....\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
}

# UPDATE THE OPERATING SYSTEM
function UpdateOperatingSystem() {
    clear
    echo -e "\n\e[91m  $ADSB_PROJECTTITLE"
    echo ""
    echo -e "\e[92m  Downloading and installing the latest updates for your operating system..."
    echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[97m"
    echo ""
    sudo apt-get -y dist-upgrade
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  Your operating system should now be up to date.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
}

AptUpdate
CheckWhiptail
UpdateRepository

## DISPLAY WELCOME SCREEN

## ASK IF OPERATING SYSTEM SHOULD BE UPDATED

if (whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Bind Dump1090-mutability To All IP Addresses" --defaultno --yesno "It is recommended that you update your system before building and/or installing any ADS-B receiver related packages. This script can do this for you at this time if you like.\n\nWould you like to update your operating system now?" 11 78) then
    UpdateOperatingSystem
fi

## EXECUTE BASH/MAIN.SH

#chmod +x $BASHDIRECTORY/main.sh
#$BASHDIRECTORY/main.sh
#if [ $? -ne 0 ]; then
#    echo ""
#    echo -e $TERMINATEDMESSAGE
#    echo ""
#    exit 1
#fi

## INSTALLATION COMPLETE

# Display the installation complete message box.
whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Software Installation Complete" --msgbox "INSTALLATION COMPLETE\n\nDO NOT DELETE THIS DIRECTORY!\n\nFiles needed for certain items to run properly are contained within this directory. Deleting this directory may result in your receiver not working properly.\n\nHopefully, these scripts and files were found useful while setting up your ADS-B Receiver. Feedback regarding this software is always welcome. If you have any issues or wish to submit feedback, feel free to do so on GitHub.\n\nhttps://github.com/jprochazka/adsb-receiver" 20 65

# Unset any exported variables.
unset ADSB_PROJECTTITLE

# Remove the FEEDERCHOICES file created by whiptail.
rm -f FEEDERCHOICES

echo -e "\033[32m"
echo "Installation complete."
echo -e "\033[37m"

exit 0

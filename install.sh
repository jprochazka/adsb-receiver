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

##############
## VARIABLES

SCRIPTDIR=${PWD}
BUILDDIR="$SCRIPTDIR/build"


##############
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

# Download the latest package lists for enabled repositories and PPAs.
function AptUpdate() {
    clear
    echo -e "\033[33m"
    echo "Downloading latest package lists for enabled repositories and PPAs..."
    echo -e "\033[37m"
    sudo apt-get update
}

# Update the operating system.
function UpdateOperatingSystem() {
    clear
    echo -e "\033[33m"
    echo "Downloading and installing the latest updates for your operating system..."
    echo -e "\033[37m"
    sudo apt-get -y upgrade
    echo -e "\033[33m"
    echo "Your system should now be up to date."
    echo -e "\033[37m"
    read -p "Press enter to continue..." CONTINUE
}

# Update Raspberry Pi firmware.
function UpdateFirmware() {
    clear
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
}

# Download, build and then install the dump1090-mutability package.
function InstallDump1090() {
    clear
    cd $BUILDDIR
    echo -e "\033[33mExecuting the dump1090-mutability installation script..."
    echo -e "\033[37m"
    chmod +x $SCRIPTDIR/bash/decoders/dump1090-mutability.sh
    $SCRIPTDIR/bash/decoders/dump1090-mutability.sh
}

# Download, build and then install the PiAware package.
function InstallPiAware() {
    clear
    cd $BUILDDIR
    echo -e "\033[33mExecuting the PiAware installation script..."
    echo -e "\033[37m"
    chmod +x $SCRIPTDIR/bash/feeders/piaware.sh
    $SCRIPTDIR/bash/feeders/piaware.sh
}

# Download and install the Plane Finder ADS-B Client package.
function InstallPlaneFinder() {
    clear
    cd $BUILDDIR
    echo -e "\033[33mExecuting the Plane Finder ADS-B Client installation script..."
    echo -e "\033[37m"
    chmod +x $SCRIPTDIR/bash/feeders/planefinder.sh
    $SCRIPTDIR/bash/feeders/planefinder.sh
}

# Setup the ADS-B Exchange feed.
function InstallAdsbExchange() {
    clear
    cd $BUILDDIR
    echo -e "\033[33mExecuting the ADS-B Exchange installation script..."
    echo -e "\033[37m"
    chmod +x $SCRIPTDIR/bash/feeders/adsbexchange.sh
    $SCRIPTDIR/bash/feeders/adsbexchange.sh
}

# Setup and execute the web portal installation scripts.
function InstallWebportal() {
    clear
    cd $SCRIPTDIR
    echo -e "\033[33mExecuting the web portal installation scripts..."
    echo -e "\033[37m"
    chmod +x $SCRIPTDIR/bash/portal/install.sh
    $SCRIPTDIR/bash/portal/install.sh
}


#############
## WHIPTAIL

##
## MESSAGES
##

# The title of the installer.
BACKTITLE="The ADS-B Feeder Project"

# The welcome message displayed when this scrip[t it first executed.
read -d '' WELCOME <<"EOF"
The ADS-B Project is a series of bash scripts and files which can be used to setup an ADS-B feeder on certain Debian derived operating system.

More information on the project can be found on GitHub.
https://github.com/jprochazka/adsb-feeder

Would you like to continue setup?
EOF

# Message displayed asking to update the operating system.
read -d '' UPDATEFIRST <<"EOF"
It is recommended that you update your system before building and/or installing any ADS-B feeder related packages. This script can do this for you at this time if you like.

Update system before installing any ADS-B feeder related software?
EOF

# Message displayed asking to update the Raspberry Pi firmware.
read -d '' UPDATEFIRMWAREFIRST <<"EOF"
This script has detected that this may be a Raspberry Pi. If this is in fact a Raspberry Pi this script can update the system's firmware now as well.

If you choose to update your Raspberry Pi firmware this script will check for the existance of the package rpi-update and install it if it is not install already. After confirming that rpi-update is installed it will be used to update your firmware.

Is this in fact a Raspberry Pi and if so do you want to update
the firmware now? (This will require a reboot.)
EOF

# Message displayed if dump1090-mutability is installed.
read -d '' DUMP1090INSTALLED <<"EOF"
The dump1090-mutability package appears to be installed on your system. Mode S decoder setup will be skipped.
EOF

# Message displayed if dump1090-mutability is not installed.
read -d '' DUMP1090NOTINSTALLED <<"EOF"
The dump1090-mutability package does not appear to be installed on your system. In order to continue setup dump1090-mutability will be downloaded, compiled and installed on this system.

Do you wish to continue setup?
Answering no will exit this script with no actions taken.
EOF

# Message displayed above feeder selection check list.
FEEDERSAVAILABLE="The following feeders are available for installation. Choose the feeders you wish to install."

# Message displayed asking if the user wishes to install the web portal.
read -d '' INSTALLWEBPORTAL <<"EOF"
The ADS-B Feeder Project Web Portal is a light weight web interface for dump-1090-mutability installations.

Current features include the following:
  Unified navigation between all web pages.
  System and dump1090 performance graphs.

Would you like to install the ADS-B Feeder Project web portal on this device?
EOF

# Message displayed once installation has been completed.
read -d '' INSTALLATIONCOMPLETE <<"EOF"
INSTALLATION COMPLETE

It is hoped these scripts and files were found useful while setting up your ADS-B Feeder. Feedback reguarding this software is always welcome. If you ran into and problems or wish to submit feed back feel free to do so on the project's GitHub site.

https://github.com/jprochazka/adsb-feeder
EOF

##
## DIALOGS
##

# Display the welcome message.
whiptail --backtitle "$BACKTITLE" --title "The ADS-B Feeder Project" --msgbox "$WELCOME" 16 65

# Ask to update the operating system.
whiptail --backtitle "$BACKTITLE" --title "Install Operating System Updates" --yesno "$UPDATEFIRST" 10 65
UPDATEOS=$?

# Ask to update the Raspberry Pi firmware.
UPDATEFIRMWARENOW=1
if [[ `uname -m` == "armv7l" ]]; then
    whiptail --backtitle "$BACKTITLE" --title "Update Raspberry Pi Firmware" --yesno "$UPDATEFIRMWAREFIRST" 10 65
    UPDATEFIRMWARENOW=$?
fi

## DUMP1090-MUTABILITY CHECK

DUMP1090CHOICE=1
# Check if the dump1090-mutability package is installed.
if [ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
    # The dump1090-mutability package appear to be installed.
    # A version check will be added here as well at a later date to enable upgrades.
    whiptail --backtitle "$BACKTITLE" --title "Dump1090-mutability Installed" --msgbox "$DUMP1090INSTALLED" 10 65
else
    whiptail --backtitle "$BACKTITLE" --title "Dump1090-mutability Not Installed" --yesno "$DUMP1090NOTINSTALLED" 10 65
    DUMP1090CHOICE=$?
    if [ $DUMP1090CHOICE = 1 ]; then
        # If the user decided not to install dump1090-mutability exit setup.
        echo -e "\033[31m"
        echo "Installation cancelled by user."
        echo -e "\033[37m"
        exit 0
    fi
fi

## FEEDER OPTIONS

declare array FEEDERLIST

# Check if the PiAware package is installed.
if [ $(dpkg-query -W -f='${STATUS}' piaware 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    # The PiAware package appear to be installed.
    # A version check will be added here as well at a later date to enable upgrades.
    FEEDERLIST=("${FEEDERLIST[@]}" 'FlightAware PiAware' '' OFF)
fi

# Check if the Plane Finder ADS-B Client package is installed.
if [ $(dpkg-query -W -f='${STATUS}' piaware 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    # The Plane Finder ADS-B Client package appear to be installed.
    # A version check will be added here as well at a later date to enable upgrades.
    FEEDERLIST=("${FEEDERLIST[@]}" 'Plane Finder ADS-B Client' '' OFF)
fi

# Check if ADS-B Exchange sharing has been set up.
if ! grep -Fxq "${SCRIPTPATH}/adsbexchange-maint.sh &" /etc/rc.local; then
    # The ADS-B Exchange maintainance script does not appear to be executed on start up.
    FEEDERLIST=("${FEEDERLIST[@]}" 'ADS-B Exchange Script' '' OFF)
fi

declare FEEDERCHOICES

if [[ -n "$FEEDERLIST" ]]; then
    # Display a checklist containing feeders that are not installed if any.
    # This command is creating a file named FEEDERCHOICES but can not fiogure out how to make it only a variable without the file being created at this time.
    whiptail --title "$TITLE" --checklist --nocancel --separate-output "$FEEDERSAVAILABLE" 13 42 3 "${FEEDERLIST[@]}" 2>FEEDERCHOICES
fi

## WEB PORTAL

# Ask if the web portal should be installed.
whiptail --backtitle "$BACKTITLE" --title "Install The ADS-B Feeder Project Web Portal" --yesno "$INSTALLWEBPORTAL" 8 78
DOINSTALLWEBPORTAL=$?

## CONFIRMATION

CONFIRMATION="The following software will be installed:\n"

if [ $DUMP1090CHOICE = 0 ]; then
    CONFIRMATION="${CONFIRMATION}\n  * dump1090-mutability"
fi

while read FEEDERCHOICE
do
    case $FEEDERCHOICE in
        "FlightAware PiAware") CONFIRMATION="${CONFIRMATION}\n  * FlightAware PiAware"
        ;;
        "Plane Finder ADS-B Client") CONFIRMATION="${CONFIRMATION}\n  * Plane Finder ADS-B Client"
        ;;
        "ADS-B Exchange Script") CONFIRMATION="${CONFIRMATION}\n  * ADS-B Exchange Script"
        ;;
    esac
done < FEEDERCHOICES

if [ $DOINSTALLWEBPORTAL = 0 ]; then
    CONFIRMATION="${CONFIRMATION}\n  * ADS-B Feeder Project Web Portal"
fi

CONFIRMATION="${CONFIRMATION}\n\nDo you wish to continue with the installation of this software?"

whiptail --backtitle "$BACKTITLE" --title "Confirm You Wish To Continue" --yesno "$CONFIRMATION" 15 78
CONFIRMATION=$?

if [ $CONFIRMATION = 1 ]; then
    echo -e "\033[31m"
    echo "Installation cancelled by user."
    echo -e "\033[37m"

    # Dirty hack but cannot make the whiptail checkbox not create this file and still work...
    # Will work on figuring this out at a later date so until then we will delete the file it created.
    rm -f FEEDERCHOICES

    exit 0
fi


################
## BEGIN SETUP

## System updates.

AptUpdate

if [ $UPDATEOS = 0 ]; then
    UpdateOperatingSystem
fi

if [ $UPDATEFIRMWARENOW == 0 ]; then
    UpdateFirmware
fi

## Mode S decoder.

if [ $DUMP1090CHOICE == 0 ]; then
    InstallDump1090
fi

## Feeders.

while read FEEDERCHOICE
do
    case $FEEDERCHOICE in
        "FlightAware PiAware") InstallPiAware
        ;;
        "Plane Finder ADS-B Client") InstallPlaneFinder
        ;;
        "ADS-B Exchange Script") InstallAdsbExchange
        ;;
    esac
done < FEEDERCHOICES

## Web portal.

if [ $DOINSTALLWEBPORTAL = 0 ]; then
    InstallWebPortal
fi


##########################
## INSTALLATION COMPLETE

# Display the installation complete message box.
whiptail --backtitle "$BACKTITLE" --title "Software Installation Complete" --msgbox "$INSTALLATIONCOMPLETE" 16 65

# Once again cannot make the whiptail checkbox not create this file and still work...
# Will work on figuring this out at a later date but until then we will delete the file created.
rm -f FEEDERCHOICES

exit 0

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

PIAWAREVERSION="5c77c4924"
PFCLIENTI386VERSION="3.1.201"
PFCLIENTARMVERSION="3.0.2080"

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
    cd $SCRIPTDIR
}

# Download, build and then install the PiAware package.
function InstallPiAware() {
    clear
    cd $BUILDDIR
    echo -e "\033[33mExecuting the PiAware installation script..."
    echo -e "\033[37m"
    chmod +x $SCRIPTDIR/bash/feeders/piaware.sh
    $SCRIPTDIR/bash/feeders/piaware.sh
    cd $SCRIPTDIR
}

# Download and install the Plane Finder ADS-B Client package.
function InstallPlaneFinder() {
    clear
    cd $BUILDDIR
    echo -e "\033[33mExecuting the Plane Finder ADS-B Client installation script..."
    echo -e "\033[37m"
    chmod +x $SCRIPTDIR/bash/feeders/planefinder.sh
    $SCRIPTDIR/bash/feeders/planefinder.sh
    cd $SCRIPTDIR
}

# Setup the ADS-B Exchange feed.
function InstallAdsbExchange() {
    clear
    cd $BUILDDIR
    echo -e "\033[33mExecuting the ADS-B Exchange installation script..."
    echo -e "\033[37m"
    chmod +x $SCRIPTDIR/bash/feeders/adsbexchange.sh
    $SCRIPTDIR/bash/feeders/adsbexchange.sh
    cd $SCRIPTDIR
}

# Setup and execute the web portal installation scripts.
function InstallWebPortal() {
    clear
    cd $SCRIPTDIR
    echo -e "\033[33mExecuting the web portal installation scripts..."
    echo -e "\033[37m"
    chmod +x $SCRIPTDIR/bash/portal/install.sh
    $SCRIPTDIR/bash/portal/install.sh
    cd $SCRIPTDIR
}


#############
## WHIPTAIL

# Check that whiptail is installed.
CheckPackage whiptail

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
The dump1090-mutability package appears to be installed on your device However...

The dump1090-mutability v1.15~dev source code is updated regularly without a change made to the version numbering. In order to insure you are running the latest version of dump1090-mutability you may opt to rebuild and reinstall this package.

Download, build, and reinstall this package?
EOF

# Message displayed if dump1090-mutability is not installed.
read -d '' DUMP1090NOTINSTALLED <<"EOF"
The dump1090-mutability package does not appear to be installed on your system. In order to continue setup dump1090-mutability will be downloaded, compiled and installed on this system.

Do you wish to continue setup?
Answering no will exit this script with no actions taken.
EOF

# Message displayed above feeder selection check list.
FEEDERSAVAILABLE="The following feeders are available for installation. Choose the feeders you wish to install."

# Message displayed if all available feeders have already been installed.
ALLFEEDERSINSTALLED="It appears that all the feeders available for installation by this script have been installed already."

# Message displayed asking if the user wishes to install the web portal.
read -d '' INSTALLWEBPORTAL <<"EOF"
The ADS-B Feeder Project Web Portal is a light weight web interface for dump-1090-mutability installations.

Current features include the following:
  Unified navigation between all web pages.
  System and dump1090 performance graphs.

Would you like to install the ADS-B Feeder Project web portal on this device?
EOF

# Message to display if there is nothing to install or do.
NOTHINGTODO="Nothing has been selected to be installed so the script will exit now."

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
whiptail --backtitle "$BACKTITLE" --title "The ADS-B Feeder Project" --yesno "$WELCOME" 16 65
BEGININSTALLATION=$?

if [ $BEGININSTALLATION = 1 ]; then
    # Exit the script if the user wishes not to continue.
    echo -e "\033[31m"
    echo "Installation cancelled by user."
    echo -e "\033[37m"
    exit 0
fi

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
DUMP1090REINSTALL=1
# Check if the dump1090-mutability package is installed.
if [ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
    # The dump1090-mutability package appear to be installed.
    whiptail --backtitle "$BACKTITLE" --title "Dump1090-mutability Installed" --yesno "$DUMP1090INSTALLED" 16 65
    DUMP1090REINSTALL=$?
    if [ $DUMP1090REINSTALL = 0 ]; then
        DUMP1090CHOICE=0
    fi
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

# Check if the PiAware package is installed or if it needs upgraded.
if [ $(dpkg-query -W -f='${STATUS}' piaware 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    # The PiAware package appear to be installed.
    FEEDERLIST=("${FEEDERLIST[@]}" 'FlightAware PiAware' '' OFF)
else
    # Check if a newer version can be installed.
    if [ $(sudo dpkg -s piaware 2>/dev/null | grep -c "Version: ${PIAWAREVERSION}") -eq 0 ]; then
        FEEDERLIST=("${FEEDERLIST[@]}" 'FlightAware PiAware (upgrade)' '' OFF)
    fi
fi

# Check if the Plane Finder ADS-B Client package is installed.
if [ $(dpkg-query -W -f='${STATUS}' pfclient 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    # The Plane Finder ADS-B Client package appear to be installed.
    FEEDERLIST=("${FEEDERLIST[@]}" 'Plane Finder ADS-B Client' '' OFF)
else
    # Set version depending on the device architecture.
    PFCLIENTVERSION=$PFCLIENTARMVERSION

    ## The i386 version even though labeled as 3.1.201 is in fact reported as 3.0.2080.
    ## So for now we will skip the architecture check and use the ARM version variable for both.
    #if [[ `uname -m` != "armv7l" ]]; then
    #    PFCLIENTVERSION=$PFCLIENTI386VERSION
    #fi

    # Check if a newer version can be installed.
    if [ $(sudo dpkg -s pfclient 2>/dev/null | grep -c "Version: ${PFCLIENTVERSION}") -eq 0 ]; then
        FEEDERLIST=("${FEEDERLIST[@]}" 'Plane Finder ADS-B Client (upgrade)' '' OFF)
    fi
fi

# Check if ADS-B Exchange sharing has been set up.
if ! grep -q "${BUILDDIR}/adsbexchange/adsbexchange-maint.sh &" /etc/rc.local; then
    # The ADS-B Exchange maintainance script does not appear to be executed on start up.
    FEEDERLIST=("${FEEDERLIST[@]}" 'ADS-B Exchange Script' '' OFF)
fi

declare FEEDERCHOICES

if [[ -n "$FEEDERLIST" ]]; then
    # Display a checklist containing feeders that are not installed if any.
    # This command is creating a file named FEEDERCHOICES but can not fiogure out how to make it only a variable without the file being created at this time.
    whiptail --backtitle "$BACKTITLE" --title "Feeder Installation Options" --checklist --nocancel --separate-output "$FEEDERSAVAILABLE" 13 52 3 "${FEEDERLIST[@]}" 2>FEEDERCHOICES
else
    # Since all available feeders appear to be installed inform the user of the fact.
    whiptail --backtitle "$BACKTITLE" --title "All Feeders Installed" --msgbox "$ALLFEEDERSINSTALLED" 10 65
fi

## WEB PORTAL

# Ask if the web portal should be installed.
whiptail --backtitle "$BACKTITLE" --title "Install The ADS-B Feeder Project Web Portal" --yesno "$INSTALLWEBPORTAL" 8 78
DOINSTALLWEBPORTAL=$?

## CONFIRMATION

# Check if anything is to be done before moving on.
if [ $UPDATEOS = 1 ] && [ $UPDATEFIRMWARENOW = 1 ] && [ $DUMP1090CHOICE = 1 ] && [ $DOINSTALLWEBPORTAL = 1 ] && [ ! -s FEEDERCHOICES ]; then
    whiptail --backtitle "$BACKTITLE" --title "Nothing to be done" --msgbox "$NOTHINGTODO" 10 65

    echo -e "\033[31m"
    echo "Nothing was selected to do or be installed."
    echo "The script has been exited."
    echo -e "\033[37m"

    # Dirty hack but cannot make the whiptail checkbox not create this file and still work...
    # Will work on figuring this out at a later date so until then we will delete the file it created.
    rm -f FEEDERCHOICES

    exit 0
fi

declare CONFIRMATION
# If the user decided to install updates...
if [ $UPDATEOS = 0 ] || [ $UPDATEFIRMWARENOW = 0 ]; then
    CONFIRMATION="The following actions will be performed:\n"

    if [ $UPDATEOS = 0 ]; then
        # Operating system updates message.
        CONFIRMATION="${CONFIRMATION}\n  * Operating system updates will be applied."
    fi

    if [ $UPDATEFIRMWARENOW = 0 ]; then
        # Firmware update message.
        CONFIRMATION="${CONFIRMATION}\n  * Raspberry Pi firmware updates will be applied."
    fi
    CONFIRMATION="${CONFIRMATION}\n"
fi

# If the user decided to install software...
if [ $DUMP1090CHOICE = 0 ] || [ $DOINSTALLWEBPORTAL = 0 ] || [ -s FEEDERCHOICES ]; then
    CONFIRMATION="${CONFIRMATION}\nThe following software will be installed:\n"

    if [ $DUMP1090CHOICE = 0 ]; then
        if [ $DUMP1090REINSTALL -eq 0 ]; then
            CONFIRMATION="${CONFIRMATION}\n  * dump1090-mutability (reinstall)"
        else
            CONFIRMATION="${CONFIRMATION}\n  * dump1090-mutability"
        fi
    fi

    if [ -s FEEDERCHOICES ]; then
        while read FEEDERCHOICE
        do
            case $FEEDERCHOICE in
                "FlightAware PiAware")
                    CONFIRMATION="${CONFIRMATION}\n  * FlightAware PiAware"
                    ;;
                "FlightAware PiAware (upgrade)")
                    CONFIRMATION="${CONFIRMATION}\n  * FlightAware PiAware (upgrade)"
                    ;;
                "Plane Finder ADS-B Client")
                    CONFIRMATION="${CONFIRMATION}\n  * Plane Finder ADS-B Client"
                    ;;
                "Plane Finder ADS-B Client (upgrade)")
                    CONFIRMATION="${CONFIRMATION}\n  * Plane Finder ADS-B Client (upgrade)"
                    ;;
                "ADS-B Exchange Script")
                    CONFIRMATION="${CONFIRMATION}\n  * ADS-B Exchange Script"
                    ;;
            esac
        done < FEEDERCHOICES
    fi

    if [ $DOINSTALLWEBPORTAL = 0 ]; then
        CONFIRMATION="${CONFIRMATION}\n  * ADS-B Feeder Project Web Portal"
    fi
    CONFIRMATION="${CONFIRMATION}\n"
fi

# Ask for confirmation before moving on.
CONFIRMATION="${CONFIRMATION}\nDo you wish to continue?"

whiptail --backtitle "$BACKTITLE" --title "Confirm You Wish To Continue" --yesno "$CONFIRMATION" 20 78
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

if [ $UPDATEFIRMWARENOW = 0 ]; then
    UpdateFirmware
fi

## Mode S decoder.

if [ $DUMP1090CHOICE = 0 ]; then
    InstallDump1090
fi

## Feeders.

# Moved execution of functions outside of while loop.
# Inside the while loop the installation scripts are not stopping at reads.
RUNPIAWARESCRIPT=1
RUNPLANEFINDERSCRIPT=1
RUNADSBEXCHANGESCRIPT=1

if [ -s FEEDERCHOICES ]; then
    while read FEEDERCHOICE
    do
        case $FEEDERCHOICE in
            "FlightAware PiAware"|"FlightAware PiAware (upgrade)")
                RUNPIAWARESCRIPT=0
            ;;
            "Plane Finder ADS-B Client"|"Plane Finder ADS-B Client (upgrade)")
                RUNPLANEFINDERSCRIPT=0
            ;;
            "ADS-B Exchange Script")
                RUNADSBEXCHANGESCRIPT=0
            ;;
        esac
    done < FEEDERCHOICES
fi

if [ $RUNPIAWARESCRIPT = 0 ]; then
    InstallPiAware
fi

if [ $RUNPLANEFINDERSCRIPT = 0 ]; then
    InstallPlaneFinder
fi

if [ $RUNADSBEXCHANGESCRIPT = 0 ]; then
    InstallAdsbExchange
fi

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

echo -e "\033[32m"
echo "Installation complete."
echo -e "\033[37m"

exit 0

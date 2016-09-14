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

## CHECK IF THIS IS THE FIRST RUN USING THE IMAGE RELEASE

if [ -f $PROJECTROOTDIRECTORY/image ]; then
    # Execute image setup script..
    chmod +x $BASHDIRECTORY/image.sh
    $BASHDIRECTORY/image.sh
    exit 0
fi

## FUNCTIONS

PROJECTTITLE="\n\e[91m  THE ADS-B RECIEVER PROJECT VERSION $PROJECTVERSION"
TERMINATEDMESSAGE="\e[91m  ANY FURTHER SETUP AND/OR INSTALLATION REQUESTS HAVE BEEN TERMINIATED\e[39m"

# UPDATE REPOSITORY PACKAGE LISTS
function AptUpdate() {
    clear
    echo -e $PROJECTTITLE
    echo ""
    echo -e "\e[92m  Downloading the latest package lists for all enabled repositories and PPAs..."
    echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[97m"
    echo ""
    sudo apt-get update
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  Finished downloading and updating package lists.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
}

# UPDATE THE OPERATING SYSTEM
function UpdateOperatingSystem() {
    clear
    echo -e $PROJECTTITLE
    echo ""
    echo -e "\e[92m  Downloading and installing the latest updates for your operating system..."
    echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[97m"
    echo ""
    sudo apt-get -y upgrade
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  Your operating system should now be up to date.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
}

# EXECUTE THE DUMP1090-MUTABILITY SETUP SCRIPT
function InstallDump1090() {
    chmod +x $BASHDIRECTORY/decoders/dump1090-mutability.sh
    $BASHDIRECTORY/decoders/dump1090-mutability.sh
    if [ $? -ne 0 ]; then
        echo ""
        echo -e $TERMINATEDMESSAGE
        echo ""
        exit 1
    fi
}

# EXECUTE THE DUMP978 SETUP SCRIPT
function InstallDump978() {
    chmod +x $BASHDIRECTORY/decoders/dump978.sh
    $BASHDIRECTORY/decoders/dump978.sh
    if [ $? -ne 0 ]; then
        echo ""
        echo -e $TERMINATEDMESSAGE
        echo ""
        exit 1
    fi
}

# EXECUTE THE PIAWARE SETUP SCRIPT
function InstallPiAware() {
    chmod +x $BASHDIRECTORY/feeders/piaware.sh
    $BASHDIRECTORY/feeders/piaware.sh
    if [ $? -ne 0 ]; then
        echo ""
        echo -e $TERMINATEDMESSAGE
        echo ""
        exit 1
    fi
}

# Download and install the Plane Finder ADS-B Client package.
function InstallPlaneFinder() {
    chmod +x $BASHDIRECTORY/feeders/planefinder.sh
    $BASHDIRECTORY/feeders/planefinder.sh
    if [ $? -ne 0 ]; then
        echo ""
        echo -e $TERMINATEDMESSAGE
        echo ""
        exit 1
    fi
}

# Download and install the Flightradar24 client package.
function InstallFlightradar24() {
    chmod +x $BASHDIRECTORY/feeders/flightradar24.sh
    $BASHDIRECTORY/feeders/flightradar24.sh
    if [ $? -ne 0 ]; then
        echo ""
        echo -e $TERMINATEDMESSAGE
        echo ""
        exit 1
    fi
}

# Setup the ADS-B Exchange feed.
function InstallAdsbExchange() {
    chmod +x $BASHDIRECTORY/feeders/adsbexchange.sh
    $BASHDIRECTORY/feeders/adsbexchange.sh
    if [ $? -ne 0 ]; then
        echo ""
        echo -e $TERMINATEDMESSAGE
        echo ""
        exit 1
    fi
}

# Setup and execute the web portal installation scripts.
function InstallWebPortal() {
    chmod +x $BASHDIRECTORY/portal/install.sh
    $BASHDIRECTORY/portal/install.sh
    if [ $? -ne 0 ]; then
        echo ""
        echo -e $TERMINATEDMESSAGE
        echo ""
        exit 1
    fi
}

# Setup and execute the web portal installation scripts.
function InstallLogs() {
    chmod +x $BASHDIRECTORY/portal/adsb_logs.sh
    $BASHDIRECTORY/portal/adsb_logs.sh
    if [ $? -ne 0 ]; then
        echo ""
        echo -e $TERMINATEDMESSAGE
        echo ""
        exit 1
    fi
}

AptUpdate

# Check that whiptail is installed.
clear
CheckPackage whiptail


#############
## WHIPTAIL

##
## MESSAGES
##

# The title of the installer.
BACKTITLE="The ADS-B Receiver Project"

# The welcome message displayed when this scrip[t it first executed.
read -d '' WELCOME <<"EOF"
The ADS-B Project is a series of bash scripts and files which can be used to setup an ADS-B receiver on certain Debian derived operating system.

More information on the project can be found on GitHub.
https://github.com/jprochazka/adsb-receiver

Would you like to continue setup?
EOF

# Message displayed asking to update the operating system.
read -d '' UPDATEFIRST <<"EOF"
It is recommended that you update your system before building and/or installing any ADS-B receiver related packages. This script can do this for you at this time if you like.

Update system before installing any ADS-B receiver related software?
EOF

# Message displayed if dump1090-mutability is installed.
read -d '' DUMP1090INSTALLED <<"EOF"
The dump1090-mutability package appears to be installed on your device, however...

The dump1090-mutability v1.15~dev source code is regularly updated without a change made to the version numbering. To ensure you are running the latest version of
dump1090-mutability you may opt to rebuild and reinstall this package.

Download, build, and reinstall this package?
EOF

# Message displayed if dump1090-mutability is not installed.
read -d '' DUMP1090NOTINSTALLED <<"EOF"
The dump1090-mutability package does not appear to be installed on your system. To continue setup dump1090-mutability will be downloaded, compiled and installed on this system.

Do you wish to continue setup?
Answering no will exit this script with no actions taken.
EOF

# Message displayed if dump978 is installed.
read -d '' DUMP978INSTALLED <<"EOF"
Dump978 appears to be installed on your device, however...

The dump978 source code may have been updated since it was built last. To ensure you are running the latest version of dump978 you may opt to rebuild the binaries making up dump978.

Download and rebuild the dump978 binaries?
EOF

# Message displayed if dump978 is not installed.
read -d '' DUMP978NOTINSTALLED <<"EOF"
Dump978 is an experimental demodulator/decoder for 978MHz UAT signals. These scripts can setup dump978 for you. However keep in mind a second RTL-SDR device will be required to feed data to it.

Do you wish to install dump978?
EOF

# Message displayed above feeder selection checklist.
FEEDERSAVAILABLE="The following feeders are available for installation. Choose the feeders you wish to install. (Hint: Use spacebar to select/deselect.)"

# Message displayed if all available feeders have already been installed.
ALLFEEDERSINSTALLED="It appears that all the feeders available for installation by this script have been installed already."

# Message displayed asking if the user wishes to install the web portal.
read -d '' INSTALLWEBPORTAL <<"EOF"
The ADS-B Receiver Project Web Portal is a lightweight web interface for dump-1090-mutability installations.

Current features include the following:
  Unified navigation between all web pages.
  System and dump1090 performance graphs.

Would you like to install the ADS-B Receiver Project web portal on this device?
EOF

# Message displayed asking if the user wishes to install frontail for viewing ADS-B Logs.
read -d '' INSTALLLOGS <<"EOF"
Would you like to install frontail to view ADS-B logs from within the ADS-B Receiver Project web portal?
EOF

# Message to display if there is nothing to install or do.
NOTHINGTODO="Nothing has been selected to be installed so the script will exit now."

# Message displayed once installation has been completed.
read -d '' INSTALLATIONCOMPLETE <<"EOF"
INSTALLATION COMPLETE

DO NOT DELETE THIS DIRECTORY!

Files needed for certain items to run properly are contained within this directory. Deleting this directory may result in your receiver not working properly.

Hopefully, these scripts and files were found useful while setting up your ADS-B Receiver. Feedback regarding this software is always welcome. If you have any issues or wish to submit feedback, feel free to do so on GitHub.

https://github.com/jprochazka/adsb-receiver
EOF

##
## DIALOGS
##

# Display the welcome message.
whiptail --backtitle "$BACKTITLE" --title "The ADS-B Receiver Project" --yesno "$WELCOME" 14 65
BEGININSTALLATION=$?

if [ $BEGININSTALLATION = 1 ]; then
    # Exit the script if the user wishes not to continue.
    echo -e "\033[31m"
    echo "Installation canceled by user."
    echo -e "\033[37m"
    exit 0
fi

# Ask to update the operating system.
whiptail --backtitle "$BACKTITLE" --title "Install Operating System Updates" --yesno "$UPDATEFIRST" 9 65
UPDATEOS=$?

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
        echo "Installation canceled by user."
        echo -e "\033[37m"
        exit 0
    fi
fi

DUMP978CHOICE=1
DUMP978REBUILD=1
# Check if the dump978 has been built.
if [ -f $BUILDDIR/dump978/dump978 ] && [ -f $BUILDDIR/dump978/uat2text ] && [ -f $BUILDDIR/dump978/uat2esnt ] && [ -f $BUILDDIR/dump978/uat2json ]; then
    # Dump978 appears to have been built already.
    whiptail --backtitle "$BACKTITLE" --title "Dump978 Installed" --yesno "$DUMP978INSTALLED" 16 65
    DUMP978REBUILD=$?
    if [ $DUMP978REBUILD = 0 ]; then
        DUMP978CHOICE=0
    fi
else
    # Dump978 does not appear to have been built yet.
    whiptail --backtitle "$BACKTITLE" --title "Dump978 Not Installed" --defaultno --yesno "$DUMP978NOTINSTALLED" 10 65
    DUMP978CHOICE=$?
fi

## FEEDER OPTIONS

declare array FEEDERLIST

# Check if the PiAware package is installed or if it needs upgraded.
if [ $(dpkg-query -W -f='${STATUS}' piaware 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    # The PiAware package appears to be installed.
    FEEDERLIST=("${FEEDERLIST[@]}" 'FlightAware PiAware' '' OFF)
else
    # Check if a newer version can be installed.
    if [ $(sudo dpkg -s piaware 2>/dev/null | grep -c "Version: ${PIAWAREVERSION}") -eq 0 ]; then
        FEEDERLIST=("${FEEDERLIST[@]}" 'FlightAware PiAware (upgrade)' '' OFF)
    fi
fi

# Check if the Plane Finder ADS-B Client package is installed.
if [ $(dpkg-query -W -f='${STATUS}' pfclient 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    # The Plane Finder ADS-B Client package appears to be installed.
    FEEDERLIST=("${FEEDERLIST[@]}" 'Plane Finder ADS-B Client' '' OFF)
else
    # Set version depending on the device architecture.
    PFCLIENTVERSION=$PFCLIENTVERSIONARM
    if [[ `uname -m` != "armv7l" ]]; then
        PFCLIENTVERSION=$PFCLIENTVERSIONI386
    fi

    # Check if a newer version can be installed.
    if [ $(sudo dpkg -s pfclient 2>/dev/null | grep -c "Version: ${PFCLIENTVERSION}") -eq 0 ]; then
        FEEDERLIST=("${FEEDERLIST[@]}" 'Plane Finder ADS-B Client (upgrade)' '' OFF)
    fi
fi

# Check if the Flightradar24 client package is installed.
if [ $(dpkg-query -W -f='${STATUS}' fr24feed 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    # The Flightradar24 client package appears to be installed.
    FEEDERLIST=("${FEEDERLIST[@]}" 'Flightradar24 Client' '' OFF)
else
    if [[ `uname -m` != "armv7l" ]]; then
        if [ $(sudo dpkg -s fr24feed 2>/dev/null | grep -c "Version: ${FR24CLIENTVERSIONI386}") -eq 0 ]; then
            FEEDERLIST=("${FEEDERLIST[@]}" 'Flightradar24  Client (upgrade)' '' OFF)
        fi
    fi
fi

# Check if ADS-B Exchange sharing has been set up.
if ! grep -q "$BUILDDIRECTORY/adsbexchange/adsbexchange-mlat_maint.sh &" /etc/rc.local; then
    # The ADS-B Exchange maintenance script does not appear to be executed on startup.
    FEEDERLIST=("${FEEDERLIST[@]}" 'ADS-B Exchange Script' '' OFF)
fi

declare FEEDERCHOICES

if [[ -n "$FEEDERLIST" ]]; then
    # Display a checklist containing feeders that are not installed if any.
    # This command is creating a file named FEEDERCHOICES but can not figure out how to make it only a variable without the file being created at this time.
    whiptail --backtitle "$BACKTITLE" --title "Feeder Installation Options" --checklist --nocancel --separate-output "$FEEDERSAVAILABLE" 13 52 4 "${FEEDERLIST[@]}" 2>FEEDERCHOICES
else
    # Since all available feeders appear to be installed inform the user of the fact.
    whiptail --backtitle "$BACKTITLE" --title "All Feeders Installed" --msgbox "$ALLFEEDERSINSTALLED" 10 65
fi

## WEB PORTAL

# Ask if the web portal should be installed.
whiptail --backtitle "$BACKTITLE" --title "Install The ADS-B Receiver Project Web Portal" --yesno "$INSTALLWEBPORTAL" 8 78
DOINSTALLWEBPORTAL=$?

# Ask if frontail should be installed
whiptail --backtitle "$BACKTITLE" --title "Install Frontail for viewing ADS-B Logs from the ADS-B Receiver Portal" --yesno "$INSTALLLOGS" 8 78
DOINSTALLLOGS=$?

## CONFIRMATION

# Check if anything is to be done before moving on.
if [ $UPDATEOS = 1 ] && [ $DUMP1090CHOICE = 1 ] && [ $DUMP978CHOICE = 1 ] && [ $DOINSTALLWEBPORTAL = 1 ] && [ ! -s FEEDERCHOICES ]; then
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
if [ $UPDATEOS = 0 ]; then
    CONFIRMATION="The following actions will be performed:\n"

    if [ $UPDATEOS = 0 ]; then
        # Operating system updates message.
        CONFIRMATION="${CONFIRMATION}\n  * Operating system updates will be applied."
    fi

    CONFIRMATION="${CONFIRMATION}\n"
fi

# If the user decided to install software...
if [ $DUMP1090CHOICE = 0 ] || [ $DUMP978CHOICE = 0 ] || [ $DOINSTALLWEBPORTAL = 0 ] || [ -s FEEDERCHOICES ]; then
    CONFIRMATION="${CONFIRMATION}\nThe following software will be installed:\n"

    if [ $DUMP1090CHOICE = 0 ]; then
        if [ $DUMP1090REINSTALL -eq 0 ]; then
            CONFIRMATION="${CONFIRMATION}\n  * dump1090-mutability (reinstall)"
        else
            CONFIRMATION="${CONFIRMATION}\n  * dump1090-mutability"
        fi
    fi

    if [ $DUMP978CHOICE = 0 ]; then
        if [ $DUMP978REBUILD -eq 0 ]; then
            CONFIRMATION="${CONFIRMATION}\n  * dump978 (rebuild)"
        else
            CONFIRMATION="${CONFIRMATION}\n  * dump978"
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
                "Flightradar24 Client")
                    CONFIRMATION="${CONFIRMATION}\n  * Flightradar24 Client"
                   ;;
                "Flightradar24 Client (upgrade)")
                    CONFIRMATION="${CONFIRMATION}\n  * Flightradar24 Client (upgrade)"
                   ;;
                "ADS-B Exchange Script")
                    CONFIRMATION="${CONFIRMATION}\n  * ADS-B Exchange Script"
                    ;;
            esac
        done < FEEDERCHOICES
    fi

    if [ $DOINSTALLWEBPORTAL = 0 ]; then
        CONFIRMATION="${CONFIRMATION}\n  * ADS-B Receiver Project Web Portal"
    fi
    CONFIRMATION="${CONFIRMATION}\n"
fi

# Ask for confirmation before moving on.
CONFIRMATION="${CONFIRMATION}\nDo you wish to continue?"

whiptail --backtitle "$BACKTITLE" --title "Confirm You Wish To Continue" --yesno "$CONFIRMATION" 21 78
CONFIRMATION=$?

if [ $CONFIRMATION = 1 ]; then
    echo -e "\033[31m"
    echo "Installation canceled by user."
    echo -e "\033[37m"

    # Dirty hack but cannot make the whiptail checkbox not create this file and still work...
    # Will work on figuring this out at a later date so until then we will delete the file it created.
    rm -f FEEDERCHOICES

    exit 0
fi

################
## BEGIN SETUP

## System updates.

if [ $UPDATEOS = 0 ]; then
    UpdateOperatingSystem
fi

## Mode S decoder.

if [ $DUMP1090CHOICE = 0 ]; then
    InstallDump1090
fi

if [ $DUMP978CHOICE = 0 ]; then
    InstallDump978
fi

## Feeders.

# Moved execution of functions outside of while loop.
# Inside the while loop the installation scripts are not stopping at reads.
RUNPIAWARESCRIPT=1
RUNPLANEFINDERSCRIPT=1
RUNFLIGHTRADAR24SCRIPT=1
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
            "Flightradar24 Client"|"Flightradar24 Client (upgrade)")
                RUNFLIGHTRADAR24SCRIPT=0
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

if [ $RUNFLIGHTRADAR24SCRIPT = 0 ]; then
    InstallFlightradar24
fi

if [ $RUNADSBEXCHANGESCRIPT = 0 ]; then
    InstallAdsbExchange
fi

## Web portal.

if [ $DOINSTALLWEBPORTAL = 0 ]; then
    InstallWebPortal
fi

## Frontail Log.

if [ $DOINSTALLLOGS = 0 ]; then
    InstallLogs
fi


##########################
## INSTALLATION COMPLETE

# Display the installation complete message box.
whiptail --backtitle "$BACKTITLE" --title "Software Installation Complete" --msgbox "$INSTALLATIONCOMPLETE" 19 65

# Once again cannot make the whiptail checkbox not create this file and still work...
# Will work on figuring this out at a later date but until then we will delete the file created.
rm -f FEEDERCHOICES

echo -e "\033[32m"
echo "Installation complete."
echo -e "\033[37m"

exit 0

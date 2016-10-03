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

## Set the project title variable.
export ADSB_PROJECTTITLE="The ADS-B Receiver Project v$PROJECTVERSION Installer"

###############
## FUNCTIONS

## DECODERS

# Execute the dump1090-mutability setup script.
function InstallDump1090Mutability() {
    chmod +x $BASHDIRECTORY/decoders/dump1090-mutability.sh
    $BASHDIRECTORY/decoders/dump1090-mutability.sh
    if [ $? -ne 0 ]; then
        echo ""
        echo -e $TERMINATEDMESSAGE
        echo ""
        exit 1
    fi
}

# Execute the dump1090-fa setup script.
function InstallDump1090Fa() {
    chmod +x $BASHDIRECTORY/decoders/dump1090-fa.sh
    $BASHDIRECTORY/decoders/dump1090-fa.sh
    if [ $? -ne 0 ]; then
        echo ""
        echo -e $TERMINATEDMESSAGE
        echo ""
        exit 1
    fi
}


# Execute the dump978 setup script.
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

## FEEDERS

# Execute the PiAware setup script
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

# Execute the Plane Finder ADS-B Client setup script.
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

# Execute the Flightradar24 Feeder client setup script.
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

# Execute the ADS-B Exchange setup script.
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

## Portal

# Execute the ADS-B Receiver Project Web Portal setup script.
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

#############
## DIALOGS

## Decoders

# Check if the dump1090-mutability package is installed.
DUMP1090MUTABILITY_INSTALLED=1
DUMP1090MUTABILITY_INSTALL=1
DUMP1090MUTABILITY_REINSTALL=1
if [ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
    # The dump1090-mutability package appear to be installed.
    DUMP1090MUTABILITY_INSTALLED=0
    whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Dump1090-mutability Installed" --defaultno --yesno "The dump1090-mutability package appears to be installed on your device, however...\n\nThe dump1090-mutability v1.15~dev source code is regularly updated without a change made to the version numbering. To ensure you are running the latest version of dump1090-mutability you may opt to rebuild and reinstall this package.\n\nDownload, build, and reinstall this package?" 16 65
    DUMP1090MUTABILITY_REINSTALL=$?
fi

# Check if the dump1090-fa package is installed.
DUMP1090FA_INSTALLED=1
DUMP1090FA_INSTALL=1
DUMP1090FA_UPGRADE=1
if [ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
    # The dump1090-fa package appear to be installed.
    DUMP1090FA_INSTALLED=0
    # Check if a newer version can be installed.
    if [ $(sudo dpkg -s dump1090-fa 2>/dev/null | grep -c "Version: ${PIAWAREVERSION}") -eq 0 ]; then
        whiptail  --backtitle "$ADSB_PROJECTTITLE" --title "Dump1090-fa Upgrade Available" --defaultno --yesno "An updated version of dump1090-fa is available.\n\nWould you like to download, build, then install the new version?" 16 65
        DUMP1090FA_UPGRADE=$?
    fi
fi

# If any version of dump1090 is not installed ask which one to install.
if [ $DUMP1090MUTABILITY_INSTALLED = 1 ] && [ $DUMP1090FA_INSTALLED = 1 ]; then
    DUMP1090OPTION=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Choose Dump1090 Version" --menu "The dump1090-mutability or dump1090-fa package does not appear to be installed on this device. In order to continue setup one of these two packages need to be installed. Please select your prefered dump1090 version from the list below.\n\nPlease note that in order to run dump1090-fa PiAware will need to be installed as well." 16 65 2 "dump1090-mutability" "(Mutability)" "dump1090-fa" "(FlightAware)" 3>&1 1>&2 2>&3)
    case $DUMP1090OPTION in
        "dump1090-mutability")
            DUMP1090MUTABILITY_INSTALL=0
            ;;
        "dump1090-fa")
            DUMP1090FA_INSTALL=0
            ;;
        *)
            echo -e "\033[31m"
            echo "  A compatable dump1090 installation is required in order to continue setup."
            exit 1
            ;;
    esac
fi

# Check if PiAware is required.
PIAWAREREQUIRED=1
if [ $DUMP1090FA_INSTALL = 0 ]; then
    PIAWAREREQUIRED=0
fi

# Check that the dump978 binaries exist.
DUMP978_INSTALL=1
DUMP978_REINSTALL=1
if [ -f $BUILDDIRECTORY/dump978/dump978 ] && [ -f $BUILDDIRECTORY/dump978/uat2text ] && [ -f $BUILDDIRECTORY/dump978/uat2esnt ] && [ -f $BUILDDIRECTORY/dump978/uat2json ]; then
    # Dump978 appears to have been built already.
    whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Dump978 Installed" --defaultno --yesno "Dump978 appears to be installed on your device, however...\n\nThe dump978 source code may have been updated since it was built last. To ensure you are running the latest version of dump978 you may opt to rebuild the binaries making up dump978.\n\nDownload and rebuild the dump978 binaries?" 14 65
    DUMP978_REINSTALL=$?
else
    # Dump978 does not appear to have been built yet.
    whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Dump978 Not Installed" --defaultno --yesno "Dump978 is an experimental demodulator/decoder for 978MHz UAT signals. These scripts can setup dump978 for you. However keep in mind a second RTL-SDR device will be required to feed data to it.\n\nDo you wish to install dump978?" 10 65
    DUMP978_INSTALL=$?
fi

## Feeder Selection Menu

# Declare the FEEDERLIST array which will store feeder installation choices for the feeder whiptail menu.
declare array FEEDERLIST

# Check for the PiAware package.
if [ $(dpkg-query -W -f='${STATUS}' piaware 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    # Do not show the PiAware install option if it is marked as required.
    if [ $PIAWAREREQUIRED = 1 ]; then
        # The PiAware package appears to not be installed.
        FEEDERLIST=("${FEEDERLIST[@]}" 'FlightAware PiAware' '' OFF)
    fi
else
    # Check if a newer version can be installed.
    if [ $(sudo dpkg -s piaware 2>/dev/null | grep -c "Version: $PIAWAREVERSION") -eq 0 ]; then
        FEEDERLIST=("${FEEDERLIST[@]}" 'FlightAware PiAware (upgrade)' '' OFF)
    fi
fi

# Check for the Planefinder ADS-B Client package.
if [ $(dpkg-query -W -f='${STATUS}' pfclient 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    # The Planefinder ADS-B Client package appears to be installed.
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

# Check for the Flightradar24 Feeder Client package.
if [ $(dpkg-query -W -f='${STATUS}' fr24feed 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    # The Flightradar24 client package appears to be installed.
    FEEDERLIST=("${FEEDERLIST[@]}" 'Flightradar24 Client' '' OFF)
else
    # Check if a newer version can be installed if this is not a Raspberry Pi device.
    if [[ `uname -m` != "armv7l" ]]; then
        if [ $(sudo dpkg -s fr24feed 2>/dev/null | grep -c "Version: ${FR24CLIENTVERSIONI386}") -eq 0 ]; then
            FEEDERLIST=("${FEEDERLIST[@]}" 'Flightradar24  Client (upgrade)' '' OFF)
        fi
    fi
fi

# Check if ADS-B Exchange MLAT client has been set up.
if ! grep -q "$BUILDDIRECTORY/adsbexchange/adsbexchange-mlat_maint.sh &" /etc/rc.local; then
    # The ADS-B Exchange maintenance script does not appear to be executed on startup.
    FEEDERLIST=("${FEEDERLIST[@]}" 'ADS-B Exchange Script' '' OFF)
fi

declare FEEDERCHOICES

if [[ -n "$FEEDERLIST" ]]; then
    # Display a checklist containing feeders that are not installed if any.
    whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Feeder Installation Options" --checklist --nocancel --separate-output "The following feeders are available for installation.\nChoose the feeders you wish to install." 13 65 4 "${FEEDERLIST[@]}" 2>FEEDERCHOICES
else
    # Since all available feeders appear to be installed inform the user of the fact.
    whiptail --backtitle "$ADSB_PROJECTTITLE" --title "All Feeders Installed" --msgbox "It appears that all the optional feeders available for installation by this script have been installed already." 8 65
fi

## ADS-B Receiver Project Web Portal

# Ask if the web portal should be installed.
whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Install The ADS-B Receiver Project Web Portal" --yesno "The ADS-B Receiver Project Web Portal is a lightweight web interface for dump-1090-mutability installations.\n\nCurrent features include the following:\n  Unified navigation between all web pages.\n  System and dump1090 performance graphs.\n\nWould you like to install the ADS-B Receiver Project web portal on this device?" 8 78
PORTAL_INSTALL=$?

## Setup Confirmation

# Check if anything is to be done before moving on.
if [ $DUMP1090MUTABILITY_INSTALL = 1 ] && [ $DUMP1090MUTABILITY_REINSTALL = 1 ] && [ $DUMP1090FA_INSTALL = 1 ] && [ $DUMP1090FA_UPGRADE = 1 ] && [ $DUMP978_INSTALL = 1 ] && [ $DUMP978_REINSTALL = 1 ] && [ $PORTAL_INSTALL = 1 ] && [ ! -s FEEDERCHOICES ]; then
    whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Nothing to be done" --msgbox "Nothing has been selected to be installed so the script will exit now." 10 65
    echo -e "\033[31m"
    echo "Nothing was selected to do or be installed."
    echo -e "\033[37m"
    exit 1
fi

declare CONFIRMATION

# If the user decided to install software...
if [ $DUMP1090MUTABILITY_INSTALL = 0 ] || [ $DUMP1090MUTABILITY_REINSTALL = 0 ] || [ $DUMP1090FA_INSTALL = 0 ] || [ $DUMP1090FA_UPGRADE = 0 ] || [ $DUMP978_INSTALL = 0 ] || [ $DUMP978_REINSTALL = 0 ] || [ $PORTAL_INSTALL = 0 ] || [ -s FEEDERCHOICES ]; then
    CONFIRMATION="$The following software will be installed:\n"

    if [ $DUMP1090MUTABILITY_INSTALL = 0 ] || [ $DUMP1090MUTABILITY_REINSTALL = 0 ]; then
        if [ $DUMP1090MUTABILITY_REINSTALL = 0 ]; then
            CONFIRMATION="$CONFIRMATION\n  * dump1090-mutability (reinstall)"
        else
            CONFIRMATION="$CONFIRMATION\n  * dump1090-mutability"
        fi
    fi

    if [ $DUMP1090FA_INSTALL = 0 ] || [ $DUMP1090FA_UPGRADE = 0 ]; then
        if [ $DUMP1090FA_UPGRADE = 0 ]; then
            CONFIRMATION="$CONFIRMATION\n  * dump1090-fa (upgrade)"
        else
            CONFIRMATION="$CONFIRMATION\n  * dump1090-fa"
        fi
    fi

    if [ $DUMP978_INSTALL = 0 ] || [ $DUMP978_REINSTALL = 0 ]; then
        if [ $DUMP978_REINSTALL = 0 ]; then
            CONFIRMATION="$CONFIRMATION\n  * dump978 (rebuild)"
        else
            CONFIRMATION="$CONFIRMATION\n  * dump978"
        fi
    fi

    # If PiAware is required add it to the list.
    if [ $PIAWAREREQUIRED = 0 ]; then
        CONFIRMATION="$CONFIRMATION\n  * FlightAware PiAware"
    fi

    if [ -s FEEDERCHOICES ]; then
        while read FEEDERCHOICE
        do
            case $FEEDERCHOICE in
                "FlightAware PiAware")
                    CONFIRMATION="$CONFIRMATION\n  * FlightAware PiAware"
                     ;;
                "FlightAware PiAware (upgrade)")
                    CONFIRMATION="$CONFIRMATION\n  * FlightAware PiAware (upgrade)"
                    ;;
                "Plane Finder ADS-B Client")
                    CONFIRMATION="$CONFIRMATION\n  * Plane Finder ADS-B Client"
                    ;;
                "Plane Finder ADS-B Client (upgrade)")
                    CONFIRMATION="$CONFIRMATION\n  * Plane Finder ADS-B Client (upgrade)"
                    ;;
                "Flightradar24 Client")
                    CONFIRMATION="$CONFIRMATION\n  * Flightradar24 Client"
                   ;;
                "Flightradar24 Client (upgrade)")
                    CONFIRMATION="$CONFIRMATION\n  * Flightradar24 Client (upgrade)"
                   ;;
                "ADS-B Exchange Script")
                    CONFIRMATION="$CONFIRMATION\n  * ADS-B Exchange Script"
                    ;;
            esac
        done < FEEDERCHOICES
    fi

    if [ $PORTAL_INSTALL = 0 ]; then
        CONFIRMATION="$CONFIRMATION\n  * ADS-B Receiver Project Web Portal"
    fi
    CONFIRMATION="$CONFIRMATION\n\n"
fi

# Ask for confirmation before moving on.
CONFIRMATION="${CONFIRMATION}Do you wish to continue setup?"
if ! (whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Confirm You Wish To Continue" --yesno "$CONFIRMATION" 17 78) then
    echo -e "\033[31m"
    echo "  Installation canceled by user."
    exit 1
fi

#################
## BEGIN SETUP

## Decoders

if [ $DUMP1090MUTABILITY_INSTALL = 0 ] || [ $DUMP1090MUTABILITY_REINSTALL = 0 ]; then
    InstallDump1090Mutability
fi

if [ $DUMP1090FA_INSTALL = 0 ] || [ $DUMP1090FA_REINSTALL = 0 ]; then
    InstallDump1090Fa
fi

if [ $DUMP978_INSTALL = 0 ] || [ $DUMP978_REINSTALL = 0 ]; then
    InstallDump978
fi

## Feeders

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

if [ $RUNPIAWARESCRIPT = 0 ] || [ $PIAWAREREQUIRED = 0 ]; then
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

## ADS-B Receiver Project Web Portal

if [ $PORTAL_INSTALL = 0 ]; then
    InstallWebPortal
fi

exit 0

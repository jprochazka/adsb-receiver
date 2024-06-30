#!/bin/bash

## INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

## Set the project title variable.
export RECEIVER_PROJECT_TITLE="The ADS-B Receiver Project v${PROJECT_VERSION} Installer"

###############
## FUNCTIONS

## DECODERS

# Execute the dump1090-fa setup script.
function InstallDump1090Fa() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/decoders/dump1090-fa.sh
    ${RECEIVER_BASH_DIRECTORY}/decoders/dump1090-fa.sh
    if [[ $? -ne 0 ]] ; then
        exit 1
    fi
}

# Execute the dump978 setup script.
function InstallDump978Fa() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/decoders/dump978-fa.sh
    ${RECEIVER_BASH_DIRECTORY}/decoders/dump978-fa.sh
    if [[ $? -ne 0 ]] ; then
        exit 1
    fi
}

## FEEDERS

# Execute the ADS-B Exchange setup script.
function InstallAdsbExchange() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/feeders/adsbexchange.sh
    ${RECEIVER_BASH_DIRECTORY}/feeders/adsbexchange.sh
    if [[ $? -ne 0 ]] ; then
        exit 1
    fi
}

# Execute the Flightradar24 Feeder client setup script.
function InstallFlightradar24() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/feeders/flightradar24.sh
    ${RECEIVER_BASH_DIRECTORY}/feeders/flightradar24.sh
    if [[ $? -ne 0 ]] ; then
        exit 1
    fi
}

# Execute the OpenSky Network setup script.
function InstallOpenSkyNetwork() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/feeders/openskynetwork.sh
    ${RECEIVER_BASH_DIRECTORY}/feeders/openskynetwork.sh
    if [[ $? -ne 0 ]] ; then
        exit 1
    fi
}

# Execute the PiAware setup script
function InstallPiAware() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/feeders/piaware.sh
    ${RECEIVER_BASH_DIRECTORY}/feeders/piaware.sh
    if [[ $? -ne 0 ]] ; then
        exit 1
    fi
}

# Execute the Plane Finder Client setup script.
function InstallPlaneFinder() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/feeders/planefinder.sh
    ${RECEIVER_BASH_DIRECTORY}/feeders/planefinder.sh
    if [[ $? -ne 0 ]] ; then
        exit 1
    fi
}

## Portal

# Execute the ADS-B Receiver Project Web Portal setup script.
function InstallWebPortal() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/portal/install.sh
    ${RECEIVER_BASH_DIRECTORY}/portal/install.sh
    if [[ $? -ne 0 ]] ; then
        exit 1
    fi
}

## Extras

# Execute the beast-splitter setup script.
function InstallBeastSplitter() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/extras/beeastsplitter.sh
    ${RECEIVER_BASH_DIRECTORY}/extras/beastsplitter.sh
    if [[ $? -ne 0 ]] ; then
        exit 1
    fi
}

# Execute the Duck DNS setup script.
function InstallDuckDns() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/extras/duckdns.sh
    ${RECEIVER_BASH_DIRECTORY}/extras/duckdns.sh
    if [[ $? -ne 0 ]] ; then
        exit 1
    fi
}

#############
## DIALOGS

## Decoders

# Check if the dump1090-fa package is installed.
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
    DUMP1090_FORK="fa"
    DUMP1090_IS_INSTALLED="true"
    # Check if a newer version can be installed.
    if [[ $(sudo dpkg -s dump1090-fa 2>/dev/null | grep -c "Version: ${DUMP1090_FA_VERSION}") -eq 0 ]] ; then
        whiptail  --backtitle "RECEIVER_PROJECT_TITLE" --title "Dump1090-fa Upgrade Available" --defaultno --yesno "An updated version of dump1090-fa is available.\n\nWould you like to download, build, then install the new version?" 16 65
        case $? in
            0)
                DUMP1090_DO_UPGRADE="true"
                ;;
            1)
                DUMP1090_DO_UPGRADE="false"
                ;;
        esac
    fi
fi

# If no dump1090 fork is installed then attempt to install one.
if [[ ! "${DUMP1090_IS_INSTALLED}" = "true" ]] ; then
    DUMP1090_OPTION=$(whiptail --nocancel --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Choose Dump1090 Version To Install" --radiolist "Dump1090 does not appear to be present on this device. In order to continue setup dump1090 will need to exist on this device. Please select your prefered dump1090 version from the list below.\n\nPlease note that in order to run dump1090-fa PiAware will need to be installed as well." 16 65 2 "dump1090-fa" "(FlightAware)" ON 3>&1 1>&2 2>&3)
    case ${DUMP1090_OPTION} in
        "dump1090-fa")
            DUMP1090_FORK="fa"
            DUMP1090_DO_INSTALL="true"
            ;;
        *)
            DUMP1090_DO_INSTALL="false"
            ;;
    esac
fi

# If the FlightAware fork of dump1090 is or has been chosen to be installed PiAware must be installed.
if [[ "${DUMP1090_FORK}" = "fa" && "${DUMP1090_DO_INSTALL}" = "true" || "${DUMP1090_DO_UPGRADE}" = "true" ]]; then
     FORCE_PIAWARE_INSTALL="true"
fi

# Check if the dump978-fa package is installed.
if [[ $(dpkg-query -W -f='${STATUS}' dump978-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
    # Dump978 appears to be present on this device.
    DUMP978_FORK="fa"
    DUMP978_IS_INSTALLED="true"
    if [[ $(sudo dpkg -s dump978-fa 2>/dev/null | grep -c "Version: ${DUMP978_FA_VERSION}") -eq 0 ]]; then
        whiptail  --backtitle "RECEIVER_PROJECT_TITLE" --title "Dump978-fa Upgrade Available" --defaultno --yesno "An updated version of dump978-fa is available.\n\nWould you like to download, build, then install the new version?" 16 65
        case $? in
            0)
                DUMP978_DO_UPGRADE="true"
                ;;
            1)
                DUMP978_DO_UPGRADE="false"
                ;;
        esac
    fi
else
    # Dump978 does not appear to be present on this device.
    DUMP978_IS_INSTALLED="false"
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump978-fa Not Installed" --defaultno --yesno "Dump978 is an experimental demodulator/decoder for 978MHz UAT signals. These scripts can setup dump978 for you. However keep in mind a second RTL-SDR device will be required to feed data to it.\n\nDo you wish to install dump978?" 10 65
    case $? in
        0)
            DUMP978_DO_INSTALL="true"
            ;;
        1)
            DUMP978_DO_INSTALL="false"
            ;;
    esac
fi

## Feeder Selection Menu

# Declare the FEEDER_LIST array and the FEEDER_CHOICES file which will store choices for feeders which are available for install.
declare array FEEDER_LIST
touch ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES

# Check if the ADS-B Exchange feeder has been set up.
if [[ -f /lib/systemd/system/adsbexchange-mlat.service && -f /lib/systemd/system/adsbexchange-feed.service ]]; then
    # The feeder appears to be set up.
    echo "ADS-B Exchange Feeder (upgrade)" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
    FEEDER_LIST=("${FEEDER_LIST[@]}" 'ADS-B Exchange Feeder (upgrade)' '' OFF)
else
    # The feeder does not appear to be set up.
    echo "ADS-B Exchange Feeder" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
    FEEDER_LIST=("${FEEDER_LIST[@]}" 'ADS-B Exchange Feeder' '' OFF)
fi

# Check for the OpenSky Network package.
if [[ $(dpkg-query -W -f='${STATUS}' opensky-feeder 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
    # The OpenSky Network feeder package appears to not be installed.
    FEEDER_LIST=("${FEEDER_LIST[@]}" 'OpenSky Network Feeder' '' OFF)
else
    # Check if a newer version can be installed if this is not a Raspberry Pi device.
    if [[ $(sudo dpkg -s opensky-feeder 2>/dev/null | grep -c "Version: ${OPENSKY_NETWORK_CLIENT_VERSION}") -eq 0 ]]; then
        FEEDER_LIST=("${FEEDER_LIST[@]}" 'OpenSky Network Feeder (upgrade)' '' OFF)
    else
        FEEDER_LIST=("${FEEDER_LIST[@]}" 'OpenSky Network Feeder (reinstall)' '' OFF)
    fi
fi

# Check for the PiAware package.
if [[ $(dpkg-query -W -f='${STATUS}' piaware 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
    # Do not show the PiAware install option if the FlightAware fork of dump1090 has been chosen.
    if [[ "${DUMP1090_FORK}" != "fa" ]] ; then
        if [[ -z "${PIAWARE_INSTALL}" && "${PIAWARE_INSTALL}" = "true" ]]; then
            echo "FlightAware PiAware" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
        fi
    fi
else
    # Check if a newer version can be installed.
    if [[ $(sudo dpkg -s piaware 2>/dev/null | grep -c "Version: ${PIAWARE_VERSION}") -eq 0 ]]; then
        FEEDER_LIST=("${FEEDER_LIST[@]}" 'FlightAware PiAware (upgrade)' '' OFF)
    else
        FEEDER_LIST=("${FEEDER_LIST[@]}" 'FlightAware PiAware (reinstall)' '' OFF)
    fi
fi

# Check for the Flightradar24 Feeder Client package.
if [[ $(dpkg-query -W -f='${STATUS}' fr24feed 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
    # Add this choice to the FEEDER_LIST array to be used by the whiptail menu.
    FEEDER_LIST=("${FEEDER_LIST[@]}" 'Flightradar24 Client' '' OFF)
else
    # Check if a newer version can be installed if this is not a Raspberry Pi device.
    if [[ $(sudo dpkg -s fr24feed 2>/dev/null | grep -c "Version: ${FLIGHTRADAR24_CLIENT_VERSION_I386}") -eq 0 ]]; then
        # Add this choice to the FEEDER_LIST array to be used by the whiptail menu.
        FEEDER_LIST=("${FEEDER_LIST[@]}" 'Flightradar24 Client (upgrade)' '' OFF)
    else
        FEEDER_LIST=("${FEEDER_LIST[@]}" 'Flightradar24 Client (reinstall)' '' OFF)
    fi
fi

# Check for the Planefinder ADS-B Client package.
if [[ $(dpkg-query -W -f='${STATUS}' pfclient 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
    # The Planefinder Client package does not appear to be installed.
    FEEDER_LIST=("${FEEDER_LIST[@]}" 'Plane Finder Client' '' OFF)
else
    # Check if a newer version can be installed.
    PLANEFINDER_CLIENT_INSTALLED_VERSION=$(sudo dpkg -s pfclient | grep Version | awk '{print $2}')
    case "${CPU_ARCHITECTURE}" in
        "armv7l"|"armv6l")
            if [[ ! "$PLANEFINDER_CLIENT_INSTALLED_VERSION" = "${PLANEFINDER_CLIENT_VERSION_ARMHF}" ]]; then
                FEEDER_LIST=("${FEEDER_LIST[@]}" 'Plane Finder Client (upgrade)' '' OFF)
            else
                FEEDER_LIST=("${FEEDER_LIST[@]}" 'Plane Finder Client (reinstall)' '' OFF)
            fi
            ;;
        "aarch64")
            if [[ ! "$PLANEFINDER_CLIENT_INSTALLED_VERSION" = "${PLANEFINDER_CLIENT_VERSION_ARM64}" ]]; then
                FEEDER_LIST=("${FEEDER_LIST[@]}" 'Plane Finder Client (upgrade)' '' OFF)
            else
                FEEDER_LIST=("${FEEDER_LIST[@]}" 'Plane Finder Client (reinstall)' '' OFF)
            fi
            ;;
        "x86_64")
            if [[ ! "$PLANEFINDER_CLIENT_INSTALLED_VERSION" = "${PLANEFINDER_CLIENT_VERSION_AMD64}" ]]; then
                FEEDER_LIST=("${FEEDER_LIST[@]}" 'Plane Finder Client (upgrade)' '' OFF)
            else
                FEEDER_LIST=("${FEEDER_LIST[@]}" 'Plane Finder Client (reinstall)' '' OFF)
            fi
            ;;
        "i386")
            if [[ ! "$PLANEFINDER_CLIENT_INSTALLED_VERSION" = "${PLANEFINDER_CLIENT_VERSION_I386}" ]]; then
                FEEDER_LIST=("${FEEDER_LIST[@]}" 'Plane Finder Client (upgrade)' '' OFF)
            else
                FEEDER_LIST=("${FEEDER_LIST[@]}" 'Plane Finder Client (reinstall)' '' OFF)
            fi
            ;;
        *)
            FEEDER_LIST=("${FEEDER_LIST[@]}" 'Plane Finder Client (reinstall)' '' OFF)
    esac
fi

if [[ -n "${FEEDER_LIST}" ]] ; then
    # Display a checklist containing feeders that are not installed if any.
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Feeder Installation Options" --checklist --nocancel --separate-output "The following feeders are available for installation.\nChoose the feeders you wish to install." 13 65 6 "${FEEDER_LIST[@]}" 2>${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
else
    # Since all available feeders appear to be installed inform the user of the fact.
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "All Feeders Installed" --msgbox "It appears that all the optional feeders available for installation by this script have been installed already." 8 65
fi

## ADS-B Receiver Project Web Portal

# Ask if the web portal should be installed.
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Install The ADS-B Receiver Project Web Portal" --yesno "The ADS-B Receiver Project Web Portal is a lightweight web interface for dump-1090  installations.\n\nCurrent features include the following:\n  Unified navigation between all web pages.\n  System and dump1090 performance graphs.\n\nWould you like to install the ADS-B Receiver Project web portal?" 14 78
case $? in
    0)
        WEBPORTAL_DO_INSTALL="true"
        ;;
    1)
        WEBPORTAL_DO_INSTALL="false"
        ;;
esac

## Extras

# Declare the EXTRAS_LIST array and the EXTRAS_CHOICES file which will store choices for extras which are available for install.
declare array EXTRAS_LIST
touch ${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES

# Check if the beast-splitter package is installed.
if [[ $(dpkg-query -W -f='${STATUS}' beast-splitter 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
    # The beast-splitter package appears to not be installed.
    EXTRAS_LIST=("${EXTRAS_LIST[@]}" 'beast-splitter' '' OFF)
else
    # Offer the option to build then reinstall the beast-splitter package.
    EXTRAS_LIST=("${EXTRAS_LIST[@]}" 'beast-splitter (reinstall)' '' OFF)
fi

# Check if the Duck DNS update script exists.
if [[ ! -f "${RECEIVER_BUILD_DIRECTORY}/duckdns/duck.sh" ]]; then
    # Duck DNS does not appear to be set up on this device.
    EXTRAS_LIST=("${EXTRAS_LIST[@]}" 'Duck DNS Free Dynamic DNS Hosting' '' OFF)
else
    # Offer the option to install/setup Duck DNS once more.
    EXTRAS_LIST=("${EXTRAS_LIST[@]}" 'Duck DNS Free Dynamic DNS Hosting (reinstall)' '' OFF)
fi

# Display a menu the user can use to pick extras to be installed.
if [[ -n "${EXTRAS_LIST}" ]]; then
    # Display a checklist containing feeders that are not installed if any.
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Feeder Installation Options" --checklist --nocancel --separate-output "The following extras are available for installation, please select any which you wish to install." 13 65 4 "${EXTRAS_LIST[@]}" 2>${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES
else
    # Since all available extras appear to be installed inform the user of the fact.
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "All Extras Installed" --msgbox "It appears that all the optional extras available for installation by this script have been installed already." 8 65
fi

## Setup Confirmation

declare CONFIRMATION

# Check if anything is to be done before moving on.
if [[ "${DUMP1090_DO_INSTALL}" = "false" && "${DUMP1090_DO_UPGRADE}" = "false" && "${DUMP978_DO_INSTALL}" = "false" && "${DUMP978_DO_UPGRADE}" = "false" && "${WEBPORTAL_DO_INSTALL}" = "false" && ! -s "${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES" && ! -s "${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES" ]]; then
    # Nothing was chosen to be installed.
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Nothing to be done" --msgbox "Nothing has been selected to be installed so the script will exit now." 10 65
    echo -e "\e[31m"
    echo -e "  Nothing was selected to do or be installed."
    echo -e "\e[37m"
    exit 1
else
    # The user decided to install software.
    CONFIRMATION="The following software will be installed:\n"

    # dump1090
    if [[ "${DUMP1090_DO_UPGRADE}" = "true" ]]; then
        case ${DUMP1090_FORK} in
            "fa")
                CONFIRMATION="${CONFIRMATION}\n  * dump1090-fa (upgrade)"
                ;;
        esac
    elif [[ "${DUMP1090_DO_INSTALL}" = "true" ]]; then
        case ${DUMP1090_FORK} in
            "fa")
                CONFIRMATION="${CONFIRMATION}\n  * dump1090-fa"
                ;;
        esac
    fi

    # dump978
    if [[ "${DUMP978_DO_UPGRADE}" = "true" ]]; then
        CONFIRMATION="${CONFIRMATION}\n  * dump978 (rebuild)"
    elif [[ "${DUMP978_DO_INSTALL}" = "true" ]]; then
        CONFIRMATION="${CONFIRMATION}\n  * dump978"
    fi

    # If PiAware is required add it to the list.
    if [[ "${DUMP1090_FORK}" = "fa" && $(dpkg-query -W -f='${STATUS}' piaware 2>/dev/null | grep -c "ok installed") -eq 0 || "${PIAWARE_INSTALL}" = "true" ]]; then
        CONFIRMATION="${CONFIRMATION}\n  * FlightAware PiAware"
    fi

    if [[ -s "${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES" ]]; then
        while read FEEDER_CHOICE
        do
            CONFIRMATION="${CONFIRMATION}\n  * ${FEEDER_CHOICE}"
        done < ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
    fi

    if [[ "${WEBPORTAL_DO_INSTALL}" = "true" ]]; then
        CONFIRMATION="${CONFIRMATION}\n  * ADS-B Receiver Project Web Portal"
    fi

    if [[ -s "${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES" ]]; then
        while read EXTRAS_CHOICE
        do
            CONFIRMATION="${CONFIRMATION}\n  * ${EXTRAS_CHOICE}"
        done < ${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES
    fi

    CONFIRMATION="${CONFIRMATION}\n\n"
fi

# Ask for confirmation before moving on.
CONFIRMATION="${CONFIRMATION}Do you wish to continue setup?"
if ! (whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Confirm You Wish To Continue" --yesno "${CONFIRMATION}" 21 78) then
    echo -e "\e[31m"
    echo "  Installation canceled by user."
    exit 1
fi

#################
## BEGIN SETUP

## Decoders

if [[ "${DUMP1090_DO_INSTALL}" = "true" || "${DUMP1090_DO_UPGRADE}" = "true" ]]; then
    case ${DUMP1090_FORK} in
        "fa")
             InstallDump1090Fa
             ;;
    esac
fi

if [[ "${DUMP978_DO_INSTALL}" = "true" || "${DUMP978_DO_UPGRADE}" = "true" ]]; then
    InstallDump978Fa
fi

## Feeders

# Moved execution of functions outside of while loop.
# Inside the while loop the installation scripts are not stopping at reads.

RUN_ADSBEXCHANGE_SCRIPT="false"
RUN_PIAWARE_SCRIPT="false"
RUN_FLIGHTRADAR24_SCRIPT="false"
RUN_OPENSKYNETWORK_SCRIPT="false"
RUN_PLANEFINDER_SCRIPT="false"

if [[ -s "${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES" ]]; then
    while read FEEDER_CHOICE
    do
        case ${FEEDER_CHOICE} in
            "ADS-B Exchange Feeder"|"ADS-B Exchange Feeder (upgrade)")
                RUN_ADSBEXCHANGE_SCRIPT="true"
                ;;
            "FlightAware PiAware"|"FlightAware PiAware (upgrade)"|"FlightAware PiAware (reinstall)")
                RUN_PIAWARE_SCRIPT="true"
                ;;
            "Flightradar24 Client"|"Flightradar24 Client (upgrade)"|"Flightradar24 Client (reinstall)")
                RUN_FLIGHTRADAR24_SCRIPT="true"
                ;;
            "OpenSky Network Feeder")
                RUN_OPENSKYNETWORK_SCRIPT="true"
                ;;
            "Plane Finder Client"|"Plane Finder Client (upgrade)"|"Plane Finder Client (reinstall)")
                RUN_PLANEFINDER_SCRIPT="true"
                ;;
        esac
    done < ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
fi

if [[ "${RUN_ADSBEXCHANGE_SCRIPT}" = "true" ]]; then
    InstallAdsbExchange
fi

if [[ "${RUN_PIAWARE_SCRIPT}" = "true" || "${FORCE_PIAWARE_INSTALL}" = "true" ]]; then
    InstallPiAware
fi

if [[ "${RUN_FLIGHTRADAR24_SCRIPT}" = "true" ]]; then
    InstallFlightradar24
fi

if [[ "${RUN_OPENSKYNETWORK_SCRIPT}" = "true" ]]; then
    InstallOpenSkyNetwork
fi

if [[ "${RUN_PLANEFINDER_SCRIPT}" = "true" ]]; then
    InstallPlaneFinder
fi

## ADS-B Receiver Project Web Portal

if [[ "${WEBPORTAL_DO_INSTALL}" = "true" ]]; then
    InstallWebPortal
fi

# Moved execution of functions outside of while loop.
# Inside the while loop the installation scripts are not stopping at reads.

RUN_BEASTSPLITTER_SCRIPT="false"
RUN_DUCKDNS_SCRIPT="false"

if [[ -s "${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES" ]]; then
    while read EXTRAS_CHOICE
    do
        case ${EXTRAS_CHOICE} in
            "beast-splitter"|"beast-splitter (reinstall)")
                RUN_BEASTSPLITTER_SCRIPT="true"
                ;;
            "Duck DNS Free Dynamic DNS Hosting"|"Duck DNS Free Dynamic DNS Hosting (reinstall)")
                RUN_DUCKDNS_SCRIPT="true"
                ;;
        esac
    done < ${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES
fi

if [[ "${RUN_BEASTSPLITTER_SCRIPT}" = "true" ]]; then
    InstallBeastSplitter
fi

if [[ "${RUN_DUCKDNS_SCRIPT}" = "true" ]]; then
    InstallDuckDns
fi

exit 0

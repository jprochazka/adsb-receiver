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
# Copyright (c) 2015-2018 Joseph A. Prochazka                                       #
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

### VARIABLES

RECEIVER_ROOT_DIRECTORY="${PWD}"
RECEIVER_BASH_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/bash"
RECEIVER_BUILD_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/build"

## INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

# Source the automated install configuration file if this is an automated installation.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] && [[ -s "${RECEIVER_CONFIGURATION_FILE}" ]] ; then
    source ${RECEIVER_CONFIGURATION_FILE}
fi

## Set the project title variable.
export RECEIVER_PROJECT_TITLE="The ADS-B Receiver Project v${PROJECT_VERSION} Installer"

###############
## FUNCTIONS

## DECODERS

# Execute the dump1090-mutability setup script.
function InstallDump1090Mutability() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/decoders/dump1090-mutability.sh
    ${RECEIVER_BASH_DIRECTORY}/decoders/dump1090-mutability.sh
    if [[ $? -ne 0 ]] ; then
        exit 1
    fi
}

# Execute the dump1090-fa setup script.
function InstallDump1090Fa() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/decoders/dump1090-fa.sh
    ${RECEIVER_BASH_DIRECTORY}/decoders/dump1090-fa.sh
    if [[ $? -ne 0 ]] ; then
        exit 1
    fi
}

# Execute the dump1090-hptoa setup script.
function InstallDump1090Hptoa() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/decoders/dump1090-hptoa.sh
    ${RECEIVER_BASH_DIRECTORY}/decoders/dump1090-hptoa.sh
    if [[ $? -ne 0 ]] ; then
        exit 1
    fi
}

# Execute the dump978 setup script.
function InstallDump978() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/decoders/dump978.sh
    ${RECEIVER_BASH_DIRECTORY}/decoders/dump978.sh
    if [[ $? -ne 0 ]] ; then
        exit 1
    fi
}

# Execute the RTL-SDR OGN setup script.
function InstallRtlsdrOgn() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/decoders/rtlsdr-ogn.sh
    ${RECEIVER_BASH_DIRECTORY}/decoders/rtlsdr-ogn.sh
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

# Execute the ADSBHub setup script.
function InstallAdsbhub() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/feeders/adsbhub.sh
    ${RECEIVER_BASH_DIRECTORY}/feeders/adsbhub.sh
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

# Execute the AboveTustin setup script.
function InstallAboveTustin() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/extras/abovetustin.sh
    ${RECEIVER_BASH_DIRECTORY}/extras/abovetustin.sh
    if [[ $? -ne 0 ]] ; then
        exit 1
    fi
}

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

# Check if the dump1090-mutability package is installed.
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
    DUMP1090_FORK="mutability"
    DUMP1090_IS_INSTALLED="true"
    # Skip over this dialog if this installation is set to be automated.
    if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
        # Ask if dump1090-mutability should be reinstalled.
        whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump1090-mutability Installed" --defaultno --yesno "The dump1090-mutability package appears to be installed on your device, however...\n\nThe dump1090-mutability v1.15~dev source code is regularly updated without a change made to the version numbering.\n\nTo ensure you are running the latest version of dump1090-mutability you may opt to rebuild and reinstall this package.\n\nDownload, build, and reinstall this package?" 17 65
        case $? in
            0)
                DUMP1090_DO_UPGRADE="true"
                ;;
            1)
                DUMP1090_DO_UPGRADE="false"
                ;;
        esac
    else
        # Refer to the installation configuration to decide if dump1090-mutability is to be reinstalled or not.
        if [[ "${DUMP1090_UPGRADE}" = "true" ]] ; then
            DUMP1090_DO_UPGRADE="true"
        else
            DUMP1090_DO_UPGRADE="false"
        fi
    fi
fi

# Check if the dump1090-fa package is installed.
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
    DUMP1090_FORK="fa"
    DUMP1090_IS_INSTALLED="true"
    # Check if a newer version can be installed.
    if [[ $(sudo dpkg -s dump1090-fa 2>/dev/null | grep -c "Version: ${PIAWARE_VERSION}") -eq 0 ]] ; then
        # Skip over this dialog if this installation is set to be automated.
        if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
            whiptail  --backtitle "RECEIVER_PROJECT_TITLE" --title "Dump1090-fa Upgrade Available" --defaultno --yesno "An updated version of dump1090-fa is available.\n\nWould you like to download, build, then install the new version?" 16 65
            case $? in
                0)
                    DUMP1090_DO_UPGRADE="true"
                    ;;
                1)
                    DUMP1090_DO_UPGRADE="false"
                    ;;
            esac
        else
            # If a newer version of dump1090-fa is available refer to the installation configuration to decide if it should be upgraded or not.
            if [[ "${DUMP1090_UPGRADE}" = "true" ]] ; then
                DUMP1090_DO_UPGRADE="true"
            else
                DUMP1090_DO_UPGRADE="false"
            fi
        fi
    fi
fi

# Check if dump1090-hptoa is being used.
if [ -f  ${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/dump1090-hptoa/build/dump1090 ] && [ -f ${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/dump1090-hptoa/build/faup1090 ] && [ -f ${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/dump1090-hptoa/build/view1090 ] && [ -f /etc/init.d/dump1090 ] ; then
    DUMP1090_FORK="hptoa"
    DUMP1090_IS_INSTALLED="true"
    # Skip over this dialog if this installation is set to be automated.
    if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
        # Ask if dump1090-hptoa should be reinstalled.
        whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump1090-hptoa Installed" --defaultno --yesno "The dump1090-hptoa package appears to be installed on your device, however...\n\nThe dump1090-hptoa source code may have been updated recently.\n\nTo ensure you are running the latest version of dump1090-hptoa you may opt to rebuild these binaries.\n\nDownload and rebuild dump1090-hptoa from source?" 17 65

        case $? in
            0)
                DUMP1090_DO_UPGRADE="true"
                ;;
            1)
                DUMP1090_DO_UPGRADE="false"
                ;;
        esac
    else
        # Refer to the installation configuration to decide if dump1090-hptoa is to be reinstalled or not.
        if [[ "${DUMP1090_UPGRADE}" = "true" ]] ; then
            DUMP1090_DO_UPGRADE="true"
        else
            DUMP1090_DO_UPGRADE="false"
        fi
    fi
fi

# If no dump1090 fork is installed then attempt to install one.
if [[ ! "${DUMP1090_IS_INSTALLED}" = "true" ]] ; then
    # If this is not an automated installation ask the user which one to install.
    if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
        DUMP1090_OPTION=$(whiptail --nocancel --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Choose Dump1090 Version To Install" --radiolist "Dump1090 does not appear to be present on this device. In order to continue setup dump1090 will need to exist on this device. Please select your prefered dump1090 version from the list below.\n\nPlease note that in order to run dump1090-fa PiAware will need to be installed as well." 16 65 3 "dump1090-mutability" "(Mutability)" ON "dump1090-fa" "(FlightAware)" OFF "dump1090-hptoa" "(OpenSky Network)" OFF 3>&1 1>&2 2>&3)
        case ${DUMP1090_OPTION} in
            "dump1090-mutability")
                DUMP1090_FORK="mutability"
                DUMP1090_DO_INSTALL="true"
                ;;
            "dump1090-fa")
                DUMP1090_FORK="fa"
                DUMP1090_DO_INSTALL="true"
                ;;
             "dump1090-hptoa")
                DUMP1090_FORK="hptoa"
                DUMP1090_DO_INSTALL="true"
                ;;
            *)
                DUMP1090_DO_INSTALL="false"
                ;;
        esac
    else
        # Refer to the installation configuration to check if a dump1090 fork has been specified
        if [[ "${DUMP1090_FORK}" = "mutability" ]] || [[ "${DUMP1090_FORK}" = "fa" ]] || [[ "${DUMP1090_FORK}" = "hptoa" ]] ; then
            DUMP1090_DO_INSTALL="true"
        else
            DUMP1090_DO_INSTALL="false"
        fi
    fi
fi

# If the FlightAware fork of dump1090 is or has been chosen to be installed PiAware must be installed.
if [[ "${DUMP1090_FORK}" = "fa" ]] ; then
    if [[ "${DUMP1090_DO_INSTALL}" = "true" ]] || [[ "${DUMP1090_DO_UPGRADE}" = "true" ]] ; then
         FORCE_PIAWARE_INSTALL="true"
    fi
fi

# Check if the dump978 binaries exist.
if [[ -f "${RECEIVER_BUILD_DIRECTORY}/dump978/dump978" ]] && [[ -f "${RECEIVER_BUILD_DIRECTORY}/dump978/uat2text" ]] && [[ -f "${RECEIVER_BUILD_DIRECTORY}/dump978/uat2esnt" ]] && [[ -f "${RECEIVER_BUILD_DIRECTORY}/dump978/uat2json" ]] ; then
    # Dump978 appears to have been built already.
    DUMP978_IS_INSTALLED="true"
    # Prompt user to confirm if a rebuild is required.
    if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
        whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump978 Installed" --defaultno --yesno "Dump978 appears to be installed on your device, however...\n\nThe dump978 source code may have been updated since it was built last. To ensure you are running the latest version of dump978 you may opt to rebuild the binaries making up dump978.\n\nDownload and rebuild the dump978 binaries?" 14 65
        case $? in
            0)
                DUMP978_DO_UPGRADE="true"
                ;;
            1)
                DUMP978_DO_UPGRADE="false"
                ;;
        esac
    else
        # Refer to the installation configuration to decide if dump978 is to be rebuilt from source or not.
        if [[ "${DUMP978_UPGRADE}" = "true" ]] ; then
            DUMP978_DO_UPGRADE="true"
        else
            DUMP978_DO_UPGRADE="false"
        fi
    fi
else
    # Dump978 does not appear to be present on this device.
    DUMP978_IS_INSTALLED="false"
    # Prompt user to confirm if installation is required.
    if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
        whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump978 Not Installed" --defaultno --yesno "Dump978 is an experimental demodulator/decoder for 978MHz UAT signals. These scripts can setup dump978 for you. However keep in mind a second RTL-SDR device will be required to feed data to it.\n\nDo you wish to install dump978?" 10 65
        case $? in
            0)
                DUMP978_DO_INSTALL="true"
                ;;
            1)
                DUMP978_DO_INSTALL="false"
                ;;
        esac
    else
        # Refer to the installation configuration to decide if dump978 is to be installed from source or not.
        if [[ "${DUMP978_INSTALL}" = "true" ]] ; then
            DUMP978_DO_INSTALL="true"
        else
            DUMP978_DO_INSTALL="false"
        fi

    fi
fi

# Check if the RTL-SDR OGN binaries exist on this device.
if [[ -f "/etc/init.d/rtlsdr-ogn" ]] ; then
    RTLSDROGN_IS_INSTALLED="true"
    # Check if a newer version of the binaries are available.
    if [[ ! -d "${RECEIVER_BUILD_DIRECTORY}/rtlsdr-ogn/rtlsdr-ogn-${RTLSDROGN_VERSION}" ]] ; then
        # Prompt user to confirm if a rebuild is required.
        if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
            whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "RTL-SDR OGN Installed" --defaultno --yesno "A newer version of the RTL-SDR OGN binaries is available.\n\nWould you like to setup the newer binaries on this device?" 14 65
            case $? in
                0)
                    RTLSDROGN_DO_UPGRADE="true"
                    ;;
                1)
                    RTLSDROGN_DO_UPGRADE="false"
                    ;;
            esac
        else
            # Refer to the installation configuration to decide if RTL-SDR OGN is to be rebuilt from source or not.
            if [[ "${RTLSDROGN_UPGRADE}" = "true" ]] ; then
                RTLSDROGN_DO_UPGRADE="true"
            else
                RTLSDROGN_DO_UPGRADE="false"
            fi
        fi
    fi
else
    # The RTL-SDR OGN binaries do not appear to exist on this device.

    # Support for Open Glider Network has been removed until the script has been rewritten to
    # utilize the updated software they supply in their GItHub repositories.
    #
    #   https://github.com/glidernet

    RTLSDROGN_IS_INSTALLED="false"
    RTLSDROGN_DO_INSTALL="false"

    ## Prompt user to confirm if installation is required.
    #if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
    #    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "RTL-SDR OGN Not Installed" --defaultno --yesno "RTL-SDR OGN is a combined decoder and feeder for the Open Glider Network which focuses on tracking gilders and other GA aircraft equipped with FLARM, FLARM-compatible devices or OGN tracker.\n\nRTL-SDR OGN will require an additional RTL-SDR dongle to run.\nFLARM is most prevalent within Europe, but new receivers are welcome at any location.\n\nDo you wish to setup RTL-SDR OGN?" 10 65
    #    case $? in
    #        0)
    #            RTLSDROGN_DO_INSTALL="true"
    #            ;;
    #        1)
    #            RTLSDROGN_DO_INSTALL="false"
    #            ;;
    #    esac
    #else
    #    # Refer to the installation configuration to decide if RTL-SDR OGN is to be installed.
    #    if [[ "${RTLSDROGN_INSTALL}" = "true" ]] ; then
    #        RTLSDROGN_DO_INSTALL="true"
    #    else
    #        RTLSDROGN_DO_INSTALL="false"
    #    fi
    #fi
fi

## Feeder Selection Menu

# Declare the FEEDER_LIST array and the FEEDER_CHOICES file which will store choices for feeders which are available for install.
declare array FEEDER_LIST
touch ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES

# Check if MLAT client has been installed to be used to feed ADS-B Exchange.
if [[ $(dpkg-query -W -f='${STATUS}' mlat-client 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
    # The mlat-client package appears to be installed.
    MLAT_CLIENT_IS_INSTALLED="true"
    MLAT_CLIENT_VERSION_AVAILABLE=$(echo ${MLAT_CLIENT_VERSION} | tr -cd '[:digit:]' | sed -e 's/^0//g')
    MLAT_CLIENT_VERSION_INSTALLED=$(sudo dpkg -s mlat-client 2>/dev/null | grep "^Version:" | awk '{print $2}' | tr -cd '[:digit:]' | sed -e 's/^0//g')
    # Check if installed mlat-client matches the available version.
    if [[ ! "${MLAT_CLIENT_VERSION_AVAILABLE}" = "${MLAT_CLIENT_VERSION_INSTALLED}" ]] ; then
        # Prompt user to confirm the upgrade.
        if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
            # Add this choice to the FEEDER_LIST array to be used by the whiptail menu.
            FEEDER_LIST=("${FEEDER_LIST[@]}" 'ADS-B Exchange data export and MLAT Client (upgrade)' '' OFF)
        else
            # Check the installation configuration file to see if the mlat-client Client is to be upgraded.
            if [[ -z "${ADSBEXCHANGE_INSTALL}" ]] && [[ "${ADSBEXCHANGE_INSTALL}" = "true" ]] && [[ -z "${ADSBEXCHANGE_UPGRADE}" ]] && [[ "${ADSBEXCHANGE_UPGRADE}" = "true" ]] ; then
                # Since the menu will be skipped add this choice directly to the FEEDER_CHOICES file.
                echo "ADS-B Exchange data export and MLAT Client (upgrade)" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
            fi
        fi
    fi
else
    # The mlat-client package does not appear to be installed.
    MLAT_CLIENT_IS_INSTALLED="false"
    if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
        # Add this choice to the FEEDER_LIST array to be used by the whiptail menu.
        FEEDER_LIST=("${FEEDER_LIST[@]}" 'ADS-B Exchange data export and MLAT Client' '' OFF)
    else
        # Check the installation configuration file to see if ADS-B Exchange feeding is to be setup.
        if [[ -z "${ADSBEXCHANGE_INSTALL}" ]] && [[ "${ADSBEXCHANGE_INSTALL}" = "true" ]] ; then
            # Since the menu will be skipped add this choice directly to the FEEDER_CHOICES file.
            echo "ADS-B Exchange data export and MLAT Client" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
        fi
    fi
fi

# Check if the ADSBHub client script has been set up.
if ! grep -q "${BUILDDIR}/adsbexchange/adsbexchange-maint.sh &" /etc/rc.local; then
    # The ADSBHub client script does not appear to be executed on start up.
    if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
        # Add this choice to the FEEDER_LIST array to be used by the whiptail menu.
        FEEDER_LIST=("${FEEDER_LIST[@]}" 'ADSBHub Client Script' '' OFF)
    else
        # Check the installation configuration file to see if the ADSBHub client is to be installed.
        if [[ -z "${ADSBHUB_INSTALL}" ]] && [[ "${ADSBHUB_INSTALL}" = "true" ]] ; then
            # Since the menu will be skipped add this choice directly to the FEEDER_CHOICES file.
            echo "ADSBHub Client Script" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
        fi
    fi
fi

# Check for the OpenSky Network package.
if [[ $(dpkg-query -W -f='${STATUS}' opensky-feeder 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
    # The OpenSky Network feeder package appears to not be installed.
    if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
        # Add this choice to the FEEDER_LIST array to be used by the whiptail menu.
        FEEDER_LIST=("${FEEDER_LIST[@]}" 'OpenSky Network Feeder' '' OFF)
    else
        # Check the installation configuration file to see if the OpenSky Network package is to be installed.
        if [[ -z "${OPENSKY_NETWORK_INSTALL}" ]] && [[ "${OPENSKY_NETWORK_INSTALL}" = "true" ]] ; then
            # Since the menu will be skipped add this choice directly to the FEEDER_CHOICES file.
            echo "OpenSky Network Feeder" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
        fi
    fi
fi

# Check for the PiAware package.
if [[ $(dpkg-query -W -f='${STATUS}' piaware 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
    # Do not show the PiAware install option if the FlightAware fork of dump1090 has been chosen.
    if [[ "${DUMP1090_FORK}" != "fa" ]] ; then
        # The PiAware package appears to not be installed.
        if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
            # Add this choice to the FEEDER_LIST array to be used by the whiptail menu.
            FEEDER_LIST=("${FEEDER_LIST[@]}" 'FlightAware PiAware' '' OFF)
        else
            # Check the installation configuration file to see if PiAware is to be installed.
            if [[ -z "${PIAWARE_INSTALL}" ]] && [[ "${PIAWARE_INSTALL}" = "true" ]] ; then
                # Since the menu will be skipped add this choice directly to the FEEDER_CHOICES file.
                echo "FlightAware PiAware" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
            fi
        fi
    fi
else
    # Check if a newer version can be installed.
    if [[ $(sudo dpkg -s piaware 2>/dev/null | grep -c "Version: ${PIAWARE_VERSION}") -eq 0 ]] ; then
        if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
            # Add this choice to the FEEDER_LIST array to be used by the whiptail menu.
            FEEDER_LIST=("${FEEDER_LIST[@]}" 'FlightAware PiAware (upgrade)' '' OFF)
        else
            # Check the installation configuration file to see if PiAware is to be upgraded.
            if [[ -z "${PIAWARE_INSTALL}" ]] && [[ "${PIAWARE_INSTALL}" = "true" ]] && [[ -z "${PIAWARE_UPGRADE}" ]] && [[ "${PIAWARE_UPGRADE}" = "true" ]] ; then
                # Since the menu will be skipped add this choice directly to the FEEDER_CHOICES file.
                echo "FlightAware PiAware (upgrade)" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
            fi
        fi
    fi
fi

# Check for the Flightradar24 Feeder Client package.
if [[ $(dpkg-query -W -f='${STATUS}' fr24feed 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
    # The Flightradar24 client package does not appear to be installed.
    if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
        # Add this choice to the FEEDER_LIST array to be used by the whiptail menu.
        FEEDER_LIST=("${FEEDER_LIST[@]}" 'Flightradar24 Client' '' OFF)
    else
        # Check the installation configuration file to see if the Flightradar24 Client is to be installed.
        if [[ -z "${FLIGHTRADAR_INSTALL}" ]] && [[ "${FLIGHTRADAR_INSTALL}" = "true" ]] ; then
            # Since the menu will be skipped add this choice directly to the FEEDER_CHOICES file.
            echo "Flightradar24 Client" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
        fi
    fi
else
    # Check if a newer version can be installed if this is not a Raspberry Pi device.
    if [[ "${CPU_ARCHITECTURE}" != "armv7l" ]] ; then
        if [[ $(sudo dpkg -s fr24feed 2>/dev/null | grep -c "Version: ${FLIGHTRADAR24_CLIENT_VERSION_I386}") -eq 0 ]] ; then
            if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
                # Add this choice to the FEEDER_LIST array to be used by the whiptail menu.
                FEEDER_LIST=("${FEEDER_LIST[@]}" 'Flightradar24 Client (upgrade)' '' OFF)
            else
                # Check the installation configuration file to see if the Flightradar24 Client is to be upgraded.
                if [[ -z "${FLIGHTRADAR_INSTALL}" ]] && [[ "${FLIGHTRADAR_INSTALL}" = "true" ]] && [[ -z "${FLIGHTRADAR_UPGRADE}" ]] && [[ "${FLIGHTRADAR_UPGRADE}" = "true" ]] ; then
                    # Since the menu will be skipped add this choice directly to the FEEDER_CHOICES file.
                    echo "Flightradar24 Client (upgrade)" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
                fi
            fi
        fi
    fi
fi

# Check for the Planefinder ADS-B Client package.
if [[ $(dpkg-query -W -f='${STATUS}' pfclient 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
    # The Planefinder Client package does not appear to be installed.
    if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
        # Add this choice to the FEEDER_LIST array to be used by the whiptail menu.
        FEEDER_LIST=("${FEEDER_LIST[@]}" 'Plane Finder Client' '' OFF)
    else
        # Check the installation configuration file to see if the Plane Finder Client is to be installed.
        if [[ -z "${PLANEFINDER_INSTALL}" ]] && [[ "${PLANEFINDER_INSTALL}" = "true" ]] ; then
            # Since the menu will be skipped add this choice directly to the FEEDER_CHOICES file.
            echo "Plane Finder Client" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
        fi
    fi
else
    # Check if a newer version can be installed.
    if [[ "${CPU_ARCHITECTURE}" = "armv7l" ]] ; then
        if [[ ! $(sudo dpkg -s pfclient | grep Version | awk '{print $2}') == "$PLANEFINDER_CLIENT_VERSION_ARM" ]] ; then
            if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
                # Add this choice to the FEEDER_LIST array to be used by the whiptail menu.
                FEEDER_LIST=("${FEEDER_LIST[@]}" 'Plane Finder Client (upgrade)' '' OFF)
            else
                # Check the installation configuration file to see if the Planefinder Client is to be upgraded.
                if [[ -z "${PLANEFINDER_INSTALL}" ]] && [[ "${PLANEFINDER_INSTALL}" = "true" ]] && [[ -z "${PLANEFINDER_UPGRADE}" ]] && [[ "${PLANEFINDER_UPGRADE}" = "true" ]] ; then
                    # Since the menu will be skipped add this choice directly to the FEEDER_CHOICES file.
                    echo "Plane Finder Client (upgrade)" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
                fi
            fi
        fi
    else
        if [[ ! $(sudo dpkg -s pfclient | grep Version | awk '{print $2}') == "$PLANEFINDER_CLIENT_VERSION_I386" ]] ; then
            if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
                # Add this choice to the FEEDER_LIST array to be used by the whiptail menu.
                FEEDER_LIST=("${FEEDER_LIST[@]}" 'Plane Finder Client (upgrade)' '' OFF)
            else
                # Check the installation configuration file to see if the Planefinder Client is to be upgraded.
                if [[ -z "${PLANEFINDER_INSTALL}" ]] && [[ "${PLANEFINDER_INSTALL}" = "true" ]] && [[ -z "${PLANEFINDER_UPGRADE}" ]] && [[ "${PLANEFINDER_UPGRADE}" = "true" ]] ; then
                    # Since the menu will be skipped add this choice directly to the FEEDER_CHOICES file.
                    echo "Plane Finder Client (upgrade)" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
                fi
            fi
        fi
    fi
fi

if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
    if [[ -n "${FEEDER_LIST}" ]] ; then
        # Display a checklist containing feeders that are not installed if any.
        whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Feeder Installation Options" --checklist --nocancel --separate-output "The following feeders are available for installation.\nChoose the feeders you wish to install." 13 65 6 "${FEEDER_LIST[@]}" 2>${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
    else
        # Since all available feeders appear to be installed inform the user of the fact.
        whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "All Feeders Installed" --msgbox "It appears that all the optional feeders available for installation by this script have been installed already." 8 65
    fi
fi

## ADS-B Receiver Project Web Portal

if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
    # Ask if the web portal should be installed.
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Install The ADS-B Receiver Project Web Portal" --yesno "The ADS-B Receiver Project Web Portal is a lightweight web interface for dump-1090-mutability installations.\n\nCurrent features include the following:\n  Unified navigation between all web pages.\n  System and dump1090 performance graphs.\n\nWould you like to install the ADS-B Receiver Project web portal?" 14 78
    case $? in
        0)
            WEBPORTAL_DO_INSTALL="true"
            ;;
        1)
            WEBPORTAL_DO_INSTALL="false"
            ;;
    esac
fi

## Extras

# Declare the EXTRAS_LIST array and the EXTRAS_CHOICES file which will store choices for extras which are available for install.
declare array EXTRAS_LIST
touch ${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES

# Check if the AboveTustin repository has been cloned.
if [[ -d "${RECEIVER_BUILD_DIRECTORY}/AboveTustin" ]] && [[ -d "${RECEIVER_BUILD_DIRECTORY}/AboveTustin/.git" ]] ; then
    # The AboveTustin repository has been cloned to this device.
    if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
        # Add this choice to the EXTRAS_LIST array to be used by the whiptail menu.
        EXTRAS_LIST=("${EXTRAS_LIST[@]}" 'AboveTustin (reinstall)' '' OFF)
    else
        # Check the installation configuration file to see if AboveTustin is to be upgraded.
        if [[ -z "${ABOVETUSTIN_INSTALL}" ]] && [[ "${ABOVETUSTIN_INSTALL}" = "true" ]] && [[ -z "${ABOVETUSTIN_UPGRADE}" ]] && [[ "${ABOVETUSTIN_UPGRADE}" = "true" ]] ; then
            # Since the menu will be skipped add this choice directly to the EXTRAS_CHOICES file.
            echo "AboveTustin (reinstall)" >> ${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES
        fi
    fi
else
    # The AboveTustin repository has not been cloned to this device.
    if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
        # Add this choice to the EXTRAS_LIST array to be used by the whiptail menu.
        EXTRAS_LIST=("${EXTRAS_LIST[@]}" 'AboveTustin' '' OFF)
    else
        # Check the installation configuration file to see if AboveTustin is to be installed.
        if [[ -z "${ABOVETUSTIN_INSTALL}" ]] && [[ "${ABOVETUSTIN_INSTALL}" = "true" ]] ; then
            # Since the menu will be skipped add this choice directly to the EXTRAS_CHOICES file.
            echo "AboveTustin" >> ${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES
        fi
    fi
fi

# Check if the beast-splitter package is installed.
if [[ $(dpkg-query -W -f='${STATUS}' beast-splitter 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
    # The beast-splitter package appears to not be installed.
    if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
        # Add this choice to the EXTRAS_LIST array to be used by the whiptail menu.
        EXTRAS_LIST=("${EXTRAS_LIST[@]}" 'beast-splitter' '' OFF)
    else
        # Check the installation configuration file to see if beast-splitter is to be installed.
        if [[ -z "${BEASTSPLITTER_INSTALL}" ]] && [[ "${BEASTSPLITTER_INSTALL}" = "true" ]] ; then
            # Since the menu will be skipped add this choice directly to the EXTRAS_CHOICES file.
            echo "beast-splitter" >> ${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES
        fi
    fi
else
    # Offer the option to build then reinstall the beast-splitter package.
    if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
        # Add this choice to the EXTRAS_LIST array to be used by the whiptail menu.
        EXTRAS_LIST=("${EXTRAS_LIST[@]}" 'beast-splitter (reinstall)' '' OFF)
    else
        if [[ -z "${BEASTSPLITTER_INSTALL}" ]] && [[ "${BEASTSPLITTER_INSTALL}" = "true" ]] && [[ -z "${BEASTSPLITTER_UPGRADE}" ]] && [[ "${BEASTSPLITTER_UPGRADE}" = "true" ]] ; then
            # Since the menu will be skipped add this choice directly to the EXTRAS_CHOICES file.
            echo "beast-splitter (reinstall)" >> ${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES
        fi
    fi
fi

# Check if the Duck DNS update script exists.
if [[ ! -f "${RECEIVER_BUILD_DIRECTORY}/duckdns/duck.sh" ]] ; then
    # Duck DNS does not appear to be set up on this device.
    if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
        # Add this choice to the EXTRAS_LIST array to be used by the whiptail menu.
        EXTRAS_LIST=("${EXTRAS_LIST[@]}" 'Duck DNS Free Dynamic DNS Hosting' '' OFF)
    else
        # Check the installation configuration file to see if Duck DNS dynamic DNS support is to be added.
        if [[ -z "${DUCKDNS_INSTALL}" ]] && [[ "${DUCKDNS_INSTALL}" = "true" ]] ; then
            # Since the menu will be skipped add this choice directly to the EXTRAS_CHOICES file.
             echo "Duck DNS Free Dynamic DNS Hosting" >> ${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES
        fi
    fi
else
    # Offer the option to install/setup Duck DNS once more.
    if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
        # Add this choice to the EXTRAS_LIST array to be used by the whiptail menu.
        EXTRAS_LIST=("${EXTRAS_LIST[@]}" 'Duck DNS Free Dynamic DNS Hosting (reinstall)' '' OFF)
    else
        if [[ -z "${DUCKDNS_INSTALL}" ]] && [[ "${DUCKDNS_INSTALL}" = "true" ]] && [[ -z "${DUCKDNS_UPGRADE}" ]] && [[ "${DUCKDNS_UPGRADE}" = "true" ]] ; then
            # Since the menu will be skipped add this choice directly to the EXTRAS_CHOICES file.
            echo "Duck DNS Free Dynamic DNS Hosting (reinstall)" >> ${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES
        fi
    fi
fi


if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
    # Display a menu the user can use to pick extras to be installed.
    if [[ -n "${EXTRAS_LIST}" ]] ; then
        # Display a checklist containing feeders that are not installed if any.
        whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Feeder Installation Options" --checklist --nocancel --separate-output "The following extras are available for installation, please select any which you wish to install." 13 65 4 "${EXTRAS_LIST[@]}" 2>${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES
    else
        # Since all available extras appear to be installed inform the user of the fact.
        whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "All Extras Installed" --msgbox "It appears that all the optional extras available for installation by this script have been installed already." 8 65
    fi
fi

## Setup Confirmation

declare CONFIRMATION

# Check if anything is to be done before moving on.
if [[ "${DUMP1090_DO_INSTALL}" = "false" ]] && [[ "${DUMP1090_DO_UPGRADE}" = "false" ]] && [[ "${DUMP978_DO_INSTALL}" = "false" ]] && [[ "${DUMP978_DO_UPGRADE}" = "false" ]] && [[ "${RTLSDROGN_DO_INSTALL}" = "false" ]] && [[ "${RTLSDROGN_DO_UPGRADE}" = "false" ]] && [[ "${WEBPORTAL_DO_INSTALL}" = "false" ]] && [[ ! -s "${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES" ]] && [[ ! -s "${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES" ]] ; then
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
    if [[ "${DUMP1090_DO_UPGRADE}" = "true" ]] ; then
        case ${DUMP1090_FORK} in
            "mutability")
                CONFIRMATION="${CONFIRMATION}\n  * dump1090-mutability (reinstall)"
                ;;
            "fa")
                CONFIRMATION="${CONFIRMATION}\n  * dump1090-fa (upgrade)"
                ;;
            "hptoa")
                CONFIRMATION="${CONFIRMATION}\n  * dump1090-hptoa (reinstall)"
                ;;
        esac
    elif [[ "${DUMP1090_DO_INSTALL}" = "true" ]] ; then
        case ${DUMP1090_FORK} in
            "mutability")
                CONFIRMATION="${CONFIRMATION}\n  * dump1090-mutability"
                ;;
            "fa")
                CONFIRMATION="${CONFIRMATION}\n  * dump1090-fa"
                ;;
            "hptoa")
                CONFIRMATION="${CONFIRMATION}\n  * dump1090-hptoa"
                ;;
        esac
    fi

    # dump978
    if [[ "${DUMP978_DO_UPGRADE}" = "true" ]] ; then
        CONFIRMATION="${CONFIRMATION}\n  * dump978 (rebuild)"
    elif [[ "${DUMP978_DO_INSTALL}" = "true" ]] ; then
        CONFIRMATION="${CONFIRMATION}\n  * dump978"
    fi

    # RTL-SDR OGN
    if [[ "${RTLSDROGN_DO_UPGRADE}" = "true" ]] ; then
        CONFIRMATION="${CONFIRMATION}\n  * RTL-SDR OGN (upgrade)"
    elif [[ "${RTLSDROGN_DO_INSTALL}" = "true" ]] ; then
        CONFIRMATION="${CONFIRMATION}\n  * RTL-SDR OGN"
    fi

    # If PiAware is required add it to the list.
    if [[ "${DUMP1090_FORK}" = "fa" ]] ; then
        CONFIRMATION="${CONFIRMATION}\n  * FlightAware PiAware"
    fi

    if [[ -s "${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES" ]] ; then
        while read FEEDER_CHOICE
        do
            case ${FEEDER_CHOICE} in
                "ADS-B Exchange data export and MLAT Client")
                    CONFIRMATION="${CONFIRMATION}\n  * ADS-B Exchange data export and MLAT Client"
                    ;;
                "ADS-B Exchange data export and MLAT Client (upgrade)")
                    CONFIRMATION="${CONFIRMATION}\n  * ADS-B Exchange data export and MLAT Client (upgrade)"
                    ;;
                "ADSBHub Client Script")
                    CONFIRMATION="${CONFIRMATION}\n  * ADSBHub Client Script"
                    ;;
                "FlightAware PiAware")
                    CONFIRMATION="${CONFIRMATION}\n  * FlightAware PiAware"
                    ;;
                "FlightAware PiAware (upgrade)")
                    CONFIRMATION="${CONFIRMATION}\n  * FlightAware PiAware (upgrade)"
                    ;;
                "Flightradar24 Client")
                    CONFIRMATION="${CONFIRMATION}\n  * Flightradar24 Client"
                    ;;
                "Flightradar24 Client (upgrade)")
                    CONFIRMATION="${CONFIRMATION}\n  * Flightradar24 Client (upgrade)"
                    ;;
                "OpenSky Network Feeder")
                    CONFIRMATION="${CONFIRMATION}\n  * OpenSky Network Feeder"
                    ;;
                "Plane Finder Client")
                    CONFIRMATION="${CONFIRMATION}\n  * Plane Finder Client"
                    ;;
                "Plane Finder Client (upgrade)")
                    CONFIRMATION="${CONFIRMATION}\n  * Plane Finder Client (upgrade)"
                    ;;
            esac
        done < ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
    fi

    if [[ "${WEBPORTAL_DO_INSTALL}" = "true" ]] ; then
        CONFIRMATION="${CONFIRMATION}\n  * ADS-B Receiver Project Web Portal"
    fi

    if [[ -s "${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES" ]] ; then
        while read EXTRAS_CHOICE
        do
            case ${EXTRAS_CHOICE} in
                "AboveTustin")
                    CONFIRMATION="${CONFIRMATION}\n  * AboveTustin"
                    ;;
                "AboveTustin (reinstall)")
                    CONFIRMATION="${CONFIRMATION}\n  * AboveTustin (reinstall)"
                    ;;
                "beast-splitter")
                    CONFIRMATION="${CONFIRMATION}\n  * beast-splitter"
                    ;;
                "beast-splitter (reinstall)")
                    CONFIRMATION="${CONFIRMATION}\n  * beast-splitter (reinstall)"
                    ;;
                "Duck DNS Free Dynamic DNS Hosting")
                    CONFIRMATION="${CONFIRMATION}\n  * Duck DNS Free Dynamic DNS Hosting"
                    ;;
                "Duck DNS Free Dynamic DNS Hosting (reinstall)")
                    CONFIRMATION="${CONFIRMATION}\n  * Duck DNS Free Dynamic DNS Hosting (reinstall)"
                    ;;
            esac
        done < ${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES
    fi

    CONFIRMATION="${CONFIRMATION}\n\n"
fi

if [[ ! "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
    # Ask for confirmation before moving on.
    CONFIRMATION="${CONFIRMATION}Do you wish to continue setup?"
    if ! (whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Confirm You Wish To Continue" --yesno "${CONFIRMATION}" 21 78) then
        echo -e "\e[31m"
        echo "  Installation canceled by user."
        exit 1
    fi
fi

#################
## BEGIN SETUP

## Decoders

if [[ "${DUMP1090_DO_INSTALL}" = "true" ]] || [[ "${DUMP1090_DO_UPGRADE}" = "true" ]] ; then
    case ${DUMP1090_FORK} in
        "mutability")
            InstallDump1090Mutability
            ;;
        "fa")
             InstallDump1090Fa
             ;;
        "hptoa")
             InstallDump1090Hptoa
             ;;
    esac
fi

if [[ "${DUMP978_DO_INSTALL}" = "true" ]] || [[ "${DUMP978_DO_UPGRADE}" = "true" ]] ; then
    InstallDump978
fi

if [[ "${RTLSDROGN_DO_INSTALL}" = "true" ]] || [[ "${RTLSDROGN_DO_UPGRADE}" = "true" ]] ; then
    InstallRtlsdrOgn
fi

## Feeders

# Moved execution of functions outside of while loop.
# Inside the while loop the installation scripts are not stopping at reads.

RUN_ADSBEXCHANGE_SCRIPT="false"
RUN_PIAWARE_SCRIPT="false"
RUN_FLIGHTRADAR24_SCRIPT="false"
RUN_OPENSKYNETWORK_SCRIPT="false"
RUN_PLANEFINDER_SCRIPT="false"

if [[ -s "${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES" ]] ; then
    while read FEEDER_CHOICE
    do
        case ${FEEDER_CHOICE} in
            "ADS-B Exchange data export and MLAT Client"|"ADS-B Exchange data export and MLAT Client (upgrade)")
                RUN_ADSBEXCHANGE_SCRIPT="true"
                ;;
            "ADSBHub Client Script")
                RUN_ADSBHUB_SCRIPT="true"
                ;;
            "FlightAware PiAware"|"FlightAware PiAware (upgrade)")
                RUN_PIAWARE_SCRIPT="true"
                ;;
            "Flightradar24 Client"|"Flightradar24 Client (upgrade)")
                RUN_FLIGHTRADAR24_SCRIPT="true"
                ;;
            "OpenSky Network Feeder")
                RUN_OPENSKYNETWORK_SCRIPT="true"
                ;;
            "Plane Finder Client"|"Plane Finder Client (upgrade)")
                RUN_PLANEFINDER_SCRIPT="true"
                ;;
        esac
    done < ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
fi

if [[ "${RUN_ADSBEXCHANGE_SCRIPT}" = "true" ]] ; then
    InstallAdsbExchange
fi

if [[ "${RUN_ADSBHUB_SCRIPT}" = "true" ]] ; then
    InstallAdsbhub
fi

if [[ "${RUN_PIAWARE_SCRIPT}" = "true" ]] || [[ "${FORCE_PIAWARE_INSTALL}" = "true" ]] ; then
    InstallPiAware
fi

if [[ "${RUN_FLIGHTRADAR24_SCRIPT}" = "true" ]] ; then
    InstallFlightradar24
fi

if [[ "${RUN_OPENSKYNETWORK_SCRIPT}" = "true" ]] ; then
    InstallOpenSkyNetwork
fi

if [[ "${RUN_PLANEFINDER_SCRIPT}" = "true" ]] ; then
    InstallPlaneFinder
fi

## ADS-B Receiver Project Web Portal

if [[ "${WEBPORTAL_DO_INSTALL}" = "true" ]] ; then
    InstallWebPortal
fi

# Moved execution of functions outside of while loop.
# Inside the while loop the installation scripts are not stopping at reads.

RUN_ABOVETUSTIN_SCRIPT="false"
RUN_BEASTSPLITTER_SCRIPT="false"
RUN_DUCKDNS_SCRIPT="false"

if [[ -s "${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES" ]] ; then
    while read EXTRAS_CHOICE
    do
        case ${EXTRAS_CHOICE} in
            "AboveTustin"|"AboveTustin (reinstall)")
                RUN_ABOVETUSTIN_SCRIPT="true"
                ;;
            "beast-splitter"|"beast-splitter (reinstall)")
                RUN_BEASTSPLITTER_SCRIPT="true"
                ;;
            "Duck DNS Free Dynamic DNS Hosting"|"Duck DNS Free Dynamic DNS Hosting (reinstall)")
                RUN_DUCKDNS_SCRIPT="true"
                ;;
        esac
    done < ${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES
fi

if [[ "${RUN_ABOVETUSTIN_SCRIPT}" = "true" ]] ; then
    InstallAboveTustin
fi

if [[ "${RUN_BEASTSPLITTER_SCRIPT}" = "true" ]] ; then
    InstallBeastSplitter
fi

if [[ "${RUN_DUCKDNS_SCRIPT}" = "true" ]] ; then
    InstallDuckDns
fi

exit 0

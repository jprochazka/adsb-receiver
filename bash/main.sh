#!/bin/bash

## INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh


## ADS-B DECODERS

# FlightAware dump1090
install_adsb_decoder="false"
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") == 1 ]] ; then
    chosen_adsb_decoder="dump1090-fa"
    if [[ $(sudo dpkg -s dump1090-fa 2>/dev/null | grep -c "Version: ${dump1090_fa_current_version}") == 0 ]] ; then
        whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                 --title "FlightAware Dump1090 Upgrade Available" \
                 --defaultno \
                 --yesno "An updated version of FlightAware dump1090 is available.\n\nWould you like to install the new version?" \
                 16 65
        if [[ $? == 0 ]]; then
            install_adsb_decoder="true"
        fi
    else
        whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                 --title "Reinstall FlightAware dump1090" \
                 --defaultno --yesno "The option to rebuild and reinstall FlightAware dump1090 is available.\n\nWould you like to rebuild and reinstall FlightAware dump1090?" \
                 9 65
        if [[ $? == 0 ]]; then
            install_adsb_decoder="true"
        fi
    fi
else
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
             --title "FlightAware dump978" \
             --defaultno \
             --yesno "FlightAware dump1090 is capable of demodulating ADS-B, Mode S, Mode 3A/3C signals received by an SDR device.\n\nGitHub Repository: https://github.com/flightaware/dump1090\n\nWould you like to install FlightAware dump1090?" \
             10 65
    if [[ $? == 0 ]]; then
        install_adsb_decoder="true"
        chosen_adsb_decoder="dump1090-fa"
    fi
fi

function install_dump1090_fa() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/decoders/dump1090-fa.sh
    ${RECEIVER_BASH_DIRECTORY}/decoders/dump1090-fa.sh
    if [[ $? != 0 ]] ; then
        exit 1
    fi
}


## UAT DECODERS

# Flightaware dump978
install_uat_decoder="false"
if [[ $(dpkg-query -W -f='${STATUS}' dump978-fa 2>/dev/null | grep -c "ok installed") == 1 ]]; then
    chosen_uat_decoder="dump978-fa"
    if [[ $(sudo dpkg -s dump978-fa 2>/dev/null | grep -c "Version: ${dump978_fa_current_version}") == 0 ]]; then
        whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                 --title "FlightAware dump978 Upgrade Available" \
                 --defaultno --yesno "An updated version of FlightAware dump978 is available.\n\nWould you like to install the new version?" \
                 16 65
        if [[ $? == 0 ]]; then
            install_uat_decoder="true"
        fi
    else
        whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                 --title "Reinstall FlightAware dump978" \
                 --defaultno --yesno "The option to rebuild and reinstall FlightAware dump978 is available.\n\nWould you like to rebuild and reinstall FlightAware dump978?" \
                 9 65
        if [[ $? == 0 ]]; then
            install_uat_decoder="true"
        fi
    fi
else
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
             --title "FlightAware dump978" \
             --defaultno \
             --yesno "FlightAware dump978 is capable of demodulating UAT received by an SDR device.\n\nGitHub Repository: https://github.com/flightaware/dump978\n\nWould you like to install FlightAware dump978?" \
             10 65
    if [[ $? == 0 ]]; then
        install_uat_decoder="true"
        chosen_uat_decoder="dump978-fa"
    fi
fi

function install_dump978_fa() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/decoders/dump978-fa.sh
    ${RECEIVER_BASH_DIRECTORY}/decoders/dump978-fa.sh
    if [[ $? != 0 ]] ; then
        exit 1
    fi
}

## ACARS DECODERS

# ACARSDEC
install_acars_decoder="false"
if [[ -f /etc/systemd/system/acarsdec.service ]]; then
    chosen_acars_decoder="acarsdec"
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
             --title "Reinstall ACARSDEC Decoder" \
             --defaultno \
             --yesno "The option to rebuild and reinstall ACARSDEC is available.\n\nWould you like to rebuild and reinstall ACARSDEC?" \
             9 65
    if [[ $? == 0 ]]; then
        install_acars_decoder="true"
    fi
else
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
             --title "ACARSDEC Decoder" \
             --defaultno \
             --yesno "ACARSDEC is a multi-channels acars decoder with built-in rtl_sdr, airspy front end or sdrplay device.\n\nGitHub Repository: https://github.com/TLeconte/acarsdec\n\nWould you like to install ACARSDEC?" \
             10 65
    if [[ $? == 0 ]]; then
        install_acars_decoder="true"
        chosen_acars_decoder="acarsdec"
    fi
fi

function install_acarsdec() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/decoders/acarsdec.sh
    ${RECEIVER_BASH_DIRECTORY}/decoders/acarsdec.sh
    if [[ $? != 0 ]] ; then
        exit 1
    fi
}


## VDL DECODERS

# VDLM2DEC
install_vdl_decoder="false"
if [[ -f /etc/systemd/system/vdlm2dec.service ]]; then
    chosen_vdl_decoder="vdlm2dec"
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
             --title "Reinstall VDLM2DEC Decoder" \
             --defaultno \
             --yesno "The option to rebuild and reinstall VDLM2DEC is available.\n\nWould you like to rebuild and reinstall VDLM2DEC?" \
             9 65
    if [[ $? == 0 ]]; then
        install_vdl_decoder="true"
    fi
else
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
             --title "VDLM2DEC Decoder" \
             --defaultno \
             --yesno "VDLM2DEC is a vdl mode 2 decoder with built-in rtl_sdr or airspy front end.\n\nGitHub Repository: https://github.com/TLeconte/vdlm2dec\n\nWould you like to install VDLM2DEC?" \
             10 65
    if [[ $? == 0 ]]; then
        install_vdl_decoder="true"
        chosen_vdl_decoder="vdlm2dec"
    fi
fi

function install_vdlm2dec() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/decoders/vdlm2dec.sh
    ${RECEIVER_BASH_DIRECTORY}/decoders/vdlm2dec.sh
    if [[ $? != 0 ]] ; then
        exit 1
    fi
}

# DUMPVDL2
install_vdl_decoder="false"
if [[ -f /etc/systemd/system/dumpvdl2.service ]]; then
    chosen_vdl_decoder="dumpvdl2"
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
             --title "Reinstall dumpvdl2 Decoder" \
             --defaultno \
             --yesno "The option to rebuild and reinstall dumpvdl2 is available.\n\nWould you like to rebuild and reinstall dumpvdl2?" \
             9 65
    if [[ $? == 0 ]]; then
        install_vdl_decoder="true"
    fi
else
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
             --title "Dumpvdl2 Decoder" \
             --defaultno \
             --yesno "Dumpvdl2 is a VDL Mode 2 message decoder and protocol analyzer.\n\nGitHub Repository: https://github.com/szpajder/dumpvdl2\n\nWould you like to install dumpvdl2?" \
             10 65
    if [[ $? == 0 ]]; then
        install_vdl_decoder="true"
        chosen_vdl_decoder="dumpvdl2"
    fi
fi

function install_dumpvdl2() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/decoders/dumpvdl2.sh
    ${RECEIVER_BASH_DIRECTORY}/decoders/dumpvdl2.sh
    if [[ $? != 0 ]] ; then
        exit 1
    fi
}


## AGGREGATE SITE CLIENTS

declare array feeder_list
touch ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES

# ADS-B Exchange
if [[ -f /lib/systemd/system/adsbexchange-mlat.service && -f /lib/systemd/system/adsbexchange-feed.service ]]; then
    echo "ADS-B Exchange Feed Client (reinstall)" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
    feeder_list=("${feeder_list[@]}" 'ADS-B Exchange Feed Client (reinstall/update)' '' OFF)
else
    echo "ADS-B Exchange Feed Client" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
    feeder_list=("${feeder_list[@]}" 'ADS-B Exchange Feed Client' '' OFF)
fi
function install_adsbexchange_client() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/feeders/adsbexchange.sh
    ${RECEIVER_BASH_DIRECTORY}/feeders/adsbexchange.sh
    if [[ $? != 0 ]] ; then
        exit 1
    fi
}

# Airplanes.live
if [[ -f /lib/systemd/system/airplanes-feed.service && -f /lib/systemd/system/airplanes-mlat.service ]]; then
    echo "Airplanes.live Feeder (reinstall)" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
    feeder_list=("${feeder_list[@]}" 'Airplanes.live Feeder (reinstall)' '' OFF)
else
    echo "Airplanes.live Feeder" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
    feeder_list=("${feeder_list[@]}" 'Airplanes.live Feeder' '' OFF)
fi

function install_airplaneslive_client() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/feeders/airplaneslive.sh
    ${RECEIVER_BASH_DIRECTORY}/feeders/airplaneslive.sh
    if [[ $? != 0 ]] ; then
        exit 1
    fi
}

# FlightAware PiAware
if [[ $(dpkg-query -W -f='${STATUS}' piaware 2>/dev/null | grep -c "ok installed") == 0 ]]; then
    feeder_list=("${feeder_list[@]}" 'FlightAware PiAware' '' OFF)
else
    if [[ $(sudo dpkg -s piaware 2>/dev/null | grep -c "Version: ${piaware_current_version}") == 0 ]]; then
        feeder_list=("${feeder_list[@]}" 'FlightAware PiAware (upgrade)' '' OFF)
    else
        feeder_list=("${feeder_list[@]}" 'FlightAware PiAware (reinstall)' '' OFF)
    fi
fi

function install_flightaware_client() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/feeders/piaware.sh
    ${RECEIVER_BASH_DIRECTORY}/feeders/piaware.sh
    if [[ $? != 0 ]] ; then
        exit 1
    fi
}

# Flightradar24
if [[ $(dpkg-query -W -f='${STATUS}' fr24feed 2>/dev/null | grep -c "ok installed") == 0 ]]; then
    feeder_list=("${feeder_list[@]}" 'Flightradar24 Client' '' OFF)
else
    if [[ $(sudo dpkg -s fr24feed 2>/dev/null | grep -c "Version: ${fr24feed_current_version}") == 0 ]]; then
        feeder_list=("${feeder_list[@]}" 'Flightradar24 Client (upgrade)' '' OFF)
    else
        feeder_list=("${feeder_list[@]}" 'Flightradar24 Client (reinstall)' '' OFF)
    fi
fi

function install_flightradar24_client() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/feeders/flightradar24.sh
    ${RECEIVER_BASH_DIRECTORY}/feeders/flightradar24.sh
    if [[ $? != 0 ]] ; then
        exit 1
    fi
}

# Fly Italy ADS-B
if [[ -f /lib/systemd/system/flyitalyadsb-mlat.service && -f /lib/systemd/system/flyitalyadsb-feed.service ]]; then
    echo "Fly Italy ADS-B Feeder (upgrade)" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
    feeder_list=("${feeder_list[@]}" 'Fly Italy ADS-B Feeder (reinstall)' '' OFF)
else
    echo "Fly Italy ADS-B Feeder" >> ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
    feeder_list=("${feeder_list[@]}" 'Fly Italy ADS-B Feeder' '' OFF)
fi

function install_flyitalyadsb_client() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/feeders/flyitalyadsb.sh
    ${RECEIVER_BASH_DIRECTORY}/feeders/flyitalyadsb.sh
    if [[ $? != 0 ]] ; then
        exit 1
    fi
}

# OpenSky Network
if [[ $(dpkg-query -W -f='${STATUS}' opensky-feeder 2>/dev/null | grep -c "ok installed") == 0 ]]; then
    feeder_list=("${feeder_list[@]}" 'OpenSky Network Feeder' '' OFF)
else
    if [[ $(sudo dpkg -s opensky-feeder 2>/dev/null | grep -c "Version: ${opensky_feeder_current_version}") == 0 ]]; then
        feeder_list=("${feeder_list[@]}" 'OpenSky Network Feeder (reinstall)' '' OFF)
    fi
fi

function install_openskynetwork_client() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/feeders/openskynetwork.sh
    ${RECEIVER_BASH_DIRECTORY}/feeders/openskynetwork.sh
    if [[ $? != 0 ]] ; then
        exit 1
    fi
}

# Planefinder
if [[ $(dpkg-query -W -f='${STATUS}' pfclient 2>/dev/null | grep -c "ok installed") == 0 ]]; then
    feeder_list=("${feeder_list[@]}" 'Plane Finder Client' '' OFF)
else
    pfclient_installed_version=$(sudo dpkg -s pfclient | grep Version | awk '{print $2}')
    case "${CPU_ARCHITECTURE}" in
        "armv7l"|"armv6l")
            if [[ "$pfclient_installed_version" != "${pfclient_current_version_armhf}" ]]; then
                feeder_list=("${feeder_list[@]}" 'Plane Finder Client (upgrade)' '' OFF)
            else
                feeder_list=("${feeder_list[@]}" 'Plane Finder Client (reinstall)' '' OFF)
            fi
            ;;
        "aarch64")
            if [[ "$pfclient_installed_version" != "${pfclient_current_version_arm64}" ]]; then
                feeder_list=("${feeder_list[@]}" 'Plane Finder Client (upgrade)' '' OFF)
            else
                feeder_list=("${feeder_list[@]}" 'Plane Finder Client (reinstall)' '' OFF)
            fi
            ;;
        "x86_64")
            if [[ "$pfclient_installed_version" != "${pfclient_current_version_amd64}" ]]; then
                feeder_list=("${feeder_list[@]}" 'Plane Finder Client (upgrade)' '' OFF)
            else
                feeder_list=("${feeder_list[@]}" 'Plane Finder Client (reinstall)' '' OFF)
            fi
            ;;
        "i386")
            if [[ "$pfclient_installed_version" != "${pfclient_current_version_i386}" ]]; then
                feeder_list=("${feeder_list[@]}" 'Plane Finder Client (upgrade)' '' OFF)
            else
                feeder_list=("${feeder_list[@]}" 'Plane Finder Client (reinstall)' '' OFF)
            fi
            ;;
        *)
            feeder_list=("${feeder_list[@]}" 'Plane Finder Client (reinstall)' '' OFF)
    esac
fi

function install_planefinder_client() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/feeders/planefinder.sh
    ${RECEIVER_BASH_DIRECTORY}/feeders/planefinder.sh
    if [[ $? != 0 ]] ; then
        exit 1
    fi
}

whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "Client Installation Options" \
         --checklist \
         --nocancel \
         --separate-output "The following clients are available for installation.\nChoose the clients you wish to install." \
         15 65 7 "${feeder_list[@]}" 2>${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES


## PORTALS

# ADS-B Portal
install_portal="false"
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "Install The ADS-B Portal" \
         --defaultno \
         --yesno "The ADS-B Portal is a web interface for your receiver. More information can be found in the ADS-B Receiver Project GitHub repository.\n\nhttps://github.com/jprochazka/adsb-receiver\n\nWould you like to install the ADS-B Portal?" \
         12 78
if [[ $? == 0 ]]; then
    install_portal="true"
fi

function install_adsb_portal() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/portal/install.sh
    ${RECEIVER_BASH_DIRECTORY}/portal/install.sh
    if [[ $? != 0 ]] ; then
        exit 1
    fi
}


## Extras

declare array extras_list
touch ${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES

# Beast-splitter
if [[ $(dpkg-query -W -f='${STATUS}' beast-splitter 2>/dev/null | grep -c "ok installed") == 0 ]]; then
    extras_list=("${extras_list[@]}" 'beast-splitter' '' OFF)
else
    extras_list=("${extras_list[@]}" 'beast-splitter (reinstall)' '' OFF)
fi

function install_beastsplitter() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/extras/beeastsplitter.sh
    ${RECEIVER_BASH_DIRECTORY}/extras/beastsplitter.sh
    if [[ $? != 0 ]] ; then
        exit 1
    fi
}

# Duck DNS
if [[ ! -f "${RECEIVER_BUILD_DIRECTORY}/duckdns/duck.sh" ]]; then
    # Duck DNS does not appear to be set up on this device.
    extras_list=("${extras_list[@]}" 'Duck DNS Free Dynamic DNS Hosting' '' OFF)
else
    # Offer the option to install/setup Duck DNS once more.
    extras_list=("${extras_list[@]}" 'Duck DNS Free Dynamic DNS Hosting (reinstall)' '' OFF)
fi

function install_duckdns() {
    chmod +x ${RECEIVER_BASH_DIRECTORY}/extras/duckdns.sh
    ${RECEIVER_BASH_DIRECTORY}/extras/duckdns.sh
    if [[ $? -ne 0 ]] ; then
        exit 1
    fi
}

whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "Extras Installation Options" \
         --checklist \
         --nocancel \
         --separate-output "The following extras are available for installation, please select any which you wish to install." \
         11 65 4 "${extras_list[@]}" 2>${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES


## Setup Confirmation

declare confirmation_message

if [[ "${install_adsb_decoder}" == "false" && "${install_uat_decoder}" == "false" && "${install_acars_decoder}" == "false" && "${install_vdl_decoder}" == "false" && "${install_portal}" == "false" && ! -s "${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES" && ! -s "${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES" ]]; then
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
             --title "Nothing to be done" \
             --msgbox "Nothing has been selected to be installed so the script will exit now." \
             8 65
    echo ""
    log_alert_heading "Nothing was selected to do or be installed"
    echo ""
    exit 1
else
    confirmation_message="The following software will be installed:\n"

    # ADS-B decoders
    if [[ "${install_adsb_decoder}" == "true" ]]; then
        case ${chosen_adsb_decoder} in
            "dump1090-fa")
                confirmation_message="${confirmation_message}\n  * FlightAware dump1090"
                ;;
        esac
    fi

    # UAT decoders
    if [[ "${install_uat_decoder}" = "true" ]]; then
        case ${chosen_uat_decoder} in
            "dump978-fa")
                confirmation_message="${confirmation_message}\n  * FlightAware dump978"
                ;;
        esac
    fi

    # ACARS decoders
    if [[ "${install_acars_decoder}" = "true" ]]; then
        case ${chosen_acars_decoder} in
            "acarsdec")
                confirmation_message="${confirmation_message}\n  * ACARSDEC"
                ;;
        esac
    fi

    # VDL decoders
    if [[ "${install_vdl_decoder}" = "true" ]]; then
        case ${chosen_vdl_decoder} in
            "dumpvdl2")
                confirmation_message="${confirmation_message}\n  * dumpvdl2"
                ;;
        esac
    fi

    # Aggragate site clients
    if [[ -s "${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES" ]]; then
        while read feeder_choice
        do
            confirmation_message="${confirmation_message}\n  * ${feeder_choice}"
        done < ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
    fi

    # Portals
    if [[ "${install_portal}" == "true" ]]; then
        confirmation_message="${confirmation_message}\n  * ADS-B Receiver Project Web Portal"
    fi

    # Extras
    if [[ -s "${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES" ]]; then
        while read extra_choice
        do
            confirmation_message="${confirmation_message}\n  * ${extra_choice}"
        done < ${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES
    fi

    confirmation_message="${confirmation_message}\n\n"
fi

confirmation_message="${confirmation_message}Do you wish to continue setup?"
if ! (whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Confirm You Wish To Continue" --yesno "${confirmation_message}" 21 78); then
    echo ""
    log_alert_heading "Installation cancelled by user"
    echo ""
    exit 1
fi


## BEGIN SETUP

# ADS-B Decoders
if [[ "${install_adsb_decoder}" == "true" ]]; then
    case ${chosen_adsb_decoder} in
        "dump1090-fa")
             install_dump1090_fa
             ;;
    esac
fi

# UAT Decoders
if [[ "${install_uat_decoder}" == "true" ]]; then
    case ${chosen_uat_decoder} in
        "dump978-fa")
             install_dump978_fa
             ;;
    esac
fi

# ACARS Decoders
if [[ "${install_acars_decoder}" == "true" ]]; then
    case ${chosen_acars_decoder} in
        "acarsdec")
             install_acarsdec
             ;;
    esac
fi

# VDL Decoders
if [[ "${install_vdl_decoder}" == "true" ]]; then
    case ${chosen_vdl_decoder} in
        "dumpvdl2")
             install_dumpvdl2
             ;;
    esac
fi

# Aggragate site clients
run_adsbexchange_script="false"
run_airplaneslive_script="false"
run_flightaware_script="false"
run_flightradar24_script="false"
run_flyitalyadsb_script="false"
run_openskynetwork_script="false"
run_planefinder_script="false"

if [[ -s "${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES" ]]; then
    while read feeder_choice
    do
        case ${feeder_choice} in
            "ADS-B Exchange Feed Client"|"ADS-B Exchange Feed Client (reinstall/update)")
                run_adsbexchange_script="true"
                ;;
            "Airplanes.live Feeder"|"Airplanes.live Feeder (reinstall)")
                run_airplaneslive_script="true"
                ;;
            "FlightAware PiAware"|"FlightAware PiAware (upgrade)"|"FlightAware PiAware (reinstall)")
                run_flightaware_script="true"
                ;;
            "Flightradar24 Client"|"Flightradar24 Client (upgrade)"|"Flightradar24 Client (reinstall)")
                run_flightradar24_script="true"
                ;;
            "Fly Italy ADS-B Feeder"|"Fly Italy ADS-B Feeder (reinstall)")
                run_flyitalyadsb_script="true"
                ;;
            "OpenSky Network Feeder"|"OpenSky Network Feeder (reinstall)")
                run_openskynetwork_script="true"
                ;;
            "Plane Finder Client"|"Plane Finder Client (upgrade)"|"Plane Finder Client (reinstall)")
                run_planefinder_script="true"
                ;;
        esac
    done < ${RECEIVER_ROOT_DIRECTORY}/FEEDER_CHOICES
fi

if [[ "${run_adsbexchange_script}" == "true" ]]; then
    install_adsbexchange_client
fi

if [[ "${run_airplaneslive_script}" == "true" ]]; then
    install_airplaneslive_client
fi

if [[ "${run_flightaware_script}" == "true" ]]; then
    install_flightaware_client
fi

if [[ "${run_flightradar24_script}" == "true" ]]; then
    install_flightradar24_client
fi

if [[ "${run_flyitalyadsb_script}" == "true" ]]; then
    install_flyitalyadsb_client
fi

if [[ "${run_openskynetwork_script}" == "true" ]]; then
    install_openskynetwork_client
fi

if [[ "${run_planefinder_script}" == "true" ]]; then
    install_planefinder_client
fi

# Portals
if [[ "${install_portal}" == "true" ]]; then
    install_adsb_portal
fi

# Extras

run_beastsplitter_script="false"
run_duckdns_script="false"

if [[ -s "${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES" ]]; then
    while read extras_choice
    do
        case ${extras_choice} in
            "beast-splitter"|"beast-splitter (reinstall)")
                run_beastsplitter_script="true"
                ;;
            "Duck DNS Free Dynamic DNS Hosting"|"Duck DNS Free Dynamic DNS Hosting (reinstall)")
                run_duckdns_script="true"
                ;;
        esac
    done < ${RECEIVER_ROOT_DIRECTORY}/EXTRAS_CHOICES
fi

if [[ "${run_beastsplitter_script}" == "true" ]]; then
    install_beastsplitter
fi

if [[ "${run_duckdns_script}" == "true" ]]; then
    install_duckdns
fi

exit 0

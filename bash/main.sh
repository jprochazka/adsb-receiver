#!/bin/bash

## INCLUDE EXTERNAL SCRIPTS

source "${RECEIVER_BASH_DIRECTORY}/variables.sh"
source "${RECEIVER_BASH_DIRECTORY}/functions.sh"


## HELPER FUNCTIONS

function run_installer() {
    if ! bash "${RECEIVER_BASH_DIRECTORY}/$1"; then
        exit 1
    fi
}

function is_package_installed() {
    [[ $(dpkg-query -W -f='${STATUS}' "$1" 2>/dev/null | grep -c "ok installed") -eq 1 ]]
}

function ask_reinstall() {
    local title="$1" msg="$2" height="$3" width="$4" var_name="$5"
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
             --title "${title}" \
             --defaultno \
             --yesno "${msg}" \
             "${height}" "${width}"
    if [[ $? -eq 0 ]]; then
        printf -v "${var_name}" "true"
    fi
}


## ADS-B DECODERS

adsb_decoder_installed="false"
install_adsb_decoder="false"

if is_package_installed "dump1090-fa"; then
    adsb_decoder_installed="true"
    chosen_adsb_decoder="dump1090-fa"
    if [[ $(sudo dpkg -s dump1090-fa 2>/dev/null | grep -c "Version: ${dump1090_fa_current_version}") -eq 0 ]]; then
        ask_reinstall "FlightAware Dump1090 Upgrade Available" \
                      "An updated version of FlightAware dump1090 is available.\n\nWould you like to install the new version?" \
                      16 65 install_adsb_decoder
    else
        ask_reinstall "Reinstall FlightAware dump1090" \
                      "The option to rebuild and reinstall FlightAware dump1090 is available.\n\nWould you like to rebuild and reinstall FlightAware dump1090?" \
                      9 65 install_adsb_decoder
    fi
fi

if is_package_installed "readsb"; then
    adsb_decoder_installed="true"
    chosen_adsb_decoder="readsb"
    ask_reinstall "Reinstall Readsb Decoder" \
                  "The option to rebuild and reinstall Readsb is available.\n\nWould you like to rebuild and reinstall Readsb?" \
                  9 65 install_adsb_decoder
fi

if [[ "${adsb_decoder_installed}" == "false" ]]; then
    install_adsb_decoder="true"
    chosen_adsb_decoder=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                   --title "ADS-B Decoder Selection" \
                                   --menu "The following ADS-B decoders are available for installation." \
                                   16 100 9 \
                                   "None" "Do not install an ADS-B decoder." \
                                   "dump1090-fa" "FlightAware's version of the dump1090 decoder." \
                                   "readsb" "Wiedehopf's detached fork of readsb." \
                                   3>&2 2>&1 1>&3)
    exit_status=$?
    if [[ $exit_status -ne 0 || "${chosen_adsb_decoder}" == "None" ]]; then
        install_adsb_decoder="false"
    fi
fi


## UAT DECODERS

uat_decoder_installed="false"
install_uat_decoder="false"

if is_package_installed "dump978-fa"; then
    uat_decoder_installed="true"
    chosen_uat_decoder="dump978-fa"
    if [[ $(sudo dpkg -s dump978-fa 2>/dev/null | grep -c "Version: ${dump978_fa_current_version}") -eq 0 ]]; then
        ask_reinstall "FlightAware dump978 Upgrade Available" \
                      "An updated version of FlightAware dump978 is available.\n\nWould you like to install the new version?" \
                      16 65 install_uat_decoder
    else
        ask_reinstall "Reinstall FlightAware dump978" \
                      "The option to rebuild and reinstall FlightAware dump978 is available.\n\nWould you like to rebuild and reinstall FlightAware dump978?" \
                      9 65 install_uat_decoder
    fi
fi

if [[ "${uat_decoder_installed}" == "false" ]]; then
    install_uat_decoder="true"
    chosen_uat_decoder=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                  --title "UAT Decoder Selection" \
                                  --menu "The following UAT decoders are available for installation." \
                                  16 100 9 \
                                  "None" "Do not install a UAT decoder." \
                                  "dump978-fa" "FlightAware's version of the dump978 decoder." \
                                  3>&2 2>&1 1>&3)
    exit_status=$?
    if [[ $exit_status -ne 0 || "${chosen_uat_decoder}" == "None" ]]; then
        install_uat_decoder="false"
    fi
fi


## ACARS DECODERS

acars_decoder_installed="false"
install_acars_decoder="false"

if [[ -f /etc/systemd/system/acarsdec.service ]]; then
    acars_decoder_installed="true"
    chosen_acars_decoder="acarsdec"
    ask_reinstall "Reinstall ACARSDEC Decoder" \
                  "The option to rebuild and reinstall ACARSDEC is available.\n\nWould you like to rebuild and reinstall ACARSDEC?" \
                  9 65 install_acars_decoder
fi

if [[ "${acars_decoder_installed}" == "false" ]]; then
    install_acars_decoder="true"
    chosen_acars_decoder=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                    --title "ACARS Decoder Selection" \
                                    --menu "The following ACARS decoders are available for installation." \
                                    16 100 9 \
                                    "None" "Do not install an ACARS decoder." \
                                    "acarsdec" "Acarsdec is a multi-channels acars decoder." \
                                    3>&2 2>&1 1>&3)
    exit_status=$?
    if [[ $exit_status -ne 0 || "${chosen_acars_decoder}" == "None" ]]; then
        install_acars_decoder="false"
    fi
fi


## VDL MODE 2 DECODERS

vdlm2_decoder_installed="false"
install_vdlm2_decoder="false"

if [[ -f /etc/systemd/system/dumpvdl2.service ]]; then
    vdlm2_decoder_installed="true"
    chosen_vdlm2_decoder="dumpvdl2"
    ask_reinstall "Reinstall dumpvdl2 Decoder" \
                  "The option to rebuild and reinstall dumpvdl2 is available.\n\nWould you like to rebuild and reinstall dumpvdl2?" \
                  9 65 install_vdlm2_decoder
fi

if [[ -f /etc/systemd/system/vdlm2dec.service ]]; then
    vdlm2_decoder_installed="true"
    chosen_vdlm2_decoder="vdlm2dec"
    ask_reinstall "Reinstall VDLM2DEC Decoder" \
                  "The option to rebuild and reinstall VDLM2DEC is available.\n\nWould you like to rebuild and reinstall VDLM2DEC?" \
                  9 65 install_vdlm2_decoder
fi

if [[ "${vdlm2_decoder_installed}" == "false" ]]; then
    install_vdlm2_decoder="true"
    chosen_vdlm2_decoder=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
             --title "VLD Mode 2 Decoder Selection" \
             --menu "The following VLD Mode 2 decoders are available for installation." \
             16 100 9 \
             "None" "Do not install a VLD decoder." \
             "vdlm2dec" "vdlm2dec is a VDL Mode 2 decoder." \
             "dumpvdl2" "dumpvdl2 is a VDL Mode 2 message decoder." \
             3>&2 2>&1 1>&3)
    exit_status=$?
    if [[ $exit_status -ne 0 || "${chosen_vdlm2_decoder}" == "None" ]]; then
        install_vdlm2_decoder="false"
    fi
fi


## AGGREGATE SITE CLIENTS

declare -a feeder_list
touch "${RECEIVER_ROOT_DIRECTORY}/feeder_choices.txt"

# ADS-B Exchange
if [[ -f /lib/systemd/system/adsbexchange-mlat.service && -f /lib/systemd/system/adsbexchange-feed.service ]]; then
    echo "ADS-B Exchange Feed Client (reinstall)" >> "${RECEIVER_ROOT_DIRECTORY}/feeder_choices.txt"
    feeder_list=("${feeder_list[@]}" 'ADS-B Exchange Feed Client (reinstall/update)' '' OFF)
else
    echo "ADS-B Exchange Feed Client" >> "${RECEIVER_ROOT_DIRECTORY}/feeder_choices.txt"
    feeder_list=("${feeder_list[@]}" 'ADS-B Exchange Feed Client' '' OFF)
fi


# AirNav Radar rbfeeder
if ! is_package_installed "rbfeeder"; then
    feeder_list=("${feeder_list[@]}" 'AirNav Radar RBFeeder' '' OFF)
else
    echo "AirNav Radar RBFeeder (reinstall)" >> "${RECEIVER_ROOT_DIRECTORY}/feeder_choices.txt"
    feeder_list=("${feeder_list[@]}" 'AirNav Radar RBFeeder (reinstall/update)' '' OFF)
fi


# Airplanes.live
if [[ -f /lib/systemd/system/airplanes-feed.service && -f /lib/systemd/system/airplanes-mlat.service ]]; then
    echo "Airplanes.live Feeder (reinstall)" >> "${RECEIVER_ROOT_DIRECTORY}/feeder_choices.txt"
    feeder_list=("${feeder_list[@]}" 'Airplanes.live Feeder (reinstall)' '' OFF)
else
    echo "Airplanes.live Feeder" >> "${RECEIVER_ROOT_DIRECTORY}/feeder_choices.txt"
    feeder_list=("${feeder_list[@]}" 'Airplanes.live Feeder' '' OFF)
fi


# FlightAware PiAware
if ! is_package_installed "piaware"; then
    feeder_list=("${feeder_list[@]}" 'FlightAware PiAware' '' OFF)
else
    if [[ $(sudo dpkg -s piaware 2>/dev/null | grep -c "Version: ${piaware_current_version}") -eq 0 ]]; then
        feeder_list=("${feeder_list[@]}" 'FlightAware PiAware (upgrade)' '' OFF)
    else
        feeder_list=("${feeder_list[@]}" 'FlightAware PiAware (reinstall)' '' OFF)
    fi
fi


# Flightradar24
if ! is_package_installed "fr24feed"; then
    feeder_list=("${feeder_list[@]}" 'Flightradar24 Client' '' OFF)
else
    if [[ $(sudo dpkg -s fr24feed 2>/dev/null | grep -c "Version: ${fr24feed_current_version}") -eq 0 ]]; then
        feeder_list=("${feeder_list[@]}" 'Flightradar24 Client (upgrade)' '' OFF)
    else
        feeder_list=("${feeder_list[@]}" 'Flightradar24 Client (reinstall)' '' OFF)
    fi
fi


# Fly Italy ADS-B
if [[ -f /lib/systemd/system/flyitalyadsb-mlat.service && -f /lib/systemd/system/flyitalyadsb-feed.service ]]; then
    echo "Fly Italy ADS-B Feeder (upgrade)" >> "${RECEIVER_ROOT_DIRECTORY}/feeder_choices.txt"
    feeder_list=("${feeder_list[@]}" 'Fly Italy ADS-B Feeder (reinstall)' '' OFF)
else
    echo "Fly Italy ADS-B Feeder" >> "${RECEIVER_ROOT_DIRECTORY}/feeder_choices.txt"
    feeder_list=("${feeder_list[@]}" 'Fly Italy ADS-B Feeder' '' OFF)
fi


# OpenSky Network
if ! is_package_installed "opensky-feeder"; then
    feeder_list=("${feeder_list[@]}" 'OpenSky Network Feeder' '' OFF)
else
    if [[ $(sudo dpkg -s opensky-feeder 2>/dev/null | grep -c "Version: ${opensky_feeder_current_version}") -eq 0 ]]; then
        feeder_list=("${feeder_list[@]}" 'OpenSky Network Feeder (reinstall)' '' OFF)
    fi
fi


# Planefinder
if ! is_package_installed "pfclient"; then
    feeder_list=("${feeder_list[@]}" 'Plane Finder Client' '' OFF)
else
    pfclient_installed_version=$(sudo dpkg -s pfclient | grep Version | awk '{print $2}')
    case "${RECEIVER_CPU_ARCHITECTURE}" in
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
        *)
            feeder_list=("${feeder_list[@]}" 'Plane Finder Client (reinstall)' '' OFF)
    esac
fi


whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "Client Installation Options" \
         --checklist \
         --nocancel \
         --separate-output "The following clients are available for installation.\nChoose the clients you wish to install." \
         15 65 7 "${feeder_list[@]}" 2>"${RECEIVER_ROOT_DIRECTORY}/feeder_choices.txt"


## PORTALS

# ADS-B Portal
install_portal="false"
ask_reinstall "Install The ADS-B Portal" \
              "The ADS-B Portal is a web interface for your receiver. More information can be found in the ADS-B Receiver Project GitHub repository.\n\nhttps://github.com/jprochazka/adsb-receiver\n\nWould you like to install the ADS-B Portal?" \
              12 78 install_portal


## Extras

declare -a extras_list
touch "${RECEIVER_ROOT_DIRECTORY}/extras_choices.txt"

# Beast-splitter
if ! is_package_installed "beast-splitter"; then
    extras_list=("${extras_list[@]}" 'beast-splitter' '' OFF)
else
    extras_list=("${extras_list[@]}" 'beast-splitter (reinstall)' '' OFF)
fi


# Duck DNS
if [[ ! -f "${RECEIVER_BUILD_DIRECTORY}/duckdns/duck.sh" ]]; then
    extras_list=("${extras_list[@]}" 'Duck DNS Free Dynamic DNS Hosting' '' OFF)
else
    extras_list=("${extras_list[@]}" 'Duck DNS Free Dynamic DNS Hosting (reinstall)' '' OFF)
fi


# Graphs1090
if [[ ! -f /lib/systemd/system/graphs1090.service ]]; then
    extras_list=("${extras_list[@]}" 'Graphs1090' '' OFF)
else
    extras_list=("${extras_list[@]}" 'Graphs1090 (reinstall)' '' OFF)
fi


# tar1090
if [[ ! -f /lib/systemd/system/tar1090.service ]]; then
    extras_list=("${extras_list[@]}" 'tar1090' '' OFF)
else
    extras_list=("${extras_list[@]}" 'tar1090 (reinstall)' '' OFF)
fi


whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "Extras Installation Options" \
         --checklist \
         --nocancel \
         --separate-output "The following extras are available for installation, please select any which you wish to install." \
         11 65 4 "${extras_list[@]}" 2>"${RECEIVER_ROOT_DIRECTORY}/extras_choices.txt"


## Setup Confirmation

confirmation_message=""

if [[ "${install_adsb_decoder}" == "false" && "${install_uat_decoder}" == "false" && "${install_acars_decoder}" == "false" && "${install_vdlm2_decoder}" == "false" && "${install_portal}" == "false" && ! -s "${RECEIVER_ROOT_DIRECTORY}/feeder_choices.txt" && ! -s "${RECEIVER_ROOT_DIRECTORY}/extras_choices.txt" ]]; then
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
        case "${chosen_adsb_decoder}" in
            "dump1090-fa")
                confirmation_message="${confirmation_message}\n  * FlightAware dump1090"
                ;;
            "readsb")
                confirmation_message="${confirmation_message}\n  * Readsb"
                ;;
        esac
    fi

    # UAT decoders
    if [[ "${install_uat_decoder}" == "true" ]]; then
        case "${chosen_uat_decoder}" in
            "dump978-fa")
                confirmation_message="${confirmation_message}\n  * FlightAware dump978"
                ;;
        esac
    fi

    # ACARS decoders
    if [[ "${install_acars_decoder}" == "true" ]]; then
        case "${chosen_acars_decoder}" in
            "acarsdec")
                confirmation_message="${confirmation_message}\n  * ACARSDEC"
                ;;
        esac
    fi

    # VDL Mode 2 decoders
    if [[ "${install_vdlm2_decoder}" == "true" ]]; then
        case "${chosen_vdlm2_decoder}" in
            "dumpvdl2")
                confirmation_message="${confirmation_message}\n  * dumpvdl2"
                ;;
            "vdlm2dec")
                confirmation_message="${confirmation_message}\n  * vdlm2dec"
                ;;
        esac
    fi

    # Aggregate site clients
    if [[ -s "${RECEIVER_ROOT_DIRECTORY}/feeder_choices.txt" ]]; then
        while IFS= read -r feeder_choice
        do
            confirmation_message="${confirmation_message}\n  * ${feeder_choice}"
        done < "${RECEIVER_ROOT_DIRECTORY}/feeder_choices.txt"
    fi

    # Portals
    if [[ "${install_portal}" == "true" ]]; then
        confirmation_message="${confirmation_message}\n  * ADS-B Receiver Project Web Portal"
    fi

    # Extras
    if [[ -s "${RECEIVER_ROOT_DIRECTORY}/extras_choices.txt" ]]; then
        while IFS= read -r extra_choice
        do
            confirmation_message="${confirmation_message}\n  * ${extra_choice}"
        done < "${RECEIVER_ROOT_DIRECTORY}/extras_choices.txt"
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
    case "${chosen_adsb_decoder}" in
        "dump1090-fa")
             run_installer "decoders/dump1090-fa.sh"
             ;;
        "readsb")
             run_installer "decoders/readsb.sh"
             ;;
    esac
fi

# UAT Decoders
if [[ "${install_uat_decoder}" == "true" ]]; then
    case "${chosen_uat_decoder}" in
        "dump978-fa")
             run_installer "decoders/dump978-fa.sh"
             ;;
    esac
fi

# ACARS Decoders
if [[ "${install_acars_decoder}" == "true" ]]; then
    case "${chosen_acars_decoder}" in
        "acarsdec")
             run_installer "decoders/acarsdec.sh"
             ;;
    esac
fi

# VDL Decoders
if [[ "${install_vdlm2_decoder}" == "true" ]]; then
    case "${chosen_vdlm2_decoder}" in
        "dumpvdl2")
            run_installer "decoders/dumpvdl2.sh"
            ;;
        "vdlm2dec")
            run_installer "decoders/vdlm2dec.sh"
            ;;
    esac
fi

# Aggregate site clients
if [[ -s "${RECEIVER_ROOT_DIRECTORY}/feeder_choices.txt" ]]; then
    while IFS= read -r feeder_choice
    do
        case "${feeder_choice}" in
            "ADS-B Exchange Feed Client"*)
                run_installer "feeders/adsbexchange.sh"
                ;;
            "AirNav Radar RBFeeder"*)
                run_installer "feeders/airnavradar.sh"
                ;;
            "Airplanes.live Feeder"*)
                run_installer "feeders/airplaneslive.sh"
                ;;
            "FlightAware PiAware"*)
                run_installer "feeders/piaware.sh"
                ;;
            "Flightradar24 Client"*)
                run_installer "feeders/flightradar24.sh"
                ;;
            "Fly Italy ADS-B Feeder"*)
                run_installer "feeders/flyitalyadsb.sh"
                ;;
            "OpenSky Network Feeder"*)
                run_installer "feeders/openskynetwork.sh"
                ;;
            "Plane Finder Client"*)
                run_installer "feeders/planefinder.sh"
                ;;
        esac
    done < "${RECEIVER_ROOT_DIRECTORY}/feeder_choices.txt"
fi

# Portals
if [[ "${install_portal}" == "true" ]]; then
    run_installer "portal/install.sh"
fi

# Extras

if [[ -s "${RECEIVER_ROOT_DIRECTORY}/extras_choices.txt" ]]; then
    while IFS= read -r extras_choice
    do
        case "${extras_choice}" in
            "beast-splitter"*)
                run_installer "extras/beastsplitter.sh"
                ;;
            "Duck DNS Free Dynamic DNS Hosting"*)
                run_installer "extras/duckdns.sh"
                ;;
            "Graphs1090"*)
                run_installer "extras/graphs1090.sh"
                ;;
            "tar1090"*)
                run_installer "extras/tar1090.sh"
                ;;
        esac
    done < "${RECEIVER_ROOT_DIRECTORY}/extras_choices.txt"
fi

exit 0

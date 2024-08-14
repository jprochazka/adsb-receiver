#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
log_project_title
log_title_heading "Setting up the VDLM2DEC decoder"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "VDLM2DEC decoder Setup" \
              --yesno "VDLM2DEC is a vdl mode 2 decoder with built-in rtl_sdr or airspy front end.\n\nWould you like to begin the setup process now?" \
              11 78; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "VDLM2DEC decoder setup halted"
    echo ""
    exit 1
fi


## GATHER REQUIRED INFORMATION FROM THE USER

log_heading "Determine the device type to build VDLM2DEC for"

log_message "Asking which type of device will be used by VDLM2DEC"
device=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                  --title "Device Type" \
                  --menu "Please choose the RTL-SDR device type which is to be used by VDLM2DEC." \
                  11 78 3 \
                  "RTL-SDR" "" \
                  "AirSpy" "" \
                  3>&1 1>&2 2>&3)
exit_status=$?
if [[ $exit_status != 0 ]]; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "VDLM2DEC decoder setup halted"
    echo ""
    exit 1
fi

log_heading "Gather information required to configure the decoder(s)"

log_message "Checking if an ACARS decoder is installed"
acars_decoder_installed="false"
if [[ -f /usr/local/bin/acarsdec ]]; then
    log_message "An ACARS decoder appears to be installed"
    acars_decoder_installed="true"
fi

log_message "Checking if an ADS-B decoder is installed"
adsb_decoder_installed="false"
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
    log_message "An ADS-B decoder appears to be installed"
    adsb_decoder_installed="true"
fi

log_message "Checking if a UAT decoder is installed"
uat_decoder_installed="false"
if [[ $(dpkg-query -W -f='${STATUS}' dump978-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
    log_message "An ADS-B decoder appears to be installed"
    uat_decoder_installed="true"
fi

log_message "Checking if a VDL decoder is installed"
vdl_decoder_installed="false"
if [[ -f /usr/local/bin/dumpvdl2 ]]; then
    log_message "A VDL decoder appears to be installed (dumpvdl2)"
    vdl_decoder_installed="true"
    vdl_decoder="dumpvdl2"
fi
if [[ -f /usr/local/bin/vdlm2dec ]]; then
    log_message "A VDL decoder appears to be installed (VDLM2DEC)"
    vdl_decoder_installed="true"
    vdl_decoder="vdlm2dec"
fi
#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh


## BEGIN SETUP

clear
log_project_title
log_title_heading "Setting up the FlightAware Dump978 decoder"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "FlightAware Dump978 Setup" \
              --yesno "This is the FlightAware 978MHz UAT decoder. It is a reimplementation in C++, loosely based on the demodulator from https://github.com/mutability/dump978.\n\n  https://github.com/flightaware/dump978\n\nContinue setup by installing dump978-fa?" \
              14 78; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "FlightAware Dump978 decoder setup halted"
    echo ""
    exit 1
fi


## GATHER REQUIRED INFORMATION FROM THE USER

log_heading "Gather information required to configure the decoder(s)"

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

log_message "Checking if an ACARS decoder is installed"
acars_decoder_installed="false"
if [[ -f /usr/local/bin/acarsdec ]]; then
    log_message "An ACARS decoder appears to be installed"
    acars_decoder_installed="true"
fi

if [[ "${adsb_decoder_installed}" == "true" || "${acars_decoder_installed}" == "true" ]]; then
    log_message "Informing the user that existing decoder(s) appears to be installed"
    whiptail --backtitle "FlightAware Dump978 Decoder Configuration" \
             --title "RTL-SDR Dongle Assignments" \
             --msgbox "It appears that existing decoder(s) have been installed on this device. In order to run FlightAware Dump978 in tandem with other decoders you will need to specifiy which RTL-SDR dongle each decoder is to use.\n\nKeep in mind in order to run multiple decoders on a single device you will need to have multiple RTL-SDR devices connected to your device." \
             12 78

    if [[ "${adsb_decoder_installed}" == "true" ]]; then
        log_message "Determining which device is currently assigned to the ADS-B decoder"
        current_adsb_device_number=`get_config "RECEIVER_SERIAL" "/etc/default/dump1090-fa"`
        log_message "Asking the user to assign a RTL-SDR device number to the ADS-B decoder"
        adsb_device_number_title="Enter the ADS-B Decoder RTL-SDR Device Number"
        while [[ -z $adsb_device_number ]] ; do
            adsb_device_number=$(whiptail --backtitle "ACARSDEC Decoder Configuration" \
                                          --title "${adsb_device_number_title}" \
                                          --inputbox "\nEnter the RTL-SDR device number to assign your ADS-B decoder." \
                                          8 78 \
                                          "${current_adsb_device_number}" 3>&1 1>&2 2>&3)
            exit_status=$?
            if [[ $exit_status != 0 ]]; then
                log_alert_heading "INSTALLATION HALTED"
                log_alert_message "Setup has been halted due to lack of required information"
                echo ""
                log_title_message "------------------------------------------------------------------------------"
                log_title_heading "FlightAware Dump978 decoder setup halted"
                exit 1
            fi
            adsb_device_number_title="Enter the ADS-B Decoder RTL-SDR Device Number (REQUIRED)"
        done
    fi

    if [[ "${acars_decoder_installed}" == "true" ]]; then
        log_message "Determining which device is currently assigned to the UAT decoder"
        exec_start=`get_config "ExecStart" "/etc/systemd/system/acarsdec.service"`
        current_acars_device_number=`echo $exec_start | grep -o -P '(?<=-r ).*(?= -A)'`
        log_message "Asking the user to assign a RTL-SDR device number to ACARSDEC"
        acars_device_number_title="Enter the ACARSDEC RTL-SDR Device Number"
        while [[ -z $acars_device_number ]] ; do
            acars_device_number=$(whiptail --backtitle "ACARSDEC Decoder Configuration" \
                                           --title "${acars_device_number_title}" \
                                           --inputbox "\nEnter the RTL-SDR device number to assign your ACARSDEC decoder." \
                                           8 78 \
                                           "${current_acars_device_number}" 3>&1 1>&2 2>&3)
            exit_status=$?
            if [[ $exit_status != 0 ]]; then
                log_alert_heading "INSTALLATION HALTED"
                log_alert_message "Setup has been halted due to lack of required information"
                echo ""
                log_title_message "------------------------------------------------------------------------------"
                log_title_heading "FlightAware Dump978 decoder setup halted"
                exit 1
            fi
            acars_device_number_title="Enter the ACARSDEC RTL-SDR Device Number (REQUIRED)"
        done
    fi

    current_uat_device_number=""
    if [[ "${uat_decoder_installed}" == "true" ]]; then
        log_message "Determining which device is currently assigned to the UAT decoder"
        receiver_options=`get_config "RECEIVER_OPTIONS" "/etc/default/dump978-fa"`
        current_uat_device_number=$receiver_options | grep -o -P '(?<=serial=).*(?= --)'
    fi
    log_message "Asking the user to assign a RTL-SDR device number to the UAT decoder"
    uat_device_number_title="Enter the UAT Decoder RTL-SDR Device Number"
    while [[ -z $uat_device_number ]] ; do
        uat_device_number=$(whiptail --backtitle "ACARSDEC Decoder Configuration" \
                                     --title "${uat_device_number_title}" \
                                     --inputbox "\nEnter the RTL-SDR device number to assign your UAT decoder." \
                                     8 78 \
                                     "${current_uat_device_number}" 3>&1 1>&2 2>&3)
        exit_status=$?
        if [[ $exit_status != 0 ]]; then
            log_alert_heading "INSTALLATION HALTED"
            log_alert_message "Setup has been halted due to lack of required information"
            echo ""
            log_title_message "------------------------------------------------------------------------------"
            log_title_heading "FlightAware Dump978 decoder setup halted"
            exit 1
        fi
        uat_device_number_title="Enter the UAT Decoder RTL-SDR Device Number (REQUIRED)"
    done
fi


## CHECK FOR PREREQUISITE PACKAGES

log_heading "Installing packages needed to fulfill FlightAware Dump978 decoder dependencies"

check_package build-essential
check_package debhelper
check_package libboost-filesystem-dev
check_package libboost-program-options-dev
check_package libboost-regex-dev
check_package libboost-system-dev
check_package libsoapysdr-dev
check_package soapysdr-module-rtlsdr


## BLACKLIST UNWANTED RTL-SDR MODULES

log_heading "Blacklist unwanted RTL-SDR kernel modules"

blacklist_modules


## CLONE OR PULL THE FLIGHTAWARE DUMP978 DECODER SOURCE

log_heading "Preparing the FlightAware Dump978 Git repository"

if [[ -d $RECEIVER_BUILD_DIRECTORY/dump978-fa/dump978 && -d $RECEIVER_BUILD_DIRECTORY/dump978-fa/dump978/.git ]]; then
    log_message "Entering the FlightAware dump978 git repository directory"
    cd $RECEIVER_BUILD_DIRECTORY/dump978-fa/dump978
    log_message "Pulling the dump1090 git repository"
    echo ""
    git pull 2>&1 | tee -a $RECEIVER_LOG_FILE
else
    log_message "Creating the FlightAware dump978 Project build directory"
    echo ""
    mkdir -v $RECEIVER_BUILD_DIRECTORY/dump978-fa 2>&1 | tee -a $RECEIVER_LOG_FILE
    echo ""
    log_message "Entering the ADS-B Receiver Project build directory"
    cd $RECEIVER_BUILD_DIRECTORY/dump978-fa
    log_message "Cloning the FlightAware dump978 git repository"
    echo ""
    git clone https://github.com/flightaware/dump978.git 2>&1 | tee -a $RECEIVER_LOG_FILE
fi


## BUILD AND INSTALL THE DUMP978-FA and SKYAWARE978 PACKAGES

log_heading "Building the FlightAware dump978-fa and skyaware978 packages"

log_message "Entering the dump978 Git repository"
cd $RECEIVER_BUILD_DIRECTORY/dump978-fa/dump978

log_message "Building the dump978-fa package"
echo ""
dpkg-buildpackage -b 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""

log_message "Installing the dump978-fa Debian package"
echo ""
sudo dpkg -i $RECEIVER_BUILD_DIRECTORY/dump978-fa/dump978-fa_*.deb 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""
log_message "Installing the skyaware978 Debian package"
echo ""
sudo dpkg -i $RECEIVER_BUILD_DIRECTORY/dump978-fa/skyaware978_*.deb 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""

log_message "Checking that the dump978-fa Debian package was installed"
if [[ $(dpkg-query -W -f='${STATUS}' dump978-fa 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    echo ""
    log_alert_message "The dump978-fa Debian package failed to install"
    log_alert_message "Setup has been terminated"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "FlightAware Dump978 decoder setup halted"
    echo ""
    read -p "Press enter to continue..." discard
    exit 1
fi

log_message "Checking that the skyaware978 Debian package was installed"
if [[ $(dpkg-query -W -f='${STATUS}' skyaware978 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    echo ""
    log_alert_message "The skyaware978 Debian package failed to install"
    log_alert_message "Setup has been terminated"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "FlightAware Dump978 decoder setup halted"
    echo ""
    read -p "Press enter to continue..." discard
    exit 1
fi

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/package-archive ]]; then
    log_message "Creating the Debian package archive directory"
    echo ""
    mkdir -v $RECEIVER_BUILD_DIRECTORY/package-archive 2>&1 | tee -a $RECEIVER_LOG_FILE
    echo ""
fi
log_message "Copying the dump978-fa Debian package into the Debian package archive directory"
echo ""
cp -vf $RECEIVER_BUILD_DIRECTORY/dump978-fa/dump978-fa_*.deb $RECEIVER_BUILD_DIRECTORY/package-archive/ 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""
log_message "Copying the skyaware978 Debian package into the Debian package archive directory"
echo ""
cp -vf $RECEIVER_BUILD_DIRECTORY/dump978-fa/skyaware978_*.deb $RECEIVER_BUILD_DIRECTORY/package-archive/ 2>&1 | tee -a $RECEIVER_LOG_FILE


## CONFIGURATION

if [[ "${adsb_decoder_installed}" == "true" || "${acars_decoder_installed}" == "true" ]]; then

    log_heading "Configuring the decoders so they can work in tandem"

    if [[ "${adsb_decoder_installed}" == "true" ]]; then
        log_message "Assigning RTL-SDR device number ${adsb_device_number} to the FlightAware Dump1090 decoder"
        change_config "RECEIVER_SERIAL" $adsb_device_number "/etc/default/dump1090-fa"
        log_message "Restarting dump1090-fa"
        sudo systemctl restart dump1090-fa
    fi

    if [[ "${acars_decoder_installed}" == "true" ]]; then
        log_message "Assigning RTL-SDR device number ${acars_device_number} to ACARSDEC"
        sudo sed -i -e "s/\(.*-r \)\([0-9]\+\)\( .*\)/\1${acars_device_number}\3/g" /etc/systemd/system/acarsdec.service
        log_message "Reload systemd units"
        sudo systemctl daemon-reload
        log_message "Restarting ACARSDEC"
        sudo systemctl restart acarsdec
    fi

    log_message "Assigning RTL-SDR device number ${uat_device_number} to the FlightAware Dump978 decoder"
    sudo sed -i -e "s/driver=rtlsdr/driver=rtlsdr,serial=${uat_device_number}/g" /etc/default/dump978-fa
    log_message "Restarting dump978-fa"
    sudo systemctl restart dump978-fa
fi


## SETUP COMPLETE

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "FlightAware Dump978 decoder setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

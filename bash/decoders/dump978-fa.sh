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

log_heading "Gather information required to configure the ADS-B decoder and dump978-fa if needed"

log_message "Checking if an ADS-B decoder is installed"
adsb_decoder_installed="false"
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
    log_message "An ADS-B decoder appears to be installed"
    adsb_decoder_installed="true"
fi

if [[ "${adsb_decoder_installed}" == "true" ]]; then
    log_message "Checking if dump978-fa has been configured"
    if [[ -f /etc/default/dump978-fa ]]; then
        log_message "A dump978-fa configuration file exists"
    else
        log_message "Informing the user an ADS-B decoder appears to be installed"
        whiptail --backtitle "FlightAware Dump978 Configuration" \
                 --title "RTL-SDR Dongle Assignments" \
                 --msgbox "It appears one of the dump1090 decoder packages has been installed on this device. In order to run dump978 in tandem with dump1090 you will need to specifiy which RTL-SDR dongle each decoder is to use.\n\nKeep in mind in order to run both decoders on a single device you will need to have two separate RTL-SDR devices connected to your device." \
                 12 78

        log_message "Asking the user to assign a RTL-SDR device serial number to the ADS-B decoder"
        dump1090_device_serial_title="Enter the Dump1090 RTL-SDR Device Serial"
        while [[ -z $dump1090_device_serial ]] ; do
            dump1090_device_serial=$(whiptail --backtitle "FlightAware Dump978 Configuration" \
                                              --title "${dump1090_device_serial_title}" \
                                              --inputbox "\nEnter the serial number for your dump1090 RTL-SDR device." \
                                              8 78 3>&1 1>&2 2>&3)
            if [[ $dump1090_device_serial == 0 ]]; then
                log_alert_heading "INSTALLATION HALTED"
                log_alert_message "Setup has been halted due to lack of required information"
                echo ""
                log_title_message "------------------------------------------------------------------------------"
                log_title_heading "FlightAware Dump978 decoder setup halted"
                exit 1
            fi
            dump1090_device_serial_title="Enter the Dump1090 RTL-SDR Device Serial (REQUIRED)"
        done

        log_message "Asking the user to assign a RTL-SDR device serial number to dump978-fa"
        dump978_device_serial_title="Enter the Dump978 RTL-SDR Device Serial"
        while [[ -z $dump978_device_serial ]] ; do
            dump978_device_serial=$(whiptail --backtitle "FlightAware Dump978 Configuration" \
                                             --title "${dump978_device_serial_title}" \
                                             --inputbox "\nEnter the serial number for your dump978 RTL-SDR device." \
                                             8 78 3>&1 1>&2 2>&3)
            if [[ $dump978_device_serial == 0 ]]; then
                log_alert_heading "INSTALLATION HALTED"
                log_alert_message "Setup has been halted due to lack of required information"
                echo ""
                log_title_message "------------------------------------------------------------------------------"
                log_title_heading "FlightAware Dump978 decoder setup halted"
                exit 1
            fi
            dump978_device_serial_title="Enter the Dump1090 RTL-SDR Device Serial (REQUIRED)"
        done
    fi
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
sudo dpkg -i $RECEIVER_BUILD_DIRECTORY/dump978-fa/dump978-fa_${DUMP978_FA_VERSION}_*.deb 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""
log_message "Installing the skyaware978 Debian package"
echo ""
sudo dpkg -i $RECEIVER_BUILD_DIRECTORY/dump978-fa/skyaware978_${DUMP978_FA_VERSION}_*.deb 2>&1 | tee -a $RECEIVER_LOG_FILE
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

if [[ "${adsb_decoder_installed}" == "true" ]]; then

    log_heading "Configuring the ADS-B decoder and dump978-fa so they can work in tandem"

    log_message "Assigning RTL-SDR device with serial ${dump978_device_serial} to dump978-fa"
    sudo sed -i -e "s/driver=rtlsdr/driver=rtlsdr,serial=${dump978_device_serial}/g" /etc/default/dump978-fa
    log_message "Restarting dump978-fa...\e[97m"
    sudo systemctl restart dump978-fa

    if [[ $(dpkg-query -W -f='${STATUS}' dump978-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
        log_message "Assigning RTL-SDR device with serial ${dump1090_device_serial} to the FlightAware Dump1090 decoder"
        change_config "RECEIVER_SERIAL" $dump1090_device_serial "/etc/default/dump1090-fa"
        log_message "Restarting dump1090-fa"
        sudo systemctl restart dump1090-fa
    fi
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

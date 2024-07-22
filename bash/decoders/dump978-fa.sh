#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh


## BEGIN SETUP

clear
LogProjectTitle
LogTitleHeading "Setting up the FlightAware Dump978 decoder"
LogTitleMessage "------------------------------------------------------------------------------"
echo ""
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "FlightAware Dump978 Setup" \
              --yesno "This is the FlightAware 978MHz UAT decoder. It is a reimplementation in C++, loosely based on the demodulator from https://github.com/mutability/dump978.\n\n  https://github.com/flightaware/dump978\n\nContinue setup by installing dump978-fa?" \
              14 78; then
    LogAlertHeading "INSTALLATION HALTED"
    LogAlertMessage "Setup has been halted at the request of the user"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "FlightAware Dump978 decoder setup halted"
    echo ""
    exit 1
fi


## GATHER REQUIRED INFORMATION FROM THE USER

LogHeading "Gather information required to configure the ADS-B decoder and dump978-fa if needed"

LogMessage "Checking if an ADS-B decoder is installed"
adsb_decoder_installed="false"
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
    adsb_decoder_installed="true"
fi

if [[ "${adsb_decoder_installed}" == "true" ]]; then
    LogMessage "Checking if dump978-fa has been configured"
    if grep -wq "driver=rtlsdr,serial=" /etc/default/dump978-fa; then
        echo -e "The dump978-fa installation appears to have been configured"
    else
        whiptail --backtitle "FlightAware Dump978 Configuration" \
                 --title "RTL-SDR Dongle Assignments" \
                 --msgbox "It appears one of the dump1090 packages has been installed on this device. In order to run dump978 in tandem with dump1090 you will need to specifiy which RTL-SDR dongle each decoder is to use.\n\nKeep in mind in order to run both decoders on a single device you will need to have two separate RTL-SDR devices connected to your device." \
                 12 78

        dump1090_device_serial_title="Enter the Dump1090 RTL-SDR Device Serial"
        while [[ -z $dump1090_device_serial ]] ; do
        dump1090_device_serial=$(whiptail --backtitle "FlightAware Dump978 Configuration" \
                                          --title "${dump1090_device_serial_title}" \
                                          --inputbox "\nEnter the serial number for your dump1090 RTL-SDR device." \
                                          8 78)
            whiptail_exit_status=$?
            if [[ $whiptail_exit_status == 0 ]]; then
                LogAlertHeading "INSTALLATION HALTED"
                LogAlertMessage "Setup has been halted due to lack of required information"
                echo ""
                LogTitleMessage "------------------------------------------------------------------------------"
                LogTitleHeading "FlightAware Dump978 decoder setup halted"
                exit 1
            fi
            dump1090_device_serial_title="Enter the Dump1090 RTL-SDR Device Serial (REQUIRED)"
        done

        dump978_device_serial_title="Enter the Dump978 RTL-SDR Device Serial"
        while [[ -z $dump1090_device_serial ]] ; do
        dump978_device_serial=$(whiptail --backtitle "FlightAware Dump978 Configuration" \
                                          --title "${dump978_device_serial_title}" \
                                          --inputbox "\nEnter the serial number for your dump978 RTL-SDR device." \
                                          8 78)
            whiptail_exit_status=$?
            if [[ $whiptail_exit_status == 0 ]]; then
                LogAlertHeading "INSTALLATION HALTED"
                LogAlertMessage "Setup has been halted due to lack of required information"
                echo ""
                LogTitleMessage "------------------------------------------------------------------------------"
                LogTitleHeading "FlightAware Dump978 decoder setup halted"
                exit 1
            fi
            dump978_device_serial_title="Enter the Dump1090 RTL-SDR Device Serial (REQUIRED)"
        done
    fi
fi


## CHECK FOR PREREQUISITE PACKAGES

LogHeading "Installing packages needed to fulfill FlightAware Dump978 decoder dependencies"

CheckPackage build-essential
CheckPackage debhelper
CheckPackage libboost-filesystem-dev
CheckPackage libboost-program-options-dev
CheckPackage libboost-regex-dev
CheckPackage libboost-system-dev
CheckPackage libsoapysdr-dev
CheckPackage soapysdr-module-rtlsdr


## BLACKLIST UNWANTED RTL-SDR MODULES

LogHeading "Blacklist unwanted RTL-SDR kernel modules"

BlacklistModules


## CLONE OR PULL THE FLIGHTAWARE DUMP978 DECODER SOURCE

LogHeading "Preparing the FlightAware Dump978 Git repository"

if [[ -d $RECEIVER_BUILD_DIRECTORY/dump978-fa/dump978 && -d $RECEIVER_BUILD_DIRECTORY/dump978-fa/dump978/.git ]]; then
    LogMessage "Entering the FlightAware dump978 git repository directory"
    cd $RECEIVER_BUILD_DIRECTORY/dump978-fa/dump978
    LogMessage "Pulling the dump1090 git repository"
    echo ""
    git pull
else
    LogMessage "Creating the FlightAware dump978 Project build directory"
    echo ""
    mkdir -vp $RECEIVER_BUILD_DIRECTORY/dump1090-fa
    echo ""
    LogMessage "Entering the ADS-B Receiver Project build directory"
    cd $RECEIVER_BUILD_DIRECTORY/dump978-fa
    LogMessage "Cloning the FlightAware dump978 git repository"
    echo ""
    git clone https://github.com/flightaware/dump978.git
fi
echo ""


## BUILD AND INSTALL THE DUMP978-FA and SKYAWARE978 PACKAGES

LogHeading "Building the FlightAware dump978-fa and skyaware978 packages"

LogMessage "Entering the dump978 Git repository"
cd $RECEIVER_BUILD_DIRECTORY/dump978-fa/dump978

LogMessage "Building the dump978-fa package"
echo ""
dpkg-buildpackage -b
echo ""

LogMessage "Installing the dump1090-fa Debian package"
sudo dpkg -i $RECEIVER_BUILD_DIRECTORY/dump978-fa/dump978-fa_${DUMP978_FA_VERSION}_*.deb
LogMessage "Installing the skyaware978 Debian package"
sudo dpkg -i $$RECEIVER_BUILD_DIRECTORY/dump978-fa/skyaware978_${DUMP978_FA_VERSION}_*.deb

LogMessage "Checking that the dump978-fa Debian package was installed"
if [[ $(dpkg-query -W -f='${STATUS}' dump978-fa 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
    echo ""
    LogAlertHeading "INSTALLATION HALTED"
    echo ""
    LogAlertMessage "The dump978-fa Debian package failed to install"
    LogAlertMessage "Setup has been terminated"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "FlightAware Dump978 decoder setup halted"
    echo ""
    read -p "Press enter to continue..." discard
    exit 1
fi

LogMessage "Checking that the skyaware978 Debian package was installed"
if [[ $(dpkg-query -W -f='${STATUS}' skyaware978 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
    echo ""
    LogAlertHeading "INSTALLATION HALTED"
    echo ""
    LogAlertMessage "The skyaware978 Debian package failed to install"
    LogAlertMessage "Setup has been terminated"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "FlightAware Dump978 decoder setup halted"
    echo ""
    read -p "Press enter to continue..." discard
    exit 1
fi

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/package-archive ]]; then
    LogMessage "Creating the Debian package archive directory"
    echo ""
    mkdir -vp $RECEIVER_BUILD_DIRECTORY/package-archive
    echo ""
fi
LogMessage "Copying the dump978-fa Debian package into the Debian package archive directory"
echo ""
cp -vf $RECEIVER_BUILD_DIRECTORY/piaware_builder/*.deb $RECEIVER_BUILD_DIRECTORY/package-archive/
echo ""
LogMessage "Copying the skyaware978 Debian package into the Debian package archive directory"
echo ""
cp -vf $RECEIVER_BUILD_DIRECTORY/piaware_builder/*.deb $RECEIVER_BUILD_DIRECTORY/package-archive/
echo ""


## CONFIGURATION


if [[ "${adsb_decoder_installed}" == "true" ]]; then

    LogHeading "Configuring the ADS-B decoder and dump978-fa so they can work in tandem"

    LogMessage "Assigning RTL-SDR device with serial ${dump978_device_serial} to dump978-fa"
    sudo sed -i -e "s/driver=rtlsdr/driver=rtlsdr,serial=${dump978_device_serial}/g" /etc/default/dump978-fa
    LogMessage "Restarting dump978-fa...\e[97m"
    sudo servicectl restart dump978-fa

    if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
        LogMessage "Assigning RTL-SDR device with serial ${dump1090_device_serial} to the FlightAware Dump1090 decoder"
        ChangeConfig "RECEIVER_SERIAL" $dump1090_device_serial "/etc/default/dump1090-fa"
        LogMessage "Restarting dump1090-fa"
        sudo servicectl restart dump1090-fa
    fi
fi


## SETUP COMPLETE

LogMessage "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
LogTitleMessage "------------------------------------------------------------------------------"
LogTitleHeading "FlightAware Dump978 decoder setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

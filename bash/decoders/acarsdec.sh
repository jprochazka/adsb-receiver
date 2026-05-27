#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
log_project_title
log_title_heading "Setting up the ACARSDEC decoder"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "ACARSDEC decoder Setup" \
              --yesno "ACARSDEC is a multi-channels acars decoder with built-in rtl_sdr, airspy front end or sdrplay device. Since 3.0, It comes with a database backend : acarsserv to store received acars messages.\n\nWould you like to begin the setup process now?" \
              11 78; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "ACARSDEC decoder setup halted"
    echo ""
    exit 1
fi


## GATHER REQUIRED INFORMATION FROM THE USER

log_heading "Determine the device type to build ACARSDEC for"

log_message "Asking which type of device will be used by ACARSDEC"
device=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                  --title "Device Type" \
                  --menu "Please choose the RTL-SDR device type which is to be used by ACARSDEC." \
                  11 78 3 \
                  "RTL-SDR" "" \
                  "AirSpy" "" \
                  "SDRPlay" "" \
                  3>&1 1>&2 2>&3)
exit_status=$?
if [[ $exit_status != 0 ]]; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "ACARSDEC decoder setup halted"
    echo ""
    exit 1
fi

ask_for_device_assignments "acarsdec"
if [[ $? -ne 0 ]] ; then
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted due to lack of required information"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "ACARSDEC decoder setup halted"
    exit 1
fi
if [[ -z $RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER ]]; then
    RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER="0"
fi

current_acars_frequencies="130.025 130.425 130.450 131.125 131.550"
if [[ "${acars_decoder_installed}" == "true" ]]; then
    log_message "Determining which frequencies are currently assigned"
    exec_start=$(get_config "ExecStart" "/etc/systemd/system/acarsdec.service")
    parsed_frequencies=$(grep -Eo '[0-9]{3}\.[0-9]{3}' <<< "${exec_start}" | tr '\n' ' ' | sed -e 's/[[:space:]]\+$//')
    if [[ -n "${parsed_frequencies}" ]]; then
        current_acars_frequencies="${parsed_frequencies}"
    fi
fi
log_message "Asking the user for ACARS frequencies to monitor"
acars_fequencies_title="Enter ACARS Frequencies"
while [[ -z $acars_fequencies ]] ; do
    acars_fequencies=$(whiptail --backtitle "ACARS Frequencies" \
                                --title "${acars_fequencies_title}" \
                                --inputbox "\nEnter the ACARS frequencies you would like to monitor." \
                                8 78 \
                                "${current_acars_frequencies}" 3>&1 1>&2 2>&3)
    exit_status=$?
    if [[ $exit_status != 0 ]]; then
        log_alert_heading "INSTALLATION HALTED"
        log_alert_message "Setup has been halted due to lack of required information"
        echo ""
        log_title_message "------------------------------------------------------------------------------"
        log_title_heading "ACARSDEC decoder setup halted"
        exit 1
    fi
    acars_fequencies_title="Enter ACARS Frequencies (REQUIRED)"
done


## CHECK FOR PREREQUISITE PACKAGES

log_heading "Installing packages needed to fulfill dependencies for FlightAware PiAware client"

check_package cmake
check_package libjansson-dev
check_package libcjson-dev
check_package libpaho-mqtt-dev
check_package libasound2-dev
check_package libsndfile1-dev
check_package libsqlite3-dev
check_package libusb-1.0-0-dev
check_package libxml2-dev
check_package pkg-config
check_package zlib1g-dev

check_package sqlite3

case "${device}" in
    "RTL-SDR")
        check_package librtlsdr-dev
        ;;
    "AirSpy")
        check_package libairspy-dev
        ;;
    "SDRPlay")
        if apt-cache show libsdrplay3-dev > /dev/null 2>&1; then
            check_package libsdrplay3-dev
        elif apt-cache show libsdrplay-api-dev > /dev/null 2>&1; then
            check_package libsdrplay-api-dev
        elif apt-cache show libmirisdr-dev > /dev/null 2>&1; then
            log_warning_message "Falling back to legacy package libmirisdr-dev for SDRPlay support"
            check_package libmirisdr-dev
        else
            log_alert_heading "INSTALLATION HALTED"
            log_alert_message "Unable to locate an SDRPlay development package for ACARSDEC"
            log_alert_message "Tried: libsdrplay3-dev, libsdrplay-api-dev, libmirisdr-dev"
            exit 1
        fi
        ;;
esac


## BLACKLIST UNWANTED RTL-SDR MODULES

log_heading "Blacklist unwanted RTL-SDR kernel modules"

blacklist_modules


## CLONE OR PULL THE LIBACARS GIT REPOSITORY

log_heading "Preparing the libacars Git repository"

if [[ -d $RECEIVER_BUILD_DIRECTORY/libacars && -d $RECEIVER_BUILD_DIRECTORY/libacars/.git ]]; then
    log_message "Entering the libacars git repository directory"
    cd $RECEIVER_BUILD_DIRECTORY/libacars
    log_message "Updating the local libacars git repository"
    echo ""
    git pull
else
    log_message "Entering the libacars build directory"
    cd $RECEIVER_BUILD_DIRECTORY
    log_message "Cloning the libacars git repository locally"
    echo ""
    git clone https://github.com/szpajder/libacars.git
fi


## BUILD AND INSTALL THE LIBACARS LIBRARY

log_heading "Building the libacars library"

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/libacars/build ]]; then
    log_message "Creating the libacars build directory"
    echo ""
        mkdir -vp $RECEIVER_BUILD_DIRECTORY/libacars/build
    echo ""
fi
if [[ -n "$(ls -A $RECEIVER_BUILD_DIRECTORY/libacars/build 2>/dev/null)" ]]; then
    log_message "Deleting all files currently residing in the libacars build directory"
    rm -rf $RECEIVER_BUILD_DIRECTORY/libacars/build/*
fi
log_message "Entering the libacars build directory"
cd $RECEIVER_BUILD_DIRECTORY/libacars/build
log_message "Executing cmake"
echo ""
cmake ../
echo ""
log_message "Executing make"
echo ""
make
echo ""
log_message "Executing make install"
echo ""
sudo make install
echo ""
log_message "Running ldconfig"
sudo ldconfig


## CLONE OR PULL THE ACARSDEC GIT REPOSITORY

log_heading "Preparing the ACARSDEC Git repository"

if [[ -d $RECEIVER_BUILD_DIRECTORY/acarsdec && -d $RECEIVER_BUILD_DIRECTORY/acarsdec/.git ]]; then
    log_message "Entering the ACARSDEC git repository directory"
    cd $RECEIVER_BUILD_DIRECTORY/acarsdec
    log_message "Ensuring the ACARSDEC git remote points to the maintained repository"
    git remote set-url origin https://github.com/f00b4r0/acarsdec.git
    log_message "Updating the local ACARSDEC git repository"
    echo ""
    git pull
else
    log_message "Entering the build directory"
    cd $RECEIVER_BUILD_DIRECTORY
    log_message "Cloning the ACARSDEC git repository locally"
    echo ""
    git clone https://github.com/f00b4r0/acarsdec.git
fi


## BUILD AND INSTALL THE ACARSDEC BINARY

log_heading "Building the ACARSDEC binary"

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/acarsdec/build ]]; then
    log_message "Creating the ACARSDEC build directory"
    echo ""
        mkdir -vp $RECEIVER_BUILD_DIRECTORY/acarsdec/build
    echo ""
fi
if [[ -n "$(ls -A $RECEIVER_BUILD_DIRECTORY/acarsdec/build 2>/dev/null)" ]]; then
    log_message "Deleting all files currently residing in the ACARSDEC build directory"
    rm -rf $RECEIVER_BUILD_DIRECTORY/acarsdec/build/*
fi
log_message "Entering the ACARSDEC build directory"
cd $RECEIVER_BUILD_DIRECTORY/acarsdec/build

log_message "Executing cmake"
echo ""
case "${device}" in
    "RTL-SDR")
        cmake .. -DRTLSDR=ON -DAIRSPY=OFF -DSDRPLAY=OFF -DSOAPYSDR=OFF
        ;;
    "AirSpy")
        cmake .. -DRTLSDR=OFF -DAIRSPY=ON -DSDRPLAY=OFF -DSOAPYSDR=OFF
        ;;
    "SDRPlay")
        cmake .. -DRTLSDR=OFF -DAIRSPY=OFF -DSDRPLAY=ON -DSOAPYSDR=OFF
        ;;
esac
echo ""

log_message "Executing make"
echo ""
make
echo ""
log_message "Executing make install"
echo ""
sudo make install


## CLONE OR PULL THE ACARSSERV GIT REPOSITORY

log_heading "Preparing the acarsserv Git repository"

if [[ -d $RECEIVER_BUILD_DIRECTORY/acarsserv && -d $RECEIVER_BUILD_DIRECTORY/acarsserv/.git ]]; then
    log_message "Entering the acarsserv git repository directory"
    cd $RECEIVER_BUILD_DIRECTORY/acarsserv
    log_message "Updating the local acarsserv git repository"
    echo ""
    git pull
else
    log_message "Entering the build directory"
    cd $RECEIVER_BUILD_DIRECTORY
    log_message "Cloning the acarsserv git repository locally"
    echo ""
    git clone https://github.com/TLeconte/acarsserv.git
fi


## BUILD AND INSTALL THE ACARSSERV BINARY

log_heading "Building the ACARSSERV binary"

log_message "Entering the acarsserv build directory"
cd $RECEIVER_BUILD_DIRECTORY/acarsserv
log_message "Executing make"
echo ""
make -f Makefile
echo ""


## RUN ACARSDECO AND ACARSSERV

log_message "Creating the ACARSDEC systemd service script"
case "${device}" in
    "RTL-SDR")
        acarsdec_input_args="--rtlsdr ${RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER} ${acars_fequencies}"
        ;;
    "AirSpy")
        acarsdec_input_args="--airspy ${RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER} ${acars_fequencies}"
        ;;
    "SDRPlay")
        acarsdec_input_args="--sdrplay ${RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER} ${acars_fequencies}"
        ;;
esac
sudo tee /etc/systemd/system/acarsdec.service > /dev/null <<EOF
[Unit]
Description=ARCARSDEC multi-channel acars decoder.
After=network.target

[Service]
ExecStart=/usr/local/bin/acarsdec --output json:udp:host=127.0.0.1,port=5555 ${acarsdec_input_args}
WorkingDirectory=/usr/local/bin
StandardOutput=null
TimeoutSec=30
Restart=on-failure
RestartSec=30
StartLimitInterval=350
StartLimitBurst=10

[Install]
WantedBy=multi-user.target
EOF

log_message "Creating the ACARSSERV systemd service script"
sudo tee /etc/systemd/system/acarsserv.service > /dev/null <<EOF
[Unit]
Description=ARCARSSERV saves acars data to SQLite.
After=network.target

[Service]
ExecStart=${RECEIVER_BUILD_DIRECTORY}/acarsserv/acarsserv -j 127.0.0.1:5555
WorkingDirectory=${RECEIVER_BUILD_DIRECTORY}/acarsserv
StandardOutput=null
TimeoutSec=30
Restart=on-failure
RestartSec=30
StartLimitInterval=350
StartLimitBurst=10

[Install]
WantedBy=multi-user.target
EOF

log_message "Enabling then starting the ACARSDEC service"
sudo systemctl enable --now acarsdec.service
log_message "Enabling then starting the acarsserv service"
sudo systemctl enable --now acarsserv.service


## CONFIGURATION

assign_devices_to_decoders


## POST INSTALLATION OPERATIONS

whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "ACARSDEC Decoder Setup Complete" \
         --msgbox "The setup process currently sets basic parameters needed to feed acarsserv. You can fine tune your installation by modifying the startup command found in the file /etc/systemd/system/acarsdec.service. Usage information for ACARSDEC can be found in the project README at https://github.com/f00b4r0/acarsdec." \
         12 78


## SETUP COMPLETE

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "ACARSDEC decoder setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

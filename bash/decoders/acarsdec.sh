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

if [[ "${adsb_decoder_installed}" == "true" || "${uat_decoder_installed}" == "true" ]]; then
    log_message "Informing the user that existing decoder(s) appears to be installed"
    whiptail --backtitle "ACARSDEC Decoder Configuration" \
             --title "RTL-SDR Dongle Assignments" \
             --msgbox "It appears that existing decoder(s) have been installed on this device. In order to run ACARSDEC in tandem with other decoders you will need to specifiy which RTL-SDR dongle each decoder is to use.\n\nKeep in mind in order to run multiple decoders on a single device you will need to have multiple RTL-SDR devices connected to your device." \
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
                log_title_heading "ACARSDEC decoder setup halted"
                exit 1
            fi
            adsb_device_number_title="Enter the ADS-B Decoder RTL-SDR Device Number (REQUIRED)"
        done
    fi

    if [[ "${uat_decoder_installed}" == "true" ]]; then
        log_message "Determining which device is currently assigned to the UAT decoder"
        receiver_options=`get_config "RECEIVER_OPTIONS" "/etc/default/dump978-fa"`
        current_uat_device_number=$receiver_options | grep -o -P '(?<=serial=).*(?= --)'
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
                log_title_heading "ACARSDEC decoder setup halted"
                exit 1
            fi
            uat_device_number_title="Enter the UAT Decoder RTL-SDR Device Number (REQUIRED)"
        done
    fi

    current_acars_device_number=""
    if [[ "${acars_decoder_installed}" == "true" ]]; then
        log_message "Determining which device is currently assigned to the UAT decoder"
        exec_start=`get_config "ExecStart" "/etc/systemd/system/acarsdec.service"`
        current_acars_device_number=`echo $exec_start | grep -o -P '(?<=-r ).*(?= -A)'`
    fi
    log_message "Asking the user to assign a RTL-SDR device number to ACARSDEC"
    acars_device_number_title="Enter the ACARSDEC RTL-SDR Device Number"
    while [[ -z $acars_device_number ]]; do
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
            log_title_heading "ACARSDEC decoder setup halted"
            exit 1
        fi
        acars_device_number_title="Enter the ACARSDEC RTL-SDR Device Number (REQUIRED)"
    done
fi

if [[ -z $acars_device_number ]]; then
    acars_device_number="0"
fi

current_acars_frequencies=""
if [[ "${acars_decoder_installed}" == "true" ]]; then
    log_message "Determining which frequencies are currently assigned"
    exec_start=`get_config "ExecStart" "/etc/systemd/system/acarsdec.service"`
    current_acars_frequencies=`sed -e "s#.*-r ${acars_device_number} \(\)#\1#" <<< "${exec_start}"`
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
check_package libpaho-mqtt-dev
check_package libsndfile1-dev
check_package libsqlite3-dev
check_package libusb-1.0-0-dev
check_package libxml2-dev
check_package pkg-config
check_package zlib1g-dev

case "${device}" in
    "RTL-SDR")
        check_package librtlsdr-dev
        ;;
    "AirSpy")
        check_package libairspy-dev
        ;;
    "SDRPlay")
        check_package libmirisdr-dev
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
    log_message "Updating the local ACARSDEC git repository"
    echo ""
    git pull
else
    log_message "Entering the build directory"
    cd $RECEIVER_BUILD_DIRECTORY
    log_message "Cloning the ACARSDEC git repository locally"
    echo ""
    git clone https://github.com/TLeconte/acarsdec.git
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
        cmake .. -Drtl=ON
        ;;
    "AirSpy")
        cmake .. -Dairspy=ON
        ;;
    "SDRPlay")
        cmake .. -Dsdrplay=ON
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


## BUILD AND INSTALL THE ACARSDEC BINARY

log_heading "Building the ACARSDEC binary"

log_message "Entering the acarsserv build directory"
cd $RECEIVER_BUILD_DIRECTORY/acarsserv
log_message "Executing make"
echo ""
make -f Makefile
echo ""


## RUN ACARSDECO AND ACARSSERV

log_message "Creating the ACARSDEC systemd service script"
sudo tee /etc/systemd/system/acarsdec.service > /dev/null <<EOF
[Unit]
Description=ARCARSDEC multi-channel acars decoder.
After=network.target

[Service]
ExecStart=/usr/local/bin/acarsdec -j 127.0.0.1:5555 -o2 -g280 -r 0 130.025 130.425 130.450 131.125 131.550
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

if [[ "${adsb_decoder_installed}" == "true" || "${uat_decoder_installed}" == "true" ]]; then

    log_heading "Configuring the decoders so they can work in tandem"

    if [[ "${adsb_decoder_installed}" == "true" ]]; then
        log_message "Assigning RTL-SDR device number ${adsb_device_number} to the FlightAware Dump1090 decoder"
        change_config "RECEIVER_SERIAL" $adsb_device_number "/etc/default/dump1090-fa"
        log_message "Restarting dump1090-fa"
        sudo systemctl restart dump1090-fa
    fi

    if [[ "${uat_decoder_installed}" == "true" ]]; then
        log_message "Assigning RTL-SDR device number ${uat_device_number} to the FlightAware Dump978 decoder"
        sudo sed -i -e "s|driver=rtlsdr|driver=rtlsdr,serial=${uat_device_number}|g" /etc/default/dump978-fa
        log_message "Restarting dump978-fa"
        sudo systemctl restart dump978-fa
    fi

    log_message "Assigning RTL-SDR device number ${acars_device_number} to ACARSDEC"
    sudo sed -i -e "s|\(.*-r \)\([0-9]\+\)\( .*\)|\1${acars_device_number}\3|g" /etc/systemd/system/acarsdec.service
    log_message "Reloading systemd units"
    sudo systemctl daemon-reload
    log_message "Restarting ACARSDEC"
    sudo systemctl restart acarsdec
fi


## POST INSTALLATION OPERATIONS

whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "ACARSDEC Decoder Setup Complete" \
         --msgbox "The setup process currently sets basic parameters needed to feed acarsserv. You can fine tune your installation by modifying the startup command found in the file /etc/systemd/system/acarsdec.service. Usage information for ACARSDEC can be found in the projects README at https://github.com/TLeconte/acarsdec." \
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

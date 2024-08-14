#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
log_project_title
log_title_heading "Setting up the dumpvdl2 decoder"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "dumpvdl2 decoder Setup" \
              --yesno "dumpvdl2 is a VDL Mode 2 message decoder and protocol analyzer.\n\nWould you like to begin the setup process now?" \
              11 78; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "dumpvdl2 decoder setup halted"
    echo ""
    exit 1
fi


## GATHER REQUIRED INFORMATION FROM THE USER

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
    log_message "A VDL decoder appears to be installed"
    vdl_decoder_installed="true"
fi


if [[ "${adsb_decoder_installed}" == "true" || "${uat_decoder_installed}" == "true" || "${vdl_decoder_installed}" == "true" ]]; then
    log_message "Informing the user that existing decoder(s) appears to be installed"
    whiptail --backtitle "Dumpvdl2 Decoder Configuration" \
             --title "RTL-SDR Dongle Assignments" \
             --msgbox "It appears that existing decoder(s) have been installed on this device. In order to run ACARSDEC in tandem with other decoders you will need to specifiy which RTL-SDR dongle each decoder is to use.\n\nKeep in mind in order to run multiple decoders on a single device you will need to have multiple RTL-SDR devices connected to your device." \
             12 78

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
                log_title_heading "Dumpvdl2 decoder setup halted"
                exit 1
            fi
            acars_device_number_title="Enter the ACARSDEC RTL-SDR Device Number (REQUIRED)"
        done
    fi

    if [[ "${adsb_decoder_installed}" == "true" ]]; then
        log_message "Determining which device is currently assigned to the ADS-B decoder"
        current_adsb_device_number=`get_config "RECEIVER_SERIAL" "/etc/default/dump1090-fa"`
        log_message "Asking the user to assign a RTL-SDR device number to the ADS-B decoder"
        adsb_device_number_title="Enter the ADS-B Decoder RTL-SDR Device Number"
        while [[ -z $adsb_device_number ]] ; do
            adsb_device_number=$(whiptail --backtitle "ACARSDEC Decoder Configuration" \
                                          --title "${adsb_device_number_title}" \
                                          --inputbox "Enter the RTL-SDR device number to assign your ADS-B decoder." \
                                          8 78 \
                                          "${current_adsb_device_number}" 3>&1 1>&2 2>&3)
            exit_status=$?
            if [[ $exit_status != 0 ]]; then
                log_alert_heading "INSTALLATION HALTED"
                log_alert_message "Setup has been halted due to lack of required information"
                echo ""
                log_title_message "------------------------------------------------------------------------------"
                log_title_heading "Dumpvdl2 decoder setup halted"
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
                                         --inputbox "Enter the RTL-SDR device number to assign your UAT decoder." \
                                         8 78 \
                                         "${current_uat_device_number}" 3>&1 1>&2 2>&3)
            exit_status=$?
            if [[ $exit_status != 0 ]]; then
                log_alert_heading "INSTALLATION HALTED"
                log_alert_message "Setup has been halted due to lack of required information"
                echo ""
                log_title_message "------------------------------------------------------------------------------"
                log_title_heading "Dumpvdl2 decoder setup halted"
                exit 1
            fi
            uat_device_number_title="Enter the UAT Decoder RTL-SDR Device Number (REQUIRED)"
        done
    fi

    current_vdl_device_number=""
    if [[ "${acars_decoder_installed}" == "true" ]]; then
        log_message "Determining which device is currently assigned to the VDL decoder"
        exec_start=`get_config "ExecStart" "/etc/systemd/system/dumpvdl2.service"`
        current_vdl_device_number=`echo $exec_start | grep -o -P '(?<=--rtlsdr ).*(?= --gain)'`
    fi
    log_message "Asking the user to assign a RTL-SDR device number to the VDL decoder"
    vdl_device_number_title="Enter the dumpvdl2 RTL-SDR Device Number"
    while [[ -z $vdl_device_number ]]; do
        vdl_device_number=$(whiptail --backtitle "Dumpvdl2 Decoder Configuration" \
                                     --title "${vdl_device_number_title}" \
                                     --inputbox "Enter the RTL-SDR device number to assign your dumpvdl2 decoder." \
                                     8 78 \
                                     "${current_vdl_device_number}" 3>&1 1>&2 2>&3)
        exit_status=$?
        if [[ $exit_status != 0 ]]; then
            log_alert_heading "INSTALLATION HALTED"
            log_alert_message "Setup has been halted due to lack of required information"
            echo ""
            log_title_message "------------------------------------------------------------------------------"
            log_title_heading "Dumpvdl2 decoder setup halted"
            exit 1
        fi
        vdl_device_number_title="Enter the dumpvdl2 RTL-SDR Device Number (REQUIRED)"
    done
fi

if [[ -z $vdl_device_number ]]; then
    vdl_device_number="0"
fi

current_vdl_frequencies="136725000 136975000 136875000"
if [[ "${vdl_decoder_installed}" == "true" ]]; then
    log_message "Determining which frequencies are currently assigned"
    exec_start=`get_config "ExecStart" "/etc/systemd/system/dumpvdl2.service"`
    current_vdl_frequencies=`sed -e "s#.*--correction ${vdl_correction} \(\)#\1#" <<< "${exec_start}"`
fi
log_message "Asking the user for VDL frequencies to monitor"
acars_fequencies_title="Enter VDL Frequencies"
while [[ -z $acars_fequencies ]] ; do
    vdl_fequencies=$(whiptail --backtitle "VDL Frequencies" \
                              --title "${vdl_fequencies_title}" \
                              --inputbox "\nEnter the VDL frequencies you would like to monitor." \
                              8 78 \
                              "${current_vdl_frequencies}" 3>&1 1>&2 2>&3)
    exit_status=$?
    if [[ $exit_status != 0 ]]; then
        log_alert_heading "INSTALLATION HALTED"
        log_alert_message "Setup has been halted due to lack of required information"
        echo ""
        log_title_message "------------------------------------------------------------------------------"
        log_title_heading "Dumpvdl2 decoder setup halted"
        exit 1
    fi
    vdl_fequencies_title="Enter VDL Frequencies (REQUIRED)"
done


## CHECK FOR PREREQUISITE PACKAGES

log_heading "Installing packages needed to fulfill dependencies for FlightAware PiAware client"

check_package build-essential
check_package cmake
check_package git
check_package libglib2.0-dev
check_package libjansson-dev
check_package libprotobuf-c-dev
check_package librtlsdr-dev
check_package libsqlite3-dev
check_package libxml2-dev
check_package libzmq3-dev
check_package pkg-config
check_package zlib1g-dev

case $RECEIVER_OS_DISTRIBUTION in
    ubuntu)
        distro_php_version=""
        ;;
    debian)
        if [[ "${RECEIVER_OS_CODE_NAME}" == "bookworm" ]]; then distro_php_version="8.2"; fi
        if [[ "${RECEIVER_OS_CODE_NAME}" == "bullseye" ]]; then distro_php_version="7.4"; fi
        ;;
esac
check_package sqlite3
check_package php${distro_php_version}-sqlite3


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


## CLONE OR PULL THE DUMPVDL2 GIT REPOSITORY

log_heading "Preparing the dumpvdl2 Git repository"

if [[ -d $RECEIVER_BUILD_DIRECTORY/dumpvdl2 && -d $RECEIVER_BUILD_DIRECTORY/dumpvdl2/.git ]]; then
    log_message "Entering the dumpvdl2 git repository directory"
    cd $RECEIVER_BUILD_DIRECTORY/dumpvdl2
    log_message "Updating the local dumpvdl2 git repository"
    echo ""
    git pull
else
    log_message "Entering the build directory"
    cd $RECEIVER_BUILD_DIRECTORY
    log_message "Cloning the dumpvdl2 git repository locally"
    echo ""
    git clone https://github.com/szpajder/dumpvdl2.git
fi


## BUILD AND INSTALL THE DUMPVDL2 BINARY

log_heading "Building the dumpvdl2 binary"

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/dumpvdl2/build ]]; then
    log_message "Creating the dumpvdl2 build directory"
    echo ""
        mkdir -vp $RECEIVER_BUILD_DIRECTORY/dumpvdl2/build
    echo ""
fi
if [[ -n "$(ls -A $RECEIVER_BUILD_DIRECTORY/dumpvdl2/build 2>/dev/null)" ]]; then
    log_message "Deleting all files currently residing in the dumpvdl2 build directory"
    rm -rf $RECEIVER_BUILD_DIRECTORY/dumpvdl2/build/*
fi
log_message "Entering the dumpvdl2 build directory"
cd $RECEIVER_BUILD_DIRECTORY/dumpvdl2/build

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


## RUN DUMPVDL2

log_message "Creating the dumpvdl2 systemd service script"
sudo tee /etc/systemd/system/dumpvdl2.service > /dev/null <<EOF
[Unit]
Description=Dumpvdl2 VDL Mode 2 message decoder and protocol analyzer.
After=network.target

[Service]
ExecStart=/usr/local/bin/dumpvdl2 --rtlsdr 0 --gain 40 --correction 42 136.975
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

log_message "Enabling then starting the dumpvdl2 service"
sudo systemctl enable --now dumpvdl2.service
log_message "Enabling then starting the dumpvdl2 service"
sudo systemctl enable --now dumpvdl2.service


## CONFIGURATION

if [[ "${adsb_decoder_installed}" == "true" || "${uat_decoder_installed}" == "true" ]]; then

    log_heading "Configuring the decoders so they can work in tandem"

    if [[ "${acars_decoder_installed}" == "true" ]]; then
        log_message "Assigning RTL-SDR device number ${acars_device_number} to ACARSDEC"
        sudo sed -i -e "s/\(.*-r \)\([0-9]\+\)\( .*\)/\1${acars_device_number}\3/g" /etc/systemd/system/acarsdec.service
        log_message "Reload systemd units"
        sudo systemctl daemon-reload
        log_message "Restarting ACARSDEC"
        sudo systemctl restart acarsdec
    fi

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

    log_message "Assigning RTL-SDR device number ${vdl_device_number} to dumpvdl2"
    sudo sed -i -e "s|\(.*--rtlsdr \)\([0-9]\+\)\( .*\)|\1${vdl_device_number}\3|g" /etc/systemd/system/dumpvdl2.service
    log_message "Reloading systemd units"
    sudo systemctl daemon-reload
    log_message "Restarting dumpvdl2"
    sudo systemctl restart dumpvdl2
fi


## POST INSTALLATION OPERATIONS

whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "Dumpvdl2 Decoder Setup Complete" \
         --msgbox "The setup process currently sets basic parameters needed to run a basic dumpvdl2 setup. You can fine tune your installation by modifying the startup command found in the file /etc/systemd/system/dumpvdl2.service. Usage information for dumpvdl2 can be found in the projects README at https://github.com/szpajder/dumpvdl2." \
         12 78


## SETUP COMPLETE

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "Dumpvdl2 decoder setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

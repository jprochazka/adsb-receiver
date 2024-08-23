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

ask_for_device_assignments "dumpvdl2"
if [[ $? -ne 0 ]] ; then
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted due to lack of required information"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "Dumpvdl2 decoder setup halted"
    exit 1
fi

current_vdlm2_frequencies="136.100 136.650 136.700 136.800 136.975"
if [[ -f /etc/systemd/system/dumpvdl2.service ]]; then
    log_message "Determining which frequencies are currently assigned"
    exec_start=`get_config "ExecStart" "/etc/systemd/system/dumpvdl2.service"`
    current_vdlm2_frequencies=`sed -e "s#.*--correction ${vdlm2_correction} \(\)#\1#" <<< "${exec_start}"`
fi
log_message "Asking the user for VDL Mode 2 frequencies to monitor"
vdlm2_fequencies_title="Enter VDL Mode 2 Frequencies"
while [[ -z $vdlm2_fequencies ]] ; do
    vdlm2_fequencies=$(whiptail --backtitle "VDL Mode 2 Frequencies" \
                              --title "${vdlm2_fequencies_title}" \
                              --inputbox "\nEnter the VDL Mode 2 frequencies you would like to monitor." \
                              8 78 \
                              "${current_vdlm2_frequencies}" 3>&1 1>&2 2>&3)
    exit_status=$?
    if [[ $exit_status != 0 ]]; then
        log_alert_heading "INSTALLATION HALTED"
        log_alert_message "Setup has been halted due to lack of required information"
        echo ""
        log_title_message "------------------------------------------------------------------------------"
        log_title_heading "Dumpvdl2 decoder setup halted"
        exit 1
    fi
    vdlm2_fequencies_title="Enter VDL Frequencies (REQUIRED)"
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
ExecStart=/usr/local/bin/dumpvdl2 --rtlsdr 0 --gain 40 --correction 42 ${current_vdlm2_frequencies}
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

assign_devices_to_decoders


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

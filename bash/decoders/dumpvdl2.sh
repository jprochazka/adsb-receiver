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
if [[ -f /etc/default/dumpvdl2 ]]; then
    log_message "Determining which frequencies are currently assigned"
    configured_frequencies=$(get_config "DUMPVDL2_FREQUENCIES" "/etc/default/dumpvdl2")
    if [[ -n "${configured_frequencies}" ]]; then
        current_vdlm2_frequencies="${configured_frequencies//M/}"
    fi
elif systemctl cat vdlm2dec.service >/dev/null 2>&1; then
    log_message "Migrating frequencies from the existing VDLM2DEC service"
    legacy_exec_start=$(systemctl show --property=ExecStart --value vdlm2dec.service)
    legacy_frequencies=$(grep -Eo '[0-9]{3}\.[0-9]{3}' <<< "${legacy_exec_start}" | tr '\n' ' ' | sed -e 's/[[:space:]]\+$//')
    if [[ -n "${legacy_frequencies}" ]]; then
        current_vdlm2_frequencies="${legacy_frequencies}"
    fi
fi
log_message "Asking the user for VDL Mode 2 frequencies to monitor"
vdlm2_frequencies_title="Enter VDL Mode 2 Frequencies"
while [[ -z "${vdlm2_frequencies}" ]] ; do
    vdlm2_frequencies=$(whiptail --backtitle "VDL Mode 2 Frequencies" \
                               --title "${vdlm2_frequencies_title}" \
                               --inputbox "\nEnter 1 to 20 space-separated frequencies between 118 and 137 MHz." \
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
    read -r -a requested_frequencies <<< "${vdlm2_frequencies}"
    if [[ ${#requested_frequencies[@]} -lt 1 || ${#requested_frequencies[@]} -gt 20 ]]; then
        vdlm2_frequencies=""
        vdlm2_frequencies_title="Enter 1 to 20 VDL Frequencies (REQUIRED)"
        continue
    fi
    for frequency in "${requested_frequencies[@]}"; do
        if [[ ! "${frequency}" =~ ^[0-9]{3}([.][0-9]{1,3})?$ ]] || \
           ! awk -v frequency="${frequency}" 'BEGIN { exit !(frequency >= 118 && frequency <= 137) }'; then
            vdlm2_frequencies=""
            vdlm2_frequencies_title="Enter Valid 118-137 MHz Frequencies (REQUIRED)"
            break
        fi
    done
done

canonical_frequencies=()
for frequency in "${requested_frequencies[@]}"; do
    canonical_frequencies+=("$(printf '%.3fM' "${frequency}")")
done
vdlm2_frequencies="${canonical_frequencies[*]}"


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

check_package sqlite3


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


## INSTALL THE MESSAGE INGESTION SERVICE

log_heading "Installing the ACARS and VDL2 message ingestion service"

if systemctl cat vdlm2dec.service >/dev/null 2>&1; then
    log_message "Disabling the archived VDLM2DEC service"
    sudo systemctl disable --now vdlm2dec.service
fi

install_acars_ingest_service


## RUN DUMPVDL2

if [[ -z "${RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER}" ]]; then
    if [[ -n "${legacy_exec_start}" ]]; then
        RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER=$(grep -o -P '(?<=-r )[0-9]+' <<< "${legacy_exec_start}")
    fi
    RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER="${RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER:-0}"
fi

dumpvdl2_gain="40"
dumpvdl2_correction="0"
if [[ -f /etc/default/dumpvdl2 ]]; then
    configured_gain=$(get_config "DUMPVDL2_GAIN" "/etc/default/dumpvdl2")
    configured_correction=$(get_config "DUMPVDL2_CORRECTION" "/etc/default/dumpvdl2")
    dumpvdl2_gain="${configured_gain:-${dumpvdl2_gain}}"
    dumpvdl2_correction="${configured_correction:-${dumpvdl2_correction}}"
fi

log_message "Creating the dumpvdl2 configuration"
sudo tee /etc/default/dumpvdl2 > /dev/null <<EOF
DUMPVDL2_DEVICE="${RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER}"
DUMPVDL2_GAIN="${dumpvdl2_gain}"
DUMPVDL2_CORRECTION="${dumpvdl2_correction}"
DUMPVDL2_FREQUENCIES="${vdlm2_frequencies}"
EOF

log_message "Creating the dumpvdl2 systemd service script"
sudo tee /etc/systemd/system/dumpvdl2.service > /dev/null <<EOF
[Unit]
Description=Dumpvdl2 VDL Mode 2 message decoder and protocol analyzer.
Requires=acars-ingest.service
After=network.target acars-ingest.service

[Service]
EnvironmentFile=/etc/default/dumpvdl2
ExecStart=/usr/local/bin/dumpvdl2 --rtlsdr \${DUMPVDL2_DEVICE} --gain \${DUMPVDL2_GAIN} --correction \${DUMPVDL2_CORRECTION} --output decoded:json:udp:address=127.0.0.1,port=5555 \$DUMPVDL2_FREQUENCIES
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

sudo systemctl daemon-reload
log_message "Enabling then starting the dumpvdl2 service"
sudo systemctl enable --now dumpvdl2.service
install_dumpvdl2_config_helper


## CONFIGURATION

assign_devices_to_decoders


## POST INSTALLATION OPERATIONS

whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "Dumpvdl2 Decoder Setup Complete" \
         --msgbox "The setup process configured dumpvdl2 to store decoded messages for the portal. Frequencies can be managed in the portal or in /etc/default/dumpvdl2. Usage information for dumpvdl2 can be found in the project's README at https://github.com/szpajder/dumpvdl2." \
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

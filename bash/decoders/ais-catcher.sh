#!/bin/bash

source "${RECEIVER_BASH_DIRECTORY}/variables.sh"
source "${RECEIVER_BASH_DIRECTORY}/functions.sh"

clear
log_project_title
log_title_heading "Setting up the AIS-catcher decoder"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "AIS-catcher Decoder Setup" \
              --yesno "AIS-catcher is a dual-channel AIS decoder for RTL-SDR devices. Decoded JSON_FULL messages will be sent to the local AIS ingest service.\n\nWould you like to begin the setup process now?" \
              11 78; then
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    exit 1
fi

ask_for_device_assignments "ais-catcher"
if [[ $? -ne 0 ]]; then
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted due to lack of required information"
    exit 1
fi

if [[ -z "${RECEIVER_DEVICE_ASSIGNED_TO_AIS_CATCHER}" ]]; then
    RECEIVER_DEVICE_ASSIGNED_TO_AIS_CATCHER="0"
fi

if [[ "${RECEIVER_DEVICE_ASSIGNED_TO_AIS_CATCHER}" =~ ^[0-9]+$ ]]; then
    ais_catcher_device_argument="-d:${RECEIVER_DEVICE_ASSIGNED_TO_AIS_CATCHER}"
else
    ais_catcher_device_argument="-d ${RECEIVER_DEVICE_ASSIGNED_TO_AIS_CATCHER}"
fi

log_heading "Installing packages needed to build AIS-catcher"
check_package build-essential
check_package cmake
check_package git
check_package pkg-config
check_package librtlsdr-dev
check_package libusb-1.0-0-dev
check_package libsqlite3-dev
check_package libssl-dev

log_heading "Blacklist unwanted RTL-SDR kernel modules"
blacklist_modules

log_heading "Preparing the AIS-catcher source repository"
if [[ -d "${RECEIVER_BUILD_DIRECTORY}/AIS-catcher/.git" ]]; then
    cd "${RECEIVER_BUILD_DIRECTORY}/AIS-catcher" || exit 1
    git fetch origin "${ais_catcher_current_version}"
    git checkout --detach FETCH_HEAD
elif [[ -e "${RECEIVER_BUILD_DIRECTORY}/AIS-catcher" ]]; then
    log_alert_message "${RECEIVER_BUILD_DIRECTORY}/AIS-catcher exists but is not a Git repository"
    exit 1
else
    cd "${RECEIVER_BUILD_DIRECTORY}" || exit 1
    git clone --branch "${ais_catcher_current_version}" --depth 1 \
              "${ais_catcher_repository_url}" AIS-catcher
    cd "${RECEIVER_BUILD_DIRECTORY}/AIS-catcher" || exit 1
fi

log_heading "Building and installing AIS-catcher ${ais_catcher_current_version}"
rm -rf build
cmake -S . -B build -DWEBVIEWER=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
sudo cmake --install build

log_heading "Creating the AIS-catcher configuration"
ais_catcher_ingest_dependency=""
if [[ -f "${RECEIVER_ROOT_DIRECTORY}/build/portal/backend/backend/ais_ingest.py" ]]; then
    install_ais_ingest_service
    ais_catcher_unit_requires="Requires=ais-ingest.service"
    ais_catcher_unit_after="After=network.target ais-ingest.service"
else
    log_warning_message "AIS ingest source is not available; creating the decoder service without an ingest dependency"
    ais_catcher_unit_requires=""
    ais_catcher_unit_after="After=network.target"
fi

if ! getent group adsb-receiver >/dev/null; then
    sudo groupadd --system adsb-receiver
fi
if ! getent passwd adsb-receiver >/dev/null; then
    sudo useradd --system --gid adsb-receiver --home-dir /var/lib/adsb-receiver \
                 --shell /usr/sbin/nologin adsb-receiver
fi

sudo tee /etc/default/ais-catcher > /dev/null <<EOF
AIS_CATCHER_DEVICE="${RECEIVER_DEVICE_ASSIGNED_TO_AIS_CATCHER}"
AIS_CATCHER_OUTPUT_HOST="127.0.0.1"
AIS_CATCHER_OUTPUT_PORT="5556"
EOF

sudo tee /etc/systemd/system/ais-catcher.service > /dev/null <<EOF
[Unit]
Description=AIS-catcher dual-channel AIS decoder
${ais_catcher_unit_requires}
${ais_catcher_unit_after}

[Service]
Type=simple
User=adsb-receiver
Group=adsb-receiver
EnvironmentFile=/etc/default/ais-catcher
ExecStart=/usr/local/bin/AIS-catcher ${ais_catcher_device_argument} -c AB -M TD -q -u \${AIS_CATCHER_OUTPUT_HOST} \${AIS_CATCHER_OUTPUT_PORT} JSON_FULL
WorkingDirectory=/usr/local/bin
StandardOutput=journal
StandardError=journal
Restart=on-failure
RestartSec=10
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict

[Install]
WantedBy=multi-user.target
EOF

if ! validate_decoder_device_assignments; then
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "AIS-catcher was not started because RTL-SDR assignments are invalid or duplicated"
    exit 1
fi

sudo systemctl daemon-reload
sudo systemctl enable --now ais-catcher.service
if ! assign_devices_to_decoders; then
    exit 1
fi

whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "AIS-catcher Decoder Setup Complete" \
         --msgbox "AIS-catcher ${ais_catcher_current_version} was installed and configured to send JSON_FULL messages to 127.0.0.1:5556. Community sharing and the built-in web viewer are disabled." \
         12 78

cd "${RECEIVER_ROOT_DIRECTORY}" || exit 1
log_title_heading "AIS-catcher decoder setup is complete"
read -r -p "Press enter to continue..." discard

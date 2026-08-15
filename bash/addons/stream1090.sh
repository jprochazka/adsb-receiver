#!/bin/bash

## PRE INSTALLATION OPERATIONS

source "${RECEIVER_BASH_DIRECTORY}/variables.sh"
source "${RECEIVER_BASH_DIRECTORY}/functions.sh"

readonly stream1090_repository="https://github.com/mgrone/stream1090.git"
readonly stream1090_commit="329280ef889d04f9be6e81b1628e07b3fc507159"
readonly stream1090_build_directory="${RECEIVER_BUILD_DIRECTORY}/stream1090"
readonly stream1090_source_directory="${stream1090_build_directory}/source"
readonly stream1090_config_directory="/etc/stream1090"
readonly stream1090_service_file="/etc/systemd/system/stream1090.service"
readonly stream1090_backup_directory="/var/backups/adsb-receiver/stream1090"
readonly stream1090_input_port="30001"

if [[ "$1" == "--disable" ]]; then
    stream1090_decoder="${RECEIVER_STREAM1090_DECODER:-}"
    if [[ "${stream1090_decoder}" != "readsb" && "${stream1090_decoder}" != "dump1090-fa" ]]; then
        if [[ -f "${stream1090_backup_directory}/readsb" ]]; then
            stream1090_decoder="readsb"
        elif [[ -f "${stream1090_backup_directory}/dump1090-fa" ]]; then
            stream1090_decoder="dump1090-fa"
        fi
    fi
    if [[ "${stream1090_decoder}" != "readsb" && "${stream1090_decoder}" != "dump1090-fa" ]]; then
        echo "Unable to determine the decoder to restore"
        exit 1
    fi
    sudo systemctl disable --now stream1090 2>/dev/null || true
    if [[ "${stream1090_decoder}" == "readsb" ]]; then
        sudo cp "${stream1090_backup_directory}/readsb" /etc/default/readsb
    else
        sudo cp "${stream1090_backup_directory}/dump1090-fa" /etc/default/dump1090-fa
    fi
    sudo systemctl daemon-reload
    sudo systemctl restart "${stream1090_decoder}"
    exit 0
fi

clear
log_project_title
log_title_heading "Setting up stream1090"
log_title_message "------------------------------------------------------------------------------"

if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "stream1090 Setup" \
              --yesno "stream1090 is a Mode-S demodulator, not an aircraft decoder. It requires readsb or dump1090-fa and will take exclusive ownership of the selected SDR device.\n\nWould you like to begin setup?" \
              12 78; then
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "stream1090 setup was halted at the request of the user"
    exit 1
fi

## GATHER REQUIRED INFORMATION

stream1090_decoder="${RECEIVER_STREAM1090_DECODER:-}"
if [[ "${stream1090_decoder}" != "readsb" && "${stream1090_decoder}" != "dump1090-fa" ]]; then
    if [[ $(dpkg-query -W -f='${STATUS}' readsb 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
        stream1090_decoder="readsb"
    elif [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
        stream1090_decoder="dump1090-fa"
    fi
fi

if [[ "${stream1090_decoder}" != "readsb" && "${stream1090_decoder}" != "dump1090-fa" ]]; then
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "stream1090 requires an installed readsb or dump1090-fa decoder"
    exit 1
fi

stream1090_device_type=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                  --title "stream1090 SDR Type" \
                                  --menu "Select the SDR device type used by stream1090." \
                                  12 78 2 \
                                  "RTL-SDR" "RTL-SDR dongle" \
                                  "Airspy" "Airspy receiver" \
                                  3>&2 2>&1 1>&3)
if [[ $? -ne 0 ]]; then
    exit 1
fi

stream1090_sample_rate="2.4"
stream1090_config_name="rtlsdr.ini"
stream1090_dependency="librtlsdr-dev"
if [[ "${stream1090_device_type}" == "Airspy" ]]; then
    stream1090_sample_rate="6"
    stream1090_config_name="airspy.ini"
    stream1090_dependency="libairspy-dev"
fi

stream1090_sample_rate=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                  --title "stream1090 Sample Rate" \
                                  --inputbox "Enter the input sample rate in MHz.\n\nRTL-SDR supports 2.4 or 2.56. Airspy supports 6 or 10." \
                                  10 78 "${stream1090_sample_rate}" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 || -z "${stream1090_sample_rate}" ]]; then
    exit 1
fi

stream1090_serial=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                              --title "stream1090 SDR Serial" \
                              --inputbox "Enter the optional SDR serial number. Leave blank to use the first available device." \
                              8 78 "" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then
    exit 1
fi

stream1090_upsample_rate=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                    --title "stream1090 Upsample Rate" \
                                    --inputbox "Enter an optional supported upsample rate, or leave blank." \
                                    8 78 "" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then
    exit 1
fi

case "${stream1090_device_type}:${stream1090_sample_rate}:${stream1090_upsample_rate}" in
    "RTL-SDR:2.4:"|"RTL-SDR:2.4:8"|"RTL-SDR:2.4:12"|"RTL-SDR:2.56:"|"RTL-SDR:2.56:8"|"RTL-SDR:2.56:12"|"Airspy:6:"|"Airspy:6:6"|"Airspy:6:12"|"Airspy:6:24"|"Airspy:10:"|"Airspy:10:10"|"Airspy:10:24")
        ;;
    *)
        whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                 --title "Unsupported stream1090 Rate" \
                 --msgbox "The selected input and upsample rates are not supported by stream1090." \
                 8 78
        exit 1
        ;;
esac

if [[ -n "${stream1090_serial}" && ! "${stream1090_serial}" =~ ^[[:alnum:]xX]+$ ]]; then
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
             --title "Invalid stream1090 Serial" \
             --msgbox "The SDR serial may contain only letters, numbers, and an optional hexadecimal x prefix." \
             8 78
    exit 1
fi

stream1090_filter=""
if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
            --title "stream1090 IQ Filter" \
            --defaultno \
            --yesno "Enable stream1090's built-in IQ low-pass filter?" \
            8 78; then
    stream1090_filter="-q"
fi

## CHECK FOR PREREQUISITE PACKAGES

log_heading "Installing packages needed to build stream1090"
check_package build-essential
check_package cmake
check_package git
check_package pkg-config
check_package socat
check_package "${stream1090_dependency}"

if [[ "${stream1090_device_type}" == "RTL-SDR" ]]; then
    blacklist_modules
fi

## CLONE AND BUILD THE OFFICIAL UPSTREAM SOURCE

log_heading "Preparing the official stream1090 Git repository"
mkdir -p "${stream1090_build_directory}"
if [[ -d "${stream1090_source_directory}/.git" ]]; then
    cd "${stream1090_source_directory}" || exit 1
    git remote set-url origin "${stream1090_repository}"
    git fetch origin main 2>&1 | log_pipe
else
    rm -rf "${stream1090_source_directory}"
    git clone "${stream1090_repository}" "${stream1090_source_directory}" 2>&1 | log_pipe
    cd "${stream1090_source_directory}" || exit 1
fi

git checkout --detach "${stream1090_commit}" 2>&1 | log_pipe

if [[ -d build ]]; then
    rm -rf build
fi
mkdir build
cd build || exit 1
cmake .. -DCMAKE_BUILD_TYPE=Release 2>&1 | log_pipe
cmake --build . --parallel 2>&1 | log_pipe

if [[ ! -x ./stream1090 ]]; then
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "The official stream1090 source build did not produce an executable"
    exit 1
fi

log_message "Verifying stream1090 native device support"
./stream1090 -h 2>&1 | log_pipe

## INSTALL RUNTIME FILES

log_heading "Installing stream1090 runtime files"
sudo install -Dm755 ./stream1090 /usr/local/bin/stream1090
sudo install -d "${stream1090_config_directory}"
if [[ ! -f "${stream1090_config_directory}/${stream1090_config_name}" ]]; then
    sudo install -m644 "${stream1090_source_directory}/configs/${stream1090_config_name}" "${stream1090_config_directory}/${stream1090_config_name}"
else
    log_message "Preserving the existing ${stream1090_config_name} device configuration"
fi

if [[ -n "${stream1090_serial}" ]]; then
    sudo sed -i -E "s|^#?[[:space:]]*serial[[:space:]]*=.*$|serial = ${stream1090_serial}|" "${stream1090_config_directory}/${stream1090_config_name}"
fi

if [[ -f "${stream1090_config_directory}/stream1090.conf" ]]; then
    source "${stream1090_config_directory}/stream1090.conf"
fi

sudo tee "${stream1090_config_directory}/stream1090.conf" > /dev/null <<EOF
STREAM1090_OPTS="-s ${stream1090_sample_rate} -d ${stream1090_config_directory}/${stream1090_config_name}${stream1090_upsample_rate:+ -u ${stream1090_upsample_rate}}${stream1090_filter:+ ${stream1090_filter}}"
READSB_PORT=${stream1090_input_port}
EOF

## CONFIGURE THE DOWNSTREAM DECODER

log_heading "Configuring ${stream1090_decoder} for stream1090 input"
sudo install -d "${stream1090_backup_directory}"
if [[ "${stream1090_decoder}" == "readsb" ]]; then
    if [[ ! -f "${stream1090_backup_directory}/readsb" ]]; then
        sudo cp /etc/default/readsb "${stream1090_backup_directory}/readsb"
    fi
    change_config "RECEIVER_OPTIONS" "" "/etc/default/readsb"
    if ! grep -q -- "--net-ri-port ${stream1090_input_port}" /etc/default/readsb; then
        if grep -q '^NET_OPTIONS=' /etc/default/readsb; then
            sudo sed -i "s|^NET_OPTIONS=\"\(.*\)\"$|NET_OPTIONS=\"\1 --net-ri-port ${stream1090_input_port}\"|" /etc/default/readsb
        else
            echo "NET_OPTIONS=\"--net-ri-port ${stream1090_input_port}\"" | sudo tee -a /etc/default/readsb > /dev/null
        fi
    fi
else
    if [[ ! -f "${stream1090_backup_directory}/dump1090-fa" ]]; then
        sudo cp /etc/default/dump1090-fa "${stream1090_backup_directory}/dump1090-fa"
    fi
    change_config "RECEIVER" "none" "/etc/default/dump1090-fa"
    change_config "NET_RAW_INPUT_PORTS" "${stream1090_input_port}" "/etc/default/dump1090-fa"
fi

## CREATE SERVICE

log_heading "Creating the stream1090 systemd service"
sudo tee "${stream1090_service_file}" > /dev/null <<EOF
[Unit]
Description=stream1090 Mode-S demodulator
After=network.target ${stream1090_decoder}.service
Wants=${stream1090_decoder}.service

[Service]
Type=simple
EnvironmentFile=${stream1090_config_directory}/stream1090.conf
ExecStart=/bin/bash -c '/usr/local/bin/stream1090 \${STREAM1090_OPTS} | /usr/bin/socat -u - TCP4:127.0.0.1:\${READSB_PORT}'
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl restart "${stream1090_decoder}"
sudo systemctl enable --now stream1090

if ! systemctl is-active --quiet stream1090; then
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "The stream1090 service failed to start"
    sudo systemctl status stream1090 --no-pager
    exit 1
fi

## SETUP COMPLETE

cd "${RECEIVER_ROOT_DIRECTORY}" || exit 1
echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "stream1090 setup is complete"
log_message "The stream1090 service owns the SDR and forwards raw frames to ${stream1090_decoder} on TCP port ${stream1090_input_port}"
echo ""
read -p "Press enter to continue..." discard

exit 0

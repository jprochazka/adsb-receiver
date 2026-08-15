#!/bin/bash

## PRE INSTALLATION OPERATIONS

source "${RECEIVER_BASH_DIRECTORY}/variables.sh"
source "${RECEIVER_BASH_DIRECTORY}/functions.sh"

readonly stream1090_repository="https://github.com/mgrone/stream1090.git"
readonly stream1090_build_directory="${RECEIVER_BUILD_DIRECTORY}/stream1090"
readonly stream1090_source_directory="${stream1090_build_directory}/source"
readonly stream1090_config_directory="/etc/stream1090"
readonly stream1090_backup_directory="/var/backups/adsb-receiver/stream1090"
readonly stream1090_input_port="30001"

function set_stream1090_ini_value() {
    local setting="$1"
    local value="$2"
    local config_file="${stream1090_config_directory}/${stream1090_config_name}"

    if grep -q -E "^[#[:space:]]*${setting}[[:space:]]*=" "${config_file}"; then
        sudo sed -i -E "s|^[#[:space:]]*${setting}[[:space:]]*=.*$|${setting} = ${value}|" "${config_file}"
    else
        echo "${setting} = ${value}" | sudo tee -a "${config_file}" > /dev/null
    fi
}

function disable_stream1090_ini_value() {
    local setting="$1"
    local config_file="${stream1090_config_directory}/${stream1090_config_name}"

    sudo sed -i -E "s|^[[:space:]]*(${setting}[[:space:]]*=.*)$|# \1|" "${config_file}"
}

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
if [[ "${stream1090_device_type}" == "Airspy" ]]; then
    stream1090_sample_rate="6"
    stream1090_config_name="airspy.ini"
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

stream1090_frequency=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                 --title "stream1090 Center Frequency" \
                                 --inputbox "Enter the center frequency in Hz." \
                                 8 78 "1090000000" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 || ! "${stream1090_frequency}" =~ ^[0-9]+$ ]]; then
    exit 1
fi

stream1090_bias_tee="false"
if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
            --title "stream1090 Bias Tee" \
            --defaultno \
            --yesno "Enable the SDR's 5V bias tee to power an attached LNA?" \
            8 78; then
    stream1090_bias_tee="true"
fi

stream1090_gain_mode=""
stream1090_gain=""
stream1090_lna_gain=""
stream1090_mixer_gain=""
stream1090_vga_gain=""
stream1090_ppm=""
stream1090_tuner_bandwidth=""
stream1090_packing=""
if [[ "${stream1090_device_type}" == "RTL-SDR" ]]; then
    stream1090_gain_mode=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                      --title "stream1090 RTL-SDR Gain" \
                                      --menu "Select the RTL-SDR gain mode." \
                                      12 78 2 \
                                      "Automatic" "Enable tuner AGC" \
                                      "Manual" "Set gain in dB" \
                                      3>&2 2>&1 1>&3)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    if [[ "${stream1090_gain_mode}" == "Manual" ]]; then
        stream1090_gain=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                    --title "stream1090 RTL-SDR Gain" \
                                    --inputbox "Enter tuner gain in dB (for example, 40 or 48.0)." \
                                    8 78 "40" 3>&1 1>&2 2>&3)
        if [[ $? -ne 0 || ! "${stream1090_gain}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            exit 1
        fi
    fi

    stream1090_ppm=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                               --title "stream1090 Frequency Correction" \
                               --inputbox "Enter optional frequency correction in PPM, or leave blank." \
                               8 78 "" 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 || ( -n "${stream1090_ppm}" && ! "${stream1090_ppm}" =~ ^-?[0-9]+$ ) ]]; then
        exit 1
    fi

    stream1090_tuner_bandwidth=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                           --title "stream1090 Tuner Bandwidth" \
                                           --inputbox "Enter tuner bandwidth in Hz, or leave blank for the packaged default." \
                                           8 78 "3000000" 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 || ( -n "${stream1090_tuner_bandwidth}" && ! "${stream1090_tuner_bandwidth}" =~ ^[0-9]+$ ) ]]; then
        exit 1
    fi
else
    stream1090_gain_mode=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                      --title "stream1090 Airspy Gain" \
                                      --menu "Select the Airspy gain control mode." \
                                      14 78 3 \
                                      "Linearity" "Combined linearity gain (0-21)" \
                                      "Sensitivity" "Combined sensitivity gain (0-21)" \
                                      "Manual" "Set LNA, mixer, and VGA gains" \
                                      3>&2 2>&1 1>&3)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    if [[ "${stream1090_gain_mode}" == "Manual" ]]; then
        stream1090_lna_gain=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Airspy LNA Gain" --inputbox "Enter LNA gain (0-14)." 8 78 "10" 3>&1 1>&2 2>&3)
        stream1090_mixer_gain=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Airspy Mixer Gain" --inputbox "Enter mixer gain (0-15)." 8 78 "7" 3>&1 1>&2 2>&3)
        stream1090_vga_gain=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Airspy VGA Gain" --inputbox "Enter VGA gain (0-15)." 8 78 "11" 3>&1 1>&2 2>&3)
        if [[ ! "${stream1090_lna_gain}" =~ ^([0-9]|1[0-4])$ || ! "${stream1090_mixer_gain}" =~ ^([0-9]|1[0-5])$ || ! "${stream1090_vga_gain}" =~ ^([0-9]|1[0-5])$ ]]; then
            exit 1
        fi
    else
        stream1090_default_gain="16"
        if [[ "${stream1090_gain_mode}" == "Sensitivity" ]]; then
            stream1090_default_gain="5"
        fi
        stream1090_gain=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                    --title "stream1090 Airspy Gain" \
                                    --inputbox "Enter ${stream1090_gain_mode,,} gain (0-21)." \
                                    8 78 "${stream1090_default_gain}" 3>&1 1>&2 2>&3)
        if [[ $? -ne 0 || ! "${stream1090_gain}" =~ ^([0-9]|1[0-9]|2[01])$ ]]; then
            exit 1
        fi
    fi

    stream1090_packing="false"
    if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                --title "stream1090 Airspy Packing" \
                --yesno "Use packed 12-bit Airspy samples to reduce USB bandwidth?" \
                8 78; then
        stream1090_packing="true"
    fi
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

stream1090_verbose=""
if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
            --title "stream1090 Verbose Logging" \
            --defaultno \
            --yesno "Enable verbose stream1090 journal logging for troubleshooting?" \
            8 78; then
    stream1090_verbose="-v"
fi

## CHECK FOR PREREQUISITE PACKAGES

log_heading "Installing packages needed to build stream1090"
check_package devscripts
check_package debhelper
check_package cmake
check_package pkg-config
check_package g++
check_package git
check_package socat
check_package libairspy-dev
check_package librtlsdr-dev

if [[ "${stream1090_device_type}" == "RTL-SDR" ]]; then
    blacklist_modules
fi

## CLONE AND BUILD THE OFFICIAL UPSTREAM PACKAGE

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

git checkout --force --detach origin/main 2>&1 | log_pipe

log_heading "Building the stream1090 Debian package"
rm -f "${stream1090_build_directory}"/stream1090_*.deb
dpkg-buildpackage -us -uc -b 2>&1 | log_pipe

stream1090_package=$(find "${stream1090_build_directory}" -maxdepth 1 -type f -name 'stream1090_*.deb' -print -quit)
if [[ -z "${stream1090_package}" ]]; then
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "The official stream1090 build did not produce a Debian package"
    exit 1
fi

log_heading "Installing the stream1090 Debian package"
sudo rm -f /etc/systemd/system/stream1090.service
sudo rm -f /usr/local/bin/stream1090
sudo dpkg -i "${stream1090_package}" 2>&1 | log_pipe

if [[ $(dpkg-query -W -f='${STATUS}' stream1090 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "The stream1090 Debian package failed to install"
    exit 1
fi

sudo systemctl stop stream1090 2>/dev/null || true

log_message "Verifying stream1090 native device support"
/usr/bin/stream1090 -h 2>&1 | log_pipe

mkdir -p "${RECEIVER_BUILD_DIRECTORY}/package-archive"
cp -vf "${stream1090_package}" "${RECEIVER_BUILD_DIRECTORY}/package-archive/" 2>&1 | log_pipe

## CONFIGURE PACKAGE RUNTIME FILES

set_stream1090_ini_value "frequency" "${stream1090_frequency}"
set_stream1090_ini_value "bias_tee" "${stream1090_bias_tee}"
if [[ -n "${stream1090_serial}" ]]; then
    set_stream1090_ini_value "serial" "${stream1090_serial}"
else
    disable_stream1090_ini_value "serial"
fi
if [[ "${stream1090_device_type}" == "RTL-SDR" ]]; then
    if [[ "${stream1090_gain_mode}" == "Automatic" ]]; then
        set_stream1090_ini_value "agc" "true"
    else
        set_stream1090_ini_value "agc" "false"
        set_stream1090_ini_value "gain" "${stream1090_gain}"
    fi
    if [[ -n "${stream1090_ppm}" ]]; then
        set_stream1090_ini_value "ppm" "${stream1090_ppm}"
    else
        disable_stream1090_ini_value "ppm"
    fi
    if [[ -n "${stream1090_tuner_bandwidth}" ]]; then
        set_stream1090_ini_value "tuner_bandwidth" "${stream1090_tuner_bandwidth}"
    else
        disable_stream1090_ini_value "tuner_bandwidth"
    fi
else
    if [[ "${stream1090_gain_mode}" == "Manual" ]]; then
        disable_stream1090_ini_value "linearity_gain"
        disable_stream1090_ini_value "sensitivity_gain"
        set_stream1090_ini_value "lna_gain" "${stream1090_lna_gain}"
        set_stream1090_ini_value "mixer_gain" "${stream1090_mixer_gain}"
        set_stream1090_ini_value "vga_gain" "${stream1090_vga_gain}"
    else
        disable_stream1090_ini_value "lna_gain"
        disable_stream1090_ini_value "mixer_gain"
        disable_stream1090_ini_value "vga_gain"
        if [[ "${stream1090_gain_mode}" == "Linearity" ]]; then
            disable_stream1090_ini_value "sensitivity_gain"
        else
            disable_stream1090_ini_value "linearity_gain"
        fi
        set_stream1090_ini_value "${stream1090_gain_mode,,}_gain" "${stream1090_gain}"
    fi
    set_stream1090_ini_value "packing" "${stream1090_packing}"
fi

sudo tee "${stream1090_config_directory}/stream1090.conf" > /dev/null <<EOF
STREAM1090_OPTS="-s ${stream1090_sample_rate} -d ${stream1090_config_directory}/${stream1090_config_name}${stream1090_upsample_rate:+ -u ${stream1090_upsample_rate}}${stream1090_filter:+ ${stream1090_filter}}${stream1090_verbose:+ ${stream1090_verbose}}"
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

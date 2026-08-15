#!/bin/bash

## LOGGING FUNCTIONS

# Log a <message> to the log file
function log_to_file() {
    local time_stamp=''
    if [[ "${RECEIVER_LOGGING_ENABLED}" == "true" ]]; then
        if [[ -z "$2" || "${2}" == "true" ]]; then
            printf -v time_stamp '[%(%Y-%m-%d %H:%M:%S)T]' -1
        fi

        if [[ -n "$3" && "${3}" == "inline" ]]; then
            printf "%s %s" "${time_stamp}" "${1}" >> "${RECEIVER_LOG_FILE}"
        else
            printf "%s %s\n" "${time_stamp}" "${1}" >> "${RECEIVER_LOG_FILE}"
        fi
    fi
}

# Logs the "PROJECT TITLE" to the console
function log_project_title() {
    log_to_file "${RECEIVER_PROJECT_TITLE}"
    echo -e "${display_project_name}  ${RECEIVER_PROJECT_TITLE}${display_default}"
    echo ""
}

# Logs a "HEADING" to the console
function log_heading() {
    log_to_file "${1}"
    echo ""
    echo -e "${display_heading}  ${1}${display_default}"
    echo ""
}

# Logs a "MESSAGE" to the console
function log_message() {
    log_to_file "${1}"
    echo -e "${display_message}  ${1}${display_default}"
}

# Logs an alert "HEADING" to the console
function log_alert_heading() {
    log_to_file "${1}"
    echo -e "${display_alert_heading}  ${1}${display_default}"
}

# Logs an alert "MESSAGE" to the console
function log_alert_message() {
    log_to_file "${1}"
    echo -e "${display_alert_message}  ${1}${display_default}"
}

# Logs a title "HEADING" to the console
function log_title_heading() {
    log_to_file "${1}"
    echo -e "${display_title_heading}  ${1}${display_default}"
}

# Logs a title "MESSAGE" to the console
function log_title_message() {
    log_to_file "${1}"
    echo -e "${display_title_message}  ${1}${display_default}"
}

# Logs a warning "HEADING" to the console
function log_warning_heading() {
    log_to_file "${1}"
    echo -e "${display_warning_heading}  ${1}${display_default}"
}

# Logs a warning "MESSAGE" to the console
function log_warning_message() {
    log_to_file "${1}"
    echo -e "${display_warning_message}  ${1}${display_default}"
}

# Logs an inline "MESSAGE" to the console
function log_message_inline() {
    log_to_file "${1}" "true" "inline"
    printf "%s  %s%s" "${display_message}" "${1}" "${display_default}"
}

# Logs an inline failure indicator to the console
function log_false_inline() {
    log_to_file "${1}" "false"
    echo -e "${display_false_inline} ${1}${display_default}"
}

# Logs an inline success indicator to the console
function log_true_inline() {
    log_to_file "${1}" "false"
    echo -e "${display_true_inline} ${1}${display_default}"
}

# Pipe command output to the console and optionally append to the log file
function log_pipe() {
    if [[ "${RECEIVER_LOGGING_ENABLED}" == "true" ]]; then
        tee -a "${RECEIVER_LOG_FILE}"
    else
        cat
    fi
}


## CHECK IF THE SUPPLIED PACKAGE IS INSTALLED AND IF NOT ATTEMPT TO INSTALL IT

function check_package() {
    local attempt=1
    local max_attempts=5
    local wait_time=5

    while (( attempt <= max_attempts + 1 )); do
        if [[ $attempt -gt $max_attempts ]]; then
            log_alert_heading "INSTALLATION HALTED"
            log_alert_message "Unable to install a required package"
            log_alert_message "The package ${1} could not be installed in ${max_attempts} attempts"
            exit 1
        fi

        log_message_inline "Checking if the package ${1} is installed"
        if [[ $(dpkg-query -W -f='${STATUS}' "${1}" 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
            if [[ $attempt -gt 1 ]]; then
                log_alert_message "Installation attempt failed"
                log_alert_message "Will attempt to install the package ${1} again in ${wait_time} seconds (attempt ${attempt} of ${max_attempts})"
                sleep "${wait_time}"
            else
                log_false_inline "[NOT INSTALLED]"
                log_message "Installing the package ${1}"
            fi
            echo ""
            (( attempt++ ))
            sudo apt-get install -y "${1}" 2>&1 | log_pipe
            echo ""
        else
            log_true_inline "[OK]"
            break
        fi
    done
}


## ALLOW LIGHTTPD TO COEXIST WITH NGINX

function configure_lighttpd_for_portal_coexistence() {
    local override_conf="/etc/lighttpd/conf-available/99-adsb-receiver-port.conf"
    local enabled_conf="/etc/lighttpd/conf-enabled/99-adsb-receiver-port.conf"

    if [[ $(dpkg-query -W -f='${STATUS}' lighttpd 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
        return 0
    fi

    if [[ $(dpkg-query -W -f='${STATUS}' nginx 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
        return 0
    fi

    log_message "Configuring lighttpd to coexist with Nginx"

    sudo install -d -m 0755 /etc/lighttpd/conf-available /etc/lighttpd/conf-enabled
    sudo tee "${override_conf}" > /dev/null <<'EOF'
server.port = 8081
EOF

    if [[ ! -e "${enabled_conf}" ]]; then
        sudo ln -s ../conf-available/99-adsb-receiver-port.conf "${enabled_conf}"
    fi

    if command -v lighttpd >/dev/null 2>&1 && [[ -f /etc/lighttpd/lighttpd.conf ]]; then
        if ! sudo /usr/sbin/lighttpd -tt -f /etc/lighttpd/lighttpd.conf >/dev/null 2>&1; then
            log_warning_message "lighttpd configuration test failed after applying the Nginx coexistence override"
            return 1
        fi
    fi

    if systemctl is-active --quiet lighttpd 2>/dev/null; then
        log_message "Restarting lighttpd so SkyAware remains available on port 8080"
        sudo systemctl restart lighttpd 2>&1 | log_pipe
    elif systemctl is-enabled --quiet lighttpd 2>/dev/null; then
        log_message "Starting lighttpd so SkyAware remains available on port 8080"
        sudo systemctl start lighttpd 2>&1 | log_pipe
    fi

    return 0
}


## BLACKLIST DVB-T DRIVERS FOR RTL-SDR DEVICES

function blacklist_modules() {
    if [[ ! -f /etc/modprobe.d/rtlsdr-blacklist.conf || $(wc -l < /etc/modprobe.d/rtlsdr-blacklist.conf) -lt 9 ]]; then
        log_message "Blacklisting unwanted RTL-SDR kernel modules so they are not loaded"
        sudo tee /etc/modprobe.d/rtlsdr-blacklist.conf  > /dev/null <<EOF
blacklist dvb_usb_v2
blacklist dvb_usb_rtl28xxu
blacklist dvb_usb_rtl2830u
blacklist dvb_usb_rtl2832u
blacklist rtl_2830
blacklist rtl_2832
blacklist r820t
blacklist rtl2830
blacklist rtl2832
EOF
    else
        log_message "Kernel module blacklisting complete"
    fi
}

function install_acars_ingest_service() {
    local ingest_source="${RECEIVER_ROOT_DIRECTORY}/build/portal/backend/backend/acars_ingest.py"
    local ingest_directory="/usr/local/lib/adsb-receiver"
    local data_directory="/var/lib/adsb-receiver"
    local database_path="${data_directory}/acars.sqlite3"
    local legacy_database=""
    local candidate
    local legacy_candidates=(
        "${RECEIVER_ROOT_DIRECTORY}/build/portal/backend/instance/acarsdec.sqlite"
    )

    if [[ ! -f "${ingest_source}" ]]; then
        log_alert_message "ACARS ingestion service source was not found at ${ingest_source}"
        return 1
    fi

    check_package python3

    if ! getent group adsb-receiver >/dev/null; then
        sudo groupadd --system adsb-receiver
    fi
    if ! getent passwd adsb-receiver >/dev/null; then
        log_message "Creating the adsb-receiver service account"
        sudo useradd --system \
                      --gid adsb-receiver \
                      --home-dir "${data_directory}" \
                      --shell /usr/sbin/nologin \
                      adsb-receiver
    else
        sudo usermod --append --groups adsb-receiver adsb-receiver
    fi
    if getent passwd www-data >/dev/null; then
        sudo usermod --append --groups adsb-receiver www-data
    fi

    sudo install -d -m 0755 "${ingest_directory}"
    sudo install -d -o adsb-receiver -g adsb-receiver -m 0775 "${data_directory}"
    sudo install -o root -g root -m 0755 "${ingest_source}" "${ingest_directory}/acars_ingest.py"

    for candidate in "${legacy_candidates[@]}"; do
        if [[ -f "${candidate}" ]]; then
            legacy_database="${candidate}"
            break
        fi
    done
    if [[ ! -f "${database_path}" && -n "${legacy_database}" ]]; then
        log_message "Migrating the legacy local ACARS database"
        sudo install -o adsb-receiver -g adsb-receiver -m 0664 \
                     "${legacy_database}" "${database_path}"
    fi
    if [[ -f "${database_path}" ]]; then
        sudo chown adsb-receiver:adsb-receiver "${database_path}"
        sudo chmod 0664 "${database_path}"
    fi

    log_message "Creating the ACARS ingestion systemd service"
    sudo tee /etc/systemd/system/acars-ingest.service >/dev/null <<EOF
[Unit]
Description=ADS-B Receiver ACARS and VDL2 message ingestion
After=network.target

[Service]
Type=simple
User=adsb-receiver
Group=adsb-receiver
UMask=0002
ExecStart=/usr/bin/python3 ${ingest_directory}/acars_ingest.py --database ${database_path} --bind 127.0.0.1 --port 5555
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=${data_directory}

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now acars-ingest.service
}

function install_dumpvdl2_config_helper() {
    local helper_source="${RECEIVER_ROOT_DIRECTORY}/bash/tools/dumpvdl2_config.sh"
    local helper_target="/usr/local/sbin/adsb-receiver-dumpvdl2-config"
    local sudoers_file="/etc/sudoers.d/adsb-receiver-dumpvdl2"

    if [[ ! -f "${helper_source}" ]]; then
        log_alert_message "dumpvdl2 configuration helper was not found at ${helper_source}"
        return 1
    fi

    sudo install -o root -g root -m 0755 "${helper_source}" "${helper_target}"

    if getent passwd www-data >/dev/null; then
        echo "www-data ALL=(root) NOPASSWD: ${helper_target} *" | \
            sudo tee "${sudoers_file}" >/dev/null
        sudo chmod 0440 "${sudoers_file}"
        if ! sudo visudo -cf "${sudoers_file}" >/dev/null; then
            sudo rm -f "${sudoers_file}"
            log_alert_message "The dumpvdl2 sudoers configuration was invalid"
            return 1
        fi
    fi
}


## CONFIGURATION RELATED FUNCTIONS

# Use sed to locate the "KEY" then replace the "VALUE", the portion after the equals sign, in the specified "FILE"
# This function should work with any configuration file with settings formated as KEY="VALUE"
function change_config() {
    sudo sed -i -e "s/\($1 *= *\).*/\1\"$2\"/" "$3"
}

# Use sed to locate the "KEY" then read the "VALUE", the portion after the equals sign, in the specified "FILE"
# This function should work with any configuration file with settings formated as KEY="VALUE"
function get_config() {
    local setting
    setting=$(sed -n "/^$1 *= *\"\(.*\)\"$/s//\1/p" "$2")
    if [[ "${setting}" == "" ]]; then
        setting=$(sed -n "/^$1 *= *\(.*\)$/s//\1/p" "$2")
    fi
    echo "${setting}"
}


## ASSIGN DEVICES TO DECODERS

function ask_device_number() {
    local decoder_name="$1"
    local var_name="$2"
    local default_value="${3:-}"
    local title="Enter the ${decoder_name} RTL-SDR Device Number"
    local value=""
    log_message "Asking the user to assign a RTL-SDR device number to ${decoder_name}"
    while [[ -z "${value}" ]]; do
        value=$(whiptail --backtitle "Decoder Configuration" \
                         --title "${title}" \
                         --inputbox "\nEnter the RTL-SDR device number to assign to ${decoder_name}." \
                         8 78 \
                         "${default_value}" 3>&1 1>&2 2>&3)
        if [[ $? -ne 0 ]]; then
            exit 1
        fi
        title="Enter the ${decoder_name} RTL-SDR Device Number (REQUIRED)"
    done
    declare -g "${var_name}=${value}"
}

function ask_for_device_assignments() {
    local decoder_being_installed="$1"
    local decoder_count=1
    local acars_decoder_installed="false"
    local adsb_decoder_installed="false"
    local uat_decoder_installed="false"
    local vdlm2_decoder_installed="false"
    local exec_start
    local receiver_options
    local device_assigned_to_acars_decoder=""
    local device_assigned_to_adsb_decoder=""
    local device_assigned_to_uat_decoder=""
    local device_assigned_to_vdlm2_decoder=""

    log_heading "Gather information required to configure the decoder(s)"

    log_message "Checking if an ACARS decoder is installed"
    if [[ -f /usr/local/bin/acarsdec ]]; then
        log_message "The ACARSDEC decoder appears to be installed"
        acars_decoder_installed="true"
        RECEIVER_ACARS_DECODER_SOFTWARE="acarsdec"
    fi
    if [[ "${acars_decoder_installed}" == "true" && "${RECEIVER_ACARS_DECODER_SOFTWARE}" != "${decoder_being_installed}" ]]; then
        (( decoder_count++ ))
    fi

    log_message "Checking if an ADS-B decoder is installed"
    if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
        log_message "The FlightAware dump1090 decoder appears to be installed"
        adsb_decoder_installed="true"
        RECEIVER_ADSB_DECODER_SOFTWARE="dump1090-fa"
    fi
    if [[ $(dpkg-query -W -f='${STATUS}' readsb 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
        log_message "The Readsb decoder appears to be installed"
        adsb_decoder_installed="true"
        RECEIVER_ADSB_DECODER_SOFTWARE="readsb"
    fi
    if [[ "${adsb_decoder_installed}" == "true" && "${RECEIVER_ADSB_DECODER_SOFTWARE}" != "${decoder_being_installed}" ]]; then
        (( decoder_count++ ))
    fi

    log_message "Checking if a UAT decoder is installed"
    if [[ $(dpkg-query -W -f='${STATUS}' dump978-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
        log_message "The FlightAware dump978 decoder appears to be installed"
        uat_decoder_installed="true"
        RECEIVER_UAT_DECODER_SOFTWARE="dump978-fa"
    fi
    if [[ "${uat_decoder_installed}" == "true" && "${RECEIVER_UAT_DECODER_SOFTWARE}" != "${decoder_being_installed}" ]]; then
        (( decoder_count++ ))
    fi

    log_message "Checking if a VDL Mode 2 decoder is installed"
    if [[ -f /usr/local/bin/dumpvdl2 ]]; then
        log_message "The dumpvdl2 decoder appears to be installed"
        vdlm2_decoder_installed="true"
        RECEIVER_VDLM2_DECODER_SOFTWARE="dumpvdl2"
    fi
    if [[ "${vdlm2_decoder_installed}" == "true" && "${RECEIVER_VDLM2_DECODER_SOFTWARE}" != "${decoder_being_installed}" ]]; then
        (( decoder_count++ ))
    fi

    if [[ $decoder_count -gt 1 ]]; then
        log_message "Informing the user that existing decoder(s) appears to be installed"
        whiptail --backtitle "Decoder Configuration" \
                --title "RTL-SDR Dongle Assignments" \
                --msgbox "It appears that existing decoder(s) have been installed on this device. In order to run this decoder in tandem with other decoders you will need to specifiy which RTL-SDR dongle each decoder is to use.\n\nKeep in mind in order to run multiple decoders on a single device you will need to have multiple RTL-SDR devices connected to your device." \
                12 78

        if [[ "${decoder_being_installed}" == "acarsdec" || "${acars_decoder_installed}" == "true" && "${RECEIVER_ACARS_DECODER_SOFTWARE}" == "acarsdec" ]]; then
            if [[ "${acars_decoder_installed}" == "true" ]]; then
                log_message "Determining which device is currently assigned to ACARSDEC"
                exec_start=$(get_config "ExecStart" "/etc/systemd/system/acarsdec.service")
                device_assigned_to_acars_decoder=$(echo "${exec_start}" | grep -o -P '(?<=--rtlsdr )[0-9]+')
            fi
            ask_device_number "ACARSDEC" "RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER" "${device_assigned_to_acars_decoder}"
        fi

        if [[ "${decoder_being_installed}" == "dump1090-fa" || "${adsb_decoder_installed}" == "true" && "${RECEIVER_ADSB_DECODER_SOFTWARE}" == "dump1090-fa" ]]; then
            if [[ "${adsb_decoder_installed}" == "true" ]]; then
                log_message "Determining which device is currently assigned to dump1090-fa"
                device_assigned_to_adsb_decoder=$(get_config "RECEIVER_SERIAL" "/etc/default/dump1090-fa")
            fi
            ask_device_number "dump1090-fa" "RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER" "${device_assigned_to_adsb_decoder}"
        fi

        if [[ "${decoder_being_installed}" == "dump978-fa" || "${uat_decoder_installed}" == "true" && "${RECEIVER_UAT_DECODER_SOFTWARE}" == "dump978-fa" ]]; then
            if [[ "${uat_decoder_installed}" == "true" ]]; then
                log_message "Determining which device is currently assigned to dump978-fa"
                receiver_options=$(get_config "RECEIVER_OPTIONS" "/etc/default/dump978-fa")
                device_assigned_to_uat_decoder=$(echo "${receiver_options}" | grep -o -P '(?<=serial=)[0-9]+')
            fi
            ask_device_number "dump978-fa" "RECEIVER_DEVICE_ASSIGNED_TO_UAT_DECODER" "${device_assigned_to_uat_decoder}"
        fi

        if [[ "${decoder_being_installed}" == "dumpvdl2" || "${vdlm2_decoder_installed}" == "true" && "${RECEIVER_VDLM2_DECODER_SOFTWARE}" == "dumpvdl2" ]]; then
            if [[ "${vdlm2_decoder_installed}" == "true" ]]; then
                log_message "Determining which device is currently assigned to dumpvdl2"
                device_assigned_to_vdlm2_decoder=$(get_config "DUMPVDL2_DEVICE" "/etc/default/dumpvdl2")
            fi
            ask_device_number "dumpvdl2" "RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER" "${device_assigned_to_vdlm2_decoder}"
        fi

        if [[ "${decoder_being_installed}" == "readsb" || "${adsb_decoder_installed}" == "true" && "${RECEIVER_ADSB_DECODER_SOFTWARE}" == "readsb" ]]; then
            if [[ "${adsb_decoder_installed}" == "true" ]]; then
                log_message "Determining which device is currently assigned to Readsb"
                receiver_options=$(get_config "RECEIVER_OPTIONS" "/etc/default/readsb")
                device_assigned_to_adsb_decoder=$(echo "${receiver_options}" | grep -o -P '(?<=--device )[0-9]+')
            fi
            ask_device_number "Readsb" "RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER" "${device_assigned_to_adsb_decoder}"
        fi

    fi
}

function assign_devices_to_decoders() {

    log_heading "Configure decoders if more than one is present"

    if [[ -n "${RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER}" && "${RECEIVER_ACARS_DECODER_SOFTWARE}" == "acarsdec" ]]; then
        log_message "Assigning RTL-SDR device number ${RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER} to ACARSDEC"
        sudo sed -i -e "s|\(.*--rtlsdr \)\([0-9]\+\)\( .*\)|\1${RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER}\3|g" /etc/systemd/system/acarsdec.service
        log_message "Reload systemd units"
        sudo systemctl daemon-reload
        log_message "Restarting ACARSDEC"
        sudo systemctl restart acarsdec
    fi

    if [[ -n "${RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER}" && "${RECEIVER_ADSB_DECODER_SOFTWARE}" == "dump1090-fa" ]]; then
        log_message "Assigning RTL-SDR device number ${RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER} to FlightAware Dump1090"
        change_config "RECEIVER_SERIAL" "${RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER}" "/etc/default/dump1090-fa"
        log_message "Restarting dump1090-fa"
        sudo systemctl restart dump1090-fa
    fi

    if [[ -n "${RECEIVER_DEVICE_ASSIGNED_TO_UAT_DECODER}" && "${RECEIVER_UAT_DECODER_SOFTWARE}" == "dump978-fa" ]]; then
        log_message "Assigning RTL-SDR device number ${RECEIVER_DEVICE_ASSIGNED_TO_UAT_DECODER} to FlightAware Dump978"
        local serial_assigned
        serial_assigned=$(grep -c "driver=rtlsdr,serial=" /etc/default/dump978-fa)
        if [[ $serial_assigned -eq 1 ]]; then
            sudo sed -i -e "s|\(.*driver=rtlsdr,serial=\)\([0-9]\+\)\( .*\)|\1${RECEIVER_DEVICE_ASSIGNED_TO_UAT_DECODER}\3|g" /etc/default/dump978-fa
        else
            sudo sed -i -e "s|driver=rtlsdr|driver=rtlsdr,serial=${RECEIVER_DEVICE_ASSIGNED_TO_UAT_DECODER}|g" /etc/default/dump978-fa
        fi
        log_message "Restarting dump978-fa"
        sudo systemctl restart dump978-fa
    fi

    if [[ -n "${RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER}" && "${RECEIVER_VDLM2_DECODER_SOFTWARE}" == "dumpvdl2" ]]; then
        log_message "Assigning RTL-SDR device number ${RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER} to dumpvdl2"
        change_config "DUMPVDL2_DEVICE" "${RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER}" "/etc/default/dumpvdl2"
        log_message "Restarting dumpvdl2"
        sudo systemctl restart dumpvdl2
    fi

    if [[ -n "${RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER}" && "${RECEIVER_ADSB_DECODER_SOFTWARE}" == "readsb" ]]; then
        log_message "Assigning RTL-SDR device number ${RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER} to Readsb"
        sudo sed -i -e "s|\(.*--device \)\([0-9]\+\)\( .*\)|\1${RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER}\3|g" /etc/default/readsb
        log_message "Restarting Readsb"
        sudo systemctl restart readsb
    fi

}

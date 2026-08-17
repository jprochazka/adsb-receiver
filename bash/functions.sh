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


## USER INTERFACE BACKENDS

function ui_config_value() {
    local variable_name="$1"
    local default_value="${2:-}"

    if [[ -v "${variable_name}" ]]; then
        printf '%s' "${!variable_name}"
    else
        printf '%s' "${default_value}"
    fi
}

function ui_title_key() {
    local title="$1"

    title=$(printf '%s' "${title}" | tr '[:lower:]' '[:upper:]' | tr -cs 'A-Z0-9' '_')
    printf '%s' "${title#_}"
}

function ui_headless_dialog() {
    local dialog_type="$1"
    local title="$2"
    local value_key="RECEIVER_HEADLESS_$(printf '%s' "${dialog_type#--}" | tr '[:lower:]' '[:upper:]')_$(ui_title_key "${title}")"
    local generic_key="RECEIVER_HEADLESS_$(ui_title_key "${title}")"
    local mapped_key=""
    local value

    case "${title}" in
        "ADS-B Decoder Selection") mapped_key="RECEIVER_HEADLESS_ADSB_DECODER" ;;
        "UAT Decoder Selection") mapped_key="RECEIVER_HEADLESS_UAT_DECODER" ;;
        "ACARS Decoder Selection") mapped_key="RECEIVER_HEADLESS_ACARS_DECODER" ;;
        "VLD Mode 2 Decoder Selection") mapped_key="RECEIVER_HEADLESS_VDLM2_DECODER" ;;
        "Client Installation Options") mapped_key="RECEIVER_HEADLESS_FEEDERS" ;;
        "Extras Installation Options") mapped_key="RECEIVER_HEADLESS_EXTRAS" ;;
        *"dump1090-fa RTL-SDR Device Number"*) mapped_key="RECEIVER_HEADLESS_DEVICE_DUMP1090_FA" ;;
        *"dump978-fa RTL-SDR Device Number"*) mapped_key="RECEIVER_HEADLESS_DEVICE_DUMP978_FA" ;;
        *"ACARSDEC RTL-SDR Device Number"*) mapped_key="RECEIVER_HEADLESS_DEVICE_ACARSDEC" ;;
        *"dumpvdl2 RTL-SDR Device Number"*) mapped_key="RECEIVER_HEADLESS_DEVICE_DUMPVDL2" ;;
        *"VDLM2DEC RTL-SDR Device Number"*) mapped_key="RECEIVER_HEADLESS_DEVICE_VDLM2DEC" ;;
        *"Readsb RTL-SDR Device Number"*) mapped_key="RECEIVER_HEADLESS_DEVICE_READSB" ;;
    esac

    case "${dialog_type}" in
        --msgbox)
            return 0
            ;;
        --yesno)
            value=$(ui_config_value "${value_key}" "$(ui_config_value "${generic_key}" "$(ui_config_value RECEIVER_HEADLESS_DEFAULT_YESNO no)")")
            case "${value,,}" in
                yes|true|1) return 0 ;;
                no|false|0) return 1 ;;
                *)
                    log_alert_message "Invalid headless answer for ${title}: '${value}'. Use yes or no."
                    return 1
                    ;;
            esac
            ;;
        --menu|--inputbox|--passwordbox)
            value=$(ui_config_value "${value_key}" "$(ui_config_value "${mapped_key}" "$(ui_config_value "${generic_key}")")")
            if [[ -z "${value}" ]]; then
                log_alert_message "Missing headless configuration value ${value_key} for '${title}'"
                return 1
            fi
            printf '%s\n' "${value}" >&2
            ;;
        --checklist)
            value=$(ui_config_value "${value_key}" "$(ui_config_value "${mapped_key}" "$(ui_config_value "${generic_key}")")")
            if [[ -n "${value}" ]]; then
                tr ',' '\n' <<< "${value}" >&2
            fi
            ;;
        *)
            log_alert_message "Unsupported headless dialog type: ${dialog_type}"
            return 1
            ;;
    esac
}

function ui_text_dialog() {
    local dialog_type="$1"
    local title="$2"
    local message="$3"
    local answer=""

    case "${dialog_type}" in
        --msgbox)
            printf '\n%s\n%s\n' "${title}" "${message}" >&2
            return 0
            ;;
        --yesno)
            printf '\n%s\n%s\n[y/N]: ' "${title}" "${message}" >&2
            read -r answer
            [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]
            return
            ;;
        --menu|--checklist|--inputbox|--passwordbox)
            printf '\n%s\n%s\nAnswer: ' "${title}" "${message}" >&2
            read -r answer
            [[ -n "${answer}" ]] || return 1
            if [[ "${dialog_type}" == "--checklist" ]]; then
                tr ',' '\n' <<< "${answer}" >&2
            else
                printf '%s\n' "${answer}" >&2
            fi
            ;;
    esac
}

function ui_dialog() {
    local dialog_type=""
    local title=""
    local message=""
    local argument
    local previous=""

    for argument in "$@"; do
        if [[ "${previous}" == "--title" ]]; then
            title="${argument}"
        elif [[ "${previous}" == "--yesno" || "${previous}" == "--menu" || "${previous}" == "--checklist" || "${previous}" == "--inputbox" || "${previous}" == "--passwordbox" || "${previous}" == "--msgbox" ]]; then
            message="${argument}"
        fi

        case "${argument}" in
            --yesno|--menu|--checklist|--inputbox|--passwordbox|--msgbox)
                dialog_type="${argument}"
                ;;
        esac
        previous="${argument}"
    done

    case "${RECEIVER_UI_MODE:-whiptail}" in
        whiptail)
            command whiptail "$@"
            ;;
        headless)
            ui_headless_dialog "${dialog_type}" "${title}"
            ;;
        text)
            ui_text_dialog "${dialog_type}" "${title}" "${message}"
            ;;
        *)
            log_alert_message "Unknown user interface mode: ${RECEIVER_UI_MODE}"
            return 1
            ;;
    esac
}

# Existing installer scripts retain their whiptail-compatible arguments while all
# backend selection is owned by ui_dialog.
function whiptail() {
    ui_dialog "$@"
}

function ui_yesno() { ui_dialog "$@"; }
function ui_menu() { ui_dialog "$@"; }
function ui_checklist() { ui_dialog "$@"; }
function ui_inputbox() { ui_dialog "$@"; }
function ui_msgbox() { ui_dialog "$@"; }

function validate_headless_config() {
    local selected_decoders=()
    local selections=()
    local decoder
    local device_key
    local device_value
    local selection
    local vdlm2_decoders
    local seen_devices=" "

    for decoder in "${RECEIVER_HEADLESS_ADSB_DECODER:-none}" "${RECEIVER_HEADLESS_UAT_DECODER:-none}" "${RECEIVER_HEADLESS_ACARS_DECODER:-none}"; do
        case "${decoder}" in
            none|dump1090-fa|readsb|dump978-fa|acarsdec|dumpvdl2|vdlm2dec) ;;
            *)
                log_alert_message "Invalid headless decoder selection: ${decoder}"
                return 1
                ;;
        esac
        [[ "${decoder}" != "none" ]] && selected_decoders+=("${decoder}")
    done

    vdlm2_decoders="${RECEIVER_HEADLESS_VDLM2_DECODERS:-${RECEIVER_HEADLESS_VDLM2_DECODER:-none}}"
    IFS=',' read -r -a selections <<< "${vdlm2_decoders}"
    for decoder in "${selections[@]}"; do
        case "${decoder}" in
            none|dumpvdl2|vdlm2dec) ;;
            *)
                log_alert_message "Invalid VDL Mode 2 decoder selection: ${decoder}"
                return 1
                ;;
        esac
        [[ "${decoder}" != "none" ]] && selected_decoders+=("${decoder}")
    done

    if [[ "${RECEIVER_HEADLESS_ADSB_DECODER:-none}" != "none" && "${RECEIVER_HEADLESS_ADSB_DECODER}" != "dump1090-fa" && "${RECEIVER_HEADLESS_ADSB_DECODER}" != "readsb" ]]; then
        log_alert_message "ADS-B decoder must be dump1090-fa, readsb, or none."
        return 1
    fi

    if [[ "${RECEIVER_HEADLESS_UAT_DECODER:-none}" != "none" && "${RECEIVER_HEADLESS_UAT_DECODER}" != "dump978-fa" ]]; then
        log_alert_message "UAT decoder must be dump978-fa or none."
        return 1
    fi

    if [[ "${RECEIVER_HEADLESS_ACARS_DECODER:-none}" != "none" && "${RECEIVER_HEADLESS_ACARS_DECODER}" != "acarsdec" ]]; then
        log_alert_message "ACARS decoder must be acarsdec or none."
        return 1
    fi

    if [[ "${vdlm2_decoders}" == *"none,"* || "${vdlm2_decoders}" == *,"none"* || ( "${vdlm2_decoders}" == *"none"* && "${vdlm2_decoders}" != "none" ) ]]; then
        log_alert_message "VDL Mode 2 selection cannot combine none with an installed decoder."
        return 1
    fi

    if (( ${#selected_decoders[@]} > 1 )); then
        for decoder in "${selected_decoders[@]}"; do
            device_key="RECEIVER_HEADLESS_DEVICE_$(printf '%s' "${decoder}" | tr '[:lower:]-' '[:upper:]_')"
            device_value=$(ui_config_value "${device_key}")
            if ! [[ "${device_value}" =~ ^[0-9]+$ ]]; then
                log_alert_message "${device_key} must assign a numeric RTL-SDR device for ${decoder}."
                return 1
            fi
            if [[ "${seen_devices}" == *" ${device_value} "* ]]; then
                log_alert_message "RTL-SDR device ${device_value} is assigned to more than one decoder."
                return 1
            fi
            seen_devices+="${device_value} "
        done
    fi

    IFS=',' read -r -a selections <<< "${RECEIVER_HEADLESS_FEEDERS:-}"
    for selection in "${selections[@]}"; do
        [[ -z "${selection}" ]] && continue
        case "${selection}" in
            "ADS-B Exchange Feed Client"|"AirNav Radar RBFeeder"|"Airplanes.live Feeder"|"FlightAware PiAware"|"Flightradar24 Client"|"Fly Italy ADS-B Feeder"|"OpenSky Network Feeder"|"Plane Finder Client") ;;
            *)
                log_alert_message "Unknown headless feeder selection: ${selection}"
                return 1
                ;;
        esac
    done

    IFS=',' read -r -a selections <<< "${RECEIVER_HEADLESS_EXTRAS:-}"
    for selection in "${selections[@]}"; do
        [[ -z "${selection}" ]] && continue
        case "${selection}" in
            "beast-splitter"|"Duck DNS Free Dynamic DNS Hosting"|"Graphs1090"|"tar1090") ;;
            *)
                log_alert_message "Unknown headless extra selection: ${selection}"
                return 1
                ;;
        esac
    done
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
    if [[ -f /usr/local/bin/vdlm2dec ]]; then
        log_message "The VDLM2DEC decoder appears to be installed"
        vdlm2_decoder_installed="true"
        RECEIVER_VDLM2_DECODER_SOFTWARE="vdlm2dec"
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
                device_assigned_to_acars_decoder=$(echo "${exec_start}" | grep -o -P '(?<=-r )[0-9]+')
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
                exec_start=$(get_config "ExecStart" "/etc/systemd/system/dumpvdl2.service")
                device_assigned_to_vdlm2_decoder=$(echo "${exec_start}" | grep -o -P '(?<=--rtlsdr )[0-9]+')
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

        if [[ "${decoder_being_installed}" == "vdlm2dec" || "${vdlm2_decoder_installed}" == "true" && "${RECEIVER_VDLM2_DECODER_SOFTWARE}" == "vdlm2dec" ]]; then
            if [[ "${vdlm2_decoder_installed}" == "true" ]]; then
                log_message "Determining which device is currently assigned to VDLM2DEC"
                exec_start=$(get_config "ExecStart" "/etc/systemd/system/vdlm2dec.service")
                device_assigned_to_vdlm2_decoder=$(echo "${exec_start}" | grep -o -P '(?<=-r )[0-9]+')
            fi
            ask_device_number "VDLM2DEC" "RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER" "${device_assigned_to_vdlm2_decoder}"
        fi
    fi
}

function assign_devices_to_decoders() {

    log_heading "Configure decoders if more than one is present"

    if [[ -n "${RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER}" && "${RECEIVER_ACARS_DECODER_SOFTWARE}" == "acarsdec" ]]; then
        log_message "Assigning RTL-SDR device number ${RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER} to ACARSDEC"
        sudo sed -i -e "s|\(.*-r \)\([0-9]\+\)\( .*\)|\1${RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER}\3|g" /etc/systemd/system/acarsdec.service
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
        sudo sed -i -e "s|\(.*--rtlsdr \)\([0-9]\+\)\( .*\)|\1${RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER}\3|g" /etc/systemd/system/dumpvdl2.service
        log_message "Reloading systemd units"
        sudo systemctl daemon-reload
        log_message "Restarting dumpvdl2"
        sudo systemctl restart dumpvdl2
    fi

    if [[ -n "${RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER}" && "${RECEIVER_ADSB_DECODER_SOFTWARE}" == "readsb" ]]; then
        log_message "Assigning RTL-SDR device number ${RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER} to Readsb"
        sudo sed -i -e "s|\(.*--device \)\([0-9]\+\)\( .*\)|\1${RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER}\3|g" /etc/default/readsb
        log_message "Restarting Readsb"
        sudo systemctl restart readsb
    fi

    if [[ -n "${RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER}" && "${RECEIVER_VDLM2_DECODER_SOFTWARE}" == "vdlm2dec" ]]; then
        log_message "Assigning RTL-SDR device number ${RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER} to vdlm2dec"
        sudo sed -i -e "s|\(.*-r \)\([0-9]\+\)\( .*\)|\1${RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER}\3|g" /etc/systemd/system/vdlm2dec.service
        log_message "Reloading systemd units"
        sudo systemctl daemon-reload
        log_message "Restarting vdlm2dec"
        sudo systemctl restart vdlm2dec
    fi
}

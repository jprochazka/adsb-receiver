#!/bin/bash

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

function ui_headless_setup_confirmation() {
    case "$1" in
        "The ADS-B Receiver Project"|"FlightAware Dump1090 Decoder Setup"|"Readsb Decoder Setup"|"FlightAware Dump978 Setup"|"ACARSDEC decoder Setup"|"dumpvdl2 decoder Setup"|"The ADS-B Portal Setup"|"Duck DNS Dynamic DNS"|"Beast-Splitter Setup"|"Graphs1090 Setup"|"tar1090 Setup"|"ADS-B Exchange Feed Setup"|"AirNav Radar feeder client Setup"|"Airplanes.live Feeder Client Setup"|"FlightRadar24 feeder client Setup"|"Fly Italy ADS-B feeder client Setup"|"OpenSky Network feeder client Setup"|"FlightAware PiAware client Setup"|"PlaneFinder ADS-B Client Setup") return 0 ;;
    esac

    return 1
}

function ui_headless_dialog() {
    local dialog_type="$1"
    local title="$2"
    local value_key="HEADLESS_$(printf '%s' "${dialog_type#--}" | tr '[:lower:]' '[:upper:]')_$(ui_title_key "${title}")"
    local generic_key="HEADLESS_$(ui_title_key "${title}")"
    local mapped_key=""
    local value

    case "${title}" in
        "Stash Changes To Branch "*) mapped_key="HEADLESS_STASH_CHANGES" ;;
        "Operating System Updates") mapped_key="HEADLESS_OPERATING_SYSTEM_UPDATES" ;;
        "ADS-B Decoder Selection") mapped_key="HEADLESS_ADSB_DECODER" ;;
        "UAT Decoder Selection") mapped_key="HEADLESS_UAT_DECODER" ;;
        "ACARS Decoder Selection") mapped_key="HEADLESS_ACARS_DECODER" ;;
        "VDL Mode 2 Decoder Selection") mapped_key="HEADLESS_VDLM2_DECODER" ;;
        "ACARSDEC Device Type") mapped_key="HEADLESS_ACARSDEC_DEVICE_TYPE" ;;
        "Confirm You Wish To Continue") mapped_key="HEADLESS_CONFIGURATION_VERIFIED" ;;
        "Install The ADS-B Portal") mapped_key="HEADLESS_INSTALL_PORTAL" ;;
        "Portal Type Selection") mapped_key="HEADLESS_PORTAL_MODE" ;;
        "Choose Database Type") mapped_key="HEADLESS_PORTAL_DATABASE_TYPE" ;;
        "MySQL Database Location") mapped_key="HEADLESS_PORTAL_DATABASE_LOCAL" ;;
        "MySQL Database Server Hostname"*) mapped_key="HEADLESS_PORTAL_DATABASE_HOSTNAME" ;;
        "Does MySQL Database Exist") mapped_key="HEADLESS_PORTAL_DATABASE_EXISTS" ;;
        "MySQL Administrator Username") mapped_key="HEADLESS_PORTAL_MYSQL_ADMINISTRATOR_USERNAME" ;;
        "MySQL Administrator Password"|"Confirm The MySQL Administrator Password") mapped_key="HEADLESS_PORTAL_MYSQL_ADMINISTRATOR_PASSWORD" ;;
        "The ADS-B Portal Database Name") mapped_key="HEADLESS_PORTAL_DATABASE_NAME" ;;
        "The ADS-B Portal Database User") mapped_key="HEADLESS_PORTAL_DATABASE_USER" ;;
        "The ADS-B Portal Database Password"|"Confirm The ADS-B Portal Database Password") mapped_key="HEADLESS_PORTAL_DATABASE_PASSWORD" ;;
        "Setup dump1090-fa heywhatsthat Maximum Range Rings") mapped_key="HEADLESS_DUMP1090_FA_SETUP_HEYWHATSTHAT" ;;
        "Setup dump978-fa heywhatsthat Maximum Range Rings") mapped_key="HEADLESS_DUMP978_FA_SETUP_HEYWHATSTHAT" ;;
        "Enter ACARS Frequencies"*) mapped_key="HEADLESS_ACARSDEC_FREQUENCIES" ;;
        "Enter VDL Mode 2 Frequencies"*) mapped_key="HEADLESS_DUMPVDL2_FREQUENCIES" ;;
        "Enter the dump1090-fa heywhatsthat Panorama ID"*) mapped_key="HEADLESS_DUMP1090_FA_HEYWHATSTHAT_PANORAMA_ID" ;;
        "First dump1090-fa heywhatsthat Ring Altitude"*) mapped_key="HEADLESS_DUMP1090_FA_HEYWHATSTHAT_FIRST_RING_ALTITUDE" ;;
        "Second dump1090-fa heywhatsthat Ring Altitude"*) mapped_key="HEADLESS_DUMP1090_FA_HEYWHATSTHAT_SECOND_RING_ALTITUDE" ;;
        "Enter the dump978-fa heywhatsthat Panorama ID"*) mapped_key="HEADLESS_DUMP978_FA_HEYWHATSTHAT_PANORAMA_ID" ;;
        "First dump978-fa heywhatsthat Ring Altitude"*) mapped_key="HEADLESS_DUMP978_FA_HEYWHATSTHAT_FIRST_RING_ALTITUDE" ;;
        "Second dump978-fa heywhatsthat Ring Altitude"*) mapped_key="HEADLESS_DUMP978_FA_HEYWHATSTHAT_SECOND_RING_ALTITUDE" ;;
        "Enter Pre-Existing Sharing-Key"*) mapped_key="HEADLESS_AIRNAVRADAR_SHARING_KEY" ;;
        "Duck DNS Sub Domain"*) mapped_key="HEADLESS_DUCK_DNS_DOMAIN" ;;
        "Duck DNS Token"*) mapped_key="HEADLESS_DUCK_DNS_TOKEN" ;;
        "Enable Beast Splitter") mapped_key="HEADLESS_ENABLE_BEAST_SPLITTER" ;;
        "Input Options for Beast Splitter") mapped_key="HEADLESS_BEAST_SPLITTER_INPUT_OPTIONS" ;;
        "Output Options for Beast Splitter") mapped_key="HEADLESS_BEAST_SPLITTER_OUTPUT_OPTIONS" ;;
        "ADS-B Exchange Stats Package") mapped_key="HEADLESS_ADSBEXCHANGE_STATS" ;;
        "ADS-B Exchange Web Interface") mapped_key="HEADLESS_ADSBEXCHANGE_WEB_INTERFACE" ;;
        "Airplanes.live Web Interface Setup") mapped_key="HEADLESS_AIRPLANESLIVE_WEB_INTERFACE" ;;
        "Install The Fly Italy ADS-B Updater") mapped_key="HEADLESS_FLYITALYADSB_UPDATER" ;;
        "Client Installation Options") mapped_key="HEADLESS_FEEDERS" ;;
        "Extras Installation Options") mapped_key="HEADLESS_EXTRAS" ;;
        *"dump1090-fa RTL-SDR Device Number"*) mapped_key="HEADLESS_DUMP1090_FA_DEVICE" ;;
        *"dump978-fa RTL-SDR Device Number"*) mapped_key="HEADLESS_DUMP978_FA_DEVICE" ;;
        *"ACARSDEC RTL-SDR Device Number"*) mapped_key="HEADLESS_ACARSDEC_DEVICE" ;;
        *"dumpvdl2 RTL-SDR Device Number"*) mapped_key="HEADLESS_DUMPVDL2_DEVICE" ;;
        *"Readsb RTL-SDR Device Number"*) mapped_key="HEADLESS_READSB_DEVICE" ;;
    esac

    case "${dialog_type}" in
        --msgbox) return 0 ;;
        --yesno)
            if ui_headless_setup_confirmation "${title}"; then return 0; fi
            value=$(ui_config_value "${value_key}" "$(ui_config_value "${mapped_key}" "$(ui_config_value "${generic_key}" "$(ui_config_value HEADLESS_DEFAULT_YESNO no)")")")
            if [[ "${title}" == "Portal Type Selection" ]]; then
                case "${value,,}" in advanced) return 0 ;; lite) return 1 ;; *) log_alert_message "HEADLESS_PORTAL_MODE must be lite or advanced."; return 1 ;; esac
            fi
            case "${value,,}" in yes|true|1) return 0 ;; no|false|0) return 1 ;; *) log_alert_message "Invalid headless answer for ${title}: '${value}'. Use yes or no."; return 1 ;; esac
            ;;
        --menu|--inputbox|--passwordbox)
            value=$(ui_config_value "${value_key}" "$(ui_config_value "${mapped_key}" "$(ui_config_value "${generic_key}")")")
            [[ -n "${value}" ]] || { log_alert_message "Missing headless configuration value ${value_key} for '${title}'"; return 1; }
            if [[ "${title}" == "ACARSDEC Device Type" ]]; then
                case "${value,,}" in
                    rtl-sdr) value="RTL-SDR" ;;
                    airspy) value="AirSpy" ;;
                    sdrplay) value="SDRPlay" ;;
                esac
            fi
            printf '%s\n' "${value}" >&2
            ;;
        --checklist)
            value=$(ui_config_value "${value_key}" "$(ui_config_value "${mapped_key}" "$(ui_config_value "${generic_key}")")")
            [[ -z "${value}" ]] || tr ',' '\n' <<< "${value}" >&2
            ;;
        *) log_alert_message "Unsupported headless dialog type: ${dialog_type}"; return 1 ;;
    esac
}

function validate_headless_required_value() {
    local variable_name="$1"

    if [[ -z "$(ui_config_value "${variable_name}")" ]]; then
        log_alert_message "${variable_name} is required by the selected headless options."
        return 1
    fi
}

function headless_value_is_yes() {
    local value

    value=$(ui_config_value "$1" no)
    case "${value,,}" in yes|true|1) return 0 ;; esac
    return 1
}

function validate_headless_boolean_value() {
    local value

    value=$(ui_config_value "$1" no)
    case "${value,,}" in
        yes|true|1|no|false|0|"")
            return 0
            ;;
        *)
            log_alert_message "$1 must be yes or no."
            return 1
            ;;
    esac
}

function prepare_headless_selection_group() {
    local output_variable="$1"
    local option_type="$2"
    shift 2
    local option_name
    local selected_names=()
    local variable_name

    for option_name in "$@"; do
        variable_name="HEADLESS_INSTALL_$(printf '%s' "${option_name}" | tr '[:lower:]' '[:upper:]')"
        validate_headless_boolean_value "${variable_name}" || return 1

        if headless_value_is_yes "${variable_name}"; then
            case "${option_type}:${option_name}" in
                feeder:ADSBEXCHANGE) selected_names+=("ADS-B Exchange Feed Client") ;;
                feeder:AIRNAVRADAR) selected_names+=("AirNav Radar RBFeeder") ;;
                feeder:AIRPLANESLIVE) selected_names+=("Airplanes.live Feeder") ;;
                feeder:FLIGHTRADAR24) selected_names+=("Flightradar24 Client") ;;
                feeder:FLYITALYADSB) selected_names+=("Fly Italy ADS-B Feeder") ;;
                feeder:OPENSKY) selected_names+=("OpenSky Network Feeder") ;;
                feeder:PIAWARE) selected_names+=("FlightAware PiAware") ;;
                feeder:PLANEFINDER) selected_names+=("Plane Finder Client") ;;
                extra:DUCK_DNS) selected_names+=("Duck DNS Free Dynamic DNS Hosting") ;;
                extra:BEAST_SPLITTER) selected_names+=("beast-splitter") ;;
                extra:GRAPHS1090) selected_names+=("Graphs1090") ;;
                extra:TAR1090) selected_names+=("tar1090") ;;
            esac
        fi
    done

    printf -v "${output_variable}" '%s' "$(IFS=,; printf '%s' "${selected_names[*]}")"
}

function prepare_headless_selections() {
    prepare_headless_selection_group HEADLESS_FEEDERS feeder \
        ADSBEXCHANGE AIRNAVRADAR AIRPLANESLIVE FLIGHTRADAR24 FLYITALYADSB OPENSKY PIAWARE PLANEFINDER || return 1
    prepare_headless_selection_group HEADLESS_EXTRAS extra \
        DUCK_DNS BEAST_SPLITTER GRAPHS1090 TAR1090 || return 1
    export HEADLESS_FEEDERS HEADLESS_EXTRAS
}

function validate_headless_config() {
    local selected_decoders=()
    local selections=()
    local decoder
    local device_key
    local device_value
    local selection
    local vdlm2_decoders
    local seen_devices=" "

    prepare_headless_selections || return 1

    for selection in HEADLESS_INSTALL_PORTAL HEADLESS_OPERATING_SYSTEM_UPDATES HEADLESS_STASH_CHANGES HEADLESS_DUMP1090_FA_SETUP_HEYWHATSTHAT HEADLESS_DUMP978_FA_SETUP_HEYWHATSTHAT HEADLESS_ENABLE_BEAST_SPLITTER HEADLESS_PORTAL_DATABASE_LOCAL HEADLESS_PORTAL_DATABASE_EXISTS; do
        validate_headless_boolean_value "${selection}" || return 1
    done

    case "${HEADLESS_PORTAL_MODE,,}" in
        lite|advanced)
            ;;
        *)
            log_alert_message "HEADLESS_PORTAL_MODE must be lite or advanced."
            return 1
            ;;
    esac

    for decoder in "${HEADLESS_ADSB_DECODER:-none}" "${HEADLESS_UAT_DECODER:-none}" "${HEADLESS_ACARS_DECODER:-none}"; do
        case "${decoder}" in
            none|dump1090-fa|readsb|dump978-fa|acarsdec|dumpvdl2)
                ;;
            *)
                log_alert_message "Invalid headless decoder selection: ${decoder}"
                return 1
                ;;
        esac

        if [[ "${decoder}" != "none" ]]; then
            selected_decoders+=("${decoder}")
        fi
    done

    vdlm2_decoders="${HEADLESS_VDLM2_DECODERS:-none}"
    IFS=',' read -r -a selections <<< "${vdlm2_decoders}"
    for decoder in "${selections[@]}"; do
        case "${decoder}" in
            none|dumpvdl2)
                ;;
            *)
                log_alert_message "Invalid VDL Mode 2 decoder selection: ${decoder}"
                return 1
                ;;
        esac

        if [[ "${decoder}" != "none" ]]; then
            selected_decoders+=("${decoder}")
        fi
    done

    if [[ "${vdlm2_decoders}" != "none" ]]; then
        validate_headless_required_value HEADLESS_DUMPVDL2_FREQUENCIES || return 1
    fi

    if [[ "${HEADLESS_ACARS_DECODER}" == "acarsdec" ]]; then
        validate_headless_required_value HEADLESS_ACARSDEC_FREQUENCIES || return 1
    fi

    if [[ "${HEADLESS_ACARS_DECODER}" == "acarsdec" ]]; then
        case "${HEADLESS_ACARSDEC_DEVICE_TYPE,,}" in
            rtl-sdr|airspy|sdrplay)
                ;;
            *)
                log_alert_message "HEADLESS_ACARSDEC_DEVICE_TYPE must be rtl-sdr, airspy, or sdrplay."
                return 1
                ;;
        esac
    fi

    if (( ${#selected_decoders[@]} > 1 )); then
        for decoder in "${selected_decoders[@]}"; do
            device_key="HEADLESS_$(printf '%s' "${decoder}" | tr '[:lower:]-' '[:upper:]_')_DEVICE"
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

    if headless_value_is_yes HEADLESS_INSTALL_DUCK_DNS; then
        validate_headless_required_value HEADLESS_DUCK_DNS_DOMAIN || return 1
        validate_headless_required_value HEADLESS_DUCK_DNS_TOKEN || return 1
    fi

    if headless_value_is_yes HEADLESS_INSTALL_BEAST_SPLITTER; then
        validate_headless_required_value HEADLESS_BEAST_SPLITTER_INPUT_OPTIONS || return 1
        validate_headless_required_value HEADLESS_BEAST_SPLITTER_OUTPUT_OPTIONS || return 1
    fi

    if [[ "${HEADLESS_ADSB_DECODER}" == "dump1090-fa" ]] && headless_value_is_yes HEADLESS_DUMP1090_FA_SETUP_HEYWHATSTHAT; then
        for selection in HEADLESS_DUMP1090_FA_HEYWHATSTHAT_PANORAMA_ID HEADLESS_DUMP1090_FA_HEYWHATSTHAT_FIRST_RING_ALTITUDE HEADLESS_DUMP1090_FA_HEYWHATSTHAT_SECOND_RING_ALTITUDE; do
            validate_headless_required_value "${selection}" || return 1
        done
    fi

    if [[ "${HEADLESS_UAT_DECODER}" == "dump978-fa" ]] && headless_value_is_yes HEADLESS_DUMP978_FA_SETUP_HEYWHATSTHAT; then
        for selection in HEADLESS_DUMP978_FA_HEYWHATSTHAT_PANORAMA_ID HEADLESS_DUMP978_FA_HEYWHATSTHAT_FIRST_RING_ALTITUDE HEADLESS_DUMP978_FA_HEYWHATSTHAT_SECOND_RING_ALTITUDE; do
            validate_headless_required_value "${selection}" || return 1
        done
    fi

    if headless_value_is_yes HEADLESS_INSTALL_PORTAL && [[ "${HEADLESS_PORTAL_MODE,,}" == "advanced" ]]; then
        case "${HEADLESS_PORTAL_DATABASE_TYPE,,}" in
            mysql)
                if ! headless_value_is_yes HEADLESS_PORTAL_DATABASE_LOCAL; then
                    validate_headless_required_value HEADLESS_PORTAL_DATABASE_HOSTNAME || return 1
                fi
                if headless_value_is_yes HEADLESS_PORTAL_DATABASE_LOCAL || ! headless_value_is_yes HEADLESS_PORTAL_DATABASE_EXISTS; then
                    validate_headless_required_value HEADLESS_PORTAL_MYSQL_ADMINISTRATOR_USERNAME || return 1
                    validate_headless_required_value HEADLESS_PORTAL_MYSQL_ADMINISTRATOR_PASSWORD || return 1
                fi
                for selection in HEADLESS_PORTAL_DATABASE_NAME HEADLESS_PORTAL_DATABASE_USER HEADLESS_PORTAL_DATABASE_PASSWORD; do
                    validate_headless_required_value "${selection}" || return 1
                done
                ;;
            sqlite)
                ;;
            *)
                log_alert_message "HEADLESS_PORTAL_DATABASE_TYPE must be mysql or sqlite."
                return 1
                ;;
        esac
    fi
}
#!/bin/bash

## LOGGING FUNCTIONS

# Log a <message> to the log file
function log_to_file() {
    if [[ "${RECEIVER_LOGGING_ENABLED}" == "true" ]]; then
        time_stamp=''
        if [[ -z $2 || "${2}" == "true" ]]; then
            printf -v time_stamp '[%(%Y-%m-%d %H:%M:%S)T]' -1
        fi

        if [[ ! -z $3 && "${3}" == "inline" ]]; then
            printf "${time_stamp} ${1}" >> $RECEIVER_LOG_FILE
        else
            echo "${time_stamp} ${1}" >> $RECEIVER_LOG_FILE
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

# Logs an title "HEADING" to the console
function log_title_heading() {
    log_to_file "${1}"
    echo -e "${display_title_heading}  ${1}${display_default}"
}

# Logs an title "MESSAGE" to the console
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

function log_message_inline() {
    log_to_file "${1}" "true" "inline"
    printf "${display_message}  ${1}${display_default}"
}

function log_false_inline() {
    log_to_file "${1}" "false"
    echo -e "${display_false_inline} ${1}${display_default}"
}

function log_true_inline() {
    log_to_file "${1}" "false"
    echo -e "${display_true_inline} ${1}${display_default}"
}


## CHECK IF THE SUPPLIED PACKAGE IS INSTALLED AND IF NOT ATTEMPT TO INSTALL IT

function check_package() {
    attempt=1
    max_attempts=5
    wait_time=5

    while (( $attempt -le `(($max_attempts + 1))` )); do
        if [[ $attempt > $max_attempts ]]; then
           log_alert_heading "INSTALLATION HALTED"
           log_alert_message "Unable to install a required package"
           log_alert_message "The package $1 could not be installed in ${max_attempts} attempts"
            exit 1
        fi

        log_message_inline "Checking if the package $1 is installed"
        if [[ $(dpkg-query -W -f='${STATUS}' $1 2>/dev/null | grep -c "ok installed") = 0 ]]; then
            if [[ $attempt > 1 ]]; then
                log_alert_message "Inastallation attempt failed"
                log_alert_message "Will attempt to Install the package $1 again in ${wait_time} seconds (attempt ${attempt} of ${max_attempts})"
                sleep $wait_time
            else
                log_false_inline "[NOT INSTALLED]"
                log_message "Installing the package ${1}"
            fi
            echo ""
            attempt=$((attempt+1))
            sudo apt-get install -y $1 #2>&1 | tee -a $RECEIVER_LOG_FILE
            echo ""
        else
            log_true_inline "[OK]"
            break
        fi
    done
}


## BLACKLIST DVB-T DRIVERS FOR RTL-SDR DEVICES

function blacklist_modules() {
    if [[ ! -f /etc/modprobe.d/rtlsdr-blacklist.conf || `cat /etc/modprobe.d/rtlsdr-blacklist.conf | wc -l` < 9 ]]; then
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
    sudo sed -i -e "s/\($1 *= *\).*/\1\"$2\"/" $3
}

# Use sed to locate the "KEY" then read the "VALUE", the portion after the equals sign, in the specified "FILE"
# This function should work with any configuration file with settings formated as KEY="VALUE"
function get_config() {
    setting=`sed -n "/^$1 *= *\"\(.*\)\"$/s//\1/p" $2`
    if [[ "${setting}" == "" ]]; then
        setting=`sed -n "/^$1 *= *\(.*\)$/s//\1/p" $2`
    fi
    echo $setting
}


## ASSIGN DEVICES TO DECODERS

function ask_for_device_assignments() {
    log_heading "Gather information required to configure the decoder(s)"

    decoder_being_installed=$1
    decoder_count=1

    log_message "Checking if an ACARS decoder is installed"
    acars_decoder_installed="false"
    if [[ -f /usr/local/bin/acarsdec ]]; then
        log_message "The ACARSDEC decoder appears to be installed"
        acars_decoder_installed="true"
        RECEIVER_ACARS_DECODER_SOFTWARE="acarsdec"
    fi
    if [[ "${acars_decoder_installed}" == "true" && "${RECEIVER_ACARS_DECODER_SOFTWARE}" != "${decoder_being_installed}" ]]; then
        decoder_count=$((decoder_count+1))
    fi

    log_message "Checking if an ADS-B decoder is installed"
    adsb_decoder_installed="false"
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
        decoder_count=$((decoder_count+1))
    fi

    log_message "Checking if a UAT decoder is installed"
    uat_decoder_installed="false"
    if [[ $(dpkg-query -W -f='${STATUS}' dump978-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
        log_message "The FlightAware dump978 decoder appears to be installed"
        uat_decoder_installed="true"
        RECEIVER_UAT_DECODER_SOFTWARE="dump978-fa"
    fi
    if [[ "${uat_decoder_installed}" == "true" && "${RECEIVER_UAT_DECODER_SOFTWARE}" != "${decoder_being_installed}" ]]; then
        decoder_count=$((decoder_count+1))
    fi

    log_message "Checking if a VDL Mode 2 decoder is installed"
    vdlm2_decoder_installed="false"
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
        decoder_count=$((decoder_count+1))
    fi

    if [[ $decoder_count > 1 ]]; then
        log_message "Informing the user that existing decoder(s) appears to be installed"
        whiptail --backtitle "Decoder Configuration" \
                --title "RTL-SDR Dongle Assignments" \
                --msgbox "It appears that existing decoder(s) have been installed on this device. In order to run this decoder in tandem with other decoders you will need to specifiy which RTL-SDR dongle each decoder is to use.\n\nKeep in mind in order to run multiple decoders on a single device you will need to have multiple RTL-SDR devices connected to your device." \
                12 78

        if [[ "${decoder_being_installed}" == "acarsdec" || "${acars_decoder_installed}" == "true" && "${RECEIVER_ACARS_DECODER_SOFTWARE}" == "acarsdec" ]]; then
            if [[ "${acars_decoder_installed}" == "true" ]]; then
                log_message "Determining which device is currently assigned to ACARSDEC"
                exec_start=`get_config "ExecStart" "/etc/systemd/system/acarsdec.service"`
                device_assigned_to_acars_decoder=`echo $exec_start | grep -o -P '(?<=-r )[0-9]+'`
            fi
            log_message "Asking the user to assign a RTL-SDR device number to ACARSDEC"
            acars_device_number_title="Enter the ACARSDEC RTL-SDR Device Number"
            while [[ -z $RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER ]]; do
                RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER=$(whiptail --backtitle "Decoder Configuration" \
                                                                     --title "${acars_device_number_title}" \
                                                                     --inputbox "\nEnter the RTL-SDR device number to assign to ACARSDEC." \
                                                                     8 78 \
                                                                     "${device_assigned_to_acars_decoder}" 3>&1 1>&2 2>&3)
                exit_status=$?
                if [[ $exit_status != 0 ]]; then
                    exit 1
                fi
                acars_device_number_title="Enter the ACARSDEC RTL-SDR Device Number (REQUIRED)"
            done
        fi

        if [[ "${decoder_being_installed}" == "dump1090-fa" || "${adsb_decoder_installed}" == "true" && "${RECEIVER_ADSB_DECODER_SOFTWARE}" == "dump1090-fa" ]]; then
            if [[ "${adsb_decoder_installed}" == "true" ]]; then
                log_message "Determining which device is currently assigned to dump1090-fa"
                device_assigned_to_adsb_decoder=`get_config "RECEIVER_SERIAL" "/etc/default/dump1090-fa"`
            fi
            log_message "Asking the user to assign a RTL-SDR device number to dump1090-fa"
            adsb_device_number_title="Enter the dump1090-fa RTL-SDR Device Number"
            while [[ -z $RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER ]]; do
                RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER=$(whiptail --backtitle "Decoder Configuration" \
                                                                    --title "${adsb_device_number_title}" \
                                                                    --inputbox "\nEnter the RTL-SDR device number to assign to dump1090-fa." \
                                                                    8 78 \
                                                                    "${device_assigned_to_adsb_decoder}" 3>&1 1>&2 2>&3)
                exit_status=$?
                if [[ $exit_status != 0 ]]; then
                    exit 1
                fi
                adsb_device_number_title="Enter the dump1090-fa RTL-SDR Device Number (REQUIRED)"
            done
        fi

        if [[ "${decoder_being_installed}" == "dump978-fa" || "${uat_decoder_installed}" == "true" && "${RECEIVER_UAT_DECODER_SOFTWARE}" == "dump978-fa" ]]; then
            if [[ "${uat_decoder_installed}" == "true" ]]; then
                log_message "Determining which device is currently assigned to dump978-fa"
                receiver_options=`get_config "RECEIVER_OPTIONS" "/etc/default/dump978-fa"`
                device_assigned_to_uat_decoder=`echo $receiver_options | grep -o -P '(?<=serial=)[0-9]+'`
            fi
            log_message "Asking the user to assign a RTL-SDR device number to dump978-fa"
            uat_device_number_title="Enter the dump978-fa RTL-SDR Device Number"
            while [[ -z $RECEIVER_DEVICE_ASSIGNED_TO_UAT_DECODER ]] ; do
                RECEIVER_DEVICE_ASSIGNED_TO_UAT_DECODER=$(whiptail --backtitle "Decoder Configuration" \
                                                                   --title "${uat_device_number_title}" \
                                                                   --inputbox "\nEnter the RTL-SDR device number to assign to dump978-fa." \
                                                                   8 78 \
                                                                   "${device_assigned_to_uat_decoder}" 3>&1 1>&2 2>&3)
                exit_status=$?
                if [[ $exit_status != 0 ]]; then
                    exit 1
                fi
                uat_device_number_title="Enter the dump978-fa RTL-SDR Device Number (REQUIRED)"
            done
        fi

        if [[ "${decoder_being_installed}" == "dumpvdl2" || "${vdlm2_decoder_installed}" == "true" && "${RECEIVER_VDLM2_DECODER_SOFTWARE}" == "dumpvdl2" ]]; then
            if [[ "${vdlm2_decoder_installed}" == "true" ]]; then
                log_message "Determining which device is currently assigned to dumpvdl2"
                exec_start=`get_config "ExecStart" "/etc/systemd/system/dumpvdl2.service"`
                device_assigned_to_vdlm2_decoder=`echo $exec_start | grep -o -P '(?<=--rtlsdr )[0-9]+'`
            fi
            log_message "Asking the user to assign a RTL-SDR device number to dumpvdl2"
            vdlm2_device_number_title="Enter the dumpvdl2 RTL-SDR Device Number"
            while [[ -z $RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER ]]; do
                RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER=$(whiptail --backtitle "Decoder Configuration" \
                                                                     --title "${vdlm2_device_number_title}" \
                                                                     --inputbox "Enter the RTL-SDR device number to assign to dumpvdl2." \
                                                                     8 78 \
                                                                     "${device_assigned_to_vdlm2_decoder}" 3>&1 1>&2 2>&3)
                exit_status=$?
                if [[ $exit_status != 0 ]]; then
                    exit 1
                fi
                vdlm2_device_number_title="Enter the dumpvdl2 RTL-SDR Device Number (REQUIRED)"
            done
        fi

        if [[ "${decoder_being_installed}" == "readsb" || "${adsb_decoder_installed}" == "true" && "${RECEIVER_ADSB_DECODER_SOFTWARE}" == "readsb" ]]; then
            if [[  "${adsb_decoder_installed}" == "true" ]]; then
                log_message "Determining which device is currently assigned to Readsb"
                receiver_options=`get_config "RECEIVER_OPTIONS" "/etc/default/readsb"`
                device_assigned_to_adsb_decoder=`echo $receiver_options | grep -o -P '(?<=--device )[0-9]+'`
            fi
            log_message "Asking the user to assign a RTL-SDR device number to Readsb"
            adsb_device_number_title="Enter the Readsb RTL-SDR Device Number"
            while [[ -z $RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER ]]; do
                RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER=$(whiptail --backtitle "Decoder Configuration" \
                                                                    --title "${adsb_device_number_title}" \
                                                                    --inputbox "\nEnter the RTL-SDR device number to assign to Readsb." \
                                                                    8 78 \
                                                                    "${device_assigned_to_adsb_decoder}" 3>&1 1>&2 2>&3)
                exit_status=$?
                if [[ $exit_status != 0 ]]; then
                    exit 1
                fi
                adsb_device_number_title="Enter the Readsb RTL-SDR Device Number (REQUIRED)"
            done
        fi

        if [[ "${decoder_being_installed}" == "vdlm2dec" || "${vdlm2_decoder_installed}" == "true" && "${RECEIVER_VDLM2_DECODER_SOFTWARE}" == "vdlm2dec" ]]; then
            if [[ "${vdlm2_decoder_installed}" == "true" ]]; then
                log_message "Determining which device is currently assigned to VDLM2DEC"
                exec_start=`get_config "ExecStart" "/etc/systemd/system/vdlm2dec.service"`
                device_assigned_to_vdlm2_decoder=`echo $exec_start | grep -o -P '(?<=-r )[0-9]+'`
            fi
            log_message "Asking the user to assign a RTL-SDR device number to VDLM2DEC"
            vdlm2_device_number_title="Enter the VDLM2DEC RTL-SDR Device Number"
            while [[ -z $RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER ]]; do
                RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER=$(whiptail --backtitle "Decoder Configuration" \
                                                                     --title "${vdlm2_device_number_title}" \
                                                                     --inputbox "\nEnter the RTL-SDR device number to assign to VDLM2DEC." \
                                                                     8 78 \
                                                                     "${device_assigned_to_vdlm2_decoder}" 3>&1 1>&2 2>&3)
                exit_status=$?
                if [[ $exit_status != 0 ]]; then
                    exit 1
                fi
                vdlm2_device_number_title="Enter the ACARSDEC RTL-SDR Device Number (REQUIRED)"
            done
        fi
    fi
}

function assign_devices_to_decoders() {

    log_heading "Configure decoders if more than one is present"

    if [[ ! -z $RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER && "${RECEIVER_ACARS_DECODER_SOFTWARE}" == "acarsdec" ]]; then
        log_message "Assigning RTL-SDR device number ${RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER} to ACARSDEC"
        sudo sed -i -e "s|\(.*-r \)\([0-9]\+\)\( .*\)|\1${RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER}\3|g" /etc/systemd/system/acarsdec.service
        log_message "Reload systemd units"
        sudo systemctl daemon-reload
        log_message "Restarting ACARSDEC"
        sudo systemctl restart acarsdec
    fi

    if [[ ! -z $RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER && "${RECEIVER_ADSB_DECODER_SOFTWARE}" == "dump1090-fa" ]]; then
        log_message "Assigning RTL-SDR device number ${RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER} to FlightAware Dump1090"
        change_config "RECEIVER_SERIAL" $RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER "/etc/default/dump1090-fa"
        log_message "Restarting dump1090-fa"
        sudo systemctl restart dump1090-fa
    fi

    if [[ ! -z $RECEIVER_DEVICE_ASSIGNED_TO_UAT_DECODER && "${RECEIVER_UAT_DECODER_SOFTWARE}" == "dump978-fa" ]]; then
        log_message "Assigning RTL-SDR device number ${RECEIVER_DEVICE_ASSIGNED_TO_UAT_DECODER} to FlightAware Dump978"
        serial_assigned=$(cat /etc/default/dump978-fa | grep -c "driver=rtlsdr,serial=")
        if [[ $serial_assigned == 1 ]]; then
            sudo sed -i -e "s|\(.*driver=rtlsdr,serial=\)\([0-9]\+\)\( .*\)|\1${RECEIVER_DEVICE_ASSIGNED_TO_UAT_DECODER}\3|g" /etc/default/dump978-fa
        else
            sudo sed -i -e "s|driver=rtlsdr|driver=rtlsdr,serial=${RECEIVER_DEVICE_ASSIGNED_TO_UAT_DECODER}|g" /etc/default/dump978-fa
        fi
        log_message "Restarting dump978-fa"
        sudo systemctl restart dump978-fa
    fi

    if [[ ! -z $RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER && "${RECEIVER_VDLM2_DECODER_SOFTWARE}" == "dumpvdl2" ]]; then
        log_message "Assigning RTL-SDR device number ${RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER} to dumpvdl2"
        sudo sed -i -e "s|\(.*--rtlsdr \)\([0-9]\+\)\( .*\)|\1${RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER}\3|g" /etc/systemd/system/dumpvdl2.service
        log_message "Reloading systemd units"
        sudo systemctl daemon-reload
        log_message "Restarting dumpvdl2"
        sudo systemctl restart dumpvdl2
    fi

    if [[ ! -z $RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER && "${RECEIVER_ADSB_DECODER_SOFTWARE}" == "readsb" ]]; then
        log_message "Assigning RTL-SDR device number ${RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER} to Readsb"
        sudo sed -i -e "s|\(.*--device \)\([0-9]\+\)\( .*\)|\1${RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER}\3|g" /etc/default/readsb
        log_message "Restarting Readsb"
        sudo systemctl restart readsb
    fi

    if [[ ! -z $RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER && "${RECEIVER_VDLM2_DECODER_SOFTWARE}" == "vdlm2dec" ]]; then
        log_message "Assigning RTL-SDR device number ${RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER} to vdlm2dec"
        sudo sed -i -e "s|\(.*-r \)\([0-9]\+\)\( .*\)|\1${RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER}\3|g" /etc/systemd/system/vdlm2dec.service
        log_message "Reloading systemd units"
        sudo systemctl daemon-reload
        log_message "Restarting vdlm2dec"
        sudo systemctl restart vdlm2dec
    fi
}

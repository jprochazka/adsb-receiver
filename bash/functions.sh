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

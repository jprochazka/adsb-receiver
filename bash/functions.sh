#!/bin/bash

## LOGGING FUNCTIONS

# LogToFile <message> <append_timestamp> <inline>
function LogToFile() {
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

function LogOutput() {
    LogToFile "${1}"
}

# Logs the "PROJECT TITLE" to the console
function LogProjectTitle {
    LogToFile "${RECEIVER_PROJECT_TITLE}"
    echo -e "${display_project_name}  ${RECEIVER_PROJECT_TITLE}${display_default}"
    echo ""
}

# Logs a "HEADING" to the console
function LogHeading() {
    LogToFile "${1}"
    echo ""
    echo -e "${display_heading}  ${1}${display_default}"
    echo ""
}

# Logs a "MESSAGE" to the console
function LogMessage() {
    LogToFile "${1}"
    echo -e "${display_message}  ${1}${display_default}"
}

# Logs an alert "HEADING" to the console
function LogAlertHeading() {
    LogToFile "${1}"
    echo -e "${display_alert_heading}  ${1}${display_default}"
}

# Logs an alert "MESSAGE" to the console
function LogAlertMessage() {
    LogToFile "${1}"
    echo -e "${display_alert_message}  ${1}${display_default}"
}

# Logs an title "HEADING" to the console
function LogTitleHeading() {
    LogToFile "${1}"
    echo -e "${display_title_heading}  ${1}${display_default}"
}

# Logs an title "MESSAGE" to the console
function LogTitleMessage() {
    LogToFile "${1}"
    echo -e "${display_title_message}  ${1}${display_default}"
}

# Logs a warning "HEADING" to the console
function LogWarningHeading() {
    LogToFile "${1}"
    echo -e "${display_warning_heading}  ${1}${display_default}"
}

# Logs a warning "MESSAGE" to the console
function LogWarningMessage() {
    LogToFile "${1}"
    echo -e "${display_warning_message}  ${1}${display_default}"
}

function LogMessageInline() {
    LogToFile "${1}" "true" "inline"
    printf "${display_message}  ${1}${display_default}"
}

function LogFalseInline() {
    LogToFile "${1}" "false"
    echo -e "${display_false_inline} ${1}${display_default}"
}

function LogTrueInline() {
    LogToFile "${1}" "false"
    echo -e "${display_true_inline} ${1}${display_default}"
}


## CHECK IF THE SUPPLIED PACKAGE IS INSTALLED AND IF NOT ATTEMPT TO INSTALL IT

function CheckPackage() {
    attempt=1
    max_attempts=5
    wait_time=5

    while (( $attempt -le `(($max_attempts + 1))` )); do
        if [[ $attempt > $max_attempts ]]; then
           LogAlertHeading "INSTALLATION HALTED"
           LogAlertMessage "Unable to install a required package"
           LogAlertMessage "The package $1 could not be installed in ${max_attempts} attempts"
            exit 1
        fi

        LogMessageInline "Checking if the package $1 is installed"
        if [[ $(dpkg-query -W -f='${STATUS}' $1 2>/dev/null | grep -c "ok installed") = 0 ]]; then
            if [[ $attempt > 1 ]]; then
                LogAlertMessage "Inastallation attempt failed"
                LogAlertMessage "Will attempt to Install the package $1 again in ${wait_time} seconds (attempt ${attempt} of ${max_attempts})"
                sleep $wait_time
            else
                LogFalseInline "[NOT INSTALLED]"
                LogMessage "Installing the package ${1}"
            fi
            echo ""
            attempt=$((attempt+1))
            sudo apt-get install -y $1 2>&1 | tee -a $RECEIVER_LOG_FILE
            echo ""
        else
            LogTrueInline "[OK]"
            break
        fi
    done
}


## BLACKLIST DVB-T DRIVERS FOR RTL-SDR DEVICES

function BlacklistModules() {
    if [[ ! -f /etc/modprobe.d/rtlsdr-blacklist.conf || `cat /etc/modprobe.d/rtlsdr-blacklist.conf | wc -l` < 9 ]]; then
        LogMessage "Blacklisting unwanted RTL-SDR kernel modules so they are not loaded"
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
        LogMessage "Kernel module blacklisting complete"
    fi
}


## CONFIGURATION RELATED FUNCTIONS

# Use sed to locate the "SWITCH" then replace the "VALUE", the portion after the equals sign, in the specified "FILE"
# This function will replace the value assigned to a specific switch contained within a file
function ChangeSwitch() {
    sudo sed -i -re "s/($1)\s+\w+/\1 $2/g" $3
}

# Use sed to locate the "KEY" then replace the "VALUE", the portion after the equals sign, in the specified "FILE"
# This function should work with any configuration file with settings formated as KEY="VALUE"
function ChangeConfig() {
    sudo sed -i -e "s/\($1 *= *\).*/\1\"$2\"/" $3
}

# Use sed to locate the "KEY" then read the "VALUE", the portion after the equals sign, in the specified "FILE"
# This function should work with any configuration file with settings formated as KEY="VALUE"
function GetConfig() {
    echo `sed -n "/^$1 *= *\"\(.*\)\"$/s//\1/p" $2`
}

# Use sed to locate the "KEY" then comment out the line containing it in the specified "FILE"
function CommentConfig() {
    if [[ ! `grep -cFx "#${1}" $2` -gt 0 ]]; then
        sudo sed -i "/${1}/ s/^/#/" $2
    fi
}

# Use sed to locate the "KEY" then uncomment the line containing it in the specified "FILE"
function UncommentConfig() {
    if [[ `grep -cFx "#${1}" $2` -gt 0 ]]; then
        sudo sed -i "/#${1}*/ s/#*//" $2
    fi
}

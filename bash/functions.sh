#!/bin/bash

# Detect if a package is installed and if not attempt to install it
function CheckPackage {
    attempt=1
    max_attempts=5
    wait_time=5

    while (( $attempt -le `(($max_attempts + 1))` )); do

        # If the maximum attempts has been reached
        if [[ $attempt > $max_attempts ]]; then
            echo -e "\n\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
            echo -e "  UNABLE TO INSTALL A REQUIRED PACKAGE."
            echo -e "  SETUP HAS BEEN TERMINATED!\n"
            echo -e "\e[93mThe package \"$1\" could not be installed in ${max_attempts} attempts.\e[39m\n"
            exit 1
        fi

        # Check if the package is already installed
        printf "\e[94m  Checking if the package $1 is installed..."
        if [[ $(dpkg-query -W -f='${STATUS}' $1 2>/dev/null | grep -c "ok installed") = 0 ]]; then

            # If this is not the first attempt at installing this package...
            if [[ $attempt > 1 ]]; then
                echo -e "\e[91m  \e[5m[INSTALLATION ATTEMPT FAILED]\e[25m"
                echo -e "\e[94m  Will attempt to Install the package $1 again in ${wait_time} seconds (ATTEMPT ${attempt} OF ${max_attempts})..."
                sleep $wait_time
            else
                echo -e "\e[91m [NOT INSTALLED]"
                echo -e "\e[94m  Installing the package $1..."
            fi

            # Attempt to install the required package
            echo -e "\e[97m"
            attempt=$((attempt+1))
            sudo apt-get install -y $1
            echo -e "\e[39m"
        else
            # The package appears to be installed
            echo -e "\e[92m [OK]\e[39m"
            break
        fi
    done
}

# Blacklist DVB-T drivers for RTL-SDR devices
function BlacklistModules {
    if [[ ! -f /etc/modprobe.d/rtlsdr-blacklist.conf || `cat /etc/modprobe.d/rtlsdr-blacklist.conf | wc -l` < 9 ]]; then
        echo -en "\e[94m  Blacklisting unwanted RTL-SDR kernel modules so they are not loaded...\e[97m"
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
        echo -en "\e[94m  Kernel module blacklisting complete...\e[97m"
    fi
}


## CHANGE SETTINGS IN CONFIGURATION FILES

# Use sed to locate the "SWITCH" then replace the "VALUE", the portion after the equals sign, in the specified "FILE"
# This function will replace the value assigned to a specific switch contained within a file
function ChangeSwitch {
    sudo sed -i -re "s/($1)\s+\w+/\1 $2/g" $3
}

# Use sed to locate the "KEY" then replace the "VALUE", the portion after the equals sign, in the specified "FILE"
# This function should work with any configuration file with settings formated as KEY="VALUE"
function ChangeConfig {
    sudo sed -i -e "s/\($1 *= *\).*/\1\"$2\"/" $3
}

# Use sed to locate the "KEY" then read the "VALUE", the portion after the equals sign, in the specified "FILE"
# This function should work with any configuration file with settings formated as KEY="VALUE"
function GetConfig {
    echo `sed -n "/^$1 *= *\"\(.*\)\"$/s//\1/p" $2`
}

# Use sed to locate the "KEY" then comment out the line containing it in the specified "FILE"
function CommentConfig {
    if [[ ! `grep -cFx "#${1}" $2` -gt 0 ]]; then
        sudo sed -i "/${1}/ s/^/#/" $2
    fi
}

# Use sed to locate the "KEY" then uncomment the line containing it in the specified "FILE"
function UncommentConfig {
    if [[ `grep -cFx "#${1}" $2` -gt 0 ]]; then
        sudo sed -i "/#${1}*/ s/#*//" $2
    fi
}


## LOGGING

# Logs the "PROJECT NAME" to the console
function LogProjectName {
    echo -e "${DISPLAY_PROJECT_NAME}  ${1}${DISPLAY_DEFAULT}"
    echo ""
}

# Logs a "HEADING" to the console
function LogHeading {
    echo ""
    echo -e "${DISPLAY_HEADING}  ${1}${DISPLAY_DEFAULT}"
    echo ""
}

# Logs a "MESSAGE" to the console
function LogMessage {
    echo -e "${DISPLAY_MESSAGE}  ${1}${DISPLAY_DEFAULT}"
}

# Logs an alert "HEADING" to the console
function LogAlertHeading {
    echo -e "${DISPLAY_ALERT_HEADING}  ${1}${DISPLAY_DEFAULT}"
}

# Logs an alert "MESSAGE" to the console
function LogAlertMessage {
    echo -e "${DISPLAY_ALERT_MESSAGE}  ${1}${DISPLAY_DEFAULT}"
}

# Logs an title "HEADING" to the console
function LogTitleHeading {
    echo -e "${DISPLAY_TITLE_HEADING}  ${1}${DISPLAY_DEFAULT}"
}

# Logs an title "MESSAGE" to the console
function LogTitleMessage {
    echo -e "${DISPLAY_TITLE_MESSAGE}  ${1}${DISPLAY_DEFAULT}"
}

# Logs a warning "HEADING" to the console
function LogWarningHeading {
    echo -e "${DISPLAY_WARNING_HEADING}  ${1}${DISPLAY_DEFAULT}"
}

# Logs a warning "MESSAGE" to the console
function LogWarningMessage {
    echo -e "${DISPLAY_WARNING_MESSAGE}  ${1}${DISPLAY_DEFAULT}"
}
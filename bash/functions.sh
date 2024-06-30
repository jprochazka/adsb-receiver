#!/bin/bash

# Detect if a package is installed and if not attempt to install it.
function CheckPackage {
    ATTEMPT=1
    MAXATTEMPTS=5
    WAITTIME=5

    while (( ${ATTEMPT} -le `(($MAXATTEMPTS + 1))` )); do

        # If the maximum attempts has been reached...
        if [[ "${ATTEMPT}" -gt "${MAXATTEMPTS}" ]] ; then
            echo -e ""
            echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
            echo -e "  UNABLE TO INSTALL A REQUIRED PACKAGE."
            echo -e "  SETUP HAS BEEN TERMINATED!"
            echo -e ""
            echo -e "\e[93mThe package \"$1\" could not be installed in ${MAXATTEMPTS} attempts.\e[39m"
            echo -e ""
            exit 1
        fi

        # Check if the package is already installed.
        printf "\e[94m  Checking if the package $1 is installed..."
        if [[ $(dpkg-query -W -f='${STATUS}' $1 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then

            # If this is not the first attempt at installing this package...
            if [[ ${ATTEMPT} -gt 1 ]] ; then
                echo -e "\e[91m  \e[5m[INSTALLATION ATTEMPT FAILED]\e[25m"
                echo -e "\e[94m  Attempting to Install the package $1 again in ${WAITTIME} seconds (ATTEMPT ${ATTEMPT} OF ${MAXATTEMPTS})..."
                sleep ${WAITTIME}
            else
                echo -e "\e[91m [NOT INSTALLED]"
                echo -e "\e[94m  Installing the package $1..."
            fi

            # Attempt to install the required package.
            echo -e "\e[97m"
            ATTEMPT=$((ATTEMPT+1))
            sudo apt-get install -y $1
            echo -e "\e[39m"
        else
            # The package appears to be installed.
            echo -e "\e[92m [OK]\e[39m"
            break
        fi
    done
}

# Blacklist DVB-T drivers for RTL-SDR devices.
function BlacklistModules {
    if [[ ! -f /etc/modprobe.d/rtlsdr-blacklist.conf ]] || [[ `cat /etc/modprobe.d/rtlsdr-blacklist.conf | wc -l` -lt 9 ]] ; then
        echo -en "\e[94m  Blacklisting unwanted RTL-SDR kernel modules so they are not loaded...\e[97m"
        sudo tee ${RECEIVER_KERNEL_MODULE_BLACKLIST}  > /dev/null <<EOF
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

# Use sed to locate the "SWITCH" then replace the "VALUE", the portion after the equals sign, in the specified "FILE".
# This function will replace the value assigned to a specific switch contained within a file.
function ChangeSwitch {
    sudo sed -i -re "s/($1)\s+\w+/\1 $2/g" $3
}

# Use sed to locate the "KEY" then replace the "VALUE", the portion after the equals sign, in the specified "FILE".
# This function should work with any configuration file with settings formated as KEY="VALUE".
function ChangeConfig {
    sudo sed -i -e "s/\($1 *= *\).*/\1\"$2\"/" $3
}

# Use sed to locate the "KEY" then read the "VALUE", the portion after the equals sign, in the specified "FILE".
# This function should work with any configuration file with settings formated as KEY="VALUE".
function GetConfig {
    echo `sed -n "/^$1 *= *\"\(.*\)\"$/s//\1/p" $2`
}

# Use sed to locate the "KEY" then comment out the line containing it in the specified "FILE".
function CommentConfig {
    if [[ ! `grep -cFx "#${1}" $2` -gt 0 ]] ; then
        sudo sed -i "/${1}/ s/^/#/" $2
    fi
}

# Use sed to locate the "KEY" then uncomment the line containing it in the specified "FILE".
function UncommentConfig {
    if [[ `grep -cFx "#${1}" $2` -gt 0 ]] ; then
        sudo sed -i "/#${1}*/ s/#*//" $2
    fi
}


## GATHER HARDWARE AND OPERATING INFORMATION

# Detect Platform.
function Check_Platform () {
    if [[ -z "${HARDWARE_PLATFORM}" ]] ; then
        echo -en "\e[94m  Detecting hardware platform...\e[97m"
        if [[ `egrep -c "^Hardware.*: BCM" /proc/cpuinfo` -gt 0 ]] ; then
            export HARDWARE_PLATFORM="RPI"
        elif [[ `egrep -c "^Hardware.*: Allwinner sun4i/sun5i Families$" /proc/cpuinfo` -gt 0 ]] ; then
            export HARDWARE_PLATFORM="CHIP"
        else
            export HARDWARE_PLATFORM="unknown"
        fi
    fi
}

# Detect Hardware Revision.
function Check_Hardware () {
    if [[ -z "${HARDWARE_REVISION}" ]] ; then
        echo -en "\e[94m  Detecting Hardware revision...\e[97m"
        export HARDWARE_REVISION=`grep "^Revision" /proc/cpuinfo | awk '{print $3}'`
    fi
}

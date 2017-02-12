#!/bin/bash

#####################################################################################
#                                  ADS-B RECEIVER                                   #
#####################################################################################
#                                                                                   #
# This script is not meant to be executed directly.                                 #
# Instead execute install.sh to begin the installation process.                     #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                   #
# Copyright (c) 2016-2017, Joseph A. Prochazka & Romeo Golf                         #
#                                                                                   #
# Permission is hereby granted, free of charge, to any person obtaining a copy      #
# of this software and associated documentation files (the "Software"), to deal     #
# in the Software without restriction, including without limitation the rights      #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell         #
# copies of the Software, and to permit persons to whom the Software is             #
# furnished to do so, subject to the following conditions:                          #
#                                                                                   #
# The above copyright notice and this permission notice shall be included in all    #
# copies or substantial portions of the Software.                                   #
#                                                                                   #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR        #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,          #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE       #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER            #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,     #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE     #
# SOFTWARE.                                                                         #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

### VARIABLES

RECEIVER_ROOT_DIRECTORY="${PWD}"
RECEIVER_BASH_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/bash"
RECEIVER_BUILD_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/build"

# Component specific variables.
COMPONENT_BUILD_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/ogn"
COMPONENT_GITHUB="https://github.com/glidernet/ogn-rf"
COMPONENT_WEBSITE="http://wiki.glidernet.org"
COMPONENT_NAME="RTLSDR-OGN"
COMPONENT_DESC="is a combined decoder and feeder for the Open Glider Network which focuses on tracking gilders and other GA aircraft equipped with FLARM, FLARM-compatible devices or OGN tracker"
COMPONENT_RADIO="Please note that a dedicated RTL-SDR dongle is required to use this decoder"

# Component service script variables.
COMPONENT_SERVICE_NAME="rtlsdr-ogn"
COMPONENT_SERVICE_SCRIPT_URL="http://download.glidernet.org/common/service/rtlsdr-ogn"
COMPONENT_SERVICE_SCRIPT_NAME="${COMPONENT_SERVICE_NAME}"
COMPONENT_SERVICE_SCRIPT_PATH="/etc/init.d/${COMPONENT_SERVICE_NAME}"
COMPONENT_SERVICE_CONFIG_PATH="/etc/${COMPONENT_SERVICE_SCRIPT_NAME}.conf"

### INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

# To be moved to functions.sh...

#################################################################################
# Blacklist DVB-T drivers for RTL-SDR devices.

function BlacklistModules () {
    RECEIVER_MODULE_BLACKLIST="/etc/modprobe.d/rtlsdr-blacklist.conf"
    if [[ ! -f "${RECEIVER_MODULE_BLACKLIST}" ]] || [[ `cat ${RECEIVER_MODULE_BLACKLIST} | wc -l` -lt 9 ]] ; then
        echo -en "\e[33m  Installing blacklist to prevent unwanted kernel modules from being loaded...\e[97m"
        sudo tee ${RECEIVER_MODULE_BLACKLIST}  > /dev/null <<EOF
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
        echo -en "\e[33m  Kernel module blacklist already installed...\e[97m"
    fi
}

#################################################################################
# Calculate RTL-SDR device error rate.

function CalibrateTuner () {
    # Attempt to calibrate the specified tuner using GSM frequencies.
    if [[ -n "$1" ]] ; then
        COMPONENT_CALIBRATION_DEVICE_ID="$1"
        # GSM Band is GSM850 in US and GSM900 elsewhere, should probably try to figure this out...
        COMPONENT_CALIBRATION_GSM_BAND="GSM900"
        # Check if gain has been specified, otherwise set to 40.
        if [[ -n "${OGN_GSM_GAIN}" ]] ; then
            COMPONENT_CALIBRATION_GAIN="${OGN_GSM_GAIN}"
        else
            COMPONENT_CALIBRATION_GAIN="40"
        fi
        # Use the Kalibrate 'kal' binary if available.
        if [[ -x "`which kal`" ]] ; then
            echo -en "\e[33m  Calibrating RTL-SDR device using Kalibrate, this may take up to 10 minutes...\e[97m"
            COMPONENT_CALIBRATION_GSM_SCAN=`kal -d "${COMPONENT_CALIBRATION_DEVICE_ID}" -g "${COMPONENT_CALIBRATION_GAIN}" -s ${COMPONENT_CALIBRATION_GSM_BAND} 2>&1 | grep "power:" | sort -n -r -k 7 | grep -m1 "power:"`
            COMPONENT_CALIBRATION_GSM_FREQ=`echo ${COMPONENT_CALIBRATION_GSM_SCAN} | awk '{print $3}' | sed -e 's/(//g' -e 's/MHz//g'`
            COMPONENT_CALIBRATION_GSM_CHAN=`echo ${COMPONENT_CALIBRATION_GSM_SCAN} | awk '{print $2}'`
            if [[ -n "${COMPONENT_CALIBRATION_GSM_CHAN}"  ]] ; then
                COMPONENT_CALIBRATION_ERROR=`kal -d "${COMPONENT_CALIBRATION_DEVICE_ID}" -g "${COMPONENT_CALIBRATION_GAIN}" -c "${COMPONENT_CALIBRATION_GSM_CHAN}" 2>&1 | grep "^average absolute error:" | awk '{print int($4)}' | sed -e 's/\-//g'`
            else
                echo -en "\e[33m  Unable to calibrate RTL-SDR device \"${COMPONENT_CALIBRATION_DEVICE_ID}\" on channel \"${COMPONENT_CALIBRATION_GSM_CHAN}\"...\e[97m"
                false
            fi
        # Otherwise use the gsm_scan binary provided with the OGN package.
        elif [[ -x "${COMPONENT_PROJECT_DIRECTORY}/gsm_scan" ]] ; then
            echo -en "\e[33m  Calibrating RTL-SDR device using gsm_scan, this may take up to 20 minutes...\e[97m"
            if [[ "${COMPONENT_CALIBRATION_GSM_BAND}" = "GSM850" ]] ; then
                COMPONENT_CALIBRATION_GSM_OPTS="--gsm850"
            else
                COMPONENT_CALIBRATION_GSM_OPTS=""
            fi
            COMPONENT_CALIBRATION_GSM_SCAN=`gsm_scan --device "${COMPONENT_CALIBRATION_DEVICE_ID}" --gain "${COMPONENT_CALIBRATION_GAIN}" ${COMPONENT_CALIBRATION_GSM_OPTS} 2>&1 | grep "^[0-9]*\.[0-9]*MHz:" | sed -e 's/dB://g' -e 's/\+//g' | sort -n -r -k 2 | grep -m1 "ppm"`
            COMPONENT_CALIBRATION_GSM_FREQ=`echo ${COMPONENT_CALIBRATION_GSM_SCAN} | awk '{print $1}' | sed -e 's/00MHz://g'`
            COMPONENT_CALIBRATION_ERROR=`echo ${COMPONENT_CALIBRATION_GSM_SCAN} | awk '{print int(($3 + $4)/2)}'`
        else
            # No suitable tool found to perform cailbrations.
            echo -en "\e[33m  Unable to calibrate RTL-SDR device \"${COMPONENT_CALIBRATION_DEVICE_ID}\"...\e[97m"
            false
        fi
    else
        # No tuner specified.
        echo -en "\e[33m  Unable calibrate due to invalid or no RTL-SDR device specified...\e[97m"
        false
    fi
}

## SET INSTALLATION VARIABLES

# Source the automated install configuration file if this is an automated installation.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] && [[ -s "${RECEIVER_CONFIGURATION_FILE}" ]] ; then
    source ${RECEIVER_CONFIGURATION_FILE}
fi

### BEGIN SETUP

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    clear
    echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
fi
echo -e ""
echo -e "\e[92m  Setting up ${COMPONENT_NAME}..."
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${COMPONENT_NAME} Setup" --yesno "${COMPONENT_NAME} ${COMPONENT_DESC}.\n\n${COMPONENT_RADIO}.\n\n${COMPONENT_WEBSITE}\n\nContinue setup by installing ${COMPONENT_NAME}?" 18 78
    if [[ $? -eq 1 ]] ; then
        # Setup has been halted by the user.
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo -e ""
        echo -e "\e[93m  ------------------------------------------------------------------------------"
        echo -e "\e[92m  ${COMPONENT_NAME} setup halted.\e[39m"
        echo -e ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
    fi
fi

### CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to fulfill dependencies for ${COMPONENT_NAME}...\e[97m"
echo -e ""
# Required by install script.
CheckPackage git
CheckPackage python-dev
CheckPackage python3-dev
# Required for USB SDR devices.
CheckPackage librtlsdr-dev
CheckPackage libusb-1.0-0-dev
CheckPackage rtl-sdr
# Required by component.
CheckPackage curl
CheckPackage libconfig9
CheckPackage libconfig-dev
CheckPackage libcurl3
CheckPackage libfftw3-3
CheckPackage libfftw3-dev
CheckPackage libjpeg8
CheckPackage libjpeg-dev
CheckPackage lynx
CheckPackage procserv
CheckPackage telnet

echo -e ""
echo -e "\e[95m  Configuring this device to run the ${COMPONENT_NAME} binaries...\e[97m"
echo -e ""

### BLACKLIST UNWANTED RTL-SDR MODULES FROM BEING LOADED

# Use function to install kernel module blacklist.
BlacklistModules
CheckReturnCode

### CHECK FOR EXISTING INSTALL AND IF SO STOP IT

# Attempt to stop using systemd.
if [[ "`sudo systemctl status ${COMPONENT_SERVICE_NAME} 2>&1 | egrep -c "Active: active"`" -gt 0 ]] ; then
    echo -e "\e[33m  Stopping the ${COMPONENT_NAME} service..."
    ACTION=$(sudo systemctl stop ${COMPONENT_SERVICE_NAME} 2>&1)
    CheckReturnCode
fi

# And the init script.
if [[ -f "${COMPONENT_SERVICE_SCRIPT_PATH}" ]] ; then
    echo -en "\e[33m  Stopping the ${COMPONENT_NAME} service...\e[97m"
    ACTION=$(sudo ${COMPONENT_SERVICE_SCRIPT_PATH} stop 2>&1)
    CheckReturnCode
fi

# Finally a failsafe process kill.
PIDS=`ps -efww | egrep "(\./ogn-rf\ |\./ogn-decode\ )" | awk -vpid=$$ '$2 != pid { print $2 }' | tr '\n\r' ' '`
if [ ! -z "${PIDS}" ]; then
    echo -en "\e[33m  Killing any running ${COMPONENT_NAME} processes...\e[97m"
    ACTION=$(sudo kill -9 ${PIDS})
    CheckReturnCode
fi
unset PIDS

### ASSIGN RTL-SDR DONGLES

# Count the number of tuners available.
RECEIVER_TUNERS_AVAILABLE=`rtl_eeprom 2>&1 | grep -c "^\s*[0-9]*:\s"`

# Start counting the number of tuners required with one for this component.
RECEIVER_TUNERS_REQUIRED="1"

# Check which components are installed.
echo -e "\e[95m  Checking for existing decoders...\e[97m"
echo -e ""

# Check if any of the dump1090 forks are installed.
echo -en "\e[94m  Checking if any of the dump1090 packages are installed...\e[97m"
# Check if the dump1090-mutability package is installed.
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
    RECEIVER_TUNERS_REQUIRED=$((RECEIVER_TUNERS_REQUIRED+1))
    DUMP1090_IS_INSTALLED="true"
# Check if the dump1090-fa package is installed.
elif [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
    RECEIVER_TUNERS_REQUIRED=$((RECEIVER_TUNERS_REQUIRED+1))
    DUMP1090_IS_INSTALLED="true"
else
    DUMP1090_IS_INSTALLED="false"
fi
CheckReturnCode

# Check if the dump978 binaries exist.
echo -en "\e[94m  Checking if the dump978 binaries exist on this device...\e[97m"
if [[ -f "${RECEIVER_BUILD_DIRECTORY}/dump978/dump978" ]] && [[ -f "${RECEIVER_BUILD_DIRECTORY}/dump978/uat2text" ]] && [[ -f "${RECEIVER_BUILD_DIRECTORY}/dump978/uat2esnt" ]] && [[ -f "${RECEIVER_BUILD_DIRECTORY}/dump978/uat2json" ]] ; then
    RECEIVER_TUNERS_REQUIRED=$((RECEIVER_TUNERS_REQUIRED+1))
    DUMP978_IS_INSTALLED="true"
else
    DUMP978_IS_INSTALLED="false"
fi
CheckReturnCode

# Multiple RTL_SDR tuners found, check if device specified for this decoder is present.
if [[ "${RECEIVER_TUNERS_AVAILABLE}" -gt 1 ]] ; then
    # If a device has been specified by serial number then try to match that with the currently detected tuners.
    if [[ -n "${OGN_DEVICE_SERIAL}" ]] ; then
        for DEVICE_ID in `seq 0 ${RECEIVER_TUNERS_AVAILABLE}` ; do
            if [[ `rtl_eeprom -d ${DEVICE_ID} 2>&1 | grep -c "Serial number:\s*${OGN_DEVICE_SERIAL}$" ` -eq 1 ]] ; then
                echo -en "\e[33m  RTL-SDR with Serial \"${OGN_DEVICE_SERIAL}\" found at device \"${OGN_DEVICE_ID}\" and will be assigned to ${COMPONENT_NAME}...\e[97m"
                OGN_DEVICE_ID=${DEVICE_ID}
            fi
        done
        # If no match for this serial then assume the highest numbered tuner will be used.
        if [[ -z "${OGN_DEVICE_ID}" ]] ; then
            echo -en "\e[33m  RTL-SDR with Serial \"${OGN_DEVICE_SERIAL}\" not found, assigning device \"${RECEIVER_TUNERS_AVAILABLE}\" to ${COMPONENT_NAME}...\e[97m"
            OGN_DEVICE_ID=${RECEIVER_TUNERS_AVAILABLE}
        fi
    # Or if a device has been specified by device ID then confirm this is currently detected.
    elif [[ -n "${OGN_DEVICE_ID}" ]] ; then
        if [[ `rtl_eeprom -d ${OGN_DEVICE_ID} 2>&1 | grep -c "^\s*${OGN_DEVICE_ID}:\s"` -eq 1 ]] ; then
            echo -en "\e[33m  RTL-SDR device \"${OGN_DEVICE_ID}\" found and will be assigned to ${COMPONENT_NAME}...\e[97m"
        # If no match for this serial then assume the highest numbered tuner will be used.
        else
            echo -en "\e[33m  RTL-SDR device \"${OGN_DEVICE_ID}\" not found, assigning device \"${RECEIVER_TUNERS_AVAILABLE}\" to ${COMPONENT_NAME}...\e[97m"
            OGN_DEVICE_ID=${RECEIVER_TUNERS_AVAILABLE}
        fi
    # Failing that configure it with device ID 0.
    else
        echo -en "\e[33m  No RTL-SDR device specified, assigning device \"0\" to ${COMPONENT_NAME}...\e[97m"
        OGN_DEVICE_ID=${RECEIVER_TUNERS_AVAILABLE}
    fi
# Single tuner present so assign device 0 and stop any other running decoders, or at least dump1090-mutablity for a default install.
elif [[ "${RECEIVER_TUNERS_AVAILABLE}" -eq 1 ]] ; then
    echo -en "\e[33m  Single RTL-SDR device \"0\" detected and assigned to ${COMPONENT_NAME}...\e[97m"
    OGN_DEVICE_ID="0"
    ACTION=$(sudo /etc/init.d/dump1090-mutability stop 2>&1)
# No tuners present so assign device 0 and stop any other running decoders, or at least dump1090-mutablity for a default install.
elif [[ "${RECEIVER_TUNERS_AVAILABLE}" -lt 1 ]] ; then
    echo -en "\e[33m  No RTL-SDR device detected so ${COMPONENT_NAME} will be assigned device \"0\"...\e[97m"
    OGN_DEVICE_ID="0"
    ACTION=$(sudo /etc/init.d/dump1090-mutability stop 2>&1)
fi
CheckReturnCode

# If either dump1090 or dump978 is installed we must assign RTL-SDR dongles for each of these decoders.
if [[ "${DUMP1090_IS_INSTALLED}" = "true" ]] || [[ "${DUMP978_IS_INSTALLED}" = "true" ]] ; then
    # Check if Dump1090 is installed.
    if [[ "${DUMP1090_IS_INSTALLED}" = "true" ]] ; then
        # The dump1090-mutability package appear to be installed.
        if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
            # Ask the user which USB device is to be used for dump1090.
            DUMP1090_DEVICE_ID=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump1090 RTL-SDR Dongle" --nocancel --inputbox "\nEnter the ID for your dump1090 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
            while [[ -z "${DUMP1090_DEVICE_ID}" ]] ; do
                DUMP1090_DEVICE_ID=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump1090 RTL-SDR Dongle (REQUIRED)" --nocancel --inputbox "\nEnter the ID for your dump1090 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
            done
        else
            ### GET DONGLE ID FROM THE INSTALLATION CONFIGURATION FILE...
            true
        fi
    fi
    # Check if Dump978 is installed.
    if [[ "${DUMP978_IS_INSTALLED}" = "true" ]] ; then
        # The dump978 binaries appear to exist on this device.
        if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
            # Ask the user which USB device is to be use for dump978.
            DUMP978_DEVICE_ID=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump978 RTL-SDR Dongle" --nocancel --inputbox "\nEnter the ID for your dump978 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
            while [[ -z "${DUMP978_DEVICE_ID}" ]] ; do
                DUMP978_DEVICE_ID=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump978 RTL-SDR Dongle (REQUIRED)" --nocancel --inputbox "\nEnter the ID for your dump978 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
            done
        else
            ### GET DONGLE ID FROM THE INSTALLATION CONFIGURATION FILE...
            true
        fi
    fi
    #
    if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
        # Ask the user which USB device is to be use for RTL-SDR OGN.
        RTLSDROGN_DEVICE_ID=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "RTL-SDR OGN RTL-SDR Dongle" --nocancel --inputbox "\nEnter the ID for your RTL-SDR OGN RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
        while [[ -z "${RTLSDROGN_DEVICE_ID}" ]] ; do
            RTLSDROGN_DEVICE_ID=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "RTL-SDR OGN RTL-SDR Dongle (REQUIRED)" --nocancel --inputbox "\nEnter the ID for your RTL-SDR OGN RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
        done
    else
        ### GET DONGLE ID FROM THE INSTALLATION CONFIGURATION FILE...
        true
    fi
    # Assign the specified RTL-SDR dongle to dump1090.
    if [[ "${DUMP1090_IS_INSTALLED}" = "true" ]] && [[ -n "${DUMP1090_DEVICE_ID}" ]] ; then
        echo -e "\e[94m  Assigning RTL-SDR dongle \"${DUMP1090_DEVICE_ID}\" to dump1090-mutability...\e[97m"
        ChangeConfig "DEVICE" ${DUMP1090_DEVICE_ID} "/etc/default/dump1090-mutability"
        echo -e "\e[94m  Reloading dump1090-mutability...\e[97m"
        echo -e ""
        ACTION=$(sudo /etc/init.d/dump1090-mutability force-reload 2>&1)
        echo -e ""
    fi
    # Assign the specified RTL-SDR dongle to dump978
    if [[ "${DUMP978_IS_INSTALLED}" = "true" ]] && [[ -n "${DUMP978_DEVICE_ID}" ]] ; then
        echo -e "\e[94m  Assigning RTL-SDR dongle \"${DUMP978_DEVICE_ID}\" to dump978...\e[97m"
        ### ADD DEVICE TO MAINTENANCE SCRIPT...
        echo -e "\e[94m  Reloading dump978...\e[97m"
        ### KILL EXISTING DUMP978 PROCESSES...
        echo -e ""
        ### RESTART DUMP978...
        echo -e ""
    fi
fi


### DOWNLOAD AND SET UP THE BINARIES

# Create build directory if not already present.
if [[ ! -d "${COMPONENT_BUILD_DIRECTORY}" ]] ; then
    echo -en "\e[33m  Creating build directory \"\e[37m${COMPONENT_BUILD_DIRECTORY}\e[33m\"...\e[97m"
    ACTION=$(mkdir -vp ${COMPONENT_BUILD_DIRECTORY} 2>&1)
    CheckReturnCode
fi

# Enter the build directory.
if [[ ! "${PWD}" = "${COMPONENT_BUILD_DIRECTORY}" ]] ; then
    echo -en "\e[33m  Entering build directory \"\e[37m${COMPONENT_BUILD_DIRECTORY}\e[33m\"...\e[97m"
    cd ${COMPONENT_BUILD_DIRECTORY} 2>&1
    ACTION=${PWD}
    CheckReturnCode
fi

# Detect CPU Architecture.
Check_CPU
CheckReturnCode

# Identify the correct binaries to download.
case ${CPU_ARCHITECTURE} in
    "armv6l")
        # Raspberry Pi 1.
        COMPONENT_BINARY_URL="http://download.glidernet.org/rpi-gpu/rtlsdr-ogn-bin-RPI-GPU-latest.tgz"
        ;;
    "armv7l")
        # Raspberry Pi 2 onwards.
        COMPONENT_BINARY_URL="http://download.glidernet.org/arm/rtlsdr-ogn-bin-ARM-latest.tgz"
        ;;
    "x86_64")
        # 64 Bit.
        COMPONENT_BINARY_URL="http://download.glidernet.org/x64/rtlsdr-ogn-bin-x64-latest.tgz"
        ;;
    *)
        # 32 Bit (default install if no others matched).
        COMPONENT_BINARY_URL="http://download.glidernet.org/x86/rtlsdr-ogn-bin-x86-latest.tgz"
        ;;
esac

# Attempt to download and extract binaries.
if [[ `echo "${COMPONENT_BINARY_URL}" | grep -c "^http"` -gt 0 ]] ; then
    # Download binaries.
    echo -en "\e[33m  Downloading ${COMPONENT_NAME} binaries for \"\e[37m${CPU_ARCHITECTURE}\e[33m\" architecture...\e[97m"
    COMPONENT_BINARY_FILE=`echo ${COMPONENT_BINARY_URL} | awk -F "/" '{print $NF}'`
    ACTION=$(curl -L ${COMPONENT_BINARY_URL} -o ${COMPONENT_BUILD_DIRECTORY}/${COMPONENT_BINARY_FILE} 2>&1)
    CheckReturnCode
    # Extract binaries.
    echo -en "\e[33m  Extracting ${COMPONENT_NAME} package \"\e[37m${COMPONENT_BINARY_FILE}\e[33m\"...\e[97m"
    ACTION=$(tar -vxzf "${COMPONENT_BUILD_DIRECTORY}/${COMPONENT_BINARY_FILE}" -C "${COMPONENT_BUILD_DIRECTORY}" 2>&1)
    CheckReturnCode
else
    # Unable to download bimary due to invalid URL.
    echo -e "\e[33m  Error invalid COMPONENT_BINARY_URL \"\e[37m${COMPONENT_BINARY_URL}\e[33m\"...\e[97m"
    exit 1
fi

# Change to component work directory for post-build actions.
COMPONENT_PROJECT_DIRECTORY="${COMPONENT_BUILD_DIRECTORY}/rtlsdr-ogn"
if [[ -d "${COMPONENT_PROJECT_DIRECTORY}" ]] ; then
    cd ${COMPONENT_PROJECT_DIRECTORY} 2>&1
else
    echo -e "\e[33m  Error unable to access \"\e[37m${COMPONENT_PROJECT_DIRECTORY}\e[33m\"...\e[97m"
    exit 1
fi

# Create named pipe if required.
if [[ ! -p "${COMPONENT_PROJECT_DIRECTORY}/ogn-rf.fifo" ]] ; then
    echo -en "\e[33m  Creating named pipe...\e[97m"
    ACTION=$(sudo mkfifo ${COMPONENT_PROJECT_DIRECTORY}/ogn-rf.fifo 2>&1)
    CheckReturnCode
fi

# Set file permissions.
echo -en "\e[33m  Setting proper file permissions...\e[97m"
COMPONENT_SETUID_BINARIES="gsm_scan ogn-rf rtlsdr-ogn"
COMPONENT_SETUID_COUNT="0"
for COMPONENT_SETUID_BINARY in ${COMPONENT_SETUID_BINARIES} ; do
    COMPONENT_SETUID_COUNT=$((COMPONENT_SETUID_COUNT+1))
    ACTION=$(sudo chown -v root ${COMPONENT_SETUID_BINARY} 2>&1)
    ACTION=$(sudo chmod -v a+s  ${COMPONENT_SETUID_BINARY} 2>&1)
done
# And check that the file permissions have been applied.
if [[ `ls -l ${COMPONENT_SETUID_BINARIES} | grep -c "\-rwsr-sr-x"` -eq "${COMPONENT_SETUID_COUNT}" ]] ; then
    true
else
    false
fi
CheckReturnCode

# Creat GPU device if required.
if [[ ! -c "${COMPONENT_PROJECT_DIRECTORY}/gpu_dev" ]] ; then
    # The mknod major_version number varies with kernel version.
    echo -en "\e[33m  Getting the version of the kernel currently running...\e[97m"
    KERNEL=`uname -r`
    KERNEL_VERSION=`echo ${KERNEL} | cut -d \. -f 1`.`echo ${KERNEL} | cut -d \. -f 2`
    CheckReturnCode
    # Check if the currently running kernel is version 4.1 or higher.
    if [[ "${KERNEL_VERSION}" < 4.1 ]] ; then
        # Kernel is older than version 4.1.
        echo -en "\e[33m  Executing mknod for older kernels...\e[97m"
        ACTION=$(sudo mknod ${COMPONENT_PROJECT_DIRECTORY}/gpu_dev c 100 0 2>&1)
    else
        # Kernel is version 4.1 or newer.
        echo -en "\e[33m  Executing mknod for newer kernels...\e[97m"
        ACTION=$(sudo mknod ${COMPONENT_PROJECT_DIRECTORY}/gpu_dev c 249 0 2>&1)
    fi
    CheckReturnCode
fi

## GATHER INFORMATION FROM USER

# Skip over this dialog if this installation is set to be automated.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # Explain to the user that the receiver's latitude and longitude is required.
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Receiver Latitude and Longitude" --msgbox "Your receivers latitude and longitude are required for distance calculations, you will now be asked to supply these values for your receiver.\n\nIf you do not have this information you can obtain it using the web based \"Geocode by Address\" utility hosted on another of the lead developers websites:\n\n  https://www.swiftbyte.com/toolbox/geocode" 16 78
fi

# Latitude.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # Ask the user to confirm the receivers latitude, this will be populated with the latitude configured in dump1090-mutability.
    COMPONENT_LATITUDE_TITLE="Receiver Latitude"
    while [[ -z "${COMPONENT_LATITUDE}" ]] ; do
        if [[ -n "${RECEIVER_LATITUDE}" ]] ; then
            COMPONENT_LATITUDE="${RECEIVER_LATITUDE}"
            COMPONENT_LATITUDE_SOURCE="the ${RECEIVER_PROJECT_TITLE} configuration file"
        elif [[ -s /etc/default/dump1090-mutability ]] && [[ `grep -c "^LAT" "/etc/default/dump1090-mutability"` -gt 0 ]] ; then
            COMPONENT_LATITUDE=$(GetConfig "LAT" "/etc/default/dump1090-mutability")
            COMPONENT_LATITUDE_SOURCE="the Dump1090-mutability configuration file"
        fi
        if [[ -n "${COMPONENT_LATITUDE_SOURCE}" ]] ; then
            COMPONENT_LATITUDE_SOURCE_MESSAGE=", the value below is obtained from ${COMPONENT_LATITUDE_SOURCE}"
        fi
        COMPONENT_LATITUDE=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --backtitle "${BACKTITLETEXT}" --title "${COMPONENT_LATITUDE_TITLE}" --nocancel --inputbox "\nPlease confirm your receiver's latitude${COMPONENT_LATITUDE_SOURCE_MESSAGE}:\n" 10 78 -- "${COMPONENT_LATITUDE}" 3>&1 1>&2 2>&3)
        COMPONENT_LATITUDE_TITLE="Receiver Latitude (REQUIRED)"
    done
else
    # Use receiver coordinates if already know, otherwise populate with dummy values to ensure valid config generation.
    if [[ -n "${RECEIVER_LATITUDE}" ]] ; then
        COMPONENT_LATITUDE="${RECEIVER_LATITUDE}"
    elif [[ -s /etc/default/dump1090-mutability ]] && [[ `grep -c "^LAT" "/etc/default/dump1090-mutability"` -gt 0 ]] ; then
        COMPONENT_LATITUDE=$(GetConfig "LAT" "/etc/default/dump1090-mutability")
    else
        COMPONENT_LATITUDE="0.000"
    fi
fi

# Longitude.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # Ask the user to confirm the receivers longitude, this will be populated with the longitude configured in dump1090-mutability.
    COMPONENT_LONGITUDE_TITLE="Receiver Longitude"
    while [[ -z "${COMPONENT_LONGITUDE}" ]] ; do
        if [[ -n "${RECEIVER_LONGITUDE}" ]] ; then
            COMPONENT_LONGITUDE="${RECEIVER_LONGITUDE}"
            COMPONENT_LONGITUDE_SOURCE="the ${RECEIVER_PROJECT_TITLE} configuration file"
        elif [[ -s /etc/default/dump1090-mutability ]] && [[ `grep -c "^LON" "/etc/default/dump1090-mutability"` -gt 0 ]] ; then
            COMPONENT_LONGITUDE=$(GetConfig "LON" "/etc/default/dump1090-mutability")
            COMPONENT_LONGITUDE_SOURCE="the Dump1090-mutability configuration file"
        fi
        if [[ -n "${COMPONENT_LONGITUDE_SOURCE}" ]] ; then
            COMPONENT_LONGITUDE_SOURCE_MESSAGE=", the value below is obtained from ${COMPONENT_LONGITUDE_SOURCE}"
        fi
        COMPONENT_LONGITUDE=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --backtitle "${BACKTITLETEXT}" --title "${COMPONENT_LONGITUDE_TITLE}" --nocancel --inputbox "\nPlease confirm your receiver's longitude${COMPONENT_LONGITUDE_SOURCE_MESSAGE}:\n" 10 78 -- "${COMPONENT_LONGITUDE}" 3>&1 1>&2 2>&3)
        COMPONENT_LONGITUDE_TITLE="Receiver Longitude (REQUIRED)"
    done
else
    # Use receiver coordinates if already know, otherwise populate with dummy values to ensure valid config generation.
    if [[ -n "${RECEIVER_LONGITUDE}" ]] ; then
        COMPONENT_LONGITUDE="${RECEIVER_LONGITUDE}"
    elif [[ -s /etc/default/dump1090-mutability ]] && [[ `grep -c "^LON" "/etc/default/dump1090-mutability"` -gt 0 ]] ; then
        COMPONENT_LONGITUDE=$(GetConfig "LON" "/etc/default/dump1090-mutability")
    else
        COMPONENT_LONGITUDE="0.000"
    fi
fi

# Altitude.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # Ask the user to confirm the receivers altitude, this will be populated with an altutude value derived from the configured LAT/LON.
    COMPONENT_ALTITUDE_TITLE="Receiver Altitude"
    while [[ -z "${COMPONENT_ALTITUDE}" ]] ; do
        if [[ -n "${COMPONENT_LATITUDE}" ]] && [[ -n "${COMPONENT_LONGITUDE}" ]] ; then
            COMPONENT_ALTITUDE=$(curl -s https://maps.googleapis.com/maps/api/elevation/json?locations=${COMPONENT_LATITUDE},${COMPONENT_LONGITUDE} | python -c "import json,sys;obj=json.load(sys.stdin);print obj['results'][0]['elevation'];" | awk '{printf("%.2f\n", $1)}')
            COMPONENT_ALTITUDE_SOURCE="Google; however should be increased to reflect your antennas height above ground level"
        fi
        if [[ -n "${COMPONENT_ALTITUDE_SOURCE}" ]] ; then
            COMPONENT_ALTITUDE_SOURCE_MESSAGE=", the value below is obtained from ${COMPONENT_ALTITUDE_SOURCE}"
        fi
        COMPONENT_ALTITUDE=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --backtitle "${BACKTITLETEXT}" --title "${COMPONENT_ALTITUDE_TITLE}" --nocancel --inputbox "\nPlease confirm your receiver's altitude in meters${COMPONENT_ALTITUDE_SOURCE_MESSAGE}:\n" 10 78 -- "${COMPONENT_ALTITUDE}" 3>&1 1>&2 2>&3)
        COMPONENT_ALTITUDE_TITLE="Receiver Altitude (REQUIRED)"
    done
else
    # Use receiver coordinates if already know, otherwise populate with dummy values to ensure valid config generation.
    if [[ -n "${RECEIVER_ALTITUDE}" ]] ; then
        COMPONENT_ALTITUDE="${RECEIVER_ALTITUDE}"
    elif [[ -n "${COMPONENT_LATITUDE}" ]] && [[ -n "${COMPONENT_LONGITUDE}" ]] ; then
        COMPONENT_ALTITUDE=$(curl -s https://maps.googleapis.com/maps/api/elevation/json?locations=${RECEIVER_LATITUDE},${RECEIVER_LONGITUDE} | python -c "import json,sys;obj=json.load(sys.stdin);print obj['results'][0]['elevation'];" | awk '{printf("%.2f\n", $1)}')
    else
        COMPONENT_ALTITUDE="0.000"
    fi
fi

# Check for component specific variables, otherwise populate with dummy values to ensure valid config generation.

# Set receiver callsign for this decoder.
# This should be between 3 and 9 alphanumeric charactors, with no punctuation.
# Please see:   http://wiki.glidernet.org/receiver-naming-convention
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    COMPONENT_RECEIVER_NAME_TITLE="Receiver Name"
    while [[ -z "${COMPONENT_RECEIVER_NAME}" ]]  || [[ `echo -n ${COMPONENT_RECEIVER_NAME} | wc -c` -gt 9 ]] ; do
        if [[ -n "${COMPONENT_SERVICE_CONFIG_PATH}" ]] && [[ `grep -c "ogn-decode" ${COMPONENT_SERVICE_CONFIG_PATH}` -gt 0 ]] ; then
            COMPONENT_RECEIVER_NAME=`grep "ogn-decode" ${COMPONENT_SERVICE_CONFIG_PATH} | awk '{print $5}' | awk -F "." '{print $1}' `
        fi
        COMPONENT_RECEIVER_NAME=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --backtitle "${BACKTITLETEXT}" --title "${COMPONENT_RECEIVER_NAME_TITLE}" --nocancel --inputbox "\nPlease confirm your receiver name, this should be between 3 and 9 alphanumeric charactors and contain no punctuation or special charactors:\n" 10 78 -- "${COMPONENT_RECEIVER_NAME}" 3>&1 1>&2 2>&3)
        COMPONENT_RECEIVER_NAME_TITLE="Receiver Name (REQUIRED)"
    done
else
    if [[ -n "${OGN_RECEIVER_NAME}" ]] ; then
        COMPONENT_RECEIVER_NAME=`echo ${OGN_RECEIVER_NAME} | tr -cd '[:alnum:]' | cut -c -9`
    else
        COMPONENT_RECEIVER_NAME=`hostname -s | tr -cd '[:alnum:]' | cut -c -9`
    fi
fi

# Geoid separation: FLARM transmits GPS altitude, APRS uses means Sea level altitude.
# To find value you can check: 	http://geographiclib.sourceforge.net/cgi-bin/GeoidEval
# Need to derive from co-ords but will set to altitude as a placeholders.
if [[ -z "${OGN_GEOID}" ]] ; then
    if [[ -n "${COMPONENT_ALTITUDE}" ]] ; then
        OGN_GEOID="${COMPONENT_ALTITUDE}"
    else
        OGN_GEOID="0"
    fi
fi

# Future option to enable OGN whitelist.
if [[ -z "${OGN_WHITELIST}" ]] ; then
    OGN_WHITELIST="0"
fi

# Gain value for RTL-SDR device.
if [[ -z "${OGN_GSM_GAIN}" ]] ; then
    if [[ -n "${COMPONENT_CALIBRATION_GAIN}" ]] ; then
        OGN_GSM_GAIN="${COMPONENT_CALIBRATION_GAIN}"
    else
        OGN_GSM_GAIN="40"
    fi
fi

# Ask if user would like to calibrate the tuner.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Tuner Calibration" --yesno "Would you like to calibrate the device \"${OGN_DEVICE_ID}\" which has been configured for use with ${COMPONENT_NAME}?\n\nPlease be aware this may take between 10 and 20 minutes." 8 78
    if [[ $? -eq 0 ]] ; then
        # User would like to calibrate the tuner.
        COMPONENT_DO_CALIBRATE="true"
    fi
elif [[ -z "${OGN_FREQ_CORR}" ]] || [[ -z "${OGN_GSM_FREQ}" ]] ; then
    COMPONENT_DO_CALIBRATE="true"
fi

# Calculate RTL-SDR device error rate.
if [[ "${COMPONENT_DO_CALIBRATE}" ]] ; then
    # Requires a device to be specified.
    if [[ -n "${OGN_DEVICE_ID}" ]] ; then
        CalibrateTuner ${OGN_DEVICE_ID}
    else
        echo -en "\e[33m  The specified device is either invalid or does not exist...\e[97m"
        false
    fi
    CheckReturnCode
fi

# Set Frequency Correction.
if [[ -z "${OGN_FREQ_CORR}" ]] ; then
    # Using the value derived from calibration, if available.
    if [[ -n "${COMPONENT_CALIBRATION_ERROR}" ]] ; then
        OGN_FREQ_CORR="${COMPONENT_CALIBRATION_ERROR}"
    else
        OGN_FREQ_CORR="0"
    fi
fi

# Set GSM Reference signal frequency.
if [[ -z "${OGN_GSM_FREQ}" ]] ; then
    # Using the value derived from calibration, if available.
    if [[ -n "${COMPONENT_CALIBRATION_GSM_FREQ}" ]] ; then
       OGN_GSM_FREQ="${COMPONENT_CALIBRATION_GSM_FREQ}"
    else
       OGN_GSM_FREQ="958"
    fi
fi

### CREATE THE CONFIGURATION FILE

# Update existing or create new config file.
if [[ -n "${COMPONENT_RECEIVER_NAME}" ]] ; then
    COMPONENT_CONFIG_FILE_NAME="${COMPONENT_RECEIVER_NAME}.conf"
    if [[ -s "${COMPONENT_PROJECT_DIRECTORY}/${COMPONENT_CONFIG_FILE_NAME}" ]] ; then
        echo -en "\e[33m  Updating existing ${COMPONENT_NAME} config file at \"\e[37m${COMPONENT_CONFIG_FILE_NAME}\e[33m\"...\e[97m"
    else
        echo -en "\e[33m  Generating new ${COMPONENT_NAME} config file as \"\e[37m${COMPONENT_CONFIG_FILE_NAME}\e[33m\"...\e[97m"
    fi
    sudo tee ${COMPONENT_PROJECT_DIRECTORY}/${COMPONENT_CONFIG_FILE_NAME} > /dev/null 2>&1 <<EOF
#########################################################
#                                                       #
#              CONFIGURATION FILE BASED ON              #
#                                                       #
#  http://wiki.glidernet.org/wiki:receiver-config-file  #
#                                                       #
#########################################################
#
RF:
{
  FreqCorr	= ${OGN_FREQ_CORR};             	# [ppm]		Some R820T sticks require a correction of up to 80ppm, measure it with gsm_scan.
  Device   	= ${OGN_DEVICE_ID};      	   	# 		Device index of the USB RTL-SDR device to be selected.
#  DeviceSerial	= ${OGN_DEVICE_SERIAL}; 	 	# char[12] 	Serial number of the USB RTL-SDR device to be selected.
  GSM:
  {
    CenterFreq	= ${OGN_GSM_FREQ};   		# [MHz]		Fnd the best GSM frequency with gsm_scan.
    Gain	= ${OGN_GSM_GAIN};   	 	# [0.1 dB] 	RF input gain for frequency calibration, beware GSM signals are very strong.
  } ;
} ;
#
Position:
{
  Latitude	= ${COMPONENT_LATITUDE};    		# [deg] 	Antenna coordinates in decimal degrees.
  Longitude	= ${COMPONENT_LONGITUDE};           	# [deg] 	Antenna coordinates in decimal degrees.
  Altitude	= ${COMPONENT_ALTITUDE};   		# [m]   	Altitude above sea leavel.
  GeoidSepar	= ${OGN_GEOID};           	# [m]   	Geoid separation: FLARM transmits GPS altitude, APRS uses means Sea level altitude.
} ;
#
APRS:
{
  Call		= "${COMPONENT_RECEIVER_NAME}";  	# char[9]	APRS callsign (max. 9 characters).
} ;
#
DDB:
{
  UseAsWhitelist = ${OGN_WHITELIST};     	     	# [0|1] 	Setting to 1 enforces strict opt in to OGN Whitelist.
} ;
#
EOF
fi

# Update ownership of new config file.
ACTION=$(sudo chown -v pi:pi ${COMPONENT_PROJECT_DIRECTORY}/${COMPONENT_CONFIG_FILE_NAME} 2>&1)
CheckReturnCode

### INSTALL AS A SERVICE

# Install service script.
if [[ -f "${COMPONENT_SERVICE_SCRIPT_NAME}" ]] ; then
    # Check for local copy of service script.
    if [[ `grep -c "conf=${COMPONENT_SERVICE_CONFIG_PATH}" ${COMPONENT_SERVICE_SCRIPT_NAME}` -eq 1 ]] ; then
        echo -en "\e[33m  Installing service script at \"\e[37m${COMPONENT_SERVICE_SCRIPT_PATH}\e[33m\"...\e[97m"
        ACTION=$(sudo cp -v ${COMPONENT_SERVICE_SCRIPT_NAME} ${COMPONENT_SERVICE_SCRIPT_PATH} 2>&1)
        ACTION=$(sudo chmod -v +x ${COMPONENT_SERVICE_SCRIPT_PATH} 2>&1)
    else
        echo -en "\e[33m  Invalid service script \"\e[37m${COMPONENT_SERVICE_SCRIPT_NAME}\e[33m\"...\e[97m"
        false
    fi
elif [[ -n "${COMPONENT_SERVICE_SCRIPT_URL}" ]] ; then
    # Otherwise attempt to download service script.
    if [[ `echo ${COMPONENT_SERVICE_SCRIPT_URL} | grep -c "^http"` -gt 0 ]] ; then
        echo -en "\e[33m  Downloading service script to \"\e[37m${COMPONENT_SERVICE_SCRIPT_PATH}\e[33m\"...\e[97m"
        ACTION=$(sudo curl -L ${COMPONENT_SERVICE_SCRIPT_URL} -o ${COMPONENT_SERVICE_SCRIPT_PATH} 2>&1)
        ACTION=$(sudo chmod -v +x ${COMPONENT_SERVICE_SCRIPT_PATH} 2>&1)
    else
        echo -en "\e[33m  Invalid service script url \"\e[37m${COMPONENT_SERVICE_SCRIPT_URL}\e[33m\"...\e[97m"
        false
    fi
else
    # Otherwise error if unable to use local or downloaded service script
    echo -en "\e[33m  Unable to install service script at \"\e[37m${COMPONENT_SERVICE_SCRIPT_PATH}\e[33m\"...\e[97m"
    false
fi
CheckReturnCode

# Generate and install service script configuration file.
if [[ -n "${COMPONENT_SERVICE_CONFIG_PATH}" ]] ; then
    echo -en "\e[33m  Creating service config file \"\e[37m${COMPONENT_SERVICE_CONFIG_PATH}\e[33m\"...\e[97m"
    sudo tee ${COMPONENT_SERVICE_CONFIG_PATH} > /dev/null 2>&1 <<EOF
#shellbox configuration file
#Starts commands inside a "box" with a telnet-like server.
#Contact the shell with: telnet <hostname> <port>
#Syntax:
#port  user     directory                 command       args
50000  pi ${COMPONENT_PROJECT_DIRECTORY}    ./ogn-rf     ${COMPONENT_RECEIVER_NAME}.conf
50001  pi ${COMPONENT_PROJECT_DIRECTORY}    ./ogn-decode ${COMPONENT_RECEIVER_NAME}.conf
EOF
    ACTION=$(sudo chown -v pi:pi ${COMPONENT_SERVICE_CONFIG_PATH} 2>&1)
else
    echo -en "\e[33m  Unable to create service config file \"\e[37m${COMPONENT_SERVICE_CONFIG_PATH}\e[33m\"...\e[97m"
    false
fi
CheckReturnCode

# Potentially obsolete tuner detection code.
if [[ "${RECEIVER_TUNERS_AVAILABLE}" -lt 2 ]] ; then
    # Less than 2 tuners present so we must stop other services before starting this decoder.
    echo -en "\e[33m  Found less than 2 tuners so other decoders will be disabled...\e[97m"
    SERVICES_DISABLE="dump1090-mutability"
    for SERVICE in ${SERVICES_DISABLE} ; do
        if [[ `sudo systemctl status ${SERVICE} | grep -c "Active: active"` -gt 0 ]] ; then
            ACTION=$(sudo update-rc.d ${SERVICE} disable 2>&1)
        fi
    done
    CheckReturnCode
fi

# Configure component as a service.
echo -en "\e[33m  Configuring ${COMPONENT_NAME} as a service...\e[97m"
ACTION=$(sudo update-rc.d ${COMPONENT_SERVICE_NAME} defaults 2>&1)
CheckReturnCode

# (re)start the component service.
if [[ "`sudo systemctl status ${COMPONENT_SERVICE_NAME} 2>&1 | egrep -c "Active: active"`" -gt 0 ]] ; then
    echo -e "\e[33m  Restarting the ${COMPONENT_NAME} service..."
    ACTION=$(sudo systemctl restart ${COMPONENT_SERVICE_NAME} 2>&1)
else
    echo -e "\e[33m  Starting the ${COMPONENT_NAME} service..."
    ACTION=$(sudo systemctl start ${COMPONENT_SERVICE_NAME} 2>&1)
fi
CheckReturnCode

### SETUP COMPLETE

# Return to the project root directory.
echo -en "\e[94m  Returning to ${RECEIVER_PROJECT_TITLE} root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1
ACTION=${PWD}
CheckReturnCode

echo -e "\e[93m  ------------------------------------------------------------------------------\n"
echo -e "\e[92m  ${COMPONENT_NAME} setup is complete.\e[39m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

# Unset component specific variables.
for VARIABLE in `grep "[A-Z]=" $0 | awk -F "=" '{print $1}'| sed -e 's/ //g' | grep "^COMPONENT_" | sort | uniq` ; do
    unset ${VARIABLE}
done

exit 0

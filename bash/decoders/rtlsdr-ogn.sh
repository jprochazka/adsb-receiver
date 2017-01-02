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
# Copyright (c) 2016, Joseph A. Prochazka & Romeo Golf                              #
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

RECIEVER_ROOT_DIRECTORY="${PWD}"
RECEIVER_BASH_DIRECTORY="${RECIEVER_ROOT_DIRECTORY}/bash"
RECEIVER_BUILD_DIRECTORY="${RECIEVER_ROOT_DIRECTORY}/build"

# Decoder specific variables.
DECODER_BUILD_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/ogn"
DECODER_GITHUB="https://github.com/glidernet/ogn-rf"
DECODER_WEBSITE="http://wiki.glidernet.org"
DECODER_NAME="RTLSDR-OGN"
DECODER_DESC="is the Open Glider Network decoder which focuses on tracking aircraft equipped with FLARM, FLARM-compatible devices or OGN tracker"
DECODER_RADIO="Please note that a dedicated RTL-SDR dongle is required to use this decoder"

# Decoder service script variables.
DECODER_SERVICE_SCRIPT_NAME="rtlsdr-ogn"
DECODER_SERVICE_SCRIPT_URL="http://download.glidernet.org/common/service/rtlsdr-ogn"
DECODER_SERVICE_SCRIPT_PATH="/etc/init.d/${DECODER_SERVICE_SCRIPT_NAME}"
DECODER_SERVICE_SCRIPT_CONFIG="/etc/${DECODER_SERVICE_SCRIPT_NAME}.conf"

## INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

# Should be moved to functions.sh.
function CheckReturnCode {
    LINE=$((`stty size | awk '{print $1}'` - 1))
    COL=$((`stty size | awk '{print $2}'` - 8))
    tput cup "${LINE}" "${COL}"
    if [[ $? -eq 0 ]] ; then
        echo -e "\e[97m[\e[32mDone\e[97m]\e[39m\n"
    else
        echo -e "\e[97m[\e[31mError\e[97m]\e[39m\n"
    fi
}

# Source the automated install configuration file if this is an automated installation.
if [[ ${RECEIVER_AUTOMATED_INSTALL} = "true" ]] ; then
    source ${RECEIVER_CONFIGURATION_FILE}
fi

## BEGIN SETUP

if [[ ${RECEIVER_AUTOMATED_INSTALL} = "false" ]] ; then
    clear
    echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
fi
echo -e ""
echo -e "\e[92m  Setting up ${DECODER_NAME}..."
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""
if [[ ${RECEIVER_AUTOMATED_INSTALL} = "false" ]] ; then
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${DECODER_NAME} Setup" --yesno "${DECODER_NAME} ${DECODER_DESC}.\n\n${DECODER_RADIO}.\n\n${DECODER_WEBSITE}\n\nContinue setup by installing ${DECODER_NAME}?" 14 78
    if [[ $? -eq 1 ]] ; then
        # Setup has been halted by the user.
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo -e ""
        echo -e "\e[93m  ------------------------------------------------------------------------------"
        echo -e "\e[92m  ${DECODER_NAME} setup halted.\e[39m"
        echo -e ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
    fi
fi


## ASK FOR DEVICE ASSIGNMENTS

# Check if the dump1090-mutability package is installed.
echo -e "\e[95m  Checking for existing decoders...\e[97m"
echo -e ""

# Check if the dump1090-mutability package is installed.
echo -e "\e[94m  Checking if the dump1090-mutability package is installed...\e[97m"
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
    DUMP1090_IS_INSTALLED="true"
else
    DUMP1090_IS_INSTALLED="false"
fi

# Check if the dump978 binaries exist.
echo -e "\e[94m  Checking if the dump978 binaries exist on this device...\e[97m"
if [[ -f ${RECEIVER_BUILD_DIRECTORY}/dump978/dump978 ]] && [[ -f ${RECEIVER_BUILD_DIRECTORY}/dump978/uat2text ]] && [[ -f ${RECEIVER_BUILD_DIRECTORY}/dump978/uat2esnt ]] && [[ -f ${RECEIVER_BUILD_DIRECTORY}/dump978/uat2json ]] ; then
    DUMP978_IS_INSTALLED="true"
else
    DUMP978_IS_INSTALLED="false"
fi

# If either dump1090 or dump978 is installed we must assign RTL-SDR dongles for each of these decoders.
if [[ ${DUMP1090_IS_INSTALLED} = "true" ]] || [[${DUMP978_IS_INSTALLED} = "true" ]] ; then
    # Check if Dump1090 is installed.
    if [[ ${DUMP1090_IS_INSTALLED} = "true" ]] ; then
        # The dump1090-mutability package appear to be installed.
        if [[ ${RECEIVER_AUTOMATED_INSTALL} = "false" ]] ; then
            # Ask the user which USB device is to be used for dump1090.
            DUMP1090_USB_DEVICE=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump1090 RTL-SDR Dongle" --nocancel --inputbox "\nEnter the ID for your dump1090 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
            while [[ -z ${DUMP1090_USB_DEVICE} ]] ; do
                DUMP1090_USB_DEVICE=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump1090 RTL-SDR Dongle (REQUIRED)" --nocancel --inputbox "\nEnter the ID for your dump1090 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
            done
        else
            ### GET DONGLE ID FROM THE INSTALLATION CONFIGURATION FILE...
            true
        fi
    fi
    # Check if Dump978 is installed.
    if [[ ${DUMP978_IS_INSTALLED} = "true" ]] ; then
        # The dump978 binaries appear to exist on this device.
        if [[ ${RECEIVER_AUTOMATED_INSTALL} = "false" ]] ; then
            # Ask the user which USB device is to be use for dump978.
            DUMP978_USB_DEVICE=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump978 RTL-SDR Dongle" --nocancel --inputbox "\nEnter the ID for your dump978 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
            while [[ -z ${DUMP978_USB_DEVICE} ]] ; do
                DUMP978_USB_DEVICE=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump978 RTL-SDR Dongle (REQUIRED)" --nocancel --inputbox "\nEnter the ID for your dump978 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
            done
        else
            ### GET DONGLE ID FROM THE INSTALLATION CONFIGURATION FILE...
            true
        fi
    fi
    #
    if [[ ${RECEIVER_AUTOMATED_INSTALL} = "false" ]] ; then
        # Ask the user which USB device is to be use for RTL-SDR OGN.
        RTLSDROGN_USB_DEVICE=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "RTL-SDR OGN RTL-SDR Dongle" --nocancel --inputbox "\nEnter the ID for your RTL-SDR OGN RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
        while [[ -z ${DUMP978_USB_DEVICE} ]] ; do
            RTLSDROGN_USB_DEVICE=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "RTL-SDR OGN RTL-SDR Dongle (REQUIRED)" --nocancel --inputbox "\nEnter the ID for your RTL-SDR OGN RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
        done
    else
        ### GET DONGLE ID FROM THE INSTALLATION CONFIGURATION FILE...
        true
    fi
    # Assign the specified RTL-SDR dongle to dump1090.
    if [[ ${DUMP1090_IS_INSTALLED} = "true" ]] && [[ -n ${DUMP1090_USB_DEVICE} ]] ; then
        echo -e "\e[94m  Assigning RTL-SDR dongle \"DUMP1090_USB_DEVICE\" to dump1090-mutability...\e[97m"
        ChangeConfig "DEVICE" ${DUMP1090_USB_DEVICE} "/etc/default/dump1090-mutability"
        echo -e "\e[94m  Reloading dump1090-mutability...\e[97m"
        echo -e ""
        ACTION=$(sudo /etc/init.d/dump1090-mutability force-reload)
        echo -e ""
    fi
    # Assign the specified RTL-SDR dongle to dump978
    if [[ ${DUMP978_IS_INSTALLED} = "true" ]] && [[ -n ${DUMP978_USB_DEVICE} ]] ; then
        echo -e "\e[94m  Assigning RTL-SDR dongle \"${DUMP978_USB_DEVICE}\" to dump978...\e[97m"
        ### ADD DEVICE TO MAINTENANCE SCRIPT...
        echo -e "\e[94m  Reloading dump978...\e[97m"
        ### KILL EXISTING DUMP978 PROCESSES...
        echo -e ""
        ### RESTART DUMP978...
        echo -e ""
    fi
fi

### ASSIGN RTL-SDR DONGLE FOR RTL-SDR OGN...

# Potentially obselse tuner detection code.
# Check for multiple tuners...
TUNER_COUNT=`rtl_eeprom 2>&1 | grep -c "^\s*[0-9]*:\s"`

# Multiple RTL_SDR tuners found, check if device specified for this decoder is present.
if [[ ${TUNER_COUNT} -gt 1 ]] ; then
    # If a device has been specified by serial number then try to match that with the currently detected tuners.
    if [[ -n ${OGN_DEVICE_SERIAL} ]] ; then
        for DEVICE_ID in `seq 0 ${TUNER_COUNT}` ; do
            if [[ `rtl_eeprom -d ${DEVICE_ID} 2>&1 | grep -c "Serial number:\s*${OGN_DEVICE_SERIAL}$" ` -eq 1 ]] ; then
                echo -en "\e[33m  RTL-SDR with Serial \"${OGN_DEVICE_SERIAL}\" found at device \"${OGN_DEVICE_ID}\" and will be assigned to ${DECODER_NAME}...\e[97m"
                OGN_DEVICE_ID=${DEVICE_ID}
            fi
        done
        # If no match for this serial then assume the highest numbered tuner will be used.
        if [[ -z ${OGN_DEVICE_ID} ]] ; then
            echo -en "\e[33m  RTL-SDR with Serial \"${OGN_DEVICE_SERIAL}\" not found, assigning device \"${TUNER_COUNT}\" to ${DECODER_NAME}...\e[97m"
            OGN_DEVICE_ID=${TUNER_COUNT}
        fi
    # Or if a device has been specified by device ID then confirm this is currently detected.
    elif [[ -n ${OGN_DEVICE_ID} ]] ; then
        if [[ `rtl_eeprom -d ${OGN_DEVICE_ID} 2>&1 | grep -c "^\s*${OGN_DEVICE_ID}:\s"` -eq 1 ]] ; then
            echo -en "\e[33m  RTL-SDR device \"${OGN_DEVICE_ID}\" found and will be assigned to ${DECODER_NAME}...\e[97m"
        # If no match for this serial then assume the highest numbered tuner will be used.
        else
            echo -en "\e[33m  RTL-SDR device \"${OGN_DEVICE_ID}\" not found, assigning device \"${TUNER_COUNT}\" to ${DECODER_NAME}...\e[97m"
            OGN_DEVICE_ID=${TUNER_COUNT}
        fi
    # Failing that configure it with device ID 0.
    else
        echo -en "\e[33m  No RTL-SDR device specified, assigning device \"0\" to ${DECODER_NAME}...\e[97m"
        OGN_DEVICE_ID=${TUNER_COUNT}
    fi
# Single tuner present so assign device 0 and stop any other running decoders, or at least dump1090-mutablity for a default install.
elif [[ ${TUNER_COUNT} -eq 1 ]] ; then
    echo -en "\e[33m  Single RTL-SDR device \"0\" detected and assigned to ${DECODER_NAME}...\e[97m"
    OGN_DEVICE_ID="0"
    ACTION=$(sudo /etc/init.d/dump1090-mutability stop)
# No tuners present so assign device 0 and stop any other running decoders, or at least dump1090-mutablity for a default install.
elif [[ ${TUNER_COUNT} -lt 1 ]] ; then
    echo -en "\e[33m  No RTL-SDR device detected so ${DECODER_NAME} will be assigned device \"0\"...\e[97m"
    OGN_DEVICE_ID="0"
    ACTION=$(sudo /etc/init.d/dump1090-mutability stop)
fi
CheckReturnCode


## CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to fulfill dependencies for ${DECODER_NAME}...\e[97m"
echo -e ""
# Required by install script.
CheckPackage git
# Required for USB SDR devices.
CheckPackage librtlsdr-dev
CheckPackage libusb-1.0-0-dev
CheckPackage rtl-sdr
# Required for Kalibrate.
CheckPackage autoconf
CheckPackage automake
CheckPackage libfftw3-3
CheckPackage libfftw3-dev
CheckPackage libtool
# Required for RTLSDR-OGN.
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
echo -e "\e[95m  Configuring this device to run the ${DECODER_NAME} binaries...\e[97m"
echo -e ""

## BLACKLIST UNWANTED RTL-SDR MODULES FROM BEING LOADED

if [[ ! -f /etc/modprobe.d/rtlsdr-blacklist.conf ]] ; then
    echo -en "\e[33m  Stopping unwanted kernel modules from being loaded..."
    sudo tee /etc/modprobe.d/rtlsdr-blacklist.conf  > /dev/null <<EOF
blacklist dvb_usb_rtl28xxu
blacklist dvb_usb_v2
blacklist rtl_2830
blacklist rtl_2832
blacklist r820t
blacklist rtl2830
blacklist rtl2832
EOF
    CheckReturnCode
fi

## CHECK FOR EXISTING INSTALL AND IF SO STOP IT

if [[ -f ${DECODER_SERVICE_SCRIPT_PATH} ]] ; then
    echo -en "\e[33m  Stopping the ${DECODER_NAME} service..."
    ACTION=$(sudo service ${DECODER_SERVICE_SCRIPT_NAME} stop)
    CheckReturnCode
fi

### DOWNLOAD AND SET UP THE BINARIES

# Create build directory if not already present.
if [[ ! -d ${DECODER_BUILD_DIRECTORY} ]] ; then
    echo -en "\e[33m  Creating build directory \"\e[37m${DECODER_BUILD_DIRECTORY}\e[33m\"..."
    mkdir ${DECODER_BUILD_DIRECTORY}
    CheckReturnCode
fi

# Enter the build directory.
if [[ ! ${PWD} == ${DECODER_BUILD_DIRECTORY} ]] ; then
    echo -en "\e[33m  Entering build directory \"\e[37m${DECODER_BUILD_DIRECTORY}\e[33m\"..."
    cd ${DECODER_BUILD_DIRECTORY}
    CheckReturnCode
fi

# Download and compile Kalibrate.
if [[ true ]] ; then
    KALIBRATE_GITHUB_URL="https://github.com/steve-m/kalibrate-rtl.git"
    KALIBRATE_GITHUB_URL_SHORT=`echo ${KALIBRATE_GITHUB_URL} | sed -e 's/http:\/\///g' -e 's/https:\/\///g' | tr '[A-Z]' '[a-z]'`
    KALIBRATE_GITHUB_PROJECT=`echo ${KALIBRATE_GITHUB_URL} | awk -F "/" '{print $NF}' | sed -e 's/\.git$//g'`
    KALIBRATE_PROJECT_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/${KALIBRATE_GITHUB_PROJECT}"
    # Check if Kalibrate is already present and located where we would expect it to be.
    if [[ -x `which kal` ]] && [[ -d "${KALIBRATE_PROJECT_DIRECTORY}" ]] ; then
        # Then perhaps we can update from github.
        echo -en "\e[33m  Updating ${KALIBRATE_GITHUB_PROJECT} from \"\e[37m${KALIBRATE_GITHUB_URL_SHORT}\e[33m\"..."
        cd ${KALIBRATE_PROJECT_DIRECTORY}
        ACTION=$(git remote update)
        if [[ `git status -uno | grep -c "is behind"` -gt 0 ]] ; then
            # Local branch is behind remote so update.
            ACTION=$(git pull)
            # And remove previous binaries.
            ACTION=$(sudo make clean)
            DO_INSTALL_FROM_GIT="true"
        fi
    else
        # Otherwise clone from github.
        echo -en "\e[33m  Building ${KALIBRATE_GITHUB_PROJECT} from \"\e[37m${KALIBRATE_GITHUB_URL_SHORT}\e[33m\"..."
        ACTION=$(git clone https://${KALIBRATE_GITHUB_URL_SHORT} ${DECODER_BUILD_DIRECTORY})
        DO_INSTALL_FROM_GIT="true"
    fi
    if [[ ${DO_INSTALL_FROM_GIT} = "true" ]] ; then
        # And build from source
        cd ${KALIBRATE_PROJECT_DIRECTORY}
        if [[ -x "bootstrap" ]] ; then
            ACTION=$(./bootstrap)
        fi
        if [[ -x "configure" ]] ; then
            ACTION=$(./configure)
        fi
        ACTION=$(make)
        if [[ `grep -c "^install:" Makefile` -gt 0 ]] ; then
            ACTION=$(sudo make install)
        fi
    fi
    CheckReturnCode
    unset DO_INSTALL_FROM_GIT
    cd ${DECODER_BUILD_DIRECTORY}
fi

# Detect CPU Architecture.
if [[ -z ${CPU_ARCHITECTURE} ]] ; then
    echo -en "\e[33m  Detecting CPU architecture..."
    CPU_ARCHITECTURE=`uname -m | tr -d "\n\r"`
    CheckReturnCode
fi

# Identify the correct binaries to download.
case ${CPU_ARCHITECTURE} in
    "armv6l")
        # Raspberry Pi 1
        DECODER_BINARY_URL="http://download.glidernet.org/rpi-gpu/rtlsdr-ogn-bin-RPI-GPU-latest.tgz"
        ;;
    "armv7l")
        # Raspberry Pi 2 onwards
        DECODER_BINARY_URL="http://download.glidernet.org/arm/rtlsdr-ogn-bin-ARM-latest.tgz"
        ;;
    "x86_64")
        # 64 Bit
        DECODER_BINARY_URL="http://download.glidernet.org/x64/rtlsdr-ogn-bin-x64-latest.tgz"
        ;;
    *)
        # 32 Bit (default install if no others matched)
        DECODER_BINARY_URL="http://download.glidernet.org/x86/rtlsdr-ogn-bin-x86-latest.tgz"
        ;;
esac

# Attempt to download and extract binaries.
if [[ `echo "${DECODER_BINARY_URL}" | grep -c "^http"` -gt 0 ]] ; then
    # Download binaries.
    echo -en "\e[33m  Downloading ${DECODER_NAME} binaries for \"\e[37m${CPU_ARCHITECTURE}\e[33m\" architecture..."
    DECODER_BINARY_FILE=`echo ${DECODER_BINARY_URL} | awk -F "/" '{print $NF}'`
    ACTION=$(curl -s ${DECODER_BINARY_URL} -o ${DECODER_BUILD_DIRECTORY}/${DECODER_BINARY_FILE})
    CheckReturnCode
    # Extract binaries.
    echo -en "\e[33m  Extracting ${DECODER_NAME} package \"\e[37m${DECODER_BINARY_FILE}\e[33m\"..."
    ACTION=$(tar xzf ${DECODER_BUILD_DIRECTORY}/${DECODER_BINARY_FILE} -C ${DECODER_BUILD_DIRECTORY})
    CheckReturnCode
else
    # Unable to download bimary due to invalid URL.
    echo -e "\e[33m  Error invalid DECODER_BINARY_URL \"${DECODER_BINARY_URL}\"..."
    exit 1
fi

# Change to DECODER work directory for post-build actions.
DECODER_PROJECT_DIRECTORY="${DECODER_BUILD_DIRECTORY}/rtlsdr-ogn"
if [[ -d ${DECODER_PROJECT_DIRECTORY} ]] ; then
    cd ${DECODER_PROJECT_DIRECTORY}
else
    echo -e "\e[33m  Error unable to access \"${DECODER_PROJECT_DIRECTORY}\"..."
    exit 1
fi

# Create named pipe if required.
if [[ ! -p ogn-rf.fifo ]] ; then
    echo -en "\e[33m  Creating named pipe..."
    ACTION=$(sudo mkfifo ogn-rf.fifo)
    CheckReturnCode
fi

# Set file permissions.
echo -en "\e[33m  Setting proper file permissions..."
DECODER_SETUID_BINARIES="gsm_scan ogn-rf rtlsdr-ogn"
DECODER_SETUID_COUNT="0"
for DECODER_SETUID_BINARY in ${DECODER_SETUID_BINARIES} ; do
    DECODER_SETUID_COUNT=$((DECODER_SETUID_COUNT+1))
    ACTION=$(sudo chown root ${DECODER_SETUID_BINARY})
    ACTION=$(sudo chmod a+s  ${DECODER_SETUID_BINARY})
done
# And check that the file permissions have been applied.
if [[ `ls -l ${DECODER_SETUID_BINARIES} | grep -c "\-rwsr-sr-x"` -eq ${DECODER_SETUID_COUNT} ]] ; then
    true
else
    false
fi
CheckReturnCode

# Creat GPU device if required.
if [[ ! -c gpu_dev ]] ; then
    # Check if kernel v4.1 or higher is being used.
    echo -en "\e[33m  Getting the version of the kernel currently running..."
    KERNEL=`uname -r`
    KERNEL_VERSION="`echo ${KERNEL} | cut -d \. -f 1`.`echo ${KERNEL} | cut -d \. -f 2`"
    CheckReturnCode
    if [[ ${KERNEL_VERSION} < 4.1 ]] ; then
        # Kernel is older than version 4.1.
        echo -en "\e[33m  Executing mknod for older kernels...\e[97m"
        ACTION=$(sudo mknod gpu_dev c 100 0)
    else
        # Kernel is version 4.1 or newer.
        echo -en "\e[33m  Executing mknod for newer kernels...\e[97m"
        ACTION=$(sudo mknod gpu_dev c 249 0)
    fi
    CheckReturnCode
fi

# Calculate RTL-SDR device error rate
if [[ -z "${OGN_FREQ_CORR}" ]] || [[ -z "${OGN_GSM_FREQ}" ]] ; then
    # Attempt to calibrate if required values are not provided.
    # May take 10+ minutes, should probably confirm if user wishes to calibrate.
    # GSM Band is GSM850 in US and GSM900 elsewhere.
    DERIVED_GSM_BAND="GSM900"
    DERIVED_GAIN="40"
    if [[ -x "`which kal`" ]] ; then
        echo -en "\e[33m  Calibrating RTL-SDR device using Kalibrate...\e[97m"
        DERIVED_GSM_SCAN=`kal -d "${OGN_DEVICE_ID}" -g "${DERIVED_GAIN}" -s ${DERIVED_GSM_BAND} 2>&1 | grep "power:" | sort -n -r -k 7 | grep -m1 "power:"`
        DERIVED_GSM_FREQ=`echo ${DERIVED_GSM_SCAN} | awk '{print $3}' | sed -e 's/(//g' -e 's/MHz//g'`
        DERIVED_GSM_CHAN=`echo ${DERIVED_GSM_SCAN} | awk '{print $2}'`
        DERIVED_ERROR=`kal -d "${OGN_DEVICE_ID}" -g "${DERIVED_GAIN}" -c "${DERIVED_GSM_CHAN}" 2>&1 | grep "^average absolute error:" | awk '{print int($4)}' | sed -e 's/\-//g'`
    elif [[ -x "${DECODER_PROJECT_DIRECTORY}/gsm_scan" ]] ; then
        echo -en "\e[33m  Calibrating RTL-SDR device using gsm_scan...\e[97m"
        if [[ "${DERIVED_GSM_BAND}" = "GSM850" ]] ; then
            DERIVED_GSM_SCAN=`gsm_scan --device "${OGN_DEVICE_ID}" --gain "${DERIVED_GAIN}" --gsm850 | grep "^[0-9]*\.[0-9]*MHz:" | sed -e 's/dB://g' -e 's/\+//g' | sort -n -r -k 2 | grep -m1 "ppm"`
        else
            DERIVED_GSM_SCAN=`gsm_scan --device "${OGN_DEVICE_ID}" --gain "${DERIVED_GAIN}" | grep "^[0-9]*\.[0-9]*MHz:" | sed -e 's/dB://g' -e 's/\+//g' | sort -n -r -k 2 | grep -m1 "ppm"`
        fi
        DERIVED_GSM_FREQ=`echo ${DERIVED_GSM_SCAN} | awk '{print $1}' | sed -e 's/00MHz://g'`
        DERIVED_ERROR=`echo ${DERIVED_GSM_SCAN} | awk '{print int(($3 + $4)/2)}'`
    else
        echo -en "\e[33m  Unable to calibrate RTL-SDR device...\e[97m"

    fi
    CheckReturnCode
fi

## CREATE THE CONFIGURATION FILE

# Use receiver coordinates if already know, otherwise populate with dummy values to ensure valid config generation.

# Latitude.
if [[ -z ${OGN_LATITUDE} ]] ; then
    if [[ -n ${RECEIVER_LATITUDE} ]] ; then
        OGN_LATITUDE="${RECEIVER_LATITUDE}"
    else
        OGN_LATITUDE="0.000"
    fi
fi

# Longitude.
if [[ -z ${OGN_LONGITUDE} ]] ; then
    if [[ -n ${RECEIVER_LONGITUDE} ]] ; then
        OGN_LONGITUDE="${RECEIVER_LONGITUDE}"
    else
        OGN_LONGITUDE="0.000"
    fi
fi

# Altitude.
if [[ -z ${OGN_ALTITUDE} ]] ; then
    if [[ -n ${RECIEVER_ALTITUDE} ]] ; then
        OGN_ALTITUDE="${RECIEVER_ALTITUDE}"
    else
        OGN_ALTITUDE="0"
    fi
fi

# Geoid separation: FLARM transmits GPS altitude, APRS uses means Sea level altitude.
# To find value you can check: 	http://geographiclib.sourceforge.net/cgi-bin/GeoidEval
# Need to derive from co-ords but will set to altitude as a placeholders.
if [[ -z ${OGN_GEOID} ]] ; then
    if [[ -n ${RECIEVER_ALTITUDE} ]] ; then
        OGN_GEOID="${RECIEVER_ALTITUDE}"
    else
        OGN_GEOID="0"
    fi
fi

# Set receiver callsign for this decoder.
# This should be between 3 and 9 alphanumeric charactors, with no punctuation.
# Please see: 	http://wiki.glidernet.org/receiver-naming-convention
if [[ -z ${OGN_RECEIVER_NAME} ]] ; then
    if [[ -n ${RECEIVERNAME} ]] ; then
        OGN_RECEIVER_NAME=`echo ${RECEIVERNAME} | tr -cd '[:alnum:]' | cut -c -9`
    else
        OGN_RECEIVER_NAME=`hostname -s | tr -cd '[:alnum:]' | cut -c -9`
    fi
fi

# Check for decoder specific variable, if not set then populate with dummy values to ensure valid config generation.

# Frequency Correction
if [[ -z ${OGN_FREQ_CORR} ]] ; then
    if [[ -n "${DERIVED_ERROR}" ]] ; then
        OGN_FREQ_CORR="${DERIVED_ERROR}"
    else
        OGN_FREQ_CORR="30"
    fi
fi

# GSM Reference signal frequency.
if [[ -z ${OGN_GSM_FREQ} ]] ; then
    if [[ -n "${DERIVED_GSM_FREQ}" ]] ; then
       OGN_GSM_FREQ="${DERIVED_GSM_FREQ}"
    else
       OGN_GSM_FREQ="958"
    fi
fi

# Gain value for RTL-SDR device.
if [[ -z ${OGN_GSM_GAIN} ]] ; then
    if [[ -n "${DERIVED_GAIN}" ]] ; then
        OGN_GSM_GAIN="${DERIVED_GAIN}"
    else
        OGN_GSM_GAIN="40"
    fi
fi

# Enforce OGN whitelist.
if [[ -z ${OGN_WHITELIST} ]] ; then
    OGN_WHITELIST="0"
fi

# Test if config file exists, if not create it.
DECODER_CONFIG_FILE_NAME="${OGN_RECEIVER_NAME}.conf"
if [[ -s "${DECODER_PROJECT_DIRECTORY}/${DECODER_CONFIG_FILE_NAME}" ]] ; then
    echo -en "\e[33m  Using existing ${DECODER_NAME} config file at \"\e[37m${DECODER_CONFIG_FILE_NAME}\e[33m\"...\e[97m"
else
    echo -en "\e[33m  Generating new ${DECODER_NAME} config file as \"\e[37m${DECODER_CONFIG_FILE_NAME}\e[33m\"...\e[97m"
    sudo tee ${DECODER_PROJECT_DIRECTORY}/${DECODER_CONFIG_FILE_NAME} > /dev/null 2>&1 <<EOF
###########################################################################################
#                                                                                         #
#     CONFIGURATION FILE BASED ON http://wiki.glidernet.org/wiki:receiver-config-file     #
#                                                                                         #
###########################################################################################
#
RF:
{
  FreqCorr	= ${OGN_FREQ_CORR};             	# [ppm]		Some R820T sticks have 40-80ppm correction factors, measure it with gsm_scan.
  Device   	= ${OGN_DEVICE_ID};      	   	# 		Device index of the USB RTL-SDR device to be selected.
#  DeviceSerial	= ${OGN_DEVICE_SERIAL};	 	# char[12] 	Serial number of the USB RTL-SDR device to be selected.
  GSM:
  {
    CenterFreq	= ${OGN_GSM_FREQ};   		# [MHz]		Fnd the best GSM frequency with gsm_scan.
    Gain	= ${OGN_GSM_GAIN};   	 	# [0.1 dB] 	RF input gain for frequency calibration (beware that GSM signals are very strong).
  } ;
} ;
#
Position:
{
  Latitude	= ${OGN_LATITUDE};    		# [deg] 	Antenna coordinates in decimal degrees.
  Longitude	= ${OGN_LONGITUDE};           	# [deg] 	Antenna coordinates in decimal degrees.
  Altitude	= ${OGN_ALTITUDE};   		# [m]   	Altitude above sea leavel.
  GeoidSepar	= ${OGN_GEOID};           	# [m]   	Geoid separation: FLARM transmits GPS altitude, APRS uses means Sea level altitude.
} ;
#
APRS:
{
  Call		= "${OGN_RECEIVER_NAME}";  	# char[9]	APRS callsign (max. 9 characters).
} ;
#
DDB:
{
  UseAsWhitelist = ${OGN_WHITELIST};     	     	# [0|1] 	Setting to 1 enforces strict opt in.
} ;
#
EOF
fi

# Update ownership of new config file.
ACTION=$(chown pi:pi ${DECODER_PROJECT_DIRECTORY}/${DECODER_CONFIG_FILE_NAME})
CheckReturnCode

### INSTALL AS A SERVICE

# Install service script.
if [[ -f ${DECODER_SERVICE_SCRIPT_NAME} ]] ; then
    # Check for local copy of service script.
    if [[ `grep -c "conf=${DECODER_SERVICE_SCRIPT_CONFIG}" ${DECODER_SERVICE_SCRIPT_NAME}` -eq 1 ]] ; then
        echo -en "\e[33m  Installing service script at \"\e[37m${DECODER_SERVICE_SCRIPT_PATH}\e[33m\"..."
        ACTION=$(cp ${DECODER_SERVICE_SCRIPT_NAME} ${DECODER_SERVICE_SCRIPT_PATH})
        ACTION=$(sudo chmod +x ${DECODER_SERVICE_SCRIPT_PATH})
    else
        echo -en "\e[33m  Invalid service script \"\e[37m${DECODER_SERVICE_SCRIPT_NAME}\e[33m\"..."
        false
    fi
elif [[ -n ${DECODER_SERVICE_SCRIPT_URL} ]] ; then
    # Otherwise attempt to download service script.
    if [[ `echo ${DECODER_SERVICE_SCRIPT_URL} | grep -c "^http"` -gt 0 ]] ; then
        echo -en "\e[33m  Downloading service script to \"\e[37m${DECODER_SERVICE_SCRIPT_PATH}\e[33m\"..."
        ACTION=$(sudo curl -s ${DECODER_SERVICE_SCRIPT_URL} -o ${DECODER_SERVICE_SCRIPT_PATH})
        ACTION=$(sudo chmod +x ${DECODER_SERVICE_SCRIPT_PATH})
    else
        echo -en "\e[33m  Invalid service script url \"\e[37m${DECODER_SERVICE_SCRIPT_URL}\e[33m\"..."
        false
    fi
else
    # Otherwise error if unable to use local or downloaded service script
    echo -en "\e[33m  Unable to install service script at \"\e[37m${DECODER_SERVICE_SCRIPT_PATH}\e[33m\"..."
    false
fi
CheckReturnCode

# Generate and install service script configuration file.
if [[ -n ${DECODER_SERVICE_SCRIPT_CONFIG} ]] ; then
    echo -en "\e[33m  Creating service config file \"\e[37m${DECODER_SERVICE_SCRIPT_CONFIG}\e[33m\"..."
    sudo tee ${DECODER_SERVICE_SCRIPT_CONFIG} > /dev/null 2>&1 <<EOF
#shellbox configuration file
#Starts commands inside a "box" with a telnet-like server.
#Contact the shell with: telnet <hostname> <port>
#Syntax:
#port  user     directory                 command       args
50000  pi ${DECODER_PROJECT_DIRECTORY}    ./ogn-rf     ${OGN_RECEIVER_NAME}.conf
50001  pi ${DECODER_PROJECT_DIRECTORY}    ./ogn-decode ${OGN_RECEIVER_NAME}.conf
EOF
    ACTION=$(chown pi:pi ${DECODER_SERVICE_SCRIPT_CONFIG})
else
    false
fi
CheckReturnCode

# Potentially obselse tuner detection code.
if [[ ${TUNER_COUNT} -lt 2 ]] ; then
    # Less than 2 tuners present so we must stop other services before starting this decoder.
    echo -en "\e[33m  Found less than 2 tuners so other decoders will be disabled..."
    SERVICES="dump1090-mutability"
    for SERVICE in ${SERVICES} ; do
        if [[ `service ${SERVICE} status | grep -c "Active: active"` -gt 0 ]] ; then
            ACTION=$(sudo update-rc.d ${SERVICE} disable)
        fi
    done
    CheckReturnCode
fi

# Configure DECODER as a service.
echo -en "\e[33m  Configuring ${DECODER_NAME} as a service..."
ACTION=$(sudo update-rc.d ${DECODER_SERVICE_SCRIPT_NAME} defaults)
CheckReturnCode

# Start the DECODER service.
echo -en "\e[33m  Starting the ${DECODER_NAME} service..."
ACTION=$(sudo service ${DECODER_SERVICE_SCRIPT_NAME} start)
CheckReturnCode

## RTL-SDR OGN SETUP COMPLETE

# Return to the project root directory.
echo -en "\e[94m  Returning to ${RECEIVER_PROJECT_TITLE} root directory...\e[97m"
cd ${RECIEVER_ROOT_DIRECTORY}
CheckReturnCode

echo -e "\e[93m  ------------------------------------------------------------------------------\n"
echo -e "\e[92m  ${DECODER_NAME} setup is complete.\e[39m"
echo -e ""
if [[ ${RECEIVER_AUTOMATED_INSTALL} = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

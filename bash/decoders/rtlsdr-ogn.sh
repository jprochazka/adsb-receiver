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

PROJECT_ROOT_DIRECTORY="$PWD"
RECEIVER_BASH_DIRECTORY="${PROJECT_ROOT_DIRECTORY}/bash"
BUILD_DIRECTORY="${PROJECT_ROOT_DIRECTORY}/build"
BUILD_DIRECTORY_DECODER="$BUILD_DIRECTORY/ogn"

DECODER_NAME="RTLSDR-OGN"
DECODER_DESC="is the Open Glider Network decoder which focuses on tracking aircraft equipped with FLARM, FLARM-compatible devices or OGN tracker"
DECODER_GITHUB="https://github.com/glidernet/ogn-rf"
DECODER_WEBSITE="http://wiki.glidernet.org"

DECODER_SERVICE_NAME="rtlsdr-ogn"
DECODER_SERVICE_SCRIPT="/etc/init.d/rtlsdr-ogn"
DECODER_SERVICE_CONFIG="/etc/rtlsdr-ogn.conf"

### INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

function CheckReturnCode {
if [[ $? -eq 0 ]] ; then
    echo -e "\t\e[97m [\e[32mDone\e[97m]\e[39m\n"
else
    echo -e "\t\e[97m [\e[31mFailed\e[97m]\e[31m\n"
fi
}

### BEGIN SETUP

clear
echo -e ""
echo -e "\e[91m  ${RECEIVER_PROJECT_TITLE}"
echo -e ""
echo -e "\e[92m  Setting up ${DECODER_NAME} ...."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo -e ""
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${DECODER_NAME} Setup" --yesno "${DECODER_NAME} ${DECODER_DESC}. \n\nPlease note that ${DECODER_NAME} requests a dedicated SDR tuner. \n\n${DECODER_WEBSITE} \n\nContinue setup by installing ${DECODER_NAME} ?" 14 78
CONTINUESETUP=$?

if [[ $CONTINUESETUP = 1 ]] ; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo -e ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  ${DECODER_NAME} setup halted.\e[39m"
    echo -e ""
    if [[ ! -z ${VERBOSE} ]] ; then
        read -p "Press enter to continue..." CONTINUE
    fi
    exit 1
fi

### ASK FOR DEVICE ASSIGNMENTS

### CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to build and fulfill dependencies for ${DECODER_NAME}...\e[97m"
echo -e ""
CheckPackage git
CheckPackage rtl-sdr
CheckPackage librtlsdr-dev
CheckPackage libusb-1.0-0-dev
CheckPackage libconfig-dev
CheckPackage libfftw3-dev
CheckPackage libjpeg8
CheckPackage libjpeg-dev
CheckPackage libconfig9
CheckPackage procserv
CheckPackage telnet
CheckPackage curl
CheckPackage lynx
echo -e ""

### BLACKLIST UNWANTED RTL-SDR MODULES FROM BEING LOADED

if [[ ! -f /etc/modprobe.d/rtlsdr-blacklist.conf ]] ; then
    echo -e "\e[33m Stopping unwanted kernel modules from being loaded..."
    echo -e "\e[37m"
    sudo tee /etc/modprobe.d/rtlsdr-blacklist.conf  > /dev/null <<EOF
blacklist dvb_usb_rtl28xxu
blacklist dvb_usb_v2
blacklist rtl_2830
blacklist rtl_2832
blacklist r820t
blacklist rtl2830
blacklist rtl2832
EOF
fi

### CHECK FOR EXISTING INSTALL AND IF SO STOP IT

if [[ -x ${DECODER_SERVICE_SCRIPT} ]] ; then
    echo -en "\e[33m  Stopping the ${DECODER_NAME} service...\t\t\t"
    sudo service ${DECODER_SERVICE_NAME} stop
    CheckReturnCode
fi

### DOWNLOAD AND SET UP THE BINARIES

# Create build directory if not already present.
if [[ ! -d ${BUILD_DIRECTORY_DECODER} ]] ; then
    echo -en "\e[33m  Creating build directory \"\e[37m${BUILD_DIRECTORY_DECODER}\e[33m\"...\t\t\t"
    mkdir ${BUILD_DIRECTORY_DECODER}
    CheckReturnCode
fi

# Enter the build directory.
echo -en "\e[33m  Entering the directory \"\e[37m${BUILD_DIRECTORY_DECODER}\e[33m\"...\t"
cd ${BUILD_DIRECTORY_DECODER}
CheckReturnCode

# Detect CPU ARchitecture.
CPU_ARCHITECTURE=`uname -m`
echo -e "\e[94m  CPU architecture detected as $CPUARCHITECTURE...\e[97m"

# Download and extract the proper binaries.
case ${CPU_ARCHITECTURE} in
    "armv6l")
        # Raspberry Pi 1
        curl http://download.glidernet.org/rpi-gpu/rtlsdr-ogn-bin-RPI-GPU-latest.tgz -o ${BUILD_DIRECTORY_DECODER}/rtlsdr-ogn-bin-RPI-GPU-latest.tgz
        tar xvzf rtlsdr-ogn-bin-RPI-GPU-latest.tgz -C ${BUILD_DIRECTORY_DECODER}
        ;;
    "armv7l")
        # Raspberry Pi 2 onwards
        curl http://download.glidernet.org/arm/rtlsdr-ogn-bin-ARM-latest.tgz -o ${BUILD_DIRECTORY_DECODER}/rtlsdr-ogn-bin-ARM-latest.tgz
        tar xvzf rtlsdr-ogn-bin-ARM-latest.tgz -C ${BUILD_DIRECTORY_DECODER}
        ;;
    "x86_64")
        # 64 Bit
        curl http://download.glidernet.org/x64/rtlsdr-ogn-bin-x64-latest.tgz -o ${BUILD_DIRECTORY_DECODER}/rtlsdr-ogn-bin-x64-latest.tgz
        tar xvzf rtlsdr-ogn-bin-x64-latest.tgz -C ${BUILD_DIRECTORY_DECODER}
        ;;
    *)
        # 32 Bit (default install if no others matched)
        curl http://download.glidernet.org/x86/rtlsdr-ogn-bin-x86-latest.tgz -o ${BUILD_DIRECTORY_DECODER}/rtlsdr-ogn-bin-x86-latest.tgz
        tar xvzf rtlsdr-ogn-bin-x86-latest.tgz -C ${BUILD_DIRECTORY_DECODER}
        ;;
esac

# Change to work directory
cd ${BUILD_DIRECTORY_DECODER}/rtlsdr-ogn

# Create named pipe.
if [[ ! -p ogn-rf.fifo ]] ; then
    echo -en "\e[33m  Creating named pipe...\t\t\t"
    sudo mkfifo ogn-rf.fifo
    CheckReturnCode
fi

# Set file permissions.
echo -en "\e[33m  Setting proper file permissions...\t\t\t"
for FILE in gsm_scan ogn-rf rtlsdr-ogn ; do
    sudo chown root ${FILE}
    sudo chmod a+s  ${FILE}
done
CheckReturnCode

if [[ ! -c gpu_dev ]] ; then
    # Check if kernel v4.1 or higher is being used.
    echo -en "\e[33m  ...\t\t\t"
    echo -e "\e[94m  Getting the version of the kernel currently running...\e[97m"
    KERNEL=`uname -r`
    KERNEL_VERSION="`echo ${KERNEL} | cut -d \. -f 1`.`echo ${KERNEL} | cut -d \. -f 2`"
    CheckReturnCode
    if [[ ${KERNEL_VERSION} < 4.1 ]] ; then
        # Kernel is older than version 4.1.
        echo -en "\e[33m  Executing mknod for older kernels...\e[97m"
        sudo mknod gpu_dev c 100 0
        CheckReturnCode
    else
        # Kernel is version 4.1 or newer.
        echo -en "\e[33m  Executing mknod for newer kernels...\e[97m"
        sudo mknod gpu_dev c 249 0
        CheckReturnCode
    fi
fi

### ASSIGN THE RTL-SDR TUNER DEVICE TO THIS DECODER

# Check for multiple tuners...
TUNER_COUNT=`rtl_eeprom 2>&1 | grep -c "^\s*[0-9]*:\s"`

# Multiple RTL_SDR tuners found, check if device specified for this decoder is present.
if [[ ${TUNER_COUNT} -gt 1 ]] ; then
    # If a device has been specified by serial number then try to match that with the currently detected tuners.
    if [[ -n ${OGN_DEVICE_SERIAL} ]] ; then
        for DEVICE_ID in `seq 0 ${TUNER_COUNT}` ; do
            if [[ `rtl_eeprom -d ${DEVICE_ID} 2>&1 | grep -c "Serial number:\s*${OGN_DEVICE_SERIAL}$" ` -eq 1 ]] ; then
                echo -e "\e[94m  RTL-SDR with Serial \"${OGN_DEVICE_SERIAL}\" found at device \"${OGN_DEVICE_ID}\" and will be assigned to ${DECODER_NAME}...\e [97m"
                OGN_DEVICE_ID=${DEVICE_ID}
            fi
        done
        # If no match for this serial then assume the highest numbered tuner will be used.
        if [[ -z ${OGN_DEVICE_ID} ]] ; then
            echo -e "\e[94m  RTL-SDR with Serial \"${OGN_DEVICE_SERIAL}\" not found, assigning device \"${TUNER_COUNT}\" to ${DECODER_NAME}...\e [97m"
            OGN_DEVICE_ID=${TUNER_COUNT}
        fi
    # Or if a device has been specified by device ID then confirm this is currently detected.
    elif [[ -n ${OGN_DEVICE_ID} ]] ; then
        if [[ `rtl_eeprom -d ${OGN_DEVICE_ID} 2>&1 | grep -c "^\s*${OGN_DEVICE_ID}:\s"` -eq 1 ]] ; then
            echo -e "\e[94m  RTL-SDR device \"${OGN_DEVICE_ID}\" found and will be assigned to ${DECODER_NAME}...\e [97m"
        # If no match for this serial then assume the highest numbered tuner will be used.
        else
            echo -e "\e[94m  RTL-SDR device \"${OGN_DEVICE_ID}\" not found, assigning device \"${TUNER_COUNT}\" to ${DECODER_NAME}...\e [97m"
            OGN_DEVICE_ID=${TUNER_COUNT}
        fi
    # Failing that configure it with device ID 0.
    else
        echo -e "\e[94m  No RTL-SDR device specified, assigning device \"0\" to ${DECODER_NAME}...\e [97m"
        OGN_DEVICE_ID=${TUNER_COUNT}
    fi
# Single tuner present so assign device 0 and stop any other running decoders, or at least dump1090-mutablity for a default install.
elif [[ ${TUNER_COUNT} -eq 1 ]] ; then
    echo -e "\e[94m  Single RTL-SDR device \"0\" detected and assigned to ${DECODER_NAME}...\e [97m"
    OGN_DEVICE_ID="0"
    sudo /etc/init.d/dump1090-mutability stop
# No tuners present so assign device 0 and stop any other running decoders, or at least dump1090-mutablity for a default install.
elif [[ ${TUNER_COUNT} -lt 1 ]] ; then
    echo -e "\e[94m  No RTL-SDR device detected so ${DECODER_NAME} will be assigned device \"0\"...\e [97m"
    OGN_DEVICE_ID="0"
    sudo /etc/init.d/dump1090-mutability stop 2>/dev/null
fi

### CREATE THE CONFIGURATION FILE

# Check for decoder specific variable, if not set then populate with dummy values to ensure valid config generation.
if [[ -z ${OGN_WHITELIST} ]] ; then
    OGN_WHITELIST="0"
fi

if [[ -z ${OGN_FREQ_CORR} ]] ; then
    OGN_FREQ_CORR="0"
fi

if [[ -z ${OGN_GSM_FREQ} ]] ; then
    OGN_GSM_FREQ="957.800"
fi

if [[ -z ${OGN_GSM_GAIN} ]] ; then
    OGN_GSM_GAIN="35"
fi

# Use receiver coordinates if already know, otherwise populate with dummy values to ensure valid config generation.

# Latitude.
if [[ -z ${OGN_LATITUDE} ]] ; then
    if [[ -n ${RECEIVER_LATITUDE} ]] ; then
        OGN_LATITUDE="${RECEIVER_LATITUDE}"
    else
        OGN_LATITUDE="0.0000000"
    fi
fi

# Longitude.
if [[ -z ${OGN_LONGITUDE} ]] ; then
    if [[ -n ${RECEIVER_LONGITUDE} ]] ; then
        OGN_LONGITUDE="${RECEIVER_LONGITUDE}"
    else
        OGN_LONGITUDE="0.0000000"
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

# Test if config file exists, if not create it.
if [[ -s ${BUILD_DIRECTORY_DECODER}/rtlsdr-ogn/${OGN_RECEIVER_NAME}.conf ]] ; then
    echo -e "\e[94m  Using existing ${DECODER_NAME} config file at \"\e[37m${OGN_RECEIVER_NAME}.conf\e[33m\"...\e [97m\t"
else
    echo -e "\e[94m  Generating new ${DECODER_NAME} config file as \"\e[37m${OGN_RECEIVER_NAME}.conf\e[33m\"...\e [97m\t"
    sudo tee ${BUILD_DIRECTORY_DECODER}/rtlsdr-ogn/${OGN_RECEIVER_NAME}.conf > /dev/null <<EOF
###########################################################################################
#                                                                                         #
#     CONFIGURATION FILE BASED ON http://wiki.glidernet.org/wiki:receiver-config-file     #
#                                                                                         #
###########################################################################################
#
RF:
{
  FreqCorr	= ${OGN_FREQ_CORR};             	# [ppm]		Some R820T sticks have 40-80ppm correction factors, measure it with gsm_scan
  Device   	= ${OGN_DEVICE_ID};      	   	# 		Device index of the USB RTL-SDR device to be selected
#  DeviceSerial	= ${OGN_DEVICE_SERIAL};	 	  	# char[12] 	Serial number of the USB RTL-SDR device to be selected
  GSM:
  {
    CenterFreq	= ${OGN_GSM_FREQ};		# [MHz]		Fnd the best GSM frequency with gsm_scan
    Gain	= ${OGN_GSM_GAIN};   	 	# [0.1 dB] 	RF input gain for frequency calibration (beware that GSM signals are very strong)
  } ;
} ;
#
Position:
{
  Latitude	= ${OGN_LATITUDE};    		# [deg] 	Antenna coordinates in decimal degrees
  Longitude	= ${OGN_LONGITUDE};           	# [deg] 	Antenna coordinates in decimal degrees
  Altitude	= ${OGN_ALTITUDE};   		# [m]   	Altitude above sea leavel
  GeoidSepar	= ${OGN_GEOID};           	# [m]   	Geoid separation: FLARM transmits GPS altitude, APRS uses means Sea level altitude
} ;
#
APRS:
{
  Call		= "${OGN_RECEIVER_NAME}";  	# 		APRS callsign (max. 9 characters)
} ;
#
DDB:
{
  UseAsWhitelist = ${OGN_WHITELIST};     	     	# [0|1] 	Setting to 1 enforces strict opt in
} ;
#
EOF
fi

# Update ownership of new config file.
chown pi:pi ${BUILD_DIRECTORY_DECODER}/rtlsdr-ogn/${OGN_RECEIVER_NAME}.conf > /dev/null 2>&1
CheckReturnCode

### INSTALL AS A SERVICE

echo -en "\e[33m  Downloading and setting permissions on the service script...\t"
sudo curl -s http://download.glidernet.org/common/service/rtlsdr-ogn -o ${DECODER_SERVICE_SCRIPT}
sudo chmod +x ${DECODER_SERVICE_SCRIPT} > /dev/null 2>&1
CheckReturnCode

echo -en "\e[33m  Creating service config file \"\e[37m${DECODER_SERVICE_CONFIG}\e[33m\"...\t"
sudo tee ${DECODER_SERVICE_CONFIG} > /dev/null 2>&1 <<EOF
#shellbox configuration file
#Starts commands inside a "box" with a telnet-like server.
#Contact the shell with: telnet <hostname> <port>
#Syntax:
#port  user     directory                 command       args
50000  pi ${BUILD_DIRECTORY_DECODER}/rtlsdr-ogn    ./ogn-rf     ${OGN_RECEIVER_NAME}.conf
50001  pi ${BUILD_DIRECTORY_DECODER}/rtlsdr-ogn    ./ogn-decode ${OGN_RECEIVER_NAME}.conf
EOF
chown pi:pi ${DECODER_SERVICE_CONFIG} > /dev/null 2>&1
CheckReturnCode

if [[ ${TUNER_COUNT} -lt 2 ]] ; then
# Less than 2 tuners present so we must stop the dump1090-mutability before starting this decoder.
    echo -en "\e[33m  Less than 2 RTL-SDR devices present so dump1090-mutability service will be disabled...\t"
    sudo update-rc.d dump1090-mutability disable > /dev/null 2>&1
    CheckReturnCode
fi

# Configure $DECODER as a service.
echo -en "\e[33m  Configuring ${DECODER_NAME} as a service...\t\t\t"
sudo update-rc.d ${DECODER_SERVICE_NAME} defaults > /dev/null 2>&1
CheckReturnCode

# Start the $DECODER service.
echo -en "\e[33m  Starting the ${DECODER_NAME} service...\t\t\t"
sudo service ${DECODER_SERVICE_NAME} start > /dev/null 2>&1
CheckReturnCode

### ARCHIVE SETUP PACKAGES

### SETUP COMPLETE

# Return to the project root directory.
echo -en "\e[94m  Returning to ${RECEIVER_PROJECT_TITLE} root directory...\e[97m"
cd ${PROJECT_ROOT_DIRECTORY}
CheckReturnCode

echo -e ""
echo -e "\e[93m-------------------------------------------------------------------------------------------------------\n"
echo -e "\e[92m  ${DECODER_NAME} setup is complete.\e[39m"
echo -e ""
if [[ ! -z ${VERBOSE} ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

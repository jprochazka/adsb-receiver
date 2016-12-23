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
# Copyright (c) 2015 Joseph A. Prochazka                                            #
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
BASHDIRECTORY="${PROJECT_ROOT_DIRECTORY}/bash"
BUILDDIRECTORY="${PROJECT_ROOT_DIRECTORY}/build"
BUILDDIRECTORY_RTLSDROGN="$BUILDDIRECTORY/rtlsdr-ogn"

DECODER_NAME="RTLSDR-OGN"
DECODER_DESC="is the Open Glider Network decoder which focuses on tracking aircraft equipped with FLARM, FLARM-compatible devices or OGN tracker"
DECORDER_GITHUB="https://github.com/glidernet/ogn-rf"
DECODER_WEBSITE="http://wiki.glidernet.org"

### INCLUDE EXTERNAL SCRIPTS

source ${BASHDIRECTORY}/variables.sh
source ${BASHDIRECTORY}/functions.sh

### BEGIN SETUP

clear
echo -e ""
echo -e "\e[91m  ${ADSB_PROJECTTITLE}"
echo -e ""
echo -e "\e[92m  Setting up ${DECODER_NAME} ...."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo -e ""
whiptail --backtitle "${ADSB_PROJECTTITLE}" --title "${DECODER_NAME} Setup" --yesno "${DECODER_NAME} ${DECODER_DESC}. \n\nPlease note that ${DECODER_NAME} requests a dedicated SDR tuner. \n\n${DECODER_WEBSITE} \n\nContinue setup by installing ${DECODER_NAME} ?" 14 78
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

### BLACKLIST UNWANTED RTL-SDR MODULES FROM BEING LOADED

echo -e "\033[33m Stopping unwanted kernel modules from being loaded..."
echo -e "\033[37m"
sudo tee /etc/modprobe.d/rtlsdr-blacklist.conf  > /dev/null <<EOF
blacklist dvb_usb_rtl28xxu
blacklist dvb_usb_v2
blacklist rtl_2830
blacklist rtl_2832
blacklist r820t
blacklist rtl2830
blacklist rtl2832
EOF

### CHECK FOR EXISTING INSTALL AND IF SO STOP IT

if [[ -x /etc/init.d/rtlsdr-ogn ]] ; then
    sudo service rtlsdr-ogn stop
fi

### DOWNLOAD AND SET UP THE BINARIES

# Create build directory if not already present.
if [[ ! -d ${BUILDDIRECTORY_RTLSDROGN} ]] ; then
    mkdir ${BUILDDIRECTORY_RTLSDROGN}
fi
cd ${BUILDDIRECTORY_RTLSDROGN}

# Download and extract the proper binaries.
case `uname -m` in
    "armv6l")
        # Raspberry Pi 1
        curl http://download.glidernet.org/rpi-gpu/rtlsdr-ogn-bin-RPI-GPU-latest.tgz -o ${BUILDDIRECTORY_RTLSDROGN}/rtlsdr-ogn-bin-RPI-GPU-latest.tgz
        tar xvzf rtlsdr-ogn-bin-RPI-GPU-latest.tgz -C ${BUILDDIRECTORY_RTLSDROGN}
        ;;
    "armv7l")
        # Raspberry Pi 2 onwards
        curl http://download.glidernet.org/arm/rtlsdr-ogn-bin-ARM-latest.tgz -o ${BUILDDIRECTORY_RTLSDROGN}/rtlsdr-ogn-bin-ARM-latest.tgz
        tar xvzf rtlsdr-ogn-bin-ARM-latest.tgz -C ${BUILDDIRECTORY_RTLSDROGN}
        ;;
    "x86_64")
        # 64 Bit
        curl http://download.glidernet.org/x64/rtlsdr-ogn-bin-x64-latest.tgz -o ${BUILDDIRECTORY_RTLSDROGN}/rtlsdr-ogn-bin-x64-latest.tgz
        tar xvzf rtlsdr-ogn-bin-x64-latest.tgz -C ${BUILDDIRECTORY_RTLSDROGN}
        ;;
    *)
        # 32 Bit (default install if no others matched)
        curl http://download.glidernet.org/x86/rtlsdr-ogn-bin-x86-latest.tgz -o ${BUILDDIRECTORY_RTLSDROGN}/rtlsdr-ogn-bin-x86-latest.tgz
        tar xvzf rtlsdr-ogn-bin-x86-latest.tgz -C ${BUILDDIRECTORY_RTLSDROGN}
        ;;
esac

# Change to work directory
cd ${BUILDDIRECTORY_RTLSDROGN}/rtlsdr-ogn

# Create named pipe.
if [[ ! -p ogn-rf.fifo ]] ; then
    sudo mkfifo ogn-rf.fifo
fi

# Set file permissions.
sudo chown root gsm_scan
sudo chmod a+s  gsm_scan
sudo chown root ogn-rf
sudo chmod a+s  ogn-rf
sudo chown root rtlsdr-ogn
sudo chmod a+s  rtlsdr-ogn

if [[ ! -c gpu_dev ]] ; then
    # Check if kernel v4.1 or higher is being used.
    KERNEL=`uname -r`
    VERSION="`echo $KERNEL | cut -d \. -f 1`.`echo $KERNEL | cut -d \. -f 2`"

    if [[ $VERSION < 4.1 ]] ; then
        # Kernel is older than version 4.1.
        sudo mknod gpu_dev c 100 0
    else
        # Kernel is version 4.1 or newer.
        sudo mknod gpu_dev c 249 0
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

OGN_WHITELIST="0"
OGN_FREQ_CORR="0"
OGN_GSM_FREQ="957.800"
OGN_GSM_GAIN="35"

# Use receiver coordinates if already know, otherwise populate with dummy values to generate a valid config file.

if [[ -z ${OGN_LAT} ]] ; then
    if [[ -n ${RECEIVER_LATITUDE} ]] ; then
        OGN_LAT="${RECEIVER_LATITUDE}"
    else
        OGN_LAT="0.0000000"
    fi
fi

if [[ -z ${OGN_LON} ]] ; then
    if [[ -n ${RECEIVER_LONGITUDE} ]] ; then
        OGN_LON="${RECEIVER_LONGITUDE}"
    else
        OGN_LON="0.0000000"
    fi
fi 

if [[ -z ${OGN_ALT} ]] ; then
    if [[ -n ${RECIEVER_ALTITUDE} ]] ; then
         OGN_ALT="${RECIEVER_ALTITUDE}"
    else
         OGN_ALT="0"
    fi
fi

# Geoid separation: FLARM transmits GPS altitude, APRS uses means Sea level altitude
# To find value you can check: 	http://geographiclib.sourceforge.net/cgi-bin/GeoidEval
# Need to derive from co-ords but will set to altitude as a placeholders
if [[ -z ${OGN_GEOID} ]] ; then
    if [[ -n ${RECIEVER_ALTITUDE} ]] ; then
        OGN_GEOID="${RECIEVER_ALTITUDE}"
    else
        OGN_GEOID="0"
    fi
fi

# Callsign should be between 3 and 9 alphanumeric charactors, with no punctuation
# Please see: 	http://wiki.glidernet.org/receiver-naming-convention
if [[ -z ${OGN_CALLSIGN} ]] ; then
    if [[ -n ${OGN_RECEIVER_NAME} ]] ; then 
        OGN_CALLSIGN=`echo ${OGN_RECEIVER_NAME} | tr -cd '[:alnum:]' | cut -c -9`
    else
        OGN_CALLSIGN=`hostname -s | tr -cd '[:alnum:]' | cut -c -9`
    fi
fi

# Test if config file exists, if not create it.

if [[ -s ${BUILDDIRECTORY_RTLSDROGN}/rtlsdr-ogn/${OGN_CALLSIGN}.conf ]] ; then
    echo -e "\e[94m Using existing ${DECODER_NAME} config file \"${OGN_CALLSIGN}.conf\"...\e [97m"
else 
    echo -e "\e[94m Generating new ${DECODER_NAME} config file as \"${OGN_CALLSIGN}.conf\"...\e [97m"
    sudo tee ${BUILDDIRECTORY_RTLSDROGN}/rtlsdr-ogn/${OGN_CALLSIGN}.conf > /dev/null <<EOF
###########################################################################################
#                                                                                         #
#     CONFIGURATION FILE BASED ON http://wiki.glidernet.org/wiki:receiver-config-file     #
#                                                                                         #
##########################################################################################
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
  Latitude	= ${OGN_LAT};    		# [deg] 	Antenna coordinates in decimal degrees
  Longitude	= ${OGN_LON};           	# [deg] 	Antenna coordinates in decimal degrees
  Altitude	= ${OGN_ALT};   		# [m]   	Altitude above sea leavel
  GeoidSepar	= ${OGN_GEOID};           	# [m]   	Geoid separation: FLARM transmits GPS altitude, APRS uses means Sea level altitude
} ;
#
APRS:
{
  Call		= "${OGN_CALLSIGN}";  	# 		APRS callsign (max. 9 characters)
} ;
#
DDB:
{
  UseAsWhitelist = ${OGN_WHITELIST};     	     	# [0|1] 	Setting to 1 enforces strict opt in
} ;
#
EOF

    # Update ownership of new config file.
    chown pi:pi ${BUILDDIRECTORY_RTLSDROGN}/rtlsdr-ogn/${OGN_CALLSIGN}.conf
fi

### INSTALL AS A SERVICE

DECODER_SERVICE_SCRIPT="/etc/init.d/rtlsdr-ogn"
DECODER_SERVICE_CONFIG="/etc/rtlsdr-ogn.conf"

echo -e "\033[33m Downloading and setting permissions on the service script..."
echo -e "\033[37m"
sudo curl http://download.glidernet.org/common/service/rtlsdr-ogn -o ${DECODER_SERVICE_SCRIPT}
sudo chmod +x ${DECODER_SERVICE_SCRIPT}

echo -e "\033[33m Creating service config file \"${DECODER_SERVICE_CONFIG}\"..."
echo -e "\033[37m"
sudo tee ${DECODER_SERVICE_CONFIG} > /dev/null <<EOF
#shellbox configuration file
#Starts commands inside a "box" with a telnet-like server.
#Contact the shell with: telnet <hostname> <port>
#Syntax:
#port  user     directory                 command       args
50000  pi ${BUILDDIRECTORY_RTLSDROGN}/rtlsdr-ogn    ./ogn-rf     ${OGN_CALLSIGN}.conf
50001  pi ${BUILDDIRECTORY_RTLSDROGN}/rtlsdr-ogn    ./ogn-decode ${OGN_CALLSIGN}.conf
EOF

if [[ ${TUNER_COUNT} -lt 2 ]] ; then
# Less than 2 tuners present so we must stop the dump1090-mutability before starting this decoder.
    echo -en "\033[33m Less than 2 RTL-SDR devices present so dump1090-mutability service will be disabled..."
    sudo update-rc.d dump1090-mutability disable 2>/dev/null
    echo -e "\t\e[92m [Done]\e[39m\n"
fi

echo -en "\033[33m Configuring ${DECODER_NAME} as a service..."
sudo update-rc.d rtlsdr-ogn defaults 2>&1 >/dev/null
echo -e "\t\e[92m [Done]\e[39m\n"

echo -en "\033[33m Starting the ${DECODER_NAME} service..."
sudo service rtlsdr-ogn start
echo -e "\t\e[92m [Done]\e[39m\n"

### ARCHIVE SETUP PACKAGES

### SETUP COMPLETE

# Return to the project root directory.
echo -e "\e[94m  Entering the ${ADSB_PROJECTTITLE} root directory...\e[97m"
cd ${PROJECT_ROOT_DIRECTORY}

echo -e ""
echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
echo -e "\e[92m  ${DECODER_NAME} setup is complete.\e[39m"
echo -e ""
if [[ ! -z ${VERBOSE} ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

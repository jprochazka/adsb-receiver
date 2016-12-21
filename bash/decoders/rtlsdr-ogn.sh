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

PROJECTROOTDIRECTORY="$PWD"
BASHDIRECTORY="$PROJECTROOTDIRECTORY/bash"
BUILDDIRECTORY="$PROJECTROOTDIRECTORY/build"
BUILDDIRECTORY_RTLSDROGN="$BUILDDIRECTORY/rtlsdr-ogn"

DECODER_NAME="RTLSDR-OGN"
DECODER_WEBSITE="http://wiki.glidernet.org"

### INCLUDE EXTERNAL SCRIPTS

source $BASHDIRECTORY/variables.sh
source $BASHDIRECTORY/functions.sh

### BEGIN SETUP

clear
echo -e ""
echo -e "\e[91m  $ADSB_PROJECTTITLE"
echo -e ""
echo -e "\e[92m  Setting up ${DECODER_NAME} ...."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo -e ""
whiptail --backtitle "$ADSB_PROJECTTITLE" --title "${DECODER_NAME} Setup" --yesno "${DECODER_NAME} is the decoder for the Open Glider Network which focuses on tracking aircraft equipped with FLARM, FLARM-compatible devices or OGN tracker. \n\n Please note that ${DECODER_NAME} requests a dedicated SDR tuner. \n\n $DECODER_WEBSITE \n\nContinue setup by installing ${DECODER_NAME} ?" 14 78
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

echo -e "\e[95m  Installing packages needed to build and fulfill dependencies for ${DECODER_NAME} ...\e[97m"
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
CheckPackage wget
CheckPackage lynx

### BLACKLIST UNWANTED RTL-SDR MODULES FROM BEING LOADED

echo -e "\033[33m Stopping unwanted kernel modules from being loaded..."
echo -e "\033[37m "
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

if [[ -f /etc/init.d/rtlsdr-ogn ]] ; then
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
        wget http://download.glidernet.org/rpi-gpu/rtlsdr-ogn-bin-RPI-GPU-latest.tgz -O $BUILDDIRECTORY_RTLSDROGN/rtlsdr-ogn-bin-RPI-GPU-latest.tgz
        tar xvzf rtlsdr-ogn-bin-RPI-GPU-latest.tgz -C $BUILDDIRECTORY_RTLSDROGN
        ;;
    "armv7l")
        # Raspberry Pi 2
        wget http://download.glidernet.org/arm/rtlsdr-ogn-bin-ARM-latest.tgz -O $BUILDDIRECTORY_RTLSDROGN/rtlsdr-ogn-bin-ARM-latest.tgz
        tar xvzf rtlsdr-ogn-bin-ARM-latest.tgz -C $BUILDDIRECTORY_RTLSDROGN
        ;;
    "x86_64")
        # 64 Bit
        wget http://download.glidernet.org/x64/rtlsdr-ogn-bin-x64-latest.tgz -O $BUILDDIRECTORY_RTLSDROGN/rtlsdr-ogn-bin-x64-latest.tgz
        tar xvzf rtlsdr-ogn-bin-x64-latest.tgz -C $BUILDDIRECTORY_RTLSDROGN
        ;;
    *)
        # 32 Bit (default install if no others matched)
        wget http://download.glidernet.org/x86/rtlsdr-ogn-bin-x86-latest.tgz -O $BUILDDIRECTORY_RTLSDROGN/rtlsdr-ogn-bin-x86-latest.tgz
        tar xvzf rtlsdr-ogn-bin-x86-latest.tgz -C $BUILDDIRECTORY_RTLSDROGN
        ;;
esac

# Create named pipe.
cd $BUILDDIRECTORY_RTLSDROGN/rtlsdr-ogn
sudo mkfifo ogn-rf.fifo

# Set file permissions.
sudo chown root gsm_scan
sudo chmod a+s  gsm_scan
sudo chown root ogn-rf
sudo chmod a+s  ogn-rf
sudo chown root rtlsdr-ogn
sudo chmod a+s  rtlsdr-ogn

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

### ASSIGN THE RTL-SDR TUNER DEVICE TO THIS DECODER

# Check for multiple tuners...
if [[ `rtl_test 2>&1 | grep -c "SN:" ` -gt 1 ]] ; then
# Multiple tuners found, check if device specified for this decoder is present.
    if [[ ${OGN_DEVICE_SERIAL} ]] ; then
        if [[ `rtl_test 2>&1 | grep -c "SN: ${OGN_DEVICE_SERIAL}" ` -eq 1 ]] ; then
            OGN_DEVICE_ID=`rtl_test 2>&1 | grep "SN: ${OGN_DEVICE_SERIAL}" | awk -F ":" '{print $1}' | sed -e 's/\ //g' `
            echo -e "\e [94m  RTL-SDR with Serial \"${OGN_DEVICE_SERIAL}" matches device \"${OGN_DEVICE_ID}\" and will be assigned to ${DECODER_NAME} ...\e [97m"
        else
            echo -e "\e [94m  RTL-SDR with Serial \"${OGN_DEVICE_SERIAL}\" not found, assigning device \"0\" to ${DECODER_NAME} ...\e [97m"
        fi
    elif [[ ${OGN_DEVICE_ID} ]] ; then
        if [[ `rtl_test 2>&1 | grep "SN: " | grep -c "^\ *${OGN_DEVICE_ID}:" -eq 1 ]] ; then
            echo -e "\e [94m  RTL-SDR device \"${OGN_DEVICE_ID}\" found and will be assigned to ${DECODER_NAME} ...\e [97m"
        else
            echo -e "\e [94m  RTL-SDR device \"${OGN_DEVICE_ID}\" not found, assigning device \"0\" to ${DECODER_NAME} ...\e [97m"
        fi
    else
        if [[ -z ${OGN_DEVICE_ID} ]] ; then
            echo -e "\e [94m  No RTL-SDR device specified, assigning device \"0\" to ${DECODER_NAME} ...\e [97m"
            OGN_DEVICE_ID="0"
        fi
    fi
elif [[ `rtl_test 2>&1 | grep -c "SN:" ` -eq 1 ]] ; then
# Single tuner present so we must stop any other running decoders, or at least dump1090-mutablity for a default install...
    echo -e "\e [94m  Single RTL-SDR device \"0\" detected and assigned to ${DECODER_NAME} ...\e [97m"
    OGN_DEVICE_ID="0"
    sudo /etc/init.d/dump1090-mutability stop
elif [[ `rtl_test 2>&1 | grep -c "SN:" ` -lt 1 ]] ; then
# No tuner found.
    echo -e "\e [94m  No RTL-SDR device detected but \"0\" to ${DECODER_NAME} for future use ...\e [97m"
    OGN_DEVICE_ID="0"
fi

### CREATE THE CONFIGURATION FILE

OGN_WHITELIST="0"
OGN_GSM_FREQ="957.800"
OGN_GSM_GAIN="35"

# Use receiver coordinates are already know, otherwise populate with dummy values
if [[ -n ${RECEIVER_LATITUDE} ]] ; then
    OGN_LAT="${RECEIVER_LATITUDE}"
else
    OGN_LAT="0.0000000"
fi

if [[ -n ${RECEIVER_LONGITUDE} ]] ; then
    OGN_LON="${ECEIVER_LONGITUDE}"
else
    OGN_LON="0.0000000"
fi

if [[ -n ${RECIEVER_ALTITUDE} ]] ; then
     OGN_ALT="${RECIEVER_ALTITUDE}"
else
     OGN_ALT="0"
fi

# Geoid separation: FLARM transmits GPS altitude, APRS uses means Sea level altitude
# To find value you can check: 	http://geographiclib.sourceforge.net/cgi-bin/GeoidEval
# Need to derive from co-ords but will set to altitude as a placeholders
if [[ -z ${RECIEVER_ALTITUDE} ]] ; then
    OGN_GEOID=""
else
    OGN_GEOID="0"
fi

# Callsign should be between 3 and 9 alphanumeric charactors, with no punctuation
# Please see: 	http://wiki.glidernet.org/receiver-naming-convention
if [[ -n ${OGN_RECEIVER_NAME} ]] ; then 
    OGN_CALLSIGN=`echo ${OGN_RECEIVER_NAME} | tr -cd '[:alnum:]' | cut -c -9`
else
    OGN_CALLSIGN=`hostname -s | tr -cd '[:alnum:]' | cut -c -9`
fi

sudo tee $BUILDDIRECTORY_RTLSDROGN/rtlsdr-ogn.conf > /dev/null <<EOF
###########################################################################################
#                                                                                         #
#     CONFIGURATION FILE BASED ON http://wiki.glidernet.org/wiki:receiver-config-file     #
#                                                                                         #
##########################################################################################
#
RF:
{ 
  FreqCorr	=  0;      		# [ppm]		Some R820T sticks have 40-80ppm correction factors, measure it with gsm_scan
  Device   	=  "${OGN_DEVICE_ID}";		# 		Device index of USB RTL-SDR 
#  DeviceSerial	=  "${OGN_DEVICE_SERIAL}";	# char[12] 	Serial number of the rtl-sdr device to be selected
  GSM:
  { 
    CenterFreq	= "${OGN_GSM_FREQ}";		# [MHz]		Fnd the best GSM frequency with gsm_scan
    Gain	= "${OGN_GSM_GAIN}";   	 	# [0.1 dB] 	RF input gain for frequency calibration (beware that GSM signals are very strong)
  } ;
} ;
#
Position:
{ 
  Latitude	= "${OGN_LAT}";   	# [deg] 	Antenna coordinates
  Longitude	= "${OGN_LON}";  	# [deg] 	Antenna coordinates
  Altitude	= "${OGN_ALT}"; 	# [m]   	Altitude above sea leavel
  GeoidSepar	= "${OGN_GEOID}"; 	# [m]   	Geoid separation: FLARM transmits GPS altitude, APRS uses means Sea level altitude
} ;
#
APRS:
{
  Call		= "${OGN_CALLSIGN}";  	# 		APRS callsign (max. 9 characters)
} ;
#
DDB:
{
  UseAsWhitelist = "${OGN_WHITELIST}";	# [0|1] 	Setting to 1 enforces strict opt in
} ;
#
EOF

### INSTALL AS A SERVICE

echo -e "\033[33m Downloading and setting permissions on the init script..."
echo -e "\033[37m "
sudo wget http://download.glidernet.org/common/service/rtlsdr-ogn -O /etc/init.d/rtlsdr-ogn
sudo chmod +x /etc/init.d/rtlsdr-ogn

echo -e "\033[33m Creating file /etc/rtlsdr-ogn.conf ..."
echo -e "\033[37m "
sudo tee /etc/rtlsdr-ogn.conf > /dev/null <<EOF
#shellbox configuration file
#Starts commands inside a "box" with a telnet-like server.
#Contact the shell with: telnet <hostname> <port>
#Syntax:
#port  user     directory                 command       args
50000  pi ${BUILDDIRECTORY_RTLSDROGN}/rtlsdr-ogn    ./ogn-rf     rtlsdr-ogn.conf
50001  pi ${BUILDDIRECTORY_RTLSDROGN}/rtlsdr-ogn    ./ogn-decode rtlsdr-ogn.conf
EOF

echo -e "\033[33m Setting up ${DECODER_NAME} as a service..."
echo -e "\033[37m "
sudo update-rc.d rtlsdr-ogn defaults

echo -e "\033[33m Starting the ${DECODER_NAME} service..."
echo -e "\033[37m "
sudo service rtlsdr-ogn start

### ARCHIVE SETUP PACKAGES

### SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the $ADSB_PROJECTTITLE root directory...\e[97m"
cd $PROJECTROOTDIRECTORY

echo -e ""
echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
echo -e "\e[92m  ${DECODER_NAME} setup is complete.\e[39m"
echo -e ""
if [[ ! -z ${VERBOSE} ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

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
BUILD_DIRECTORY_DECODER="$BUILD_DIRECTORY/hab"

DECODER_NAME="HAB-LoRa-Gateway"
DECODER_DESC="is a combined receiver and feeder for the LoRa based High Altitude Baloon Tracking System"
DECODER_GITHUB="https://github.com/PiInTheSky/lora-gateway"
DECODER_WEBSITE="http://www.pi-in-the-sky.com"

DECODER_SERVICE_NAME="hab-lora-gateway"
#DECODER_SERVICE_SCRIPT="/etc/init.d/hab-lora-gateway"
DECODER_SERVICE_CONFIG="/etc/hab-lora-gateway.conf"

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
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${DECODER_NAME} Setup" --yesno "${DECODER_NAME} ${DECODER_DESC}. \n\nPlease note that ${DECODER_NAME} requires a LoRa transceiver connected via SPI. \n\n${DECODER_WEBSITE} \n\nContinue setup by installing ${DECODER_NAME} ?" 14 78
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
CheckPackage libncurses5-dev
CheckPackage libcurl4-openssl-dev
CheckPackage curl
CheckPackage wiringpi
echo -e ""

# Check if SPI is enabled, if not use raspi-config to enable it.
if [[ `sudo raspi-config nonint get_spi` -eq 1 ]] ; then
    echo -en "\e[33m  Enabling SPI interface used by LoRa radio module..."
    sudo raspi-config nonint do_spi 0
    CheckReturnCode
    echo -e ""
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

# Download and compile the required SSDV library.
if [[ -d ${BUILD_DIRECTORY_DECODER}/ssdv ]] ; then
    echo -en "\e[33m  Updating SSDV library from github...\t\t\t\t"
    cd ${BUILD_DIRECTORY_DECODER}/ssdv
    git remote update > /dev/null 2>&1
    if [[ `git status -uno | grep -c "is behind"` -gt 0 ]] ; then
        sudo make clean
        git pull
        sudo make install
    fi
else
    echo -en "\e[33m  Cloning SSDV library from github...\t\t\t\t"
    cd ${BUILD_DIRECTORY_DECODER}
    git clone https://github.com/fsphil/ssdv.git
    cd ${BUILD_DIRECTORY_DECODER}/ssdv
    sudo make install
fi
CheckReturnCode
cd ${BUILD_DIRECTORY_DECODER}

# Download and compile the decoder itself.
if [[ -d ${BUILD_DIRECTORY_DECODER}/lora-gateway ]] ; then
    echo -en "\e[33m  Updating ${DECODER_NAME} from github...\t\t\t"
    cd ${BUILD_DIRECTORY_DECODER}/lora-gateway
    git remote update > /dev/null 2>&1
    if [[ `git status -uno | grep -c "is behind"` -gt 0 ]] ; then
        make clean
        git pull
        make
    fi
else
    echo -en "\e[33m  Cloning ${DECODER_NAME} from github...\t\t\t"
    cd ${BUILD_DIRECTORY_DECODER}
    git clone https://github.com/PiInTheSky/lora-gateway.git
    cd ${BUILD_DIRECTORY_DECODER}/lora-gateway
    make
fi
CheckReturnCode
cd ${BUILD_DIRECTORY_DECODER}

# TODO - Map GPIO pins using WiringPi.


### CREATE THE CONFIGURATION FILE

# Use receiver coordinates if already know, otherwise populate with dummy values to ensure valid config generation.

# Latitude.
if [[ -z ${HAB_LATITUDE} ]] ; then
    if [[ -n ${RECEIVER_LATITUDE} ]] ; then
        HAB_LATITUDE="${RECEIVER_LATITUDE}"
    else
        HAB_LATITUDE="0.0000000"
    fi
fi

# Longitude.
if [[ -z ${HAB_LONGITUDE} ]] ; then
    if [[ -n ${RECEIVER_LONGITUDE} ]] ; then
        HAB_LONGITUDE="${RECEIVER_LONGITUDE}"
    else
        HAB_LONGITUDE="0.0000000"
    fi
fi

# Set receiver callsign for this decoder.
# Format TBC, for now assume it should be between 3 and 9 alphanumeric charactors, with no punctuation.
if [[ -z ${HAB_RECEIVER_NAME} ]] ; then
    if [[ -n ${RECEIVERNAME} ]] ; then
        HAB_RECEIVER_NAME=`echo ${RECEIVERNAME} | tr -cd '[:alnum:]' | cut -c -9`
    else
        HAB_RECEIVER_NAME=`hostname -s | tr -cd '[:alnum:]' | cut -c -9`
    fi
fi

# In not specified then set to Unknown.
if [[ -z ${HAB_ANTENNA} ]] ; then
    HAB_ANTENNA="Unknown"
fi

# Test if config file exists, if not create it.
if [[ -s ${BUILD_DIRECTORY_DECODER}/lora-gateway/gateway.txt ]] ; then
    echo -en "\e[33m  Found existing ${DECODER_NAME} config file at \"\e[37mgateway.txt\e[33m\"...\e [97m"
else
    echo -en "\e[33m  Generating new ${DECODER_NAME} config file as \"\e[37mgateway.txt\e[33m\"...\e [97m"
    sudo tee ${BUILD_DIRECTORY_DECODER}/lora-gateway/gateway.txt > /dev/null 2>&1 <<EOF
###########################################################################################
#                                                                                         #
#  CONFIGURATION FILE BASED ON https://github.com/PiInTheSky/lora-gateway#configuration   #
#                                                                                         #
###########################################################################################
#

##### Station Details #####

#	tracker=	<callsign>	The stations callsign.
tracker=${HAB_RECEIVER_NAME}

#	Latitude=	[-180 to 180]	Latitude in decimal degrees.
Latitude=${HAB_LATITUDE}

#	Longitude=	[-180 to 180]	Longitude in decimal degrees.
Longitude=${HAB_LONGITUDE}

#	Antenna=	<freetext>	Antenna description.
Antenna=${HAB_ANTENNA}

##### Global Options #####
#

# 	EnableHabitat=	[Y|N]		Enables uploading of telemetry packets to Habitat.
EnableHabitat=Y

# 	EnableSSDV=	[Y|N]		Enables uploading of SSDV image packets to the SSDV server.
EnableSSDV=Y

# 	JPGFolder=	<folder>	Tells the gateway where to save local JPEG files built from incoming SSDV packets.
JPGFolder=ssdv

# 	LogTelemetry	[Y|N]		Enables logging of telemetry packets (ASCII only at present) to telemetry.txt.
LogTelemetry=Y

# 	LogPackets=	[Y|N]		Enables logging of packet information (SNR, RSSI, length, type) to packets.txt.
LogPackets=Y

# 	CallingTimeout=	<seconds>	Sets a timeout for returning to calling mode after a period with no received packets.
CallingTimeout=60

# 	ServerPort=	[1-65535]	Opens a server socket which can have 1 client connected.  Sends JSON telemetry and status information to that client.
ServerPort=6004

# 	SMSFolder=	<folder>	Tells the gateway to check for incoming SMS messages or tweets that should be sent to the tracker via the uplink.
#SMSFolder=./

#	EnableDev=	[Y|N]		Presumably some sort of developer mode.
EnableDev=N

#	NetworkLED=	<WiringPi pin>	These are used for LED status indicators.
#NetworkLED=22

#	InternetLED=    <WiringPi pin>	Which may be useful for packaged gateways that don't have a monitor attached.	
#InternetLED=23

##### Transceiver Config #####
#

# Channel specific configuration for each LoRa module with each variable in the $variable_n format where n = 0 for the first, 1 for the second etc.
# If the frequency_n line is commented out, then that channel is disabled.
#
# There are a number of preset "modes" which can be used to configure a module for various roles:
#	
#	0 = (normal for telemetry)  		Explicit mode, Error coding 4:8, Bandwidth 20.8 kHz, SF 11, Low data rate optimize on
#	1 = (normal for SSDV)       		Implicit mode, Error coding 4:5, Bandwidth 20.8 kHz, SF  6, Low data rate optimize off
#	2 = (normal for repeater)   		Explicit mode, Error coding 4:8, Bandwidth 62.5 kHz, SF  8, Low data rate optimize off
#	3 = (normal for fast SSDV)  		Explicit mode, Error coding 4:6, Bandwidth 250  kHz, SF  7, Low data rate optimize off
#	4 = Test mode not for normal use.	
#	5 = (normal for calling mode) 		Explicit mode, Error coding 4:8, Bandwidth 41.7 kHz, SF 11, Low data rate optimize off

##### Config CE0 #####
#

#	frequency_0=	<freq in MHz>  	Sets the frequency for LoRa module.
frequency_0=434.451

#	mode_0=  	[0-4]		Sets the "mode" which offers a simple way of setting the various LoRa parameters in one go.
mode_0=1

#	AFC_0=		[Y|N]		Enables automatic frequency control (retunes by the frequency error of last received packet).	
AFC_0=Y

#	bandwidth_0=	<Bandwidth>	Options are 7K8, 10K4, 15K6, 20K8, 31K25, 41K7, 62K5, 125K, 250K, 500K.	
#bandwidth_0=125K

#	implicit_0	[Y|N]		TBC.
#implicit_0=0

#	coding_0=	[5-8]		Second value of 4:x error coding, eg a value of 5 corresponds to 4:5 error coding.
#coding_0=5

#	sf_0=		<Spread Factor> TBC.
#sf_0=8

#	lowopt_0=	[Y|N]		Enables low data rate optimization.
#lowopt_0=0

#	power_0=	[0-255]		This is the power setting used for uplinks.  Refer to the LoRa manual for details on setting this.
#					** Only set values that are legal in your location (for EU see IR2030) **
#power_0=255

#	DIO0_0=		<WiringPi pin>
DIO0_0=31

#	DIO5_0=		<WiringPi pin>	
DIO5_0=26

#	UplinkTime_0=	<seconds>	When to send any uplink messages, measured as seconds into each cycle.
#UplinkTime_0=2

#	UplinkCycle_0=	<seconds>	Cycle time for uplinks, first cycle starts at 00:00:00.
#					eg for uplink time=2 and cycle=30, transmissions will start at 2 and 32 seconds after each minute.	
#UplinkCycle_0=60

#	ActivityLED_0=	<WiringPi pin>
#ActivityLED_0=21

##### Config CE1 #####
#

#	frequency_1=	<freq in MHz>	Sets the frequency for LoRa module.	
#frequency_1=434.500

#	mode_1=		[0-5]		Sets the "mode" which offers a simple way of setting the various LoRa parameters in one go.	
#mode_1=1

#	AFC_1=		[Y|N]		Enables automatic frequency control (retunes by the frequency error of last received packet).	
#AFC_1=Y

#	bandwidth_1=	<Bandwidth>	Options are 7K8, 10K4, 15K6, 20K8, 31K25, 41K7, 62K5, 125K, 250K, 500K.	
#bandwidth_1=125K

#	implicit_1=	[Y|N]		TBC.	
#implicit_1=0

#	coding_1=	[5-8]		Second value of 4:x error coding, eg a value of 5 corresponds to 4:5 error coding.	
#coding_1=5

#	sf_1=		<Spread Factor>	TBC.	
#sf_1=8A

#	lowopt_1=	[Y|N]		Enables low data rate optimization.
#lowopt_1=0

#	power_1		[0-255]		This is the power setting used for uplinks.  Refer to the LoRa manual for details on setting this.
#					** Only set values that are legal in your location (for EU see IR2030) **
#power_1=255

#	DIO0_1=6	<WiringPi pin>	
#DIO0_1=6

#	DIO5_1=		<WiringPi pin>	
#DIO5_1=5

#	UplinkTime_1=	<seconds>	When to send any uplink messages, measured as seconds into each cycle.
#UplinkTime_1=5

#	UplinkCycle_1=	<seconds>	Cycle time for uplinks, first cycle starts at 00:00:00.	
#					eg for uplink time=2 and cycle=30, transmissions will start at 2 and 32 seconds after each minute.
#UplinkCycle_1=60

#	ActivityLED_1=	<WiringPi pin>
#ActivityLED_1=29

EOF
fi

# Update ownership of new config file.
chown pi:pi ${BUILD_DIRECTORY_DECODER}/lora-gateway/gateway.txt > /dev/null 2>&1
CheckReturnCode

### INSTALL AS A SERVICE

#echo -en "\e[33m Downloading and setting permissions on the service script...\t"
#sudo curl -s http:// -o ${DECODER_SERVICE_SCRIPT}
#sudo chmod +x ${DECODER_SERVICE_SCRIPT} > /dev/null 2>&1

echo -en "\e[33m  Creating service config file \"\e[37m${DECODER_SERVICE_CONFIG}\e[33m\"...\t"
sudo tee ${DECODER_SERVICE_CONFIG} > /dev/null 2>&1 <<EOF
#shellbox configuration file
#Starts commands inside a "box" with a telnet-like server.
#Contact the shell with: telnet <hostname> <port>
#Syntax:
#port  user     directory                 command       args
50100  pi ${BUILD_DIRECTORY_DECODER}/lora-gateway    ./gateway
EOF
chown pi:pi ${DECODER_SERVICE_CONFIG} > /dev/null 2>&1
CheckReturnCode

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
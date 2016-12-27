#!/bin/bash

### VARIABLES

PROJECT_ROOT_DIRECTORY="$PWD"
BASHDIRECTORY="${PROJECT_ROOT_DIRECTORY}/bash"
BUILDDIRECTORY="${PROJECT_ROOT_DIRECTORY}/build"
BUILDDIRECTORY_HAB="$BUILDDIRECTORY/hab/"

DECODER_NAME="HAB-LoRa-Gateway"
DECODER_DESC="is a combined receiver and feeder for the LoRa based High Altitude Baloon Tracking System"
DECORDER_GITHUB="https://github.com/PiInTheSky/lora-gateway"
DECODER_WEBSITE="http://www.pi-in-the-sky.com"

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
whiptail --backtitle "${ADSB_PROJECTTITLE}" --title "${DECODER_NAME} Setup" --yesno "${DECODER_NAME} ${DECODER_DESC}. \n\nPlease note that ${DECODER_NAME} requests a LoRa transceiver connected via SPI. \n\n${DECODER_WEBSITE} \n\nContinue setup by installing ${DECODER_NAME} ?" 14 78
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

# Check if SPI is enabled, if not use raspi-config to enable it.
if [[ `sudo raspi-config nonint get_spi` -eq 1 ]] ; then
    sudo raspi-config nonint do_spi 0
fi

### CHECK FOR EXISTING INSTALL AND IF SO STOP IT

### DOWNLOAD AND SET UP THE BINARIES

# Create build directory if not already present.
if [[ ! -d ${BUILDDIRECTORY_HAB} ]] ; then
    mkdir ${BUILDDIRECTORY_HAB}
fi

# Download and compile the required SSDV library.
if [[ -d ${BUILDDIRECTORY_HAB}/ssdv ]] ; then
    cd ${BUILDDIRECTORY_HAB}/ssdv
    git pull
else
    cd ${BUILDDIRECTORY_HAB}
    git clone https://github.com/fsphil/ssdv.git
    cd ${BUILDDIRECTORY_HAB}/ssdv
fi
sudo make install
cd ${BUILDDIRECTORY_HAB}

# Download and compile the decoder itself.
if [[ -d ${BUILDDIRECTORY_HAB}/lora-gateway ]] ; then
    cd ${BUILDDIRECTORY_HAB}/lora-gateway
    git pull
else
    cd ${BUILDDIRECTORY_HAB}
    git clone https://github.com/PiInTheSky/lora-gateway.git
    cd ${BUILDDIRECTORY_HAB}/lora-gateway
fi
make
cd ${BUILDDIRECTORY_HAB}

# TODO - Map GPIO pins using WiringPi.


### CREATE THE CONFIGURATION FILE

# Use receiver coordinates if already know, otherwise populate with dummy values to ensure valid config generation.

if [[ -z ${HAB_LATITUDE} ]] ; then
    if [[ -n ${RECEIVER_LATITUDE} ]] ; then
        HAB_LATITUDE="${RECEIVER_LATITUDE}"
    else
        HAB_LATITUDE="0.0000000"
    fi
fi

if [[ -z ${HAB_LONGITUDE} ]] ; then
    if [[ -n ${RECEIVER_LONGITUDE} ]] ; then
        HAB_LONGITUDE="${RECEIVER_LONGITUDE}"
    else
        HAB_LONGITUDE="0.0000000"
    fi
fi

# Callsign format TBC, for now assume it should be between 3 and 9 alphanumeric charactors, with no punctuation.
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
if [[ -s ${BUILDDIRECTORY_HAB}/lora-gateway/gateway.txt ]] ; then
    echo -e "\e[94m Using existing ${DECODER_NAME} config file \"gateway.txt\"...\e [97m"
else
    echo -e "\e[94m Generating new ${DECODER_NAME} config file as \"gateway.txt\"...\e [97m"
    sudo tee ${BUILDDIRECTORY_HAB}/lora-gateway/gateway.txt > /dev/null <<EOF
###########################################################################################
#                                                                                         #
#  CONFIGURATION FILE BASED ON https://github.com/PiInTheSky/lora-gateway#configuration   #
#                                                                                         #
###########################################################################################
#

##### Station details #####

tracker=${HAB_RECEIVER_NAME}
Latitude=${HAB_LATITUDE}
Longitude=${HAB_ALTITUDE}
Antenna=${HAB_ANTENNA}


##### Config Options #####

EnableHabitat=Y		#	[Y|N]		Enables uploading of telemetry packets to Habitat
EnableSSDV=Y		#	[Y|N]		Enables uploading of SSDV image packets to the SSDV server.
JPGFolder=ssdv		#	<folder>	Tells the gateway where to save local JPEG files built from incoming SSDV packets.
LogTelemetry=Y		#	[Y|N]		Enables logging of telemetry packets (ASCII only at present) to telemetry.txt.
LogPackets=Y		#	[Y|N]		Enables logging of packet information (SNR, RSSI, length, type) to packets.txt.
CallingTimeout=60	#	<seconds>	Sets a timeout for returning to calling mode after a period with no received packets.
ServerPort=6004		#	[1-65535]	Opens a server socket which can have 1 client connected.  Sends JSON telemetry and status information to that client.
#SMSFolder=./		#	<folder>	Tells the gateway to check for incoming SMS messages or tweets that should be sent to the tracker via the uplink.
EnableDev=N		#	[Y|N]		Presumably some sort of developer mode..

#NetworkLED=22		#	<WiringPi pin>	These are used for LED status indicators.
#InternetLED=23		#       <WiringPi pin>	Which may be useful for packaged gateways that don't have a monitor attached.	
#ActivityLED_0=21	#       <WiringPi pin>	
#ActivityLED_1=29	#       <WiringPi pin>	

##### Transceiver Config #####

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

frequency_0=434.451	#	<freq in MHz>  	Sets the frequency for LoRa module.
mode_0=1  		#	[0-4]		Sets the "mode" which offers a simple way of setting the various LoRa parameters in one go.
AFC_0=Y 	 	#	[Y|N]		Enables automatic frequency control (retunes by the frequency error of last received packet).	
#bandwidth_0=125K	#	<Bandwidth>	Options are 7K8, 10K4, 15K6, 20K8, 31K25, 41K7, 62K5, 125K, 250K, 500K.	
#implicit_0=0		#	[Y|N]		TBC.
#coding_0=5		#	[5-8]		Second value of 4:x error coding, eg a value of 5 corresponds to 4:5 error coding.
#sf_0=8			#	<Spread Factor> TBC.
#lowopt_0=0		#	[Y|N]		Enables low data rate optimization.
#power_0=255		#	[0-255]		This is the power setting used for uplinks.  Refer to the LoRa manual for details on setting this.
#						** Only set values that are legal in your location (for EU see IR2030) **
DIO0_0=31		#	<WiringPi pin>
DIO5_0=26		#	<WiringPi pin>	
#UplinkTime_0=2		#	<seconds>	When to send any uplink messages, measured as seconds into each cycle.
#UplinkCycle_0=60	#	<seconds>	Cycle time for uplinks, first cycle starts at 00:00:00. 
#						eg for uplink time=2 and cycle=30, transmissions will start at 2 and 32 seconds after each minute.	


##### Config CE1 #####

#frequency_1=434.500	#	<freq in MHz>	Sets the frequency for LoRa module.	
#mode_1=1		#	[0-5]		Sets the "mode" which offers a simple way of setting the various LoRa parameters in one go.	
#AFC_1=Y 		#	[Y|N]		Enables automatic frequency control (retunes by the frequency error of last received packet).	
#bandwidth_1=125K	#	<Bandwidth>	Options are 7K8, 10K4, 15K6, 20K8, 31K25, 41K7, 62K5, 125K, 250K, 500K.	
#implicit_1=0		#	[Y|N]		TBC.	
#coding_1=5		#	[5-8]		Second value of 4:x error coding, eg a value of 5 corresponds to 4:5 error coding.	
#sf_1=8A		#	<Spread Factor>	TBC.	
#lowopt_1=0		#	[Y|N]		Enables low data rate optimization.
#power_1=255		#	[0-255]		This is the power setting used for uplinks.  Refer to the LoRa manual for details on setting this.
#						** Only set values that are legal in your location (for EU see IR2030) **
#DIO0_1=6		#	<WiringPi pin>	
#DIO5_1=5		#	<WiringPi pin>	
#UplinkTime_1=5		#	<seconds>	When to send any uplink messages, measured as seconds into each cycle.	
#UplinkCycle_1=60	#	<seconds>	Cycle time for uplinks, first cycle starts at 00:00:00.	
#						eg for uplink time=2 and cycle=30, transmissions will start at 2 and 32 seconds after each minute.
EOF
    # Update ownership of new config file.
    chown pi:pi ${BUILDDIRECTORY_HAB}/lora-gateway/gateway.txt
fi

### INSTALL AS A SERVICE

#DECODER_SERVICE_SCRIPT="/etc/init.d/hab-lora-gateway"
DECODER_SERVICE_CONFIG="/etc/hab-lora-gateway.conf"

#echo -e "\033[33m Downloading and setting permissions on the service script..."
#echo -e "\033[37m"
#sudo curl http:// -o ${DECODER_SERVICE_SCRIPT}
#sudo chmod +x ${DECODER_SERVICE_SCRIPT}

echo -e "\033[33m Creating service config file \"${DECODER_SERVICE_CONFIG}\"..."
echo -e "\033[37m"
sudo tee ${DECODER_SERVICE_CONFIG} > /dev/null <<EOF
#shellbox configuration file
#Starts commands inside a "box" with a telnet-like server.
#Contact the shell with: telnet <hostname> <port>
#Syntax:
#port  user     directory                 command       args
50100  pi ${BUILDDIRECTORY_HAB}/lora-gateway    ./gateway  
EOF

echo -en "\033[33m Configuring ${DECODER_NAME} as a service..."
sudo update-rc.d hab-lora-gateway defaults 2>&1 >/dev/null
echo -e "\t\e[92m [Done]\e[39m\n"

echo -en "\033[33m Starting the ${DECODER_NAME} service..."
if [[ `sudo service hab-lora-gateway start` ]] ; then
    echo -e "\t\e[97m [\e[32mDone\e[97m]\e[39m\n"
else 
    echo -e "\t\e[97m [\e[31mFailed\e[97m]\e[31m\n"
fi

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

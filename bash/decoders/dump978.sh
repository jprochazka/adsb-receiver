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
# Copyright (c) 2015-2016 Joseph A. Prochazka                                       #
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
BUILDDIRECTORY_DUMP978="$BUILDDIRECTORY/dump978"

DECODER_NAME="Dump978"
DECODER_WEBSITE="https://github.com/mutability/dump978"

### INCLUDE EXTERNAL SCRIPTS

source $BASHDIRECTORY/variables.sh
source $BASHDIRECTORY/functions.sh

### BEGIN SETUP

clear
echo -e ""
echo -e "\e[91m  $RECEIVER_PROJECT_TITLE"
echo -e ""
echo -e "\e[92m  Setting up ${DECODER_NAME} ...."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo -e ""
whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "${DECODER_NAME} Setup" --yesno "${DECODER_NAME} is an experimental demodulator/decoder for 978MHz UAT signals.\n\n  $DECODER_WEBSITE \n\nWould you like to continue setup by installing ${DECODER_NAME} ?" 9 78
CONTINUESETUP=$?

if [[ $CONTINUESETUP = 1 ]] ; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo -e ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  ${DECODER_NAME} setup halted.\e[39m"
    echo -e ""
    if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
        read -p "Press enter to continue..." CONTINUE
    fi
    exit 1
fi

### CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to build and fulfill dependencies for ${DECODER_NAME} ...\e[97m"
echo -e ""
CheckPackage git
CheckPackage make
CheckPackage rtl-sdr
CheckPackage librtlsdr-dev
CheckPackage libusb-1.0-0-dev
CheckPackage gcc
CheckPackage netcat
CheckPackage lighttpd

### DOWNLOAD THE DUMP978 SOURCE CODE

echo -e ""
echo -e "\e[95m  Preparing the ${DECODER_NAME} Git repository...\e[97m"
echo -e ""

# Remove the existing dumpp978 build directory if it exists.
if [[ -d $BUILDDIRECTORY_DUMP978 ]] ; then
    # Delete the current dump978 build directory if it already exists.
    echo -e "\e[94m  Deleting the existing ${DECODER_NAME} Git repository directory...\e[97m"
    rm -rf $BUILDDIRECTORY_DUMP978
fi

# Clone the dump978 Git repository.
echo -e "\e[94m  Entering the $RECEIVER_PROJECT_TITLE build directory...\e[97m"
cd $BUILDDIRECTORY
echo -e "\e[94m  Cloning the ${DECODER_NAME} Git repository locally...\e[97m"
echo -e ""
git clone https://github.com/mutability/dump978.git

### BUILD THE DUMP978 BINARIES

echo -e ""
echo -e "\e[95m  Building the ${DECODER_NAME} binaries...\e[97m"
echo -e ""
if [[ ! $PWD = $BUILDDIRECTORY_DUMP978 ]] ; then
    echo -e "\e[94m  Entering the ${DECODER_NAME} Git repository directory...\e[97m"
    cd $BUILDDIRECTORY_DUMP978
fi
echo -e "\e[94m  Building the ${DECODER_NAME} binaries...\e[97m"
echo -e ""
make all
echo -e ""

# Check that the dump978 binaries were built.
echo -e "\e[94m  Checking that the ${DECODER_NAME} binaries were built...\e[97m"
if [[ ! -f $BUILDDIRECTORY_DUMP978/dump978 ]] || [[ ! -f $BUILDDIRECTORY_DUMP978/uat2esnt ] || [ ! -f $BUILDDIRECTORY_DUMP978/uat2json ] || [ ! -f $BUILDDIRECTORY_DUMP978/uat2text ]] ; then
    # If the dump978 binaries could not be found halt setup.
    echo -e ""
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  UNABLE TO LOCATE THE ${DECODER_NAME} BINARIES."
    echo -e "  SETUP HAS BEEN TERMINATED!"
    echo -e ""
    echo -e "\e[93mThe ${DECODER_NAME} binaries appear to have not been built successfully..\e[39m"
    echo -e ""
    echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  ${DECODER_NAME} setup halted.\e[39m"
    echo -e ""
    if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
        read -p "Press enter to continue..." CONTINUE
    fi
    exit 1
fi

### SETUP AND CONFIGURE THE DEVICE TO UTILIZE THE DDUMP978 BINARIES

echo -e ""
echo -e "\e[95m  Configuring the device to utilize the ${DECODER_NAME} binaries...\e[97m"
echo -e ""

# Create an RTL-SDR blacklist file so the device does not claim SDR's for other purposes.
echo -e "\e[94m  Creating an RTL-SDR kernel module blacklist file...\e[97m"
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
echo -e "\e[94m  Removing the kernel module dvb_usb_rtl28xxu...\e[97m"
echo -e ""
sudo rmmod dvb_usb_rtl28xxu
echo -e ""

# Check if the dump1090-mutability package is installed.
echo -e "\e[94m  Checking if the dump1090-mutability package is installed...\e[97m"
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
    # The dump1090-mutability package appear to be installed.
    whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "RTL-SDR Device Assignments" --msgbox "It appears the dump1090-mutability package is installed on this device. In order to run ${DECODER_NAME} in tandem with dump1090-mutability you will need to specifiy which RTL-SDR device each decoder is to use.\n\nKeep in mind in order to run both decoders on a single device you will need to have two separate RTL-SDR devices connected to your device." 12 78
    DUMP1090_DEVICE_TITLE="Dump1090 RTL-SDR Device"
    while [[ -z $DUMP1090_DEVICE_ID ]] ; do
        DUMP1090_DEVICE_ID=$(whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "$DUMP1090_DEVICE_TITLE" --nocancel --inputbox "\nEnter the ID for your dump1090 RTL-SDR device." 8 78 3>&1 1>&2 2>&3)
        DUMP1090_DEVICE_TITLE="Dump1090 RTL-SDR Device (REQUIRED)"
    done
    DUMP978_DEVICE_TITLE="Dump978 RTL-SDR Device"
    while [[ -z $DUMP978_DEVICE_ID ]] ; do
        DUMP978_DEVICE_ID=$(whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "$DUMP978_DEVICE_TITLE" --nocancel --inputbox "\nEnter the ID for your dump978 RTL-SDR device." 8 78 3>&1 1>&2 2>&3)
        DUMP978_DEVICE_TITLE="Dump978 RTL-SDR Device (REQUIRED)"
    done

    # Assign the specified RTL-SDR device to dump1090-mutability.
    echo -e "\e[94m  Assigning RTL-SDR device \"$DUMP1090_DEVICE_ID\" to dump1090-mutability...\e[97m"
    ChangeConfig "DEVICE" $DUMP1090_DEVICE_ID "/etc/default/dump1090-mutability"
    echo -e "\e[94m  Restarting dump1090-mutability...\e[97m"
    echo -e ""
    sudo /etc/init.d/dump1090-mutability restart
    echo -e ""

    # Get the latitude and longitude set in the dump1090-mutability configuration file to be used later.
    echo -e "\e[94m  Retrieving the receiver's latitude from /etc/default/dump1090-mutability...\e[97m"
    RECEIVER_LATITUDE=`GetConfig "LAT" "/etc/default/dump1090-mutability"`
    echo -e "\e[94m  Retrieving the receiver's longitude from /etc/default/dump1090-mutability...\e[97m"
    RECEIVERLONGITUDE=`GetConfig "LON" "/etc/default/dump1090-mutability"`
fi

# If a device has not yet been assigned to ${DECODER_NAME} assign the first available.
if [[ -z $DUMP978_DEVICE_ID ]] ; then
    echo -e "\e[94m  Assigning RTL-SDR device \"0\" to ${DECODER_NAME} ...\e[97m"
    DUMP978_DEVICE_ID="0"
fi

# Declare the LIGHTTPDDOCUMENTROOTDIRECTORY variable.
echo -e "\e[94m  Getting the path to Lighttpd's document root...\e[97m"
LIGHTTPDDOCUMENTROOTSETTING=`/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root`
LIGHTTPDDOCUMENTROOTDIRECTORY=`sed 's/.*"\(.*\)"[^"]*$/\1/' <<< $LIGHTTPDDOCUMENTROOTSETTING`

# Confirm the receivers latitude and longitude, if not already known.
if [[ -z $RECEIVER_LATITUDE ]] || [[ -z $RECEIVER_LONGITUDE ]] ; then
    # If dump1090-mutability is not installed ask for the latitude and longitude of this receiver.
    RECEIVER_LATITUDE_TITLE="Receiver Latitude (OPTIONAL)" 
#    while [[ -z $RECEIVER_LATITUDE ]] ; do
        RECEIVER_LATITUDE=$(whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "$RECEIVER_LATITUDE_TITLE" --nocancel --inputbox "\nEnter your receiver's latitude.\n(Example: XX.XXXXXXX)\n\nLeave blank and select <Ok> to skip." 12 78 3>&1 1>&2 2>&3)
        RECEIVER_LONGITUDE_TITLE="Receiver Longitude"
#    done
    while [[ -z $RECEIVER_LONGITUDE ]] ; do
        RECEIVER_LONGITUDE=$(whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "$RECEIVER_LONGITUDE_TITLE" --nocancel --inputbox "\nEnter your receeiver's longitude.\n(Example: XX.XXXXXXX)" 9 78 3>&1 1>&2 2>&3)
        RECEIVER_LONGITUDE_TITLE="Receiver Longitude (REQUIRED)"
    done
fi

# Now set the receivers latitude and longitude.
if [[ ! -z $RECEIVER_LATITUDE ]] && [[ ! -z $RECEIVER_LONGITUDE ]] ; then
    echo -e "\e[94m  Setting the receiver's latitude to $RECEIVER_LATITUDE...\e[97m"
    ChangeConfig "SiteLat" "$RECEIVER_LATITUDE" "$LIGHTTPDDOCUMENTROOTDIRECTORY/dump978/config.js"
    echo -e "\e[94m  Setting the receiver's longitude to $RECEIVER_LONGITUDE...\e[97m"
    ChangeConfig "SiteLon" "$RECEIVER_LONGITUDE" "$LIGHTTPDDOCUMENTROOTDIRECTORY/dump978/config.js"
fi

# Create the dump978 JSON directory in Lighttpd's document root.
echo -e "\e[94m  Creating the ${DECODER_NAME} JSON data directory within Lighttpd's document root...\e[97m"
sudo mkdir -p $LIGHTTPDDOCUMENTROOTDIRECTORY/dump978/data
echo -e "\e[94m  Setting permissions for the dump978 JSON data directory within Lighttpd's document root...\e[97m"
sudo chmod +w $LIGHTTPDDOCUMENTROOTDIRECTORY/dump978/data

# Create the dump978 maintenance script.
echo -e "\e[94m  Creating the ${DECODER_NAME} maintenance script...\e[97m"
tee $BUILDDIRECTORY_DUMP978/dump978-maint.sh > /dev/null <<EOF
#! /bin/bash

# Start dump978 without logging.
while true; do
    rtl_sdr -d $DUMP978_DEVICE_ID -f 978000000 -s 2083334 -g 48 - | $BUILDDIRECTORY_DUMP978/dump978 | tee >($BUILDDIRECTORY_DUMP978/uat2json $LIGHTTPDDOCUMENTROOTDIRECTORY/dump978/data) | $BUILDDIRECTORY_DUMP978/uat2esnt | /bin/nc -q1 127.0.0.1 30001
    sleep 15
done
EOF
echo -e "\e[94m  Setting permissions on the ${DECODER_NAME} maintenance script...\e[97m"
chmod +x $BUILDDIRECTORY_DUMP978/dump978-maint.sh

# Add the dump978 maintenance script to /etc/rc.local.
echo -e "\e[94m  Checking if the file /etc/rc.local is already set to execute the ${DECODER_NAME} maintenance script...\e[97m"
if ! grep -Fxq "$BUILDDIRECTORY_DUMP978/dump978-maint.sh &" /etc/rc.local; then
    echo -e "\e[94m  Adding a line to execute the ${DECODER_NAME} maintenance script to the file /etc/rc.local...\e[97m"
    LINENUMBER=($(sed -n '/exit 0/=' /etc/rc.local))
    ((LINENUMBER>0)) && sudo sed -i "${LINENUMBER[$((${#LINENUMBER[@]}-1))]}i ${BUILDDIRECTORY_DUMP978}/dump978-maint.sh &\n" /etc/rc.local
fi

### EXECUTE THE MAINTAINANCE SCRIPT TO START DUMP978

echo -e ""
echo -e "\e[95m  Starting ${DECODER_NAME} ...\e[97m"
echo -e ""
echo -e "\e[94m  Starting ${DECODER_NAME} by executing the ${DECODER_NAME} maintenance script...\e[97m"
sudo nohup $BUILDDIRECTORY_DUMP978/dump978-maint.sh > /dev/null 2>&1 &

### SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the $RECEIVER_PROJECT_TITLE root directory...\e[97m"
cd $PROJECTROOTDIRECTORY

echo -e ""
echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
echo -e "\e[92m  ${DECODER_NAME} setup is complete.\e[39m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

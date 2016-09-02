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
DUMP978BUILDDIRECTORY="$BUILDDIRECTORY/dump978"

### INCLUDE EXTERNAL SCRIPTS

source $BASHDIRECTORY/variables.sh
source $BASHDIRECTORY/functions.sh

### BEGIN SETUP

clear
echo -e "\n\e[91m  THE ADS-B RECIEVER PROJECT VERSION $PROJECTVERSION"
echo ""
echo -e "\e[92m  Setting up dump978..."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo ""
whiptail --title "Dump1090-mutability Setup" --yesno "Dump978 is an experimental demodulator/decoder for 978MHz UAT signals.\n\n  https://github.com/mutability/dump978\n\nContinue setup by installing dump978?" 9 78
CONTINUESETUP=$?
if [ $CONTINUESETUP = 1 ]; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo ""
    echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  Dump978 setup halted.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo ""
CheckPackage git
CheckPackage make
CheckPackage rtl-sdr
CheckPackage librtlsdr-dev
CheckPackage libusb-1.0-0-dev
CheckPackage gcc
CheckPackage netcat
CheckPackage lighttpd

## DOWNLOAD THE DUMP978 SOURCE CODE

echo ""
echo -e "\e[95m  Preparing the dump978 Git repository...\e[97m"
echo ""

# Remove the existing dumpp978 build directory if it exists.
if [ -d $DUMP978BUILDDIRECTORY ]; then
    # Delete the current dump978 build directory if it already exists.
    echo -e "\e[94m  Deleting the existing dump978 Git repository directory...\e[97m"
    rm -rf $DUMP978BUILDDIRECTORY
fi

# Clone the dump978 Git repository.
echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
cd $BUILDDIRECTORY
echo -e "\e[94m  Cloning the dump978 Git repository locally...\e[97m"
echo ""
git clone https://github.com/mutability/dump978.git

## BUILD THE DUMP978 BINARIES

echo ""
echo -e "\e[95m  Building the dump978 binaries...\e[97m"
echo ""
if [ ! $PWD = $DUMP978BUILDDIRECTORY ]; then
    echo -e "\e[94m  Entering the dump978 Git repository directory...\e[97m"
    cd $DUMP978BUILDDIRECTORY
fi
echo -e "\e[94m  Building the dump978 binaries...\e[97m"
echo ""
make all
echo ""

# Check that the dump978 binaries were built.
echo -e "\e[94m  Checking that the dump978 binaries were built...\e[97m"
if [ ! -f $DUMP978BUILDDIRECTORY/dump978 ] || [ ! -f $DUMP978BUILDDIRECTORY/uat2esnt ] || [ ! -f $DUMP978BUILDDIRECTORY/uat2json ] || [ ! -f $DUMP978BUILDDIRECTORY/uat2text ]; then
    # If the dump978 binaries could not be found halt setup.
    echo ""
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  UNABLE TO LOCATE THE DUMP978 BINARIES."
    echo -e "  SETUP HAS BEEN TERMINATED!"
    echo ""
    echo -e "\e[93mThe dump978 binaries appear to have not been built successfully..\e[39m"
    echo ""
    echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  Dump978 setup halted.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

## SETUP AND CONFIGURE THE DEVICE TO UTILIZE THE DDUMP978 BINARIES

echo ""
echo -e "\e[95m  Configuring the device to utilize the dump978 binaries...\e[97m"
echo ""

# Create an RTL-SDR blacklist file so the device does not claim SDR's for other purposes.
echo -e "\e[94m  Creating an RTL-SDR kernel module blacklist file...\e[97m"
sudo tee /etc/modprobe.d/rtlsdr-blacklist.conf  > /dev/null <<EOF
blacklist dvb_usb_rtl28xxu
blacklist dvb_usb_v2
blacklist rtl_2830
blacklist rtl_2832
blacklist r820t
EOF
echo -e "\e[94m  Removing the kernel module dvb_usb_rtl28xxu...\e[97m"
echo ""
sudo rmmod dvb_usb_rtl28xxu
echo ""

# Check if the dump1090-mutability package is installed.
echo -e "\e[94m  Checking if the dump1090-mutability package is installed...\e[97m"
if [ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
    # The dump1090-mutability package appear to be installed.
    whiptail --title "RTL-SDR Dongle Assignments" --msgbox "It appears the dump1090-mutability package is installed on this device. In order to run dump978 in tandem with dump1090-mutability you will need to specifiy which RTL-SDR dongle each decoder is to use.\n\nKeep in mind in order to run both decoders on a single device you will need to have two separate RTL-SDR devices connected to your device." 12 78
    DUMP1090DEVICE_TITLE="Dump1090 RTL-SDR Dongle"
    while [[ -z $DUMP1090DEVICE ]]; do
        DUMP1090DEVICE=$(whiptail --title "$DUMP1090DEVICE_TITLE" --nocancel --inputbox "\nEnter the ID for your dump1090 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
        DUMP1090DEVICE_TITLE="Dump1090 RTL-SDR Dongle (REQUIRED)"
    done
    DUMP978DEVICE_TITLE="Dump978 RTL-SDR Dongle"
    while [[ -z $DUMP978DEVICE ]]; do
        DUMP978DEVICE=$(whiptail --title "$DUMP978DEVICE_TITLE" --nocancel --inputbox "\nEnter the ID for your dump978 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
        DUMP978DEVICE_TITLE="Dump978 RTL-SDR Dongle (REQUIRED)"
    done

    # Assign the specified RTL-SDR dongle to dump1090-mutability.
    echo -e "\e[94m  Assigning RTL-SDR dongle \"$DUMP1090DEVICE\" to dump1090-mutability...\e[97m"
    ChangeConfig "DEVICE" $DUMP1090DEVICE "/etc/default/dump1090-mutability"
    echo -e "\e[94m  Restarting dump1090-mutability...\e[97m"
    echo ""
    sudo /etc/init.d/dump1090-mutability restart
    echo ""
fi

# If a device has not yet been assigned to dump978 assign the first available.
if [ -z $DUMP978DEVICE ]; then
    echo -e "\e[94m  Assigning RTL-SDR dongle \"0\" to dump978...\e[97m"
    DUMP978DEVICE="0"
fi

# Create the dump978 JSON directory in Lighttpd's document root.
echo -e "\e[94m  Getting the path to Lighttpd's document root...\e[97m"
LIGHTTPDDOCUMENTROOTSETTING=`/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root`
LIGHTTPDDOCUMENTROOTDIRECTORY=`sed 's/.*"\(.*\)"[^"]*$/\1/' <<< $LIGHTTPDDOCUMENTROOTSETTING`
echo -e "\e[94m  Creating the dump978 JSON data directory within Lighttpd's document root...\e[97m"
sudo mkdir -p $LIGHTTPDDOCUMENTROOTDIRECTORY/dump978/data
echo -e "\e[94m  Setting permissions for the dump978 JSON data directory within Lighttpd's document root...\e[97m"
sudo chmod +w $LIGHTTPDDOCUMENTROOTDIRECTORY/dump978/data

# Create the dump978 maintenance script.
echo -e "\e[94m  Creating the dump978 maintenance script...\e[97m"
tee $DUMP978BUILDDIRECTORY/dump978-maint.sh > /dev/null <<EOF
#! /bin/sh

# Start dump978 without logging.
while true; do
    rtl_sdr -d $DUMP978DEVICE -f 978000000 -s 2083334 -g 48 - | $DUMP978BUILDDIRECTORY/dump978 | $DUMP978BUILDDIRECTORY/uat2json $LIGHTTPDDOCUMENTROOTDIRECTORY/dump978/data | $DUMP978BUILDDIRECTORY/uat2esnt | /bin/nc -q1 127.0.0.1 30001 &
    sleep 15
done
EOF
echo -e "\e[94m  Setting permissions on the dump978 maintenance script...\e[97m"
chmod +x $DUMP978BUILDDIRECTORY/dump978-maint.sh

# Add the dump978 maintenance script to /etc/rc.local.
echo -e "\e[94m  Checking if the file /etc/rc.local is already set to execute the dump978 maintenance script...\e[97m"
if ! grep -Fxq "$DUMP978BUILDDIRECTORY/dump978-maint.sh &" /etc/rc.local; then
    echo -e "\e[94m  Adding a line to execute the dump978 maintenance script to the file /etc/rc.local...\e[97m"
    LINENUMBER=($(sed -n '/exit 0/=' /etc/rc.local))
    ((LINENUMBER>0)) && sudo sed -i "${LINENUMBER[$((${#LINENUMBER[@]}-1))]}i ${DUMP978BUILDDIRECTORY}/dump978-maint.sh &\n" /etc/rc.local
fi

exit 0

## EXECUTE THE MAINTAINANCE SCRIPT TO START DUMP978

echo ""
echo -e "\e[95m  Starting dump978...\e[97m"
echo ""
echo -e "\e[94m  Starting dump978 by executing the dump978 maintenance script...\e[97m"
sudo $DUMP978BUILDDIRECTORY/dump978-maint.sh > /dev/null &


## DUMP978 SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd $PROJECTROOTDIRECTORY

echo ""
echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
echo -e "\e[92m  Dump978 setup is complete.\e[39m"
echo ""
read -p "Press enter to continue..." CONTINUE

exit 0

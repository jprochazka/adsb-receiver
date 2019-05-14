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
# Copyright (c) 2015-2019 Joseph A. Prochazka                                       #
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

### INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

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
echo -e "\e[92m  Setting up dump978..."
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump1090-mutability Setup" --yesno "Dump978 is an experimental demodulator/decoder for 978MHz UAT signals.\n\n  https://github.com/mutability/dump978\n\nWould you like to continue setup by installing dump978?" 9 78
    if [[ $? -eq 1 ]] ; then
        # Setup has been halted by the user.
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo -e ""
        echo -e "\e[93m  ------------------------------------------------------------------------------"
        echo -e "\e[92m  Dump978 setup halted.\e[39m"
        echo -e ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
    fi
fi

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo -e ""
CheckPackage git
CheckPackage make
CheckPackage rtl-sdr
CheckPackage librtlsdr-dev
CheckPackage libusb-1.0-0-dev
CheckPackage gcc
CheckPackage netcat
CheckPackage lighttpd

## ENABLE THE USE OF /ETC/RC.LOCAL IF THE FILE DOES NOT EXIST

if [ ! -f /etc/rc.local ]; then
    echo ""
    echo -e "\e[95m  Enabling the use of the /etc/rc.local file...\e[97m"
    echo ""

    # In Debian Stretch /etc/rc.local has been removed.
    # However at this time we can bring this file back into play.
    # As to if in future releases this will work remains to be seen...

    echo -e "\e[94m  Creating the file /etc/rc.local...\e[97m"
    sudo tee /etc/rc.local > /dev/null <<EOF
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.
exit 0
EOF

    echo -e "\e[94m  Making /etc/rc.local executable...\e[97m"
    sudo chmod +x /etc/rc.local
    echo -e "\e[94m  Enabling the use of /etc/rc.local...\e[97m"
    sudo systemctl start rc-local
fi

## DOWNLOAD THE DUMP978 SOURCE CODE

echo -e ""
echo -e "\e[95m  Preparing the dump978 Git repository...\e[97m"
echo -e ""

# Create or recreate the dump978 build directory.
if [[ -d "${RECEIVER_BUILD_DIRECTORY}/dump978" ]] ; then
    # Delete the current dump978 build directory if it already exists.
    echo -e "\e[94m  Deleting the existing dump978 build directory...\e[97m"
    rm -rf ${RECEIVER_BUILD_DIRECTORY}/dump978
fi
echo -e "\e[94m  Creating the dump978 build directory...\e[97m"
echo ""
mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/dump978
echo ""

# Clone the dump978 Git repository.
echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
cd ${RECEIVER_BUILD_DIRECTORY}/dump978 2>&1
echo -e "\e[94m  Cloning the dump978 Git repository locally...\e[97m"
echo -e ""
git clone https://github.com/mutability/dump978.git

## BUILD THE DUMP978 BINARIES

echo -e ""
echo -e "\e[95m  Building the dump978 binaries...\e[97m"
echo -e ""
# Enter the dump978 repository if we are not already in it.
if [[ ! "${PWD}" = "${RECEIVER_BUILD_DIRECTORY}/dump978/dump978" ]] ; then
    echo -e "\e[94m  Entering the dump978 Git repository directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/dump978/dump978 2>&1
fi
# Build the dump978 binaries from source.
echo -e "\e[94m  Building the dump978 binaries...\e[97m"
echo -e ""
make all
echo -e ""

# Check that the dump978 binaries were built.
echo -e "\e[94m  Checking that the dump978 binaries were built...\e[97m"
if [[ ! -f "${RECEIVER_BUILD_DIRECTORY}/dump978/dump978/dump978" ]] || [[ ! -f "${RECEIVER_BUILD_DIRECTORY}/dump978/dump978/uat2esnt" ]] || [[ ! -f "${RECEIVER_BUILD_DIRECTORY}/dump978/dump978/uat2json" ]] || [[ ! -f "${RECEIVER_BUILD_DIRECTORY}/dump978/dump978/uat2text" ]] ; then
    # If the dump978 binaries could not be found halt setup.
    echo -e ""
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  UNABLE TO LOCATE THE DUMP978 BINARIES."
    echo -e "  SETUP HAS BEEN TERMINATED!"
    echo -e ""
    echo -e "\e[93mThe dump978 binaries appear to have not been built successfully..\e[39m"
    echo -e ""
    echo -e "\e[93m  ------------------------------------------------------------------------------"
    echo -e "\e[92m  Dump978 setup halted.\e[39m"
    echo -e ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

## SETUP AND CONFIGURE THE DEVICE TO UTILIZE THE DDUMP978 BINARIES

echo -e ""
echo -e "\e[95m  Configuring the device to utilize the dump978 binaries...\e[97m"
echo -e ""

### BLACKLIST UNWANTED RTL-SDR MODULES

# Create an RTL-SDR blacklist file so the device does not claim SDR's for other purposes.
BlacklistModules

# Remove the dvb_usb_rtl28xxu kernel module.
echo -e "\e[94m  Checking if the kernel module dvb_usb_rtl28xxu is loaded...\e[97m"
if lsmod | grep "dvb_usb_rtl28xxu" &> /dev/null ; then
    echo -e "\e[94m  Removing the kernel module dvb_usb_rtl28xxu...\e[97m"
    echo ""
    sudo rmmod dvb_usb_rtl28xxu
    echo ""
fi

# Check if the dump1090-mutability package is installed.
echo -e "\e[94m  Checking if the dump1090-mutability package is installed...\e[97m"
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]] || [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
    # The dump1090-mutability package appear to be installed.
    if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
        whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "RTL-SDR Dongle Assignments" --msgbox "It appears one of the dump1090 packages has been installed on this device. In order to run dump978 in tandem with dump1090 you will need to specifiy which RTL-SDR dongle each decoder is to use.\n\nKeep in mind in order to run both decoders on a single device you will need to have two separate RTL-SDR devices connected to your device." 12 78
        # Ask the user which USB device is to be used for dump1090.
        DUMP1090_DEVICE_ID=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump1090 RTL-SDR Dongle" --nocancel --inputbox "\nEnter the ID for your dump1090 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
        while [[ -z "${DUMP1090_DEVICE_ID}" ]] ; do
            DUMP1090_DEVICE_ID=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump1090 RTL-SDR Dongle (REQUIRED)" --nocancel --inputbox "\nEnter the ID for your dump1090 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
        done
        # Ask the user which USB device is to be use for dump978.
        DUMP978_DEVICE_ID=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump978 RTL-SDR Dongle" --nocancel --inputbox "\nEnter the ID for your dump978 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
        while [[ -z "${DUMP978_DEVICE_ID}" ]] ; do
            DUMP978_DEVICE_ID=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump978 RTL-SDR Dongle (REQUIRED)" --nocancel --inputbox "\nEnter the ID for your dump978 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
        done
    fi

    # Assign the specified RTL-SDR dongle to dump1090-mutability.
    if [[ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
        echo -e "\e[94m  Assigning RTL-SDR dongle \"${DUMP1090_DEVICE_ID}\" to dump1090-mutability...\e[97m"
        ChangeConfig "DEVICE" ${DUMP1090_DEVICE_ID} "/etc/default/dump1090-mutability"
        echo -e "\e[94m  Restarting dump1090-mutability...\e[97m"
        echo -e ""
        sudo service dump1090-mutability force-reload
        echo -e ""
    fi

    # Assign the specified RTL-SDR dongle to dump1090-fa.
    if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
        echo -e "\e[94m  Assigning RTL-SDR dongle \"${DUMP1090_DEVICE_ID}\" to dump1090-fa...\e[97m"
        ChangeSwitch "--device-index" "${DUMP1090_DEVICE_ID}" "/etc/default/dump1090-fa"
        echo -e "\e[94m  Restarting dump1090-fa...\e[97m"
        echo -e ""
        sudo service dump1090-fa force-reload
        echo -e ""
    fi

    # Get the latitude and longitude set in the dump1090-mutability configuration file to be used later.
    echo -e "\e[94m  Retrieving the receiver's latitude from /etc/default/dump1090-mutability...\e[97m"
    RECEIVER_LATITUDE=`GetConfig "LAT" "/etc/default/dump1090-mutability"`
    echo -e "\e[94m  Retrieving the receiver's longitude from /etc/default/dump1090-mutability...\e[97m"
    RECEIVER_LONGITUDE=`GetConfig "LON" "/etc/default/dump1090-mutability"`
fi

# If a device has not yet been assigned to dump978 assign the first available.
if [[ -z "${DUMP978_DEVICE_ID}" ]] ; then
    echo -e "\e[94m  Assigning RTL-SDR dongle \"0\" to dump978...\e[97m"
    DUMP978_DEVICE_ID="0"
fi

# Declare the LIGHTTPD_DOCUMENT_ROOT_DIRECTORY variable.
echo -e "\e[94m  Getting the path to Lighttpd's document root...\e[97m"
LIGHTTPD_DOCUMENT_ROOT_SETTING=`/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root`
LIGHTTPD_DOCUMENT_ROOT_DIRECTORY=`sed 's/.*"\(.*\)"[^"]*$/\1/' <<< ${LIGHTTPD_DOCUMENT_ROOT_SETTING}`

# Set the receivers latitude and longitude.
if [[ -z "${RECEIVER_LATITUDE}" ]] && [[ -z "${RECEIVER_LONGITUDE}" ]] && [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # If the receiver's' latitude has not yet been set ask for it.
    RECEIVER_LATITUDE_TITLE="Receiver Latitude"
    while [[ -z "${RECEIVER_LATITUDE}" ]] ; do
        RECEIVER_LATITUDE=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${RECEIVER_LATITUDE_TITLE}" --nocancel --inputbox "\nEnter your receiver's latitude.\n(Example: XX.XXXXXXX)" 9 78 3>&1 1>&2 2>&3)
        RECEIVER_LATITUDE_TITLE="Receiver Latitude (REQUIRED)"
    done
    # If the receiver's' longitude has not yet been set ask for it.
    RECEIVER_LONGITUDE_TITLE="Receiver Longitude"
    while [[ -z "${RECEIVER_LONGITUDE}" ]] ; do
        RECEIVER_LONGITUDE=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${RECEIVER_LONGITUDE_TITLE}" --nocancel --inputbox "\nEnter your receiver's longitude.\n(Example: XX.XXXXXXX)" 9 78 3>&1 1>&2 2>&3)
        RECEIVER_LONGITUDE_TITLE="Receiver Latitude (REQUIRED)"
    done
fi
# Finally set the reciver's latitude and longitude if these variables were supplied.
if [[ -n "${RECEIVER_LATITUDE}" ]] && [[ -n "${RECEIVER_LONGITUDE}" ]] ; then
    if [ -f ${LIGHTTPD_DOCUMENT_ROOT_DIRECTORY}/dump978/config.js ]; then
        echo -e "\e[94m  Setting the receiver's latitude in ${LIGHTTPD_DOCUMENT_ROOT_DIRECTORY}/dump978/config.js to ${RECEIVER_LATITUDE}...\e[97m"
        ChangeConfig "SiteLat" "${RECEIVER_LATITUDE}" "${LIGHTTPD_DOCUMENT_ROOT_DIRECTORY}/dump978/config.js"
        echo -e "\e[94m  Setting the receiver's longitude in ${LIGHTTPD_DOCUMENT_ROOT_DIRECTORY}/dump978/config.js to ${RECEIVER_LONGITUDE}...\e[97m"
        ChangeConfig "SiteLon" "${RECEIVER_LONGITUDE}" "${LIGHTTPD_DOCUMENT_ROOT_DIRECTORY}/dump978/config.js"
    fi
    echo -e "\e[94m  Setting the receiver's latitude in ${RECEIVER_BUILD_DIRECTORY}/portal/html/dump978/config.js to ${RECEIVER_LATITUDE}...\e[97m"
    ChangeConfig "SiteLat" "${RECEIVER_LATITUDE}" "${RECEIVER_BUILD_DIRECTORY}/portal/html/dump978/config.js"
    echo -e "\e[94m  Setting the receiver's longitude in ${RECEIVER_BUILD_DIRECTORY}/portal/html/dump978/config.js to ${RECEIVER_LONGITUDE}...\e[97m"
    ChangeConfig "SiteLon" "${RECEIVER_LONGITUDE}" "${RECEIVER_BUILD_DIRECTORY}/portal/html/dump978/config.js"
fi

# Create the dump978 JSON directory in Lighttpd's document root.
if [[ ! -d ${LIGHTTPD_DOCUMENT_ROOT_DIRECTORY}/dump978/data ]]; then
    echo -e "\e[94m  Creating the dump978 JSON data directory within Lighttpd's document root...\e[97m"
    echo ""
    sudo mkdir -vp ${LIGHTTPD_DOCUMENT_ROOT_DIRECTORY}/dump978/data
    echo ""
    echo -e "\e[94m  Setting permissions for the dump978 JSON data directory within Lighttpd's document root...\e[97m"
    sudo chmod +w ${LIGHTTPD_DOCUMENT_ROOT_DIRECTORY}/dump978/data
fi

# Create the dump978 maintenance script.
echo -e "\e[94m  Creating the dump978 maintenance script...\e[97m"
tee ${RECEIVER_BUILD_DIRECTORY}/dump978/dump978-maint.sh > /dev/null <<EOF
#!/bin/bash

# Start dump978 without logging.
while true; do
    rtl_sdr -d ${DUMP978_DEVICE_ID} -f 978000000 -s 2083334 -g 48 - | ${RECEIVER_BUILD_DIRECTORY}/dump978/dump978/dump978 | tee >(${RECEIVER_BUILD_DIRECTORY}/dump978/dump978/uat2json ${LIGHTTPD_DOCUMENT_ROOT_DIRECTORY}/dump978/data) | ${RECEIVER_BUILD_DIRECTORY}/dump978/dump978/uat2esnt | /bin/nc -q1 127.0.0.1 30001
    sleep 15
done
EOF
echo -e "\e[94m  Setting permissions on the dump978 maintenance script...\e[97m"
chmod +x ${RECEIVER_BUILD_DIRECTORY}/dump978/dump978-maint.sh

# Add the dump978 maintenance script to /etc/rc.local.
echo -e "\e[94m  Checking if the file /etc/rc.local is already set to execute the dump978 maintenance script...\e[97m"
if [[ `grep -cFx "${RECEIVER_BUILD_DIRECTORY}/dump978/dump978-maint.sh &" /etc/rc.local` -eq 0 ]] ; then
    echo -e "\e[94m  Adding a line to execute the dump978 maintenance script to the file /etc/rc.local...\e[97m"
    LINENUMBER=($(sed -n '/exit 0/=' /etc/rc.local))
    ((LINENUMBER>0)) && sudo sed -i "${LINENUMBER[$((${#LINENUMBER[@]}-1))]}i ${RECEIVER_BUILD_DIRECTORY}/dump978/dump978-maint.sh &\n" /etc/rc.local
fi

## EXECUTE THE MAINTAINANCE SCRIPT TO START DUMP978

echo -e ""
echo -e "\e[95m  Starting dump978...\e[97m"
echo -e ""
echo -e "\e[94m  Starting dump978 by executing the dump978 maintenance script...\e[97m"
sudo nohup ${RECEIVER_BUILD_DIRECTORY}/dump978/dump978-maint.sh > /dev/null 2>&1 &

### SETUP COMPLETE

# Return to the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  Dump978 setup is complete.\e[39m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

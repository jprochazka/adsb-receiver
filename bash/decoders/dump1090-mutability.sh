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
BUILDDIRECTORY_DUMP1090="$BUILDDIRECTORY/dump1090-mutability"

DECODER_NAME="Dump1090-mutability"
DECODER_WEBSITE="https://github.com/mutability/dump1090"

### INCLUDE EXTERNAL SCRIPTS

source $BASHDIRECTORY/variables.sh
source $BASHDIRECTORY/functions.sh

### BEGIN SETUP

clear
echo -e ""
echo -e "\e[91m  $RECEIVER_PROJECT_TITLE"
echo -e ""
echo -e "\e[92m  Setting up ${DECODER_NAME} ..."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo -e ""
whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "${DECODER_NAME} Setup" --yesno "Dump1090 is a Mode-S decoder specifically designed for RTL-SDR devices. ${DECODER_NAME} is a fork of MalcolmRobb's version of Dump1090 that adds new functionality and is designed to be built as a Debian/Raspbian package.\n\n  $DECODER_WEBSITE \n\nContinue setup by installing ${DECODER_NAME}?" 14 78
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
CheckPackage curl
CheckPackage build-essential
CheckPackage debhelper
CheckPackage cron
CheckPackage rtl-sdr
CheckPackage librtlsdr-dev
CheckPackage libusb-1.0-0-dev
CheckPackage pkg-config
CheckPackage lighttpd
CheckPackage fakeroot

### DOWNLOAD OR UPDATE THE DUMP1090-MUTABILITY SOURCE

echo -e ""
echo -e "\e[95m  Preparing the ${DECODER_NAME} Git repository...\e[97m"
echo -e ""
if [[ -d $BUILDDIRECTORY_DUMP1090/dump1090 ]] && [[ -d $BUILDDIRECTORY_DUMP1090/dump1090/.git ]] ; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the ${DECODER_NAME} git repository directory...\e[97m"
    cd $BUILDDIRECTORY_DUMP1090/dump1090
    echo -e "\e[94m  Updating the local ${DECODER_NAME} git repository...\e[97m"
    echo -e ""
    git pull
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Entering the $RECEIVER_PROJECT_TITLE build directory...\e[97m"
    mkdir -p $BUILDDIRECTORY_DUMP1090
    cd $BUILDDIRECTORY_DUMP1090
    echo -e "\e[94m  Cloning the ${DECODER_NAME} git repository locally...\e[97m"
    echo -e ""
    git clone https://github.com/mutability/dump1090.git
fi

### BUILD AND INSTALL THE DUMP1090-MUTABILITY PACKAGE

echo -e ""
echo -e "\e[95m  Building and installing the ${DECODER_NAME} package...\e[97m"
echo -e ""
if [[ ! $PWD = $BUILDDIRECTORY_DUMP1090/dump1090 ]] ; then
    echo -e "\e[94m  Entering the ${DECODER_NAME} git repository directory...\e[97m"
    cd $BUILDDIRECTORY_DUMP1090/dump1090
fi
echo -e "\e[94m  Building the ${DECODER_NAME} package...\e[97m"
echo -e ""
dpkg-buildpackage -b
echo -e ""
echo -e "\e[94m  Entering the $RECEIVER_PROJECT_TITLE build directory...\e[97m"
cd $BUILDDIRECTORY_DUMP1090
echo -e "\e[94m  Installing the ${DECODER_NAME} package...\e[97m"
echo -e ""
sudo dpkg -i dump1090-mutability_1.15~dev_*.deb

# Check that the package was installed.
echo -e ""
echo -e "\e[94m  Checking that the ${DECODER_NAME} package was installed properly...\e[97m"
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 0 ]] ; then
    # If the dump1090-mutability package could not be installed halt setup.
    echo -e ""
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  UNABLE TO INSTALL A REQUIRED PACKAGE."
    echo -e "  SETUP HAS BEEN TERMINATED!"
    echo -e ""
    echo -e "\e[93mThe package \"${DECODER_NAME}\" could not be installed.\e[39m"
    echo -e ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  ${DECODER_NAME} setup halted.\e[39m"
    echo -e ""
    if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
        read -p "Press enter to continue..." CONTINUE
    fi
    exit 1
fi

### DUMP1090-MUTABILITY POST INSTALLATION CONFIGURATION

DUMP1090_CONFIGURATION_FILE="/etc/default/dump1090-mutability"

# Set the receiver's latitude and longitude if it is not already set in the dump1090-mutibility configuration file.
echo -e ""
echo -e "\e[95m  Begining post installation configuration...\e[97m"
echo -e ""
whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "Receiver Latitude and Longitude" --msgbox "Your receivers latitude and longitude are required for certain features to function properly. You will now be asked to supply the latitude and longitude for your receiver. If you do not have this information you get it by using the web based \"Geocode by Address\" utility hosted on another of my websites.\n\n  https://www.swiftbyte.com/toolbox/geocode" 13 78
RECEIVER_LATITUDE_TITLE="Receiver Latitude"
while [[ -z $RECEIVER_LATITUDE ]] ; do
    RECEIVER_LATITUDE=`GetConfig "LAT" "/etc/default/dump1090-mutability"`
    RECEIVER_LATITUDE=$(whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "$RECEIVER_LATITUDE_TITLE" --nocancel --inputbox "\nEnter your receiver's latitude.\n(Example: XX.XXXXXXX)" 9 78 " $RECEIVER_LATITUDE" 3>&1 1>&2 2>&3)
    RECEIVER_LATITUDE_TITLE="Receiver Latitude (REQUIRED)"
done
RECEIVER_LONGITUDE_TITLE="Receiver Longitude"
while [[ -z $RECEIVER_LONGITUDE ]] ; do
    RECEIVER_LONGITUDE=`GetConfig "LON" "/etc/default/dump1090-mutability"`
    RECEIVER_LONGITUDE=$(whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "$RECEIVER_LONGITUDE_TITLE" --nocancel --inputbox "\nEnter your receeiver's longitude.\n(Example: XX.XXXXXXX)" 9 78 " $RECEIVER_LONGITUDE" 3>&1 1>&2 2>&3)
    RECEIVER_LONGITUDE_TITLE="Receiver Longitude (REQUIRED)"
done

echo -e "\e[94m  Setting the receiver's latitude to $RECEIVER_LATITUDE...\e[97m"

ChangeConfig "LAT" "$(sed -e 's/[[:space:]]*$//' <<<${RECEIVER_LATITUDE})" "/etc/default/dump1090-mutability"
echo -e "\e[94m  Setting the receiver's longitude to $RECEIVER_LONGITUDE...\e[97m"
ChangeConfig "LON" "$(sed -e 's/[[:space:]]*$//' <<<${RECEIVER_LONGITUDE})" "/etc/default/dump1090-mutability"

# Ask for a Bing Maps API key.
BINGMAPSKEY=$(whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "Bing Maps API Key" --nocancel --inputbox "\nProvide a Bing Maps API key here to enable the Bing imagery layer.\nYou can obtain a free key at https://www.bingmapsportal.com/\n\nProviding a Bing Maps API key is not required to continue." 12 78 `GetConfig "BingMapsAPIKey" "/usr/share/dump1090-mutability/html/config.js"` 3>&1 1>&2 2>&3)
if [[ ! -z $BINGMAPSKEY ]] ; then
    echo -e "\e[94m  Setting the Bing Maps API Key to $BINGMAPSKEY...\e[97m"
    ChangeConfig "BingMapsAPIKey" "$BINGMAPSKEY" "/usr/share/dump1090-mutability/html/config.js"
fi

# Ask for a Mapzen API key.
MAPZENKEY=$(whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "Mapzen API Key" --nocancel --inputbox "\nProvide a Mapzen API key here to enable the Mapzen vector tile layer within the ${DECODER_NAME} map. You can obtain a free key at https://mapzen.com/developers/\n\nProviding a Mapzen API key is not required to continue." 13 78 `GetConfig "MapzenAPIKey" "/usr/share/dump1090-mutability/html/config.js"` 3>&1 1>&2 2>&3)
if [[ ! -z $MAPZENKEY ]] ; then
    echo -e "\e[94m  Setting the Mapzen API Key to $MAPZENKEY...\e[97m"
    ChangeConfig "MapzenAPIKey" "$MAPZENKEY" "/usr/share/dump1090-mutability/html/config.js"
fi

# Ask if dump1090-mutability should bind on all IP addresses.
if (whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "Bind ${DECODER_NAME} To All IP Addresses" --yesno "By default ${DECODER_NAME} is bound only to the local loopback IP address(s) for security reasons. However some people wish to make ${DECODER_NAME}'s data accessable externally by other devices. To allow this ${DECODER_NAME} can be configured to listen on all IP addresses bound to this device. It is recommended that unless you plan to access this device from an external source that ${DECODER_NAME} remain bound only to the local loopback IP address(s).\n\nWould you like ${DECODER_NAME} to listen on all IP addesses?" 15 78) then
    echo -e "\e[94m  Binding ${DECODER_NAME} to all available IP addresses...\e[97m"
    CommentConfig "NET_BIND_ADDRESS" "/etc/default/dump1090-mutability"
else
    echo -e "\e[94m  Binding ${DECODER_NAME} to the localhost IP addresses...\e[97m"
    UncommentConfig "NET_BIND_ADDRESS" "/etc/default/dump1090-mutability"
    ChangeConfig "NET_BIND_ADDRESS" "127.0.0.1" "/etc/default/dump1090-mutability"
fi

# In future ask the user if they would like to specify the dump1090 range manually, if not set to 360 nmi / ~667 km to match dump1090-fa.
if [[ `grep "MAX_RANGE" ${DUMP1090_CONFIGURATION_FILE} | awk -F \" '{print $2}' | grep -c "360"` -eq 0 ]] ; then
    ChangeConfig "MAX_RANGE" "360" "${DUMP1090_CONFIGURATION_FILE}"
fi

# Ask if measurments should be displayed using imperial or metric.
UNITOFMEASUREMENT=$(whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "Unit of Measurement" --nocancel --menu "\nChoose unit of measurement to be used by ${DECODER_NAME}." 11 78 2 "Imperial" "" "Metric" "" 3>&1 1>&2 2>&3)
if [[ $UNITOFMEASUREMENT = "Metric" ]] ; then
    echo -e "\e[94m  Setting ${DECODER_NAME} unit of measurement to Metric...\e[97m"
    ChangeConfig "Metric" "false" "/usr/share/dump1090-mutability/html/config.js"
else
    echo -e "\e[94m  Setting ${DECODER_NAME} unit of measurement to Imperial...\e[97m"
    ChangeConfig "Metric" "true" "/usr/share/dump1090-mutability/html/config.js"
fi

# Download Heywhatsthat.com maximum range rings.
if [[ ! -f /usr/share/dump1090-mutability/html/upintheair.json ]] && (whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "Heywhaststhat.com Maimum Range Rings" --yesno "Maximum range rings can be added to ${DECODER_NAME} usings data obtained from Heywhatsthat.com. In order to add these rings to your ${DECODER_NAME} map you will first need to visit http://www.heywhatsthat.com and generate a new panarama centered on the location of your receiver. Once your panarama has been generated a link to the panarama will be displayed in the up left hand portion of the page. You will need the view id which is the series of letters and/or numbers after \"?view=\" in this URL.\n\nWould you like to add heywatsthat.com maximum range rings to your map?" 16 78); then
    HEYWHATSTHATID_TITLE="Heywhatsthat.com Panarama ID"
    while [[ -z $HEYWHATSTHATID ]] ; do
        HEYWHATSTHATID=$(whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "$HEYWHATSTHATID_TITLE" --nocancel --inputbox "\nEnter your Heywhatsthat.com panarama ID." 8 78 3>&1 1>&2 2>&3)
        HEYWHATSTHATID_TITLE="Heywhatsthat.com Panarama ID (REQUIRED)"
    done
    HEYWHATSTHATRINGONE_TITLE="Heywhatsthat.com First Ring Altitude"
    while [[ -z $HEYWHATSTHATRINGONE ]] ; do
        HEYWHATSTHATRINGONE=$(whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "$HEYWHATSTHATRINGONE_TITLE" --nocancel --inputbox "\nEnter the first ring's altitude in meters.\n(default 3048 meters or 10000 feet)" 8 78 "3048" 3>&1 1>&2 2>&3)
        HEYWHATSTHATRINGONE_TITLE="Heywhatsthat.com First Ring Altitude (REQUIRED)"
    done
    HEYWHATSTHATRINGTWO_TITLE="Heywhatsthat.com Second Ring Altitude"
    while [[ -z $HEYWHATSTHATRINGTWO ]] ; do
        HEYWHATSTHATRINGTWO=$(whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "$HEYWHATSTHATRINGTWO_TITLE" --nocancel --inputbox "\nEnter the second ring's altitude in meters.\n(default 12192 meters or 40000 feet)" 8 78 "12192" 3>&1 1>&2 2>&3)
        HEYWHATSTHATRINGTWO_TITLE="Heywhatsthat.com Second Ring Altitude (REQUIRED)"
    done
    echo -e "\e[94m  Downloading JSON data pertaining to the supplied panorama ID...\e[97m"
    echo -e ""
    sudo wget -O /usr/share/dump1090-mutability/html/upintheair.json "http://www.heywhatsthat.com/api/upintheair.json?id=${HEYWHATSTHATID}&refraction=0.25&alts=$HEYWHATSTHATRINGONE,$HEYWHATSTHATRINGTWO"
fi

# Reload ${DECODER_NAME} to ensure all changes take effect.
echo -e "\e[94m  Reloading ${DECODER_NAME} ...\e[97m"
echo -e ""
sudo /etc/init.d/dump1090-mutability force-reload

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

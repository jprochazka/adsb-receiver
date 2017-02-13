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
# Copyright (c) 2016-2017, Joseph A. Prochazka & Romeo Golf                         #
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

# Component specific variables.

# Component service script variables.

### INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

# To be moved to functions.sh...

#################################################################################
# Blacklist DVB-T drivers for RTL-SDR devices.

function BlacklistModules () {
    RECEIVER_KERNEL_MODULE_BLACKLIST="/etc/modprobe.d/rtlsdr-blacklist.conf"
    if [[ ! -f "${RECEIVER_KERNEL_MODULE_BLACKLIST}" ]] || [[ `cat ${RECEIVER_KERNEL_MODULE_BLACKLIST} | wc -l` -lt 9 ]] ; then
        echo -en "\e[33m  Installing blacklist to prevent unwanted kernel modules from being loaded...\e[97m"
        sudo tee ${RECEIVER_KERNEL_MODULE_BLACKLIST}  > /dev/null <<EOF
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
    else
        echo -en "\e[33m  Kernel module blacklist already installed...\e[97m"
    fi
}

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
echo -e "\e[92m  Setting up RTL-SDR OGN..."
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "RTL-SDR OGN Setup" --yesno "RTL-SDR OGN is a combined decoder and feeder for the Open Glider Network which focuses on tracking gilders and other GA aircraft equipped with FLARM, FLARM-compatible devices or OGN tracker.\n\nPlease note you will need a dedicated RTL-SDR dongle to use this software.\n\n  http://wiki.glidernet.org\n\nContinue setup by installing RTL-SDR OGN?" 14 78
    if [[ $? -eq 1 ]] ; then
        # Setup has been halted by the user.
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo -e ""
        echo -e "\e[93m  ------------------------------------------------------------------------------"
        echo -e "\e[92m  RTL-SDR OGN setup halted.\e[39m"
        echo -e ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
    fi
fi

### CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to fulfill dependencies for RTL-SDR OGN...\e[97m"
echo -e ""
# Required by install script.
CheckPackage git
CheckPackage python-dev
CheckPackage python3-dev
# Required for USB SDR devices.
CheckPackage librtlsdr-dev
CheckPackage libusb-1.0-0-dev
CheckPackage rtl-sdr
# Required by component.
CheckPackage curl
CheckPackage libconfig9
CheckPackage libconfig-dev
CheckPackage libcurl3
CheckPackage libfftw3-3
CheckPackage libfftw3-dev
CheckPackage libjpeg62-turbo
CheckPackage libjpeg8
CheckPackage libjpeg-dev
CheckPackage lynx
CheckPackage procserv
CheckPackage telnet
CheckPackage wget

echo -e ""
echo -e "\e[95m  Configuring this device to run the RTL-SDR OGN binaries...\e[97m"
echo -e ""

### BLACKLIST TO PREVENT UNWANTED RTL-SDR MODULES FROM BEING LOADED

# Create an RTL-SDR blacklist file so the device does not claim SDR's for other purposes.
BlacklistModules
CheckReturnCode

### CHECK FOR EXISTING INSTALL AND IF SO STOP IT

# Attempt to stop using systemd.

# And the init script.
if [[ -f "/etc/init.d/rtlsdr-ogn" ]] ; then
    echo -e "\e[94m  Stopping the RTL-SDR OGN service...\e[97m"
    sudo service rtlsdr-ogn stop
fi

# Finally a failsafe process kill.

### ASSIGN RTL-SDR DONGLES

# Check which components are installed.
echo -e "\e[95m  Checking for existing decoders...\e[97m"
echo -e ""

# Check if any of the dump1090 forks are installed.
echo -e "\e[94m  Checking if any of the dump1090 packages are installed...\e[97m"
# Check if the dump1090-mutability package is installed.
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
    DUMP1090_IS_INSTALLED="true"
# Check if the dump1090-fa package is installed.
elif [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
    DUMP1090_IS_INSTALLED="true"
else
    DUMP1090_IS_INSTALLED="false"
fi

# Check if the dump978 binaries exist.
echo -e "\e[94m  Checking if the dump978 binaries exist on this device...\e[97m"
if [[ -f "${RECEIVER_BUILD_DIRECTORY}/dump978/dump978" ]] && [[ -f "${RECEIVER_BUILD_DIRECTORY}/dump978/uat2text" ]] && [[ -f "${RECEIVER_BUILD_DIRECTORY}/dump978/uat2esnt" ]] && [[ -f "${RECEIVER_BUILD_DIRECTORY}/dump978/uat2json" ]] ; then
    DUMP978_IS_INSTALLED="true"
else
    DUMP978_IS_INSTALLED="false"
fi

# If either dump1090 or dump978 is installed we must assign RTL-SDR dongles for each of these decoders.
if [[ "${DUMP1090_IS_INSTALLED}" = "true" ]] || [[ "${DUMP978_IS_INSTALLED}" = "true" ]] ; then
    # Check if Dump1090 is installed.
    if [[ "${DUMP1090_IS_INSTALLED}" = "true" ]] ; then
        # The dump1090-mutability package appear to be installed.
        if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
            # Ask the user which USB device is to be used for dump1090.
            DUMP1090_DEVICE_ID=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump1090 RTL-SDR Dongle" --nocancel --inputbox "\nEnter the ID for your dump1090 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
            while [[ -z "${DUMP1090_DEVICE_ID}" ]] ; do
                DUMP1090_DEVICE_ID=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump1090 RTL-SDR Dongle (REQUIRED)" --nocancel --inputbox "\nEnter the ID for your dump1090 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
            done
        else
            ### GET DONGLE ID FROM THE INSTALLATION CONFIGURATION FILE...
            true
        fi
    fi
    # Check if Dump978 is installed.
    if [[ "${DUMP978_IS_INSTALLED}" = "true" ]] ; then
        # The dump978 binaries appear to exist on this device.
        if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
            # Ask the user which USB device is to be use for dump978.
            DUMP978_DEVICE_ID=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump978 RTL-SDR Dongle" --nocancel --inputbox "\nEnter the ID for your dump978 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
            while [[ -z "${DUMP978_DEVICE_ID}" ]] ; do
                DUMP978_DEVICE_ID=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump978 RTL-SDR Dongle (REQUIRED)" --nocancel --inputbox "\nEnter the ID for your dump978 RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
            done
        else
            ### GET DONGLE ID FROM THE INSTALLATION CONFIGURATION FILE...
            true
        fi
    fi
    #
    if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
        # Ask the user which USB device is to be use for RTL-SDR OGN.
        RTLSDROGN_DEVICE_ID=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "RTL-SDR OGN RTL-SDR Dongle" --nocancel --inputbox "\nEnter the ID for your RTL-SDR OGN RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
        while [[ -z "${DUMP978_DEVICE_ID}" ]] ; do
            RTLSDROGN_DEVICE_ID=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "RTL-SDR OGN RTL-SDR Dongle (REQUIRED)" --nocancel --inputbox "\nEnter the ID for your RTL-SDR OGN RTL-SDR dongle." 8 78 3>&1 1>&2 2>&3)
        done
    else
        ### GET DONGLE ID FROM THE INSTALLATION CONFIGURATION FILE...
        true
    fi
    # Assign the specified RTL-SDR dongle to dump1090.
    if [[ "${DUMP1090_IS_INSTALLED}" = "true" ]] && [[ -n "${DUMP1090_DEVICE_ID}" ]] ; then
        echo -e "\e[94m  Assigning RTL-SDR dongle \"${DUMP1090_DEVICE_ID}\" to dump1090-mutability...\e[97m"
        ChangeConfig "DEVICE" ${DUMP1090_DEVICE_ID} "/etc/default/dump1090-mutability"
        echo -e "\e[94m  Reloading dump1090-mutability...\e[97m"
        echo -e ""
        sudo /etc/init.d/dump1090-mutability force-reload
        echo -e ""
    fi
    # Assign the specified RTL-SDR dongle to dump978
    if [[ "${DUMP978_IS_INSTALLED}" = "true" ]] && [[ -n "${DUMP978_DEVICE_ID}" ]] ; then
        echo -e "\e[94m  Assigning RTL-SDR dongle \"${DUMP978_DEVICE_ID}\" to dump978...\e[97m"
        ### ADD DEVICE TO MAINTENANCE SCRIPT...
        echo -e "\e[94m  Reloading dump978...\e[97m"
        ### KILL EXISTING DUMP978 PROCESSES...
        echo -e ""
        ### RESTART DUMP978...
        echo -e ""
    fi
fi

### ASSIGN RTL-SDR DONGLE FOR RTL-SDR OGN...

### DOWNLOAD AND SET UP THE BINARIES

# Create build directory if not already present.
if [[ ! -d "${RECEIVER_BUILD_DIRECTORY}/rtlsdr-ogn" ]] ; then
    echo -e "\e[94m  Creating the directory (${RECEIVER_BUILD_DIRECTORY}/rtlsdr-ogn)...\e[97m"
    mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/rtlsdr-ogn
fi

# Enter the build directory.
if [[ ! "${PWD}" = "${RECEIVER_BUILD_DIRECTORY}/rtlsdr-ogn" ]] ; then
    echo -e "\e[94m  Entering the directory (${RECEIVER_BUILD_DIRECTORY}/rtlsdr-ogn)...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/rtlsdr-ogn 2>&1
fi

# Use function to detect cpu architecture.
if [[ -z "${CPU_ARCHITECTURE}" ]] ; then
    Check_CPU
    echo -e ""
fi

# Identify the correct binaries to download.
case ${CPU_ARCHITECTURE} in
    "armv6l")
        # Raspberry Pi 1.
        COMPONENT_BINARY_URL="http://download.glidernet.org/rpi-gpu/rtlsdr-ogn-bin-RPI-GPU-latest.tgz"
        echo -e "\e[94m  Downloading the latest RTL-SDR OGN RPI-GPU binaries...\e[97m"
        echo -e ""
        wget "${COMPONENT_BINARY_URL}" -O "${RECEIVER_BUILD_DIRECTORY}/rtlsdr-ogn/rtlsdr-ogn-bin-RPI-GPU-latest.tgz"
        echo -e ""
        echo -e "\e[94m  Extracting the latest RTL-SDR OGN RPI-GPU binaries from the archive...\e[97m"
        echo -e ""
        tar xvzf rtlsdr-ogn-bin-RPI-GPU-latest.tgz -C ${RECEIVER_BUILD_DIRECTORY}/rtlsdr-ogn
        ;;
    "armv7l")
        # Raspberry Pi 2 onwards.
        COMPONENT_BINARY_URL="http://download.glidernet.org/arm/rtlsdr-ogn-bin-ARM-latest.tgz"
        echo -e "\e[94m  Downloading the latest RTL-SDR OGN ARM binaries...\e[97m"
        echo -e ""
        wget "${COMPONENT_BINARY_URL}" -O "${RECEIVER_BUILD_DIRECTORY}/rtlsdr-ogn/rtlsdr-ogn-bin-ARM-latest.tgz"
        echo -e ""
        echo -e "\e[94m  Extracting the latest RTL-SDR OGN ARM binaries from the archive...\e[97m"
        echo -e ""
        tar xvzf rtlsdr-ogn-bin-ARM-latest.tgz -C ${RECEIVER_BUILD_DIRECTORY}/rtlsdr-ogn
        ;;
    "x86_64")
        # 64 Bit.
        COMPONENT_BINARY_URL="http://download.glidernet.org/x64/rtlsdr-ogn-bin-x64-latest.tgz"
        echo -e "\e[94m  Downloading the latest RTL-SDR OGN x64 binaries...\e[97m"
        echo -e ""
        wget "${COMPONENT_BINARY_URL}" -O "${RECEIVER_BUILD_DIRECTORY}/rtlsdr-ogn/rtlsdr-ogn-bin-x64-latest.tgz"
        echo -e ""
        echo -e "\e[94m  Extracting the latest RTL-SDR OGN x64 binaries from the archive...\e[97m"
        echo -e ""
        tar xvzf rtlsdr-ogn-bin-x64-latest.tgz -C ${RECEIVER_BUILD_DIRECTORY}/rtlsdr-ogn
        ;;
    *)
        # 32 Bit (default install if no others matched).
        COMPONENT_BINARY_URL="http://download.glidernet.org/x86/rtlsdr-ogn-bin-x86-latest.tgz"
        echo -e "\e[94m  Downloading the latest RTL-SDR OGN x86 binaries...\e[97m"
        echo -e ""
        wget "${COMPONENT_BINARY_URL}" -O "${RECEIVER_BUILD_DIRECTORY}/rtlsdr-ogn/rtlsdr-ogn-bin-x86-latest.tgz"
        echo -e ""
        echo -e "\e[94m  Extracting the latest RTL-SDR OGN x86 binaries from the archive...\e[97m"
        echo -e ""
        tar xvzf rtlsdr-ogn-bin-x86-latest.tgz -C ${RECEIVER_BUILD_DIRECTORY}/rtlsdr-ogn
        ;;
esac

# Change to component work directory for post-build actions.
echo -e ""
echo -e "\e[94m  Entering the directory containing the RTL-SDR binaries...\e[97m"
cd ${RECEIVER_BUILD_DIRECTORY}/rtlsdr-ogn/rtlsdr-ogn 2>&1

# Create named pipe if required.
if [[ ! -p "ogn-rf.fifo" ]] ; then
    echo -e "\e[94m  Creating named pipe...\e[97m"
    sudo mkfifo ogn-rf.fifo
fi

# Set file permissions.
echo -e "\e[94m  Setting proper file permissions...\e[97m"
sudo chown root gsm_scan
sudo chmod a+s  gsm_scan
sudo chown root ogn-rf
sudo chmod a+s  ogn-rf
sudo chown root rtlsdr-ogn
sudo chmod a+s  rtlsdr-ogn
# And check that the file permissions have been applied.

# Creat GPU device if required.
if [[ ! -c "gpu_dev" ]] ; then
    # The mknod major_version number varies with kernel version.
    echo -e "\e[94m  Getting the version of the kernel currently running...\e[97m"
    KERNEL=`uname -r`
    KERNEL_VERSION=`echo ${KERNEL} | cut -d \. -f 1`.`echo ${KERNEL} | cut -d \. -f 2`
    # Check if the currently running kernel is version 4.1 or higher.
    if [[ "${KERNEL_VERSION}" < 4.1 ]] ; then
        # Kernel is older than version 4.1.
        echo -e "\e[94m  Executing mknod for older kernels...\e[97m"
        sudo mknod gpu_dev c 100 0
    else
        # Kernel is version 4.1 or newer.
        echo -e "\e[94m  Executing mknod for newer kernels...\e[97m"
        sudo mknod gpu_dev c 249 0
    fi
fi

## GATHER INFORMATION FROM USER


# Latitude.

# Longitude.

# Altitude.

# Check for component specific variables, otherwise populate with dummy values to ensure valid config generation.

# Ask if user would like to calibrate the tuner.

### CREATE THE CONFIGURATION FILE

# Update existing or create new config file.
#########################################################
#                                                       #
#             CREATE THE CONFIGURATION FILE             #
#                                                       #
#  http://wiki.glidernet.org/wiki:receiver-config-file  #
#                                                       #
#########################################################

# Update ownership of new config file.

### INSTALL AS A SERVICE

# Install service script.
echo -e "\e[94m  Downloading and setting permissions on the init script...\e[97m"
echo -e ""
sudo wget http://download.glidernet.org/common/service/rtlsdr-ogn -O /etc/init.d/rtlsdr-ogn
sudo chmod +x /etc/init.d/rtlsdr-ogn

# Generate and install service script configuration file.
echo -e "\e[94m  Creating the file /etc/rtlsdr-ogn.conf...\e[97m"
echo -e ""
sudo tee /etc/rtlsdr-ogn.conf > /dev/null <<EOF
#shellbox configuration file
#Starts commands inside a "box" with a telnet-like server.
#Contact the shell with: telnet <hostname> <port>
#Syntax:
#port  user     directory                 command       args
50000  pi ${RECEIVER_BUILD_DIRECTORY}/rtlsdr-ogn/rtlsdr-ogn    ./ogn-rf     rtlsdr-ogn.conf
50001  pi ${RECEIVER_BUILD_DIRECTORY}/rtlsdr-ogn/rtlsdr-ogn    ./ogn-decode rtlsdr-ogn.conf
EOF

# Configure component as a service.
echo -e "\e[94m  Setting up rtlsdr-ogn as a service...\e[97m"
echo -e ""
sudo update-rc.d rtlsdr-ogn defaults

# (re)start the component service.
echo -e "\e[94m  Starting the rtlsdr-ogn service...\e[97m"
echo -e ""
sudo service rtlsdr-ogn start

### SETUP COMPLETE

# Return to the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo -e "\e[93m  ------------------------------------------------------------------------------\n"
echo -e "\e[92m  RTL-SDR OGN setup is complete.\e[39m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

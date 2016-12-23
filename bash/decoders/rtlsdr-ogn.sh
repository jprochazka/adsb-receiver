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
BUILDDIRECTORY_RTLSDROGN="$BUILDDIRECTORY/rtlsdr-ogn"

DECODER_NAME="RTLSDR-OGN"
DECODER_WEBSITE="http://wiki.glidernet.org"

### INCLUDE EXTERNAL SCRIPTS

source $BASHDIRECTORY/variables.sh
source $BASHDIRECTORY/functions.sh

### BEGIN SETUP

clear

echo "http://wiki.glidernet.org"
echo ""
echo -e "\033[31mBEFORE CONTINUING:\033[33m"
echo "RTLSDR-OGN requires it's own dedicated dongle."
echo ""
echo -e "\033[37m"
if [[ ! -z ${VERBOSE} ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

### CHECK FOR PREREQUISITE PACKAGES

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

echo -e "\033[33mStopping unwanted kernel modules from being loaded..."
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

### CREATE THE CONFIGURATION FILE


#######################################################
# CREATE THE CONFIGURATION FILE                       #
# http://wiki.glidernet.org/wiki:receiver-config-file #
#######################################################


### INSTALL AS A SERVICE

echo -e "\033[33mDownloading and setting permissions on the init script..."
echo -e "\033[37m"
sudo wget http://download.glidernet.org/common/service/rtlsdr-ogn -O /etc/init.d/rtlsdr-ogn
sudo chmod +x /etc/init.d/rtlsdr-ogn

echo -e "\033[33mCreating file /etc/rtlsdr-ogn.conf..."
echo -e "\033[37m"
sudo tee /etc/rtlsdr-ogn.conf > /dev/null <<EOF
#shellbox configuration file
#Starts commands inside a "box" with a telnet-like server.
#Contact the shell with: telnet <hostname> <port>
#Syntax:
#port  user     directory                 command       args
50000  pi ${BUILDDIRECTORY_RTLSDROGN}/rtlsdr-ogn    ./ogn-rf     rtlsdr-ogn.conf
50001  pi ${BUILDDIRECTORY_RTLSDROGN}/rtlsdr-ogn    ./ogn-decode rtlsdr-ogn.conf
EOF

echo -e "\033[33mSetting up rtlsdr-ogn as a service..."
echo -e "\033[37m"
sudo update-rc.d rtlsdr-ogn defaults

echo -e "\033[33mStarting the rtlsdr-ogn service..."
echo -e "\033[37m"
sudo service rtlsdr-ogn start

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

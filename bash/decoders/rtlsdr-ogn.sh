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

BUILDDIR=$PWD

source ../bash/functions.sh

clear

echo "http://wiki.glidernet.org"
echo ""
echo -e "\033[31mBEFORE CONTINUING:\033[33m"
echo "RTLSDR-OGN requires it's own dedicated dongle."
echo ""
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

## CHECK FOR PREREQUISITE PACKAGES

CheckPackage git
CheckPackage wget
CheckPackage rtl-sdr
CheckPackage librtlsdr-dev
CheckPackage libusb-1.0-0-dev
CheckPackage libconfig-dev
CheckPackage fftw3-dev
CheckPackage libjpeg-dev
CheckPackage libconfig9

## BLACKLIST UNWANTED RTL-SDR MODULES FROM BEING LOADED

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

## DOWNLOAD AND SET UP THE BINARIES

# Download and extract the proper binaries.
case `uname -m` in
    "armv6l")
        # Raspberry Pi 1
        wget http://download.glidernet.org/rpi-gpu/rtlsdr-ogn-bin-RPI-GPU-latest.tgz -O $BUILDDIR/rtlsdr-ogn-bin-RPI-GPU-latest.tgz
        tar xvzf rtlsdr-ogn-bin-RPI-GPU-latest.tgz -C $BUILDDIR
        ;;
    "armv7l")
        # Raspberry Pi 2
        wget http://download.glidernet.org/arm/rtlsdr-ogn-bin-ARM-latest.tgz -O $BUILDDIR/rtlsdr-ogn-bin-ARM-latest.tgz
        tar xvzf rtlsdr-ogn-bin-ARM-latest.tgz -C $BUILDDIR
        ;;
    "x86_64")
        # 64 Bit
        wget http://download.glidernet.org/x64/rtlsdr-ogn-bin-x64-latest.tgz -O $BUILDDIR/rtlsdr-ogn-bin-x64-latest.tgz
        tar xvzf rtlsdr-ogn-bin-x64-latest.tgz -C $BUILDDIR
        ;;
    *)
        # 32 Bit (default install if no others matched)
        wget http://download.glidernet.org/x86/rtlsdr-ogn-bin-x86-latest.tgz -O $BUILDDIR/rtlsdr-ogn-bin-x86-latest.tgz
        tar xvzf rtlsdr-ogn-bin-x86-latest.tgz -C $BUILDDIR
        ;;
esac

# Create named pipe
cd $BUILDDIR/rtlsdr-ogn
sudo mkfifo ogn-rf.fifo

# Set file permissions.
sudo chown root gsm_scan
sudo chmod a+s gsm_scan
sudo chown root rtlsdr-ogn
sudo chmod a+s rtlsdr-ogn

# Check if kernel v4.1 or higher is being used.

################################################
# ADD A WAY TO CHECK KERNEL                    #
# THIS WILL NOT WORK AND IS ONLY A PLACEHOLDER #
################################################

if [[ `uname -r` == $SOMETHING ]]; then
    # Kernel is version 4.1 or newer.
    sudo mknod gpu_dev c 249 0
else
    # Kernel is older than version 4.1.
    sudo mknod gpu_dev c 100 0
fi

## CREATE THE CONFIGURATION FILE


#######################################################
# CREATE THE CONFIGURATION FILE                       #
# http://wiki.glidernet.org/wiki:receiver-config-file #
#######################################################


## INSTALL AS A SERVICE

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
50000  pi ${BUILDDIR}/rtlsdr-ogn    ./ogn-rf     rtlsdr-ogn.conf
50001  pi ${BUILDDIR}/rtlsdr-ogn    ./ogn-decode rtlsdr-ogn.conf
EOF

echo -e "\033[33mSetting up rtlsdr-ogn as a service..."
echo -e "\033[37m"
sudo update-rc.d rtlsdr-ogn defaults

echo -e "\033[33mStarting the rtlsdr-ogn service..."
echo -e "\033[37m"
sudo service rtlsdr-ogn start

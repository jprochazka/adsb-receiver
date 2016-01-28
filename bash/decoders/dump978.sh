#!/bin/bash

#####################################################################################
#                                   ADS-B FEEDER                                    #
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
DUMP978DIR="$BUILDDIR/dump978"

source ../bash/functions.sh

clear

echo -e "\033[31m"
echo "-------------------------------------------"
echo " Now ready to install dump978."
echo "-------------------------------------------"
echo -e "\033[33mDump 978 is an experimental demodulator/decoder for 978MHz UAT signals.."
echo ""
echo "https://github.com/mutability/dump978"
echo ""
echo -e "\033[31mBEFORE CONTINUING:\033[33m"
echo "It is recommended before continuing with the dump978 setup you read the wiki page"
echo "related to the installation of dump978. Doing so will help you through configuring"
echo "dump978 properly using this script."
echo ""
echo "https://github.com/jprochazka/adsb-feeder/wiki/dump978"
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

## CHECK FOR PREREQUISITE PACKAGES

CheckPackage git
CheckPackage make
CheckPackage rtl-sdr
CheckPackage librtlsdr-dev
CheckPackage libusb-1.0-0-dev
CheckPackage gcc
CheckPackage netcat

## BLACKLIST UNWANTED RTL-SDR MODULES FROM BEING LOADED

echo -e "\033[33mStopping unwanted kernel modules from being loaded..."
echo -e "\033[37m"
sudo tee /etc/modprobe.d/rtlsdr-blacklist.conf  > /dev/null <<EOF
blacklist dvb_usb_rtl28xxu
blacklist dvb_usb_v2
blacklist rtl_2830
blacklist rtl_2832
blacklist r820t
EOF
sudo rmmod dvb_usb_rtl28xxu

## DOWNLOAD OR UPDATE THE DUMP1090-MUTABILITY SOURCE

# Check if the git repository already exists locally.
if [ -d $DUMP978DIR ] && [ -d $DUMP978DIR/.git ]; then
    # A directory with a git repository containing the source code exists.
    echo -e "\033[33m"
    echo "Updating the local dump978 git repository..."
    echo -e "\033[37m"
    cd $DUMP978DIR
    git pull origin master
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\033[33m"
    echo "Cloning the dump978 git repository locally..."
    echo -e "\033[37m"
    git clone https://github.com/mutability/dump978.git
fi

## BUILD THE DUMP978 BINARIES

cd $DUMP978DIR
make all

## ASSIGN DEVICES TO DUMP1090-MUTABILITY AND DUMP978 IF DUMP1090-MUTABILITY IS INSTALLED

# Check if the dump1090-mutability package is installed.
DUMP978DEVICE=0
if [ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
    # The dump1090-mutability package appear to be installed.
    echo -e "\033[31m"
    echo "ASSIGN RTL-SDR DEVICES TO DECODERS"
    echo -e "\033[33m"
    echo "It appears the dump1090-mutability package is installed on this device."
    echo "In order to run dump978 in tandem with dump1090-mutability you will"
    echo "need to specifiy which device each decoder is to use."
    echo ""
    echo "Keep in mind in order to run both decoders on a single device you will"
    echo "need to have two separate RTL-SDR devices connected to your device."
    echo -e "\033[37m"
    read -p "Dump1090 Device: " DUMP1090DEVICE
    read -p "Dump978 Device: " DUMP978DEVICE

    # Assign the specified device to dump1090-mutability.
    echo -e "\033[33m"
    echo "Configuring dump1090-mutability to use the specified device..."
    ChangeConfig "DEVICE" $DUMP1090DEVICE "/etc/default/dump1090-mutability"
    echo "Restarting dump1090-mutability..."
    echo -e "\033[37m"
    sudo /etc/init.d/dump1090-mutability restart
fi

## CREATE JSON DATA DIRECTORY

echo -e "\033[33mCreating Json data directory..."
echo -e "\033[37m"
sudo mkdir -p /var/www/html/dump978/data
sudo chmod 777 /var/www/html/dump978/data

## ADD SCRIPT AND COMMAND TO EXECUTE MAINTAINANCE SCRIPT USING RC.LOCAL

echo -e "\033[33mCreating the script dump978-maint.sh..."
echo -e "\033[37m"
tee $DUMP978DIR/dump978-maint.sh > /dev/null <<EOF
#! /bin/sh

# Start with logging.
rtl_sdr -d ${DUMP978DEVICE} -f 978000000 -s 2083334 -g 48 - | ${DUMP978DIR}/dump978 > /var/log/dump978.log &
while true; do
    tail -n0 -f /var/log/dump978.log | ${DUMP978DIR}/uat2json /var/www/html/dump978/data | ${DUMP978DIR}/uat2esnt | /bin/nc -q1 127.0.0.1 30001
    sleep 15
done
EOF

echo -e "\033[33mCreating logrotate file..."
echo -e "\033[37m"
tee /etc/logrotate.d/dump978-maint.sh > /dev/null <<EOF
/var/log/dump978.log {
    weekly
    rotate 4
    copytruncate
}
EOF

echo -e "\033[33mSetting permissions on dump978-maint.sh..."
echo -e "\033[37m"
sudo chmod +x $DUMP978DIR/dump978-maint.sh

if ! grep -Fxq "${DUMP978DIR}/dump978-maint.sh &" /etc/rc.local; then
    echo -e "\033[33mAdding startup line to rc.local..."
    echo -e "\033[37m"
    lnum=($(sed -n '/exit 0/=' /etc/rc.local))
    ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i ${DUMP978DIR}/dump978-maint.sh &\n" /etc/rc.local
fi

## EXECUTE THE MAINTAINANCE SCRIPT

echo -e "\033[33m"
echo "Executing the dump978 maintainance script..."
echo -e "\033[37m"
sudo $DUMP978DIR/dump978-maint.sh > /dev/null &

## DISPLAY MESSAGE STATING DUMP978 SETUP IS COMPLETE

echo -e "\033[33m"
echo "Installation of dump978 is now complete."
echo "Please look over the output generated to be sure no errors were encountered."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

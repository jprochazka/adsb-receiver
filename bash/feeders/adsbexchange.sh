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

## VARIABLES

BUILDDIR=$PWD
MLATCLIENTDIR="$BUILDDIR/mlat-client"
ADSBEXCHANGEDIR="$BUILDDIR/adsbexchange"

source ../bash/variables.sh
source ../bash/functions.sh

## INFORMATIVE MESSAAGE ABOUT THIS SOFTWARE

clear

echo -e "\033[31m"
echo "-----------------------------------------------------"
echo " Now ready to set up a feed to ADS-B Exchange."
echo "-----------------------------------------------------"
echo -e "\033[33mADSBexchange.com is a co-op of ADS-B/Mode S/MLAT feeders from around the world."
echo ""
echo "http://www.adsbexchange.com/how-to-feed/"
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\033[33m"
echo "Installing packages needed to fulfill dependencies..."
echo -e "\033[37m"
CheckPackage curl
CheckPackage build-essential
CheckPackage debhelper
CheckPackage python3-dev
CheckPackage netcat

## DOWNLOAD OR UPDATE THE MLAT-CLIENT SOURCE

# Check if the git repository already exists locally.
if [ -d $MLATCLIENTDIR ] && [ -d $MLATCLIENTDIR/.git ]; then
    # A directory with a git repository containing the source code exists.
    echo -e "\033[33m"
    echo "Updating the local mlat-client git repository..."
    echo -e "\033[37m"
    cd $MLATCLIENTDIR
    git pull
    git checkout tags/${MLATCLIENTTAG}
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\033[33m"
    echo "Cloning the mlat-client git repository locally..."
    echo -e "\033[37m"
    git clone https://github.com/mutability/mlat-client.git
    cd $MLATCLIENTDIR
    git checkout tags/${MLATCLIENTTAG}
fi

## BUILD AND INSTALL THE MLAT-CLIENT PACKAGE

echo -e "\033[33m"
echo "Building the mlat-client package..."
echo -e "\033[37m"
dpkg-buildpackage -b -uc

echo -e "\033[33m"
echo "Installing the mlat-client package..."
echo -e "\033[37m"
sudo dpkg -i ${BUILDDIR}/mlat-client_${MLATCLIENTVERSION}*.deb

## REMOVE THE OLD ADB-B EXCHANGE STARTUP LINE FROM /ETC/RC.LOCAL IF IT EXISTS

# Check if the old adsbexchange-maint.sh line exists in /etc/rc.local.
if grep -Fxq "${ADSBEXCHANGEDIR}/adsbexchange-maint.sh &" /etc/rc.local; then
    # Kill any currently running instances of the adsbexchange_maint.sh script.
    PIDS=`ps -efww | grep -w "${ADSBEXCHANGEDIR}/adsbexchange-maint.sh &" | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [ ! -z "$PIDS" ]; then
        sudo kill $PIDS >> $LOGFILE
        sudo kill -9 $PIDS >> $LOGFILE
    fi
    # Remove the old line from /etc/rc.local.
    sudo sed -i /$$ADSBEXCHANGEDIR\/adsbexchange-maint.sh &/d /etc/rc.local
fi

## CONFIGURE SCRIPT TO EXECUTE AND MAINTAIN MLAT-CLIENT AND NETCAT TO FEED ADS-B EXCHANGE

# Ask the user for the user name for this receiver.
ADSBEXCHANGEUSER=$(whiptail --backtitle "$BACKTITLETEXT" --title "ADS-B Exchange User Name" --nocancel --inputbox "\nPlease enter your ADS-B Exchange user name. (NOT REQUIRED)\n\nIf you have more than one receiver, this username should be unique.\nExample: \"username-01\", \"username-02\", etc." 12 78 3>&1 1>&2 2>&3)

# Get the altitude of the receiver from the Google Maps API using the latitude and longitude assigned dump1090-mutability.
RECEIVERLAT=`GetConfig "LAT" "/etc/default/dump1090-mutability"`
RECEIVERLON=`GetConfig "LON" "/etc/default/dump1090-mutability"`

# Ask the user for the receivers altitude. (This will be prepopulated by the altitude returned from the Google Maps API.
RECEIVERALT=$(whiptail --backtitle "$BACKTITLETEXT" --title "Receiver Altitude" --nocancel --inputbox "\nEnter your receiver's altitude." 9 78 "`curl -s https://maps.googleapis.com/maps/api/elevation/json?locations=$RECEIVERLAT,$RECEIVERLON | python -c "import json,sys;obj=json.load(sys.stdin);print obj['results'][0]['elevation'];"`" 3>&1 1>&2 2>&3)

# Create the adsbexchange directory in the build directory if it does not exist.
if [ ! -d "$ADSBEXCHANGEDIR" ]; then
    mkdir $ADSBEXCHANGEDIR
fi

echo -e "\033[33mCreating the file adsbexchange-netcat_maint.sh..."
echo -e "\033[37m"
tee $ADSBEXCHANGEDIR/adsbexchange-netcat_maint.sh > /dev/null <<EOF
#! /bin/sh
while true
  do
    sleep 30
    /bin/nc 127.0.0.1 30005 | /bin/nc feed.adsbexchange.com 30005
  done
EOF

echo -e "\033[33mCreating the file adsbexchange-mlat_maint.sh..."
echo -e "\033[37m"
tee $ADSBEXCHANGEDIR/adsbexchange-mlat_maint.sh > /dev/null <<EOF
#! /bin/sh
while true
  do
    sleep 30
    /usr/bin/mlat-client --input-type dump1090 --input-connect 127.0.0.1:30005 --lat $RECEIVERLAT --lon $RECEIVERLON --alt $RECEIVERALT --user $ADSBEXCHANGEUSER --server feed.adsbexchange.com:31090 --no-udp --results beast,connect,127.0.0.1:30104
  done
EOF

echo -e "\033[33mSetting permissions on adsbexchange-netcat_maint.sh..."
echo -e "\033[37m"
sudo chmod +x $ADSBEXCHANGEDIR/adsbexchange-netcat_maint.sh

echo -e "\033[33mSetting permissions on adsbexchange-mlat_maint.sh..."
echo -e "\033[37m"
sudo chmod +x $ADSBEXCHANGEDIR/adsbexchange-mlat_maint.sh

echo -e "\033[33mAdding netcat startup line to rc.local..."
echo -e "\033[37m"
if ! grep -Fxq "$ADSBEXCHANGEDIR/adsbexchange-netcat_maint.sh &" /etc/rc.local; then
    lnum=($(sed -n '/exit 0/=' /etc/rc.local))
    ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i ${ADSBEXCHANGEDIR}/adsbexchange-netcat_maint.sh &\n" /etc/rc.local
fi
echo -e "\033[33mAdding mlat-client startup line to rc.local..."
echo -e "\033[37m"
if ! grep -Fxq "$ADSBEXCHANGEDIR/adsbexchange-mlat_maint.sh &" /etc/rc.local; then
    lnum=($(sed -n '/exit 0/=' /etc/rc.local))
    ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i ${ADSBEXCHANGEDIR}/adsbexchange-mlat_maint.sh &\n" /etc/rc.local
fi

## START THE MLAT-CLIENT AND NETCAT FEED

# Kill any currently running instances of the adsbexchange-netcat_maint.sh script.
PIDS=`ps -efww | grep -w "adsbexchange-netcat_maint.sh" | awk -vpid=$$ '$2 != pid { print $2 }'`
if [ ! -z "$PIDS" ]; then
    sudo kill $PIDS
    sudo kill -9 $PIDS
fi

# Kill any currently running instances of the adsbexchange-mlat_maint.sh script.
PIDS=`ps -efww | grep -w "adsbexchange-mlat_maint.sh" | awk -vpid=$$ '$2 != pid { print $2 }'`
if [ ! -z "$PIDS" ]; then
    sudo kill $PIDS
    sudo kill -9 $PIDS
fi

echo -e "\033[33mExecuting adsbexchange-netcat_maint.sh..."
echo -e "\033[37m"
sudo nohup $ADSBEXCHANGEDIR/adsbexchange-netcat_maint.sh > /dev/null &

echo -e "\033[33mExecuting adsbexchange-mlat_maint.sh..."
echo -e "\033[37m"
sudo nohup $ADSBEXCHANGEDIR/adsbexchange-mlat_maint.sh > /dev/null &

echo -e "\033[33mConfiguration of the ADS-B Exchange feed is now complete."
echo "Please look over the output generated to be sure no errors were encountered."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

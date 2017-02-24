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

## VARIABLES

PROJECTROOTDIRECTORY="$PWD"
BASHDIRECTORY="$PROJECTROOTDIRECTORY/bash"
BUILDDIRECTORY="$PROJECTROOTDIRECTORY/build"
MLATCLIENTBUILDDIRECTORY="$PROJECTROOTDIRECTORY/build/mlat-client"
ADSBEXCHANGEBUILDDIRECTORY="$PROJECTROOTDIRECTORY/build/adsbexchange"

## INCLUDE EXTERNAL SCRIPTS

source $BASHDIRECTORY/variables.sh
source $BASHDIRECTORY/functions.sh

## BEGIN SETUP

clear
echo -e "\n\e[91m  $ADSB_PROJECTTITLE"
echo ""
echo -e "\e[92m  Setting up the ADS-B Exchange feed..."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo ""
whiptail --backtitle "$ADSB_PROJECTTITLE" --title "ADS-B Exchange Feed Setup" --yesno "ADS-B Exchange is a co-op of ADS-B/Mode S/MLAT feeders from around the world, and the world’s largest source of unfiltered flight data.\n\n  http://www.adsbexchange.com/how-to-feed/\n\nContinue setting up the ADS-B Exchange feed?" 12 78
CONTINUESETUP=$?
if [ $CONTINUESETUP = 1 ]; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  ADS-B Exchange feed setup halted.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

## CHECK FOR AND REMOVE  ANY OLD STYLE ADB-B EXCHANGE SETUPS IF ANY EXIST

echo -e "\e[95m  Checking for and removing any old style ADS-B Exchange setups if any exist...\e[97m"
echo ""
# Check if the old adsbexchange-maint.sh line exists in /etc/rc.local.
echo -e "\e[94m  Checking for any preexisting older style setups...\e[97m"
if grep -Fxq "$ADSBEXCHANGEBUILDDIRECTORY/adsbexchange-maint.sh &" /etc/rc.local; then
    # Kill any currently running instances of the adsbexchange_maint.sh script.
    echo -e "\e[94m  Checking for any running adsbexchange-maint.sh processes...\e[97m"
    PIDS=`ps -efww | grep -w "$ADSBEXCHANGEBUILDDIRECTORY/adsbexchange-maint.sh &" | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [ ! -z "$PIDS" ]; then
        echo -e "\e[94m  Killing any running adsbexchange-maint.sh processes...\e[97m"
        echo ""
        sudo kill $PIDS
        sudo kill -9 $PIDS
        echo ""
    fi
    # Remove the old line from /etc/rc.local.
    echo -e "\e[94m  Removing the old adsbexchange-maint.sh startup line from /etc/rc.local...\e[97m"
    sudo sed -i /$$ADSBEXCHANGEDIR\/adsbexchange-maint.sh &/d /etc/rc.local
fi
echo ""

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo ""
CheckPackage curl
CheckPackage build-essential
CheckPackage debhelper
CheckPackage python-dev
CheckPackage python3-dev
CheckPackage netcat

## DOWNLOAD OR UPDATE THE MLAT-CLIENT SOURCE

echo ""
echo -e "\e[95m  Preparing the mlat-client Git repository...\e[97m"
echo ""
if [ -d $MLATCLIENTBUILDDIRECTORY ] && [ -d $MLATCLIENTBUILDDIRECTORY/.git ]; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the mlat-client git repository directory...\e[97m"
    cd $MLATCLIENTBUILDDIRECTORY
    echo -e "\e[94m  Fetching changes from the remote mlat-client git repository...\e[97m"
    echo ""
    git fetch --tags origin 2>&1
    echo -e "\e[94m  Updating the local mlat-client git repository...\e[97m"
    echo ""
    git reset --hard origin/master 2>&1
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
    cd $BUILDDIRECTORY
    echo -e "\e[94m  Cloning the mlat-client git repository locally...\e[97m"
    echo ""
    git clone https://github.com/mutability/mlat-client.git
fi

# Enter the git repository directory.
if [[ ! ${PWD} = ${MLATCLIENTBUILDDIRECTORY} ]] ; then
    echo -e "\e[94m  Entering the mlat-client git repository directory...\e[97m"
    cd ${MLATCLIENTBUILDDIRECTORY}
fi

# Attempt to check out the required code version based on the supplied tag.
if [[ -n "${MLATCLIENTTAG}" ]] && [[ `git ls-remote 2>/dev/null| grep -c "refs/tags/${MLATCLIENTTAG}"` -gt 0 ]] ; then
    # If a valid git tag has been specified then check that out.
    echo -e "\e[94m  Checking out mlat-client version \"${MLATCLIENTTAG}\"...\e[97m"
    git checkout tags/${MLATCLIENTTAG} 2>&1
else
    # Otherwise checkout the master branch.
    echo -e "\e[94m  Checking out mlat-client from the master branch...\e[97m"
    git checkout master 2>&1
fi


## BUILD AND INSTALL THE MLAT-CLIENT PACKAGE

echo ""
echo -e "\e[95m  Building and installing the mlat-client package...\e[97m"
echo ""

echo -e "\e[94m  Building the mlat-client package...\e[97m"
echo ""
dpkg-buildpackage -b -uc
echo ""
echo -e "\e[94m  Installing the mlat-client package...\e[97m"
echo ""
sudo dpkg -i $BUILDDIRECTORY/mlat-client_${MLATCLIENTVERSION}*.deb

# Check that the mlat-client package was installed successfully.
echo ""
echo -e "\e[94m  Checking that the mlat-client package was installed properly...\e[97m"
if [ $(dpkg-query -W -f='${STATUS}' mlat-client 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    # If the mlat-client package could not be installed halt setup.
    echo ""
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  UNABLE TO INSTALL A REQUIRED PACKAGE."
    echo -e "  SETUP HAS BEEN TERMINATED!"
    echo ""
    echo -e "\e[93mThe package \"mlat-client\" could not be installed.\e[39m"
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  ADS-B Exchange feed setup halted.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

## CREATE THE SCRIPT TO EXECUTE AND MAINTAIN MLAT-CLIENT AND NETCAT TO FEED ADS-B EXCHANGE

echo ""
echo -e "\e[95m  Creating maintenance for both the mlat-client and netcat feeds...\e[97m"
echo ""

# Ask the user for the user name for this receiver.
RECEIVERNAME_TITLE="Receiver Name"
while [[ -z $RECEIVERNAME ]]; do
    RECEIVERNAME=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --backtitle "$BACKTITLETEXT" --title "$RECEIVERNAME_TITLE" --nocancel --inputbox "\nPlease enter a name for this receiver.\n\nIf you have more than one receiver, this name should be unique.\nExample: \"username-01\", \"username-02\", etc." 12 78 3>&1 1>&2 2>&3)
    RECEIVERNAME_TITLE="Receiver Name (REQUIRED)"
done

# Source the latitude and longitude values configured in dump1090.
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
    # dump1090 fork is -mutability
    if [[ -s /etc/default/dump1090-mutability ]] ; then
        RECEIVERLATITUDE=`GetConfig "LAT" "/etc/default/dump1090-mutability"`
        RECEIVERLONGITUDE=`GetConfig "LON" "/etc/default/dump1090-mutability"`
    fi
elif [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
    # dump1090 fork is -fa
    if [[ -s /run/dump1090-fa/receiver.json ]] ; then
        RECEIVERLATITUDE=`cat /run/dump1090-fa/receiver.json | awk -F "lat\" : " '{print $2}' | awk -F "," '{print $1}'`
        RECEIVERLONGITUDE=`cat /run/dump1090-fa/receiver.json | awk -F "lon\" : " '{print $2}' | awk '{print $1}'`
    fi
fi

# Get the altitude of the receiver from the Google Maps API using the latitude and longitude.
if [[ -n "${RECEIVERLATITUDE}" ]] && [[ -n "${RECEIVERLONGITUDE}" ]] ; then
    RECEIVERALTITUDE=`curl -s https://maps.googleapis.com/maps/api/elevation/json?locations=${RECEIVERLATITUDE},${RECEIVERLONGITUDE} | python -c "import json,sys;obj=json.load(sys.stdin);print obj['results'][0]['elevation'];"`
fi

# Ask the user for the receivers altitude. (This will be prepopulated by the altitude returned from the Google Maps API.
RECEIVERALTITUDE=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --backtitle "$BACKTITLETEXT" --title "Receiver Altitude" --nocancel --inputbox "\nEnter your receiver's altitude." 9 78 "${RECEIVERALTITUDE}" 3>&1 1>&2 2>&3)

# Create the adsbexchange directory in the build directory if it does not exist.
echo -e "\e[94m  Checking for the adsbexchange build directory...\e[97m"
if [ ! -d "$ADSBEXCHANGEBUILDDIRECTORY" ]; then
    echo -e "\e[94m  Creating the adsbexchange build directory...\e[97m"
    mkdir $ADSBEXCHANGEBUILDDIRECTORY
fi

echo -e "\e[94m  Creating the file adsbexchange-netcat_maint.sh...\e[97m"
tee $ADSBEXCHANGEBUILDDIRECTORY/adsbexchange-netcat_maint.sh > /dev/null <<EOF
#! /bin/sh
while true
  do
    sleep 30
    /bin/nc 127.0.0.1 30005 | /bin/nc feed.adsbexchange.com 30005
  done
EOF

echo -e "\e[94m  Creating the file adsbexchange-mlat_maint.sh...\e[97m"
tee $ADSBEXCHANGEBUILDDIRECTORY/adsbexchange-mlat_maint.sh > /dev/null <<EOF
#! /bin/sh
while true
  do
    sleep 30
    /usr/bin/mlat-client --input-type dump1090 --input-connect 127.0.0.1:30005 --lat $RECEIVERLATITUDE --lon $RECEIVERLONGITUDE --alt $RECEIVERALTITUDE --user $RECEIVERNAME --server feed.adsbexchange.com:31090 --no-udp --results beast,connect,127.0.0.1:30104
  done
EOF

echo -e "\e[94m  Setting file permissions for adsbexchange-netcat_maint.sh...\e[97m"
sudo chmod +x $ADSBEXCHANGEBUILDDIRECTORY/adsbexchange-netcat_maint.sh

echo -e "\e[94m  Setting file permissions for adsbexchange-mlat_maint.sh...\e[97m"
sudo chmod +x $ADSBEXCHANGEBUILDDIRECTORY/adsbexchange-mlat_maint.sh

echo -e "\e[94m  Checking if the netcat startup line is contained within the file /etc/rc.local...\e[97m"
if ! grep -Fxq "$ADSBEXCHANGEBUILDDIRECTORY/adsbexchange-netcat_maint.sh &" /etc/rc.local; then
    echo -e "\e[94m  Adding the netcat startup line to the file /etc/rc.local...\e[97m"
    lnum=($(sed -n '/exit 0/=' /etc/rc.local))
    ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i $ADSBEXCHANGEBUILDDIRECTORY/adsbexchange-netcat_maint.sh &\n" /etc/rc.local
fi

echo -e "\e[94m  Checking if the mlat-client startup line is contained within the file /etc/rc.local...\e[97m"
if ! grep -Fxq "$ADSBEXCHANGEBUILDDIRECTORY/adsbexchange-mlat_maint.sh &" /etc/rc.local; then
    echo -e "\e[94m  Adding the mlat-client startup line to the file /etc/rc.local...\e[97m"
    lnum=($(sed -n '/exit 0/=' /etc/rc.local))
    ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i $ADSBEXCHANGEBUILDDIRECTORY/adsbexchange-mlat_maint.sh &\n" /etc/rc.local
fi

## START THE MLAT-CLIENT AND NETCAT FEED

echo ""
echo -e "\e[95m  Starting both the mlat-client and netcat feeds...\e[97m"
echo ""

# Kill any currently running instances of the adsbexchange-netcat_maint.sh script.
echo -e "\e[94m  Checking for any running adsbexchange-netcat_maint.sh processes...\e[97m"
PIDS=`ps -efww | grep -w "adsbexchange-netcat_maint.sh" | awk -vpid=$$ '$2 != pid { print $2 }'`
if [ ! -z "$PIDS" ]; then
    echo -e "\e[94m  Killing any running adsbexchange-netcat_maint.sh processes...\e[97m"
    sudo kill $PIDS
    sudo kill -9 $PIDS
fi
PIDS=`ps -efww | grep -w "/bin/nc feed.adsbexchange.com" | awk -vpid=$$ '$2 != pid { print $2 }'`
if [ ! -z "$PIDS" ]; then
    echo -e "\e[94m  Killing any running netcat processes...\e[97m"
    sudo kill $PIDS
    sudo kill -9 $PIDS
fi

# Kill any currently running instances of the adsbexchange-mlat_maint.sh script.
echo -e "\e[94m  Checking for any running adsbexchange-mlat_maint.sh processes...\e[97m"
PIDS=`ps -efww | grep -w "adsbexchange-mlat_maint.sh" | awk -vpid=$$ '$2 != pid { print $2 }'`
if [ ! -z "$PIDS" ]; then
    echo -e "\e[94m  Killing any running adsbexchange-mlat_maint.sh processes...\e[97m"
    sudo kill $PIDS
    sudo kill -9 $PIDS
fi
PIDS=`ps -efww | grep -w "mlat-client" | awk -vpid=$$ '$2 != pid { print $2 }'`
if [ ! -z "$PIDS" ]; then
    echo -e "\e[94m  Killing any running mlat-client processes...\e[97m"
    sudo kill $PIDS
    sudo kill -9 $PIDS
fi

echo -e "\e[94m  Executing the adsbexchange-netcat_maint.sh script...\e[97m"
sudo nohup $ADSBEXCHANGEBUILDDIRECTORY/adsbexchange-netcat_maint.sh > /dev/null 2>&1 &

echo -e "\e[94m  Executing the adsbexchange-mlat_maint.sh script...\e[97m"
sudo nohup $ADSBEXCHANGEBUILDDIRECTORY/adsbexchange-mlat_maint.sh > /dev/null 2>&1 &

## ADS-B EXCHANGE FEED SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd $PROJECTROOTDIRECTORY

echo ""
echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
echo -e "\e[92m  ADS-B Exchange feed setup is complete.\e[39m"
echo ""
read -p "Press enter to continue..." CONTINUE

exit 0

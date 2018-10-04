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
# Copyright (c) 2016-2018, Joseph A. Prochazka                                      #
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

RECEIVER_ROOT_DIRECTORY="${PWD}"
RECEIVER_BASH_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/bash"
RECEIVER_BUILD_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/build"

### INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

# Source the automated install configuration file if this is an automated installation.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
    source ${RECEIVER_CONFIGURATION_FILE}
fi

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    clear
    echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
fi
echo -e ""
echo -e "\e[92m  Setting up the ADS-B Exchange feed..."
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # Interactive install.
    CONTINUE_SETUP=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "ADS-B Exchange Feed Setup" --yesno "ADS-B Exchange is a co-op of ADS-B/Mode S/MLAT feeders from around the world, and the world’s largest source of unfiltered flight data.\n\n  http://www.adsbexchange.com/how-to-feed/\n\nContinue setting up the ADS-B Exchange feed?" 12 78 3>&1 1>&2 2>&3)
    if [[ ${CONTINUE_SETUP} -eq 1 ]] ; then
        # Setup has been halted by the user.
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo -e ""
        echo -e "\e[93m  ------------------------------------------------------------------------------"
        echo -e "\e[92m  ADS-B Exchange feed setup halted.\e[39m"
        echo -e ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
    fi
else
    # Warn that automated installation is not supported.
    echo -e "\e[92m  Automated installation of this script is not yet supported...\e[39m"
    echo -e ""
    exit 1
fi

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

## CHECK FOR AND REMOVE ANY OLD STYLE ADB-B EXCHANGE SETUPS IF ANY EXIST

echo -e "\e[95m  Checking for and removing any old style ADS-B Exchange setups if any exist...\e[97m"
echo -e ""

# Check if the old style adsbexchange-maint.sh line exists in /etc/rc.local.
echo -e "\e[94m  Checking for any preexisting older style setups...\e[97m"
if [[ `grep -cFx "$RECEIVER_BUILD_DIRECTORY/adsbexchange/adsbexchange-maint.sh &" /etc/rc.local` -gt 0 ]] ; then
    # Kill any currently running instances of the adsbexchange-maint.sh script.
    echo -e "\e[94m  Checking for any running adsbexchange-maint.sh processes...\e[97m"
    PIDS=`ps -efww | grep -w "$RECEIVER_BUILD_DIRECTORY/adsbexchange/adsbexchange-maint.sh &" | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [[ -n "${PIDS}" ]] ; then
        echo -e "\e[94m  -Killing any running adsbexchange-maint.sh processes...\e[97m"
        echo -e ""
        sudo kill ${PIDS} 2>&1
        sudo kill -9 ${PIDS} 2>&1
        echo -e ""
    fi
    # Remove the old line from /etc/rc.local.
    echo -e "\e[94m  Removing the old adsbexchange--maint.sh startup line from /etc/rc.local...\e[97m"
    sudo sed -i /$RECEIVER_BUILD_DIRECTORY\/adsbexchange\/adsbexchange-maint.sh &/d /etc/rc.local 2>&1
fi

# Remove the depreciated adsbexchange-netcat_maint.sh script.
if [ -f /etc/rc.local ]; then
    echo -e "\e[94m  Checking if the netcat startup line is contained within the file /etc/rc.local...\e[97m"
    if ! grep -Fxq "$RECEIVER_BUILD_DIRECTORY/adsbexchange/adsbexchange-netcat_maint.sh &" /etc/rc.local; then
        # Kill any currently running instances of the adsbexchange-netcat_maint.sh script.
        echo -e "\e[94m  Checking for any running adsbexchange-netcat_maint.sh processes...\e[97m"
        if [[ $(ps -aux | grep '[a]dsbexchange-netcat_maint.sh' | awk '{print $2}') ]]; then
            echo -e "\e[94m  Killing the current adsbexchange-netcat_maint.sh process...\e[97m"
            sudo kill -9 $(ps -aux | grep '[a]dsbexchange-netcat_maint.sh' | awk '{print $2}') &> /dev/null
        fi
        if [[ $(ps -aux | grep '[f]eed.adsbexchange.com' | awk '{print $2}') ]]; then
            echo -e "\e[94m  Killing the current feed.adsbexchange.com process...\e[97m"
            sudo kill -9 $(ps -aux | grep '[f]eed.adsbexchange.com' | awk '{print $2}') &> /dev/null
        fi
        # Remove the depreciated netcat script start up line.
        if [ -f /etc/rc.local ]; then
            echo -e "\e[94m  Removing the netcat startup script line to the file /etc/rc.local...\e[97m"
            sudo sed -i /$RECEIVER_BUILD_DIRECTORY\/adsbexchange\/adsbexchange-netcat_maint.sh &/d /etc/rc.local 2>&1
        fi
    fi
fi
echo -e ""

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo -e ""
CheckPackage curl
CheckPackage build-essential
CheckPackage debhelper
CheckPackage python-dev
CheckPackage python3-dev
CheckPackage socat

## DOWNLOAD OR UPDATE THE MLAT-CLIENT SOURCE

echo ""
echo -e "\e[95m  Preparing the mlat-client Git repository...\e[97m"
echo ""
if [ -d $RECEIVER_BUILD_DIRECTORY/mlat-client/mlat-client ] && [ -d $RECEIVER_BUILD_DIRECTORY/mlat-client/mlat-client/.git ]; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the mlat-client git repository directory...\e[97m"
    cd $RECEIVER_BUILD_DIRECTORY/mlat-client/mlat-client
    echo -e "\e[94m  Updating the local mlat-client git repository...\e[97m"
    echo ""
    git pull
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Creating the mlat-client build directory...\e[97m"
    echo ""
    mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/mlat-client
    echo ""
    echo -e "\e[94m  Entering the mlat-client build directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/mlat-client 2>&1
    echo -e "\e[94m  Cloning the mlat-client git repository locally...\e[97m"
    echo ""
    git clone https://github.com/mutability/mlat-client.git
fi

## BUILD AND INSTALL THE MLAT-CLIENT PACKAGE

echo ""
echo -e "\e[95m  Building and installing the mlat-client package...\e[97m"
echo ""
if [ ! $PWD = $RECEIVER_BUILD_DIRECTORY/mlat-client/mlat-client ]; then
    echo -e "\e[94m  Entering the mlat-client git repository directory...\e[97m"
    cd $RECEIVER_BUILD_DIRECTORY/mlat-client/mlat-client
fi
echo -e "\e[94m  Building the mlat-client package...\e[97m"
echo ""
dpkg-buildpackage -b -uc
echo ""
echo -e "\e[94m  Installing the mlat-client package...\e[97m"
echo ""
sudo dpkg -i $RECEIVER_BUILD_DIRECTORY/mlat-client/mlat-client_${MLATCLIENTVERSION}*.deb

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

# Create binary package archive directory.
if [[ ! -d "${RECEIVER_BUILD_DIRECTORY}/package-archive" ]] ; then
    echo -e "\e[94m  Creating package archive directory...\e[97m"
    echo -e ""
    mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/package-archive 2>&1
    echo -e ""
fi

# Archive binary package.
echo -e "\e[94m  Moving the mlat-client binary package into the archive directory...\e[97m"
echo ""
mv -vf ${RECEIVER_BUILD_DIRECTORY}/mlat-client/mlat-client_*.deb ${RECEIVER_BUILD_DIRECTORY}/package-archive 2>&1

## CREATE THE SCRIPT TO EXECUTE AND MAINTAIN MLAT-CLIENT AND SOCAT TO FEED ADS-B EXCHANGE

echo ""
echo -e "\e[95m  Creating maintenance for both the mlat-client and socat feeds...\e[97m"
echo ""

# Ask the user for the user name for this receiver.
RECEIVER_NAME_TITLE="Receiver Name"
while [[ -z $RECEIVER_NAME ]]; do
    RECEIVER_NAME=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --backtitle "$BACKTITLETEXT" --title "$RECEIVER_NAME_TITLE" --nocancel --inputbox "\nPlease enter a name for this receiver.\n\nIf you have more than one receiver, this name should be unique.\nExample: \"username-01\", \"username-02\", etc." 12 78 3>&1 1>&2 2>&3)
    RECEIVER_NAME_TITLE="Receiver Name (REQUIRED)"
done

# Get the altitude of the receiver from the Google Maps API using the latitude and longitude assigned dump1090-mutability if it is installed.
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
    RECEIVER_LATITUDE=`GetConfig "LAT" "/etc/default/dump1090-mutability"`
    RECEIVER_LONGITUDE=`GetConfig "LON" "/etc/default/dump1090-mutability"`
fi

# Ask the user for the receivers altitude. (This will be prepopulated by the altitude returned from the Google Maps API.
RECEIVER_ALTITUDE=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --backtitle "$BACKTITLETEXT" --title "Receiver Altitude" --nocancel --inputbox "\nEnter your receiver's altitude." 9 78 "`curl -s https://maps.googleapis.com/maps/api/elevation/json?locations=$RECEIVER_LATITUDE,$RECEIVER_LONGITUDE | python -c \"import json,sys;obj=json.load(sys.stdin);print obj['results'][0]['elevation']\"`" 3>&1 1>&2 2>&3)

# Create the adsbexchange directory in the build directory if it does not exist.
echo -e "\e[94m  Checking for the adsbexchange build directory...\e[97m"
if [ ! -d "$RECEIVER_BUILD_DIRECTORY/adsbexchange" ]; then
    echo -e "\e[94m  Creating the adsbexchange build directory...\e[97m"
    mkdir $RECEIVER_BUILD_DIRECTORY/adsbexchange
fi

echo -e "\e[94m  Creating the file adsbexchange-socat_maint.sh...\e[97m"

# Some distgros place socat in /usr/bin instead of /user/sbin..
if [ -f "/usr/sbin/socat" ]; then
    SOCAT_PATH="/usr/sbin/socat"
fi
if [ -f "/usr/bin/socat" ]; then
    SOCAT_PATH="/usr/bin/socat"
fi
if [ -z $SOCAT_PATH ]; then
    echo -e ""
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  UNABLE TO LOCATE SOCAT."
    echo -e ""
    exit 1
fi

tee $RECEIVER_BUILD_DIRECTORY/adsbexchange/adsbexchange-socat_maint.sh > /dev/null <<EOF
#! /bin/sh
while true
  do
    sleep 30
    $SOCAT_PATH -u TCP:localhost:30005 TCP:feed.adsbexchange.com:30005
  done
EOF

echo -e "\e[94m  Creating the file adsbexchange-mlat_maint.sh...\e[97m"
tee $RECEIVER_BUILD_DIRECTORY/adsbexchange/adsbexchange-mlat_maint.sh > /dev/null <<EOF
#! /bin/sh
while true
  do
    sleep 30
    /usr/bin/mlat-client --input-type dump1090 --input-connect 127.0.0.1:30005 --lat $RECEIVER_LATITUDE --lon $RECEIVER_LONGITUDE --alt $RECEIVER_ALTITUDE --user $RECEIVER_NAME --server feed.adsbexchange.com:31090 --no-udp --results beast,connect,127.0.0.1:30104
  done
EOF

echo -e "\e[94m  Setting file permissions for adsbexchange-socat_maint.sh...\e[97m"
sudo chmod +x $RECEIVER_BUILD_DIRECTORY/adsbexchange/adsbexchange-socat_maint.sh

echo -e "\e[94m  Setting file permissions for adsbexchange-mlat_maint.sh...\e[97m"
sudo chmod +x $RECEIVER_BUILD_DIRECTORY/adsbexchange/adsbexchange-mlat_maint.sh

# Add a line to start up socat at boot.
echo -e "\e[94m  Checking if the socat startup line is contained within the file /etc/rc.local...\e[97m"
if ! grep -Fxq "$RECEIVER_BUILD_DIRECTORY/adsbexchange/adsbexchange-socat_maint.sh &" /etc/rc.local; then
    echo -e "\e[94m  Adding the socat startup script line to the file /etc/rc.local...\e[97m"
    lnum=($(sed -n '/exit 0/=' /etc/rc.local))
    ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i $RECEIVER_BUILD_DIRECTORY/adsbexchange/adsbexchange-socat_maint.sh &\n" /etc/rc.local
fi

echo -e "\e[94m  Checking if the mlat-client startup line is contained within the file /etc/rc.local...\e[97m"
if ! grep -Fxq "$RECEIVER_BUILD_DIRECTORY/adsbexchange/adsbexchange-mlat_maint.sh &" /etc/rc.local; then
    echo -e "\e[94m  Adding the mlat-client startup line to the file /etc/rc.local...\e[97m"
    lnum=($(sed -n '/exit 0/=' /etc/rc.local))
    ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i $RECEIVER_BUILD_DIRECTORY/adsbexchange/adsbexchange-mlat_maint.sh &\n" /etc/rc.local
fi

## START THE MLAT-CLIENT AND SOCAT FEED

echo ""
echo -e "\e[95m  Starting both the mlat-client and socat feeds...\e[97m"
echo ""

# Kill any currently running instances of the adsbexchange-socat_maint.sh script.
echo -e "\e[94m  Checking for any running adsbexchange-socat_maint.sh processes...\e[97m"
if [[ $(ps -aux | grep '[a]dsbexchange-socat_maint.sh' | awk '{print $2}') ]]; then
    echo -e "\e[94m  Killing the current adsbexchange-socat_maint.sh process...\e[97m"
    sudo kill -9 $(ps -aux | grep '[a]dsbexchange-socat_maint.sh' | awk '{print $2}') &> /dev/null
fi
if [[ $(ps -aux | grep '[f]eed.adsbexchange.com' | awk '{print $2}') ]]; then
    echo -e "\e[94m  Killing the current feed.adsbexchange.com process...\e[97m"
    sudo kill -9 $(ps -aux | grep '[f]eed.adsbexchange.com' | awk '{print $2}') &> /dev/null
fi

# Kill any currently running instances of the adsbexchange-mlat_maint.sh script.
echo -e "\e[94m  Checking for any running adsbexchange-mlat_maint.sh processes...\e[97m"
if [[ $(ps -aux | grep '[a]dsbexchange-mlat_maint.sh' | awk '{print $2}') ]]; then
    echo -e "\e[94m  Killing the current adsbexchange-mlat_maint.sh process...\e[97m"
    sudo kill -9 $(ps -aux | grep '[a]dsbexchange-mlat_maint.sh' | awk '{print $2}') &> /dev/null
fi
if [[ $(ps -aux | grep 'mlat-client' | awk '{print $2}') ]]; then
    echo -e "\e[94m  Killing the current mlat-client process...\e[97m"
    sudo kill -9 $(ps -aux | grep '[m]lat-client' | awk '{print $2}') &> /dev/null
fi

echo -e "\e[94m  Executing the adsbexchange-socat_maint.sh script...\e[97m"
sudo nohup $RECEIVER_BUILD_DIRECTORY/adsbexchange/adsbexchange-socat_maint.sh > /dev/null 2>&1 &

echo -e "\e[94m  Executing the adsbexchange-mlat_maint.sh script...\e[97m"
sudo nohup $RECEIVER_BUILD_DIRECTORY/adsbexchange/adsbexchange-mlat_maint.sh > /dev/null 2>&1 &

## ADS-B EXCHANGE FEED SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
echo -e "\e[92m  ADS-B Exchange feed setup is complete.\e[39m"
echo ""
read -p "Press enter to continue..." CONTINUE

exit 0

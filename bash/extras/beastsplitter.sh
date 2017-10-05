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

## SET INSTALLATION VARIABLES

RECEIVER_ROOT_DIRECTORY="${PWD}"
RECEIVER_BASH_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/bash"
RECEIVER_BUILD_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/build"

## INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] && [[ -s "${RECEIVER_CONFIGURATION_FILE}" ]] ; then
    source ${RECEIVER_CONFIGURATION_FILE}
fi

## BEGIN SETUP

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    clear
    echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
fi
echo -e ""
echo -e "\e[92m  Setting up beast-splitter..."
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Beast-Splitter Setup" --yesno "beast-splitter is a helper utility for the Mode-S Beast.\n\nThe Beast provides a single data stream over a (USB) serial port. If you have more than one thing that wants to read that data stream, you need something to redistribute the data. This is what beast-splitter does.\n\n  https://github.com/flightaware/beast-splitter\n\nContinue beast-splitter setup?" 15 78
    if [[ $? -eq 1 ]] ; then
        # Setup has been halted by the user.
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo -e ""
        echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
        echo -e "\e[92m  beast-splitter setup halted.\e[39m"
        echo -e ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
    fi
fi

echo -e "\e[95m  Setting up beast-splitter on this device...\e[97m"
echo -e ""

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

## CHECK FOR PREREQUISITE PACKAGES

# Check that the required packages are installed.
CheckPackage build-essential
CheckPackage debhelper
CheckPackage libboost-system-dev
CheckPackage libboost-program-options-dev
CheckPackage libboost-regex-dev
CheckPackage dh-systemd

## CONFIRM SETTINGS

# Confirm settings with user.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # Ask the beast-splitter listen port.
    BEASTSPLITTER_LISTEN_PORT_TITLE="Listen Port"
    while [[ -z "${BEASTSPLITTER_LISTEN_PORT}" ]] ; do
        BEASTSPLITTER_LISTEN_PORT=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${BEASTSPLITTER_LISTEN_PORT_TITLE}" --nocancel --inputbox "\nPlease enter the port beast-splitter will listen on.\nThis must be a port which is currently not in use." 10 78 "30005" 3>&1 1>&2 2>&3)
        BEASTSPLITTER_LISTEN_PORT_TITLE="Listen Port (REQUIRED)"
    done
    # Ask the beast-splitter connect port.
    BEASTSPLITTER_CONNECT_PORT_TITLE="Connect Port"
    while [[ -z "${BEASTSPLITTER_CONNECT_PORT}" ]] ; do
        BEASTSPLITTER_CONNECT_PORT=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${BEASTSPLITTER_CONNECT_PORT_TITLE}" --nocancel --inputbox "\nPlease enter the port beast-splitter will connect to.\nThis is generally port 30104 on dump1090." 10 78 "30104" 3>&1 1>&2 2>&3)
       BEASTSPLITTER_CONNECT_PORT_TITLE="Connect Port (REQUIRED)"
   done
fi

## DOWNLOAD SOURCE

echo -e ""
echo -e "\e[95m  Downloading and configuring beast-splitter...\e[97m"
echo -e ""

echo -e "\e[94m  Checking if the Git repository has been cloned...\e[97m"
if [[ -d "${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter" ]] && [[ -d "${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter/.git" ]] ; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the local beast-splitter git repository directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter 2>&1
    echo -e "\e[94m  Updating the local beast-splitter git repository...\e[97m"
    echo -e ""
    git pull 2>&1
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Creating the beast-splitter build directory...\e[97m"
    echo ""
    mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/beast-splitter 2>&1
    echo ""
    echo -e "\e[94m  Entering the beast-splitter build directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/beast-splitter 2>&1
    echo -e "\e[94m  Cloning the beast-splitter git repository locally...\e[97m"
    echo -e ""
    git clone https://github.com/flightaware/beast-splitter.git 2>&1
fi

## BUILD AND INSTALL

echo -e ""
echo -e "\e[95m  Building and installing the beast-splitter package...\e[97m"
echo -e ""
if [[ ! ${PWD} = ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter ]] ; then
    echo -e "\e[94m  Entering the beast-splitter git repository directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter 2>&1
fi
echo -e "\e[94m  Executing the beast-splitter build script...\e[97m"
echo -e ""
dpkg-buildpackage -b 2>&1
echo -e ""
echo -e "\e[94m  Entering the beast-splitter build directory...\e[97m"
cd ${RECEIVER_BUILD_DIRECTORY}/beast-splitter 2>&1
echo -e "\e[94m  Installing the beast-splitter package...\e[97m"
sudo dpkg -i beast-splitter_*.deb 2>&1

if [[ ! -d "${RECEIVER_BUILD_DIRECTORY}/package-archive" ]] ; then
    # Create binary package archive directory.
    echo -e "\e[94m  Creating package archive directory...\e[97m"
    echo ""
    mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/package-archive 2>&1
    echo ""
fi

# Archive binary package.
echo -e "\e[94m  Moving the beast-splitter package into the archive directory...\e[97m"
echo ""
mv -vf ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter_*.deb ${RECEIVER_BUILD_DIRECTORY}/package-archive/ 2>&1
echo ""

## CREATE SCRIPTS

echo -e "\e[94m  Creating the file beast-splitter_maint.sh...\e[97m"
tee ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter_maint.sh > /dev/null <<EOF
#! /bin/bash
while true
  do
    sleep 30
    beast-splitter --serial /dev/beast --listen ${BEASTSPLITTER_LISTEN_PORT}:R --connect localhost:${BEASTSPLITTER_CONNECT_PORT}:R
  done
EOF

echo -e "\e[94m  Setting file permissions for beast-splitter_maint.sh...\e[97m"
sudo chmod -v +x ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter_maint.sh 2>&1

echo -e "\e[94m  Checking if the beast-splitter startup line is contained within the file /etc/rc.local...\e[97m"
if [[ `grep -cFx "${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter_maint.sh &" /etc/rc.local` -eq 0 ]] ; then
    echo -e "\e[94m  Adding the beast-splitter startup line to the file /etc/rc.local...\e[97m"
    lnum=($(sed -n '/exit 0/=' /etc/rc.local))
    ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter_maint.sh &\n" /etc/rc.local
fi

## START SCRIPTS

echo -e ""
echo -e "\e[95m  Starting beast-splitter...\e[97m"
echo -e ""

# Kill any currently running instances.
PROCS="beast-splitter_maint.sh beast-splitter"
for PROC in ${PROCS} ; do
    PIDS=`ps -efww | grep -w "${PROC} " | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [[ -n "${PIDS}" ]] ; then
        echo -e "\e[94m  Killing any running ${PROC} processes...\e[97m"
        sudo kill ${PIDS} 2>&1
        sudo kill -9 ${PIDS} 2>&1
    fi
    unset PIDS
done

# Start the beast-splitter_maint.sh script.
echo -e "\e[94m  Executing the beast-splitter script...\e[97m"
echo -e ""
sudo nohup ${RECEIVER_BUILD_DIRECTORY}/beast-splitter/beast-splitter_maint.sh > /dev/null 2>&1 &

## SETUP COMPLETE

# Return to the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  beast-splitter setup is complete.\e[39m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

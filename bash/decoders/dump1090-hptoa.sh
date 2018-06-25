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
# Copyright (c) 2015-2018, Joseph A. Prochazka                                      #
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
echo -e "\e[92m  Setting up dump1090-hptoa..."
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""

# Confirm that the installation process should continue.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # Interactive install.
    CONTINUE_SETUP=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Dump1090-hptoa Setup" --yesno "This is a fork of Mutability's version of dump1090 that adds a novel method to compute high-precision Time-of-Arrival (ToA) timestamps of the Mode S / ADS-B packets. The actual precision is in the order of a few nanoseconds, depending on the packet strength.\n\n  https://github.com/openskynetwork/dump1090-hptoa \n\nContinue setup by installing dump1090-hptoa?" 15 78 3>&1 1>&2 2>&3)
    if [[ ${CONTINUE_SETUP} -eq 1 ]] ; then
        # Setup has been halted by the user.
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo -e ""
        echo -e "\e[93m  ------------------------------------------------------------------------------"
        echo -e "\e[92m  Dump1090-hptoa setup halted.\e[39m"
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

### CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to fulfill dependencies for dump1090-hptoa...\e[97m"
echo -e ""

# Required by install script.
CheckPackage git
CheckPackage cmake
CheckPackage build-essential
CheckPackage pkg-config
CheckPackage autotools-dev
CheckPackage automake
# Required for USB SDR devices.
CheckPackage librtlsdr-dev
CheckPackage libusb-1.0-0-dev
CheckPackage rtl-sdr
# Required by component.
CheckPackage lighttpd

### START INSTALLATION

echo -e ""
echo -e "\e[95m  Begining the dump1090-hptoa installation process...\e[97m"
echo -e ""

## SETUP UDEV RTL-SDR RULES

# Download the file rtl-sdr.rules from the osmocon rtl-sdr repository if it does not already exist.
if [[ ! -f "/etc/udev/rules.d/rtl-sdr.rules" ]] ; then
    echo -e "\e[94m  Downloading the file rtl-sdr.rules from the rtl-sdr repository...\e[97m"
    echo ""
    sudo wget -O /etc/udev/rules.d/rtl-sdr.rules https://raw.githubusercontent.com/osmocom/rtl-sdr/master/rtl-sdr.rules
    echo -e "\e[94m  Restarting udev...\e[97m"
    sudo service udev restart
fi

# Create an RTL-SDR blacklist file so the device does not claim SDR's for other purposes.
BlacklistModules

## CREATE THE DUMP1090-HPTOA BUILD DIRECTORY IF IT DOES NOT EXIST

if [[ ! -d "${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa" ]] ; then
    echo -e "\e[94m  Creating the dump1090-hptoa build directory...\e[97m"
    echo ""
    mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa
    echo ""
fi

## ATTEMPT TO DOWNLOAD OR UPDATE THE LIQUID-DSP SOURCE CODE FROM GITHUB

if [[ -d "${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/liquid-dsp" ]] && [[ -d "${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/liquid-dsp/.git" ]] ; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the liquid-dsp git repository directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/liquid-dsp 2>&1
    echo -e "\e[94m  Updating the local liquid-dsp git repository...\e[97m"
    echo -e ""
    git pull 2>&1
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Entering to dump1090-hptoa build directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa 2>&1
    echo -e "\e[94m  Cloning the liquid-dsp git repository locally...\e[97m"
    echo -e ""
    git clone https://github.com/jgaeddert/liquid-dsp.git 2>&1
    echo ""
fi

## ATTEMPT TO DOWNLOAD OR UPDATE THE DUMP1090-HPTOA SOURCE CODE FROM GITHUB

if [[ -d "${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/dump1090-hptoa" ]] && [[ -d "${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/dump1090-hptoa/.git" ]] ; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the dump1090-hptoa git repository directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/dump1090-hptoa 2>&1
    echo -e "\e[94m  Updating the local dump1090-hptoa git repository...\e[97m"
    echo -e ""
    git pull 2>&1
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Entering dump1090-hptoa build directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa 2>&1
    echo -e "\e[94m  Cloning the dump1090-hptoa git repository locally...\e[97m"
    echo -e ""
    git clone https://github.com/openskynetwork/dump1090-hptoa.git 2>&1
fi

## BUILD AND INSTALL THE LIQUID-DSP LIBRARY.

echo -e ""
echo -e "\e[95m  Building the liquid-dsp library...\e[97m"
echo -e ""

# Change directory to the liquid-dsp build directory.
if [[ ! "${PWD}" = "${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/liquid-dsp" ]] ; then
    echo -e "\e[94m  Entering the liquid-dsp build directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/liquid-dsp 2>&1
fi

echo -e "\e[94m  Executing bootstrap.sh...\e[97m"
./bootstrap.sh
echo -e "\e[94m  Executing configure...\e[97m"
echo -e ""
./configure
echo -e ""
echo -e "\e[94m  Building the liquid-sdr library...\e[97m"
echo -e ""
make
echo -e ""
echo -e "\e[94m  Installing the liquid-sdr library...\e[97m"
echo -e ""
sudo make install
echo -e ""
echo -e "\e[94m  Updating the shared library cache...\e[97m"
sudo ldconfig

## BUILD THE DUMP1090-HPTOA BINARIES

echo -e ""
echo -e "\e[95m  Building the dump1090-hptoa binaries...\e[97m"
echo -e ""

# Change to the dump1090-hptoa build directory.
if [[ ! "${PWD}" = "${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/dump1090-hptoa" ]] ; then
    echo -e "\e[94m  Entering the dump1090-hptoa build directory...\e[97m"
    cd  ${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/dump1090-hptoa 2>&1
fi

# Build the binaries.
echo -e "\e[94m  Creating the directory ${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/dump1090-hptoa/build...\e[97m"
echo ""
mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/dump1090-hptoa/build
echo ""
echo -e "\e[94m  Entering the directory ${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/dump1090-hptoa/build...\e[97m"
cd ${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/dump1090-hptoa/build 2>&1
echo -e "\e[94m  Executing cmake...\e[97m"
echo ""
cmake ../
echo ""
echo -e "\e[94m  Now executing make...\e[97m"
echo ""
make
echo ""

# Checking that the binaries were in fact built.
if [ ! -f  ${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/dump1090-hptoa/build/dump1090 ] || [ ! -f ${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/dump1090-hptoa/build/faup1090 ] || [ ! -f ${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/dump1090-hptoa/build/view1090 ] ; then
    # If any of the binaries were not installed halt the setup process..
    echo -e ""
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  FAILED TO BUILD A REQUIRED BINARY."
    echo -e "  SETUP HAS BEEN TERMINATED!"
    echo -e ""
    echo -e "\e[93mOne or more of the dump1090-hptoa binaries failed to be built.\e[39m"
    echo -e ""
    echo -e "\e[93m  ------------------------------------------------------------------------------"
    echo -e "\e[92m  Dump1090-hptoa setup halted.\e[39m"
    echo -e ""
    if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
        read -p "Press enter to continue..." CONTINUE
    fi
    exit 1
fi

## POST INSTALL ACTIONS

# Create the dump190 init script.
echo -e "\e[94m  Creating the dump1090 init script...\e[97m"
sudo tee /etc/init.d/dump1090 > /dev/null <<EOF
#!/bin/bash
### BEGIN INIT INFO
#
# Provides:		dump1090
# Required-Start:	\$remote_fs
# Required-Stop:	\$remote_fs
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	dump1090 initscript

#
### END INIT INFO
## Fill in name of program here.
PROG="dump1090"
PROG_PATH="${RECEIVER_BUILD_DIRECTORY}/dump1090-hptoa/dump1090-hptoa/build/dump1090"
PROG_ARGS="--quiet --gain -10 --net --net-beast --enable-hptoa PeakPulse"
PIDFILE="/var/run/dump1090.pid"

start() {
      if [ -e \$PIDFILE ]; then
          ## Program is running, exit with error.
          echo "Error! \$PROG is currently running!" 1>&2
          exit 1
      else
          ## Change from /dev/null to something like /var/log/\$PROG if you want to save output.
          cd \$PROG_PATH
          ./\$PROG \$PROG_ARGS 2>&1 >/dev/null &
          echo "\$PROG started"
          touch \$PIDFILE
      fi
}

stop() {
      if [ -e \$PIDFILE ]; then
          ## Program is running, so stop it
         echo "\$PROG is running"
         killall \$PROG
         rm -f \$PIDFILE
         echo "\$PROG stopped"
      else
          ## Program is not running, exit with error.
          echo "Error! \$PROG not started!" 1>&2
          exit 1
      fi
}

## Check to see if we are running as root first.
## Found at http://www.cyberciti.biz/tips/shell-root-user-check-script.html
if [ "\$(id -u)" != "0" ]; then
      echo "This script must be run as root" 1>&2
      exit 1
fi

case "\$1" in
      start)
          start
          exit 0
      ;;
      stop)
          stop
          exit 0
      ;;
      reload|restart|force-reload)
          stop
          start
          exit 0
      ;;
      **)
          echo "Usage: \$0 {start|stop|reload}" 1>&2
          exit 1
      ;;
esac
exit 0
EOF

echo -e "\e[94m  Setting permissions for the dump1090 init script...\e[97m"
sudo chmod +x /etc/init.d/dump1090
echo -e "\e[94m  Executing update-rc.d to add the init script link for dump1090...\e[97m"
sudo update-rc.d dump1090 defaults
echo -e "\e[94m  Starting dump1090-hptoa...\e[97m"
sudo /etc/init.d/dump1090 start

### SETUP COMPLETE

# Return to the project root directory.
echo -e "\e[94m  Returning to ${RECEIVER_PROJECT_TITLE} root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  Dump1090-hptoa setup is complete.\e[39m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

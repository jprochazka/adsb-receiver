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
COMPONENT_NAME="Acarsdec"
COMPONENT_GITHUB_URL="https://github.com/TLeconte/acarsdec.git"
COMPONENT_BUILD_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/Acarsdec"

# Component service script variables.
COMPONENT_SERVICE_NAME=$(echo ${COMPONENT_NAME} | tr '[A-Z]' '[a-z]')
COMPONENT_SERVICE_SCRIPT_URL="https://raw.githubusercontent.com/Romeo-golf/acarsdec/master/acarsdec-service"
COMPONENT_SERVICE_SCRIPT_NAME="${COMPONENT_SERVICE_NAME}-service"
COMPONENT_SERVICE_SCRIPT_PATH="/etc/init.d/${COMPONENT_SERVICE_NAME}"
COMPONENT_SERVICE_CONFIG_PATH="/etc/${COMPONENT_SERVICE_SCRIPT_NAME}.conf"

### INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

# Source the automated install configuration file if this is an automated installation.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
    source ${RECEIVER_CONFIGURATION_FILE}
fi

### BEGIN SETUP

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    clear
    echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
fi
echo -e ""
echo -e "\e[92m  Setting up ${COMPONENT_NAME}...\e[97m"
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""
#

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to fulfill dependencies for ${COMPONENT_NAME}...\e[97m"
echo -e ""
# Required by install script.
CheckPackage git
CheckPackage curl
# Required for USB SDR devices.
CheckPackage librtlsdr-dev
CheckPackage libusb-1.0-0-dev
CheckPackage rtl-sdr
# Required by component.
CheckPackage autoconf
CheckPackage automake
CheckPackage libfftw3-3
CheckPackage libfftw3-dev
CheckPackage libtool
CheckPackage procserv
CheckPackage telnet
echo -e ""
echo -e "\e[95m  Configuring this device to run the ${COMPONENT_NAME} binaries...\e[97m"
echo -e ""

## CHECK FOR EXISTING INSTALL AND IF SO STOP IT

if [[ -f "${COMPONENT_SERVICE_SCRIPT_PATH}" ]] ; then
    echo -en "\e[33m  Stopping the ${COMPONENT_NAME} service...\e[97m"
    ACTION=$(sudo ${COMPONENT_SERVICE_SCRIPT_PATH} stop 2>&1)
    CheckReturnCode
fi

### ASSIGN RTL-SDR DONGLES


# Download from github and compile.
if [[ true ]] ; then
    COMPONENT_GITHUB_URL_SHORT=`echo ${COMPONENT_GITHUB_URL} | sed -e 's/http:\/\///g' -e 's/https:\/\///g' | tr '[A-Z]' '[a-z]'`
    COMPONENT_GITHUB_PROJECT=`echo ${COMPONENT_GITHUB_URL} | awk -F "/" '{print $NF}' | sed -e 's/\.git$//g'`
    COMPONENT_BUILD_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/${COMPONENT_GITHUB_PROJECT}"

    # Check if already installed and located where we would expect it to be.
    if [[ -d "${COMPONENT_BUILD_DIRECTORY}/.git/" ]] ; then
        # Then perhaps we can update from github.
        cd ${COMPONENT_BUILD_DIRECTORY}
        ACTION=$(git remote update 2>&1)
        if [[ `git status -uno | grep -c "is behind"` -gt 0 ]] ; then
            # Local branch is behind remote so update.
            echo -en "\e[33m  Updating ${COMPONENT_GITHUB_PROJECT} from \"\e[37m${COMPONENT_GITHUB_URL_SHORT}\e[33m\"...\e[97m"
            ACTION=$(git pull 2>&1)
            DO_INSTALL_FROM_GIT="true"
        else
            echo -en "\e[33m  Local ${COMPONENT_GITHUB_PROJECT} repository is up to date with \"\e[37m${COMPONENT_GITHUB_URL_SHORT}\e[33m\"...\e[97m"
        fi
    else
        # Otherwise clone from github.
        echo -en "\e[33m  Cloning ${COMPONENT_GITHUB_PROJECT} from \"\e[37m${COMPONENT_GITHUB_URL_SHORT}\e[33m\"...\e[97m"
        ACTION=$(git clone https://${COMPONENT_GITHUB_URL_SHORT} ${COMPONENT_BUILD_DIRECTORY} 2>&1)
        DO_INSTALL_FROM_GIT="true"
    fi
    CheckReturnCode

    # Compile and install from source.
    if [[ "${DO_INSTALL_FROM_GIT}" = "true" ]] ; then
        echo -en "\e[33m  Compiling ${COMPONENT_GITHUB_PROJECT} from source..."
        # Prepare to build from source.
        cd ${COMPONENT_BUILD_DIRECTORY}
        # And remove previous binaries.
        if [[ `ls -l *.h 2>/dev/null | grep -c "\.h"` -gt 0 ]] ; then
            ACTION=$(sudo make -C ${COMPONENT_BUILD_DIRECTORY} clean 2>&1)
        fi
        # Run bootstrap.
        if [[ -x "bootstrap" ]] ; then
            ACTION=$(./bootstrap 2>&1)
        fi
        # Configure with CFLAGS.
        if [[ -x "configure" ]] ; then
            ACTION=$(./configure ${COMPONENT_CFLAGS} 2>&1)
        fi
        # Make.
        if [[ -f "Makefile" ]] ; then
            ACTION=$(make -C ${COMPONENT_BUILD_DIRECTORY} 2>&1)
            # Install
            if [[ `grep -c "^install:" Makefile` -gt 0 ]] ; then
                ACTION=$(sudo make -C ${COMPONENT_BUILD_DIRECTORY} install 2>&1)
            fi
        fi
    else
        echo -en "\e[33m  ${COMPONENT_GITHUB_PROJECT} is already installed..."
    fi
    CheckReturnCode

    unset DO_INSTALL_FROM_GIT
    cd ${COMPONENT_BUILD_DIRECTORY}
fi

### INSTALL AS A SERVICE

# Install service script.
if [[ -f "${COMPONENT_SERVICE_SCRIPT_NAME}" ]] ; then
    # Check for local copy of service script.
    if [[ `grep -c "conf=${COMPONENT_SERVICE_CONFIG_PATH}" ${COMPONENT_SERVICE_SCRIPT_NAME}` -eq 1 ]] ; then
        echo -en "\e[33m  Installing service script at \"\e[37m${COMPONENT_SERVICE_SCRIPT_PATH}\e[33m\"...\e[97m"
        ACTION=$(cp -v ${COMPONENT_SERVICE_SCRIPT_NAME} ${COMPONENT_SERVICE_SCRIPT_PATH})
        ACTION=$(sudo chmod -v +x ${COMPONENT_SERVICE_SCRIPT_PATH} 2>&1)
    else
        echo -en "\e[33m  Invalid service script \"\e[37m${COMPONENT_SERVICE_SCRIPT_NAME}\e[33m\"...\e[97m"
        false
    fi
elif [[ -n "${COMPONENT_SERVICE_SCRIPT_URL}" ]] ; then
    # Otherwise attempt to download service script.
    if [[ `echo ${COMPONENT_SERVICE_SCRIPT_URL} | grep -c "^http"` -gt 0 ]] ; then
        echo -en "\e[33m  Downloading service script to \"\e[37m${COMPONENT_SERVICE_SCRIPT_PATH}\e[33m\"...\e[97m"
        ACTION=$(sudo curl -L ${COMPONENT_SERVICE_SCRIPT_URL} -o ${COMPONENT_SERVICE_SCRIPT_PATH} 2>&1)
        ACTION=$(sudo chmod -v +x ${COMPONENT_SERVICE_SCRIPT_PATH} 2>&1)
    else
        echo -en "\e[33m  Invalid service script url \"\e[37m${COMPONENT_SERVICE_SCRIPT_URL}\e[33m\"...\e[97m"
        false
    fi
else
    # Otherwise error if unable to use local or downloaded service script
    echo -en "\e[33m  Unable to install service script at \"\e[37m${COMPONENT_SERVICE_SCRIPT_PATH}\e[33m\"...\e[97m"
    false
fi
CheckReturnCode

# Generate and install service script configuration file.
if [[ -n "${COMPONENT_SERVICE_CONFIG_PATH}" ]] ; then
    echo -en "\e[33m  Creating service config file \"\e[37m${COMPONENT_SERVICE_CONFIG_PATH}\e[33m\"...\e[97m"
    sudo tee ${COMPONENT_SERVICE_CONFIG_PATH} > /dev/null 2>&1 <<EOF
#shellbox configuration file
#Starts commands inside a "box" with a telnet-like server.
#Contact the shell with: telnet <hostname> <port>
#Syntax:
#port  user     directory                 command       args
50600  pi       ${COMPONENT_PROJECT_DIRECTORY} ./acarsdec    -o 2
EOF
    ACTION=$(chown -v pi:pi ${COMPONENT_SERVICE_CONFIG_PATH})
else
    echo -en "\e[33m  Unable to create service config file...\e[97m"
    false
fi
CheckReturnCode

# Configure DECODER as a service.
echo -en "\e[33m  Configuring ${COMPONENT_NAME} as a service...\e[97m"
ACTION=$(sudo update-rc.d ${COMPONENT_SERVICE_NAME} defaults 2>&1)
CheckReturnCode

# Start the DECODER service.
echo -en "\e[33m  Starting the ${COMPONENT_NAME} service...\e[97m"
ACTION=$(sudo /etc/init.d/${COMPONENT_SERVICE_NAME} start 2>&1)
CheckReturnCode

### SETUP COMPLETE

# Return to the project root directory.
echo -en "\e[94m  Returning to ${RECEIVER_PROJECT_TITLE} root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY}
ACTION=${PWD}
CheckReturnCode

echo -e "\e[93m  ------------------------------------------------------------------------------\n"
echo -e "\e[92m  ${COMPONENT_NAME} setup is complete.\e[39m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

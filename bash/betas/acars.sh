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

RECIEVER_ROOT_DIRECTORY="${PWD}"
RECEIVER_BASH_DIRECTORY="${RECIEVER_ROOT_DIRECTORY}/bash"
RECEIVER_BUILD_DIRECTORY="${RECIEVER_ROOT_DIRECTORY}/build"

# Decoder specific variables.
BETA_NAME="Acarsdec"
BETA_GITHUB_URL="https://github.com/TLeconte/acarsdec.git"

# Decoder service script variables.
BETA_SERVICE_NAME=$(echo ${BETA_NAME} | tr '[A-Z]' '[a-z]')
BETA_SERVICE_SCRIPT_URL="https://raw.githubusercontent.com/Romeo-golf/acarsdec/master/acarsdec-service"
BETA_SERVICE_SCRIPT_NAME="${BETA_SERVICE_NAME}-service"
BETA_SERVICE_SCRIPT_PATH="/etc/init.d/${BETA_SERVICE_NAME}"
BETA_SERVICE_CONFIG_PATH="/etc/${BETA_SERVICE_SCRIPT_NAME}.conf"

## INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

# Should be moved to functions.sh.
function CheckReturnCode {
    LINE=$((`stty size | awk '{print $1}'` - 1))
    COL=$((`stty size | awk '{print $2}'` - 8))
    tput cup "${LINE}" "${COL}"
    if [[ $? -eq 0 ]] ; then
        echo -e "\e[97m[\e[32mDone\e[97m]\e[39m\n"
    else
        echo -e "\e[97m[\e[31mError\e[97m]\e[39m\n"
        echo -e "\e[39m  ${ACTION}\n"
    fi
}

# Source the automated install configuration file if this is an automated installation.
if [[ ${RECEIVER_AUTOMATED_INSTALL} = "true" ]] ; then
    source ${RECEIVER_CONFIGURATION_FILE}
fi

## BEGIN SETUP

if [[ ${RECEIVER_AUTOMATED_INSTALL} = "false" ]] ; then
    clear
    echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
fi
echo -e ""
echo -e "\e[92m  Setting up ${BETA_NAME}...\e[97m"
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""
#

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to fulfill dependencies for ${BETA_NAME}...\e[97m"
echo -e ""
# Required by install script.
CheckPackage git
CheckPackage curl
# Required for USB SDR devices.
CheckPackage librtlsdr-dev
CheckPackage libusb-1.0-0-dev
CheckPackage rtl-sdr
# Required for Acarsdec.
CheckPackage autoconf
CheckPackage automake
CheckPackage libfftw3-3
CheckPackage libfftw3-dev
CheckPackage libtool
CheckPackage procserv
CheckPackage telnet
echo -e ""
echo -e "\e[95m  Configuring this device to run the ${BETA_NAME} binaries...\e[97m"
echo -e ""

## CHECK FOR EXISTING INSTALL AND IF SO STOP IT

if [[ -f ${BETA_SERVICE_SCRIPT_PATH} ]] ; then
    echo -en "\e[33m  Stopping the ${BETA_NAME} service...\e[97m"
    ACTION=$(sudo ${BETA_SERVICE_SCRIPT_PATH} stop 2>&1)
    CheckReturnCode
fi

### ASSIGN RTL-SDR DONGLES


# Download from github and compile.
if [[ true ]] ; then
    BETA_GITHUB_URL_SHORT=`echo ${BETA_GITHUB_URL} | sed -e 's/http:\/\///g' -e 's/https:\/\///g' | tr '[A-Z]' '[a-z]'`
    BETA_GITHUB_PROJECT=`echo ${BETA_GITHUB_URL} | awk -F "/" '{print $NF}' | sed -e 's/\.git$//g'`
    BETA_BUILD_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/${BETA_GITHUB_PROJECT}"

    # Check if already installed and located where we would expect it to be.
    if [[ -d "${BETA_BUILD_DIRECTORY}" ]] ; then
        # Then perhaps we can update from github.
        cd ${BETA_BUILD_DIRECTORY}
        ACTION=$(git remote update 2>&1)
        if [[ `git status -uno | grep -c "is behind"` -gt 0 ]] ; then
            # Local branch is behind remote so update.
            echo -en "\e[33m  Updating ${BETA_GITHUB_PROJECT} from \"\e[37m${BETA_GITHUB_URL_SHORT}\e[33m\"...\e[97m"
            ACTION=$(git pull 2>&1)
            DO_INSTALL_FROM_GIT="true"
        else
            echo -en "\e[33m  Local ${BETA_GITHUB_PROJECT} repository is up to date with \"\e[37m${BETA_GITHUB_URL_SHORT}\e[33m\"...\e[97m"
        fi
    else
        # Otherwise clone from github.
        echo -en "\e[33m  Cloning ${BETA_GITHUB_PROJECT} from \"\e[37m${BETA_GITHUB_URL_SHORT}\e[33m\"...\e[97m"
        ACTION=$(git clone https://${BETA_GITHUB_URL_SHORT} ${BETA_BUILD_DIRECTORY} 2>&1)
        DO_INSTALL_FROM_GIT="true"
    fi
    CheckReturnCode

    # Compile and install from source.
    if [[ ${DO_INSTALL_FROM_GIT} = "true" ]] ; then
        echo -en "\e[33m  Compiling ${BETA_GITHUB_PROJECT} from source..."
        # Prepare to build from source.
        cd ${BETA_BUILD_DIRECTORY}
        # And remove previous binaries.
        if [[ `ls -l *.h 2>/dev/null | grep -c "\.h"` -gt 0 ]] ; then
            ACTION=$(sudo make -C ${BETA_BUILD_DIRECTORY} clean 2>&1)
        fi
        # Run bootstrap.
        if [[ -x "bootstrap" ]] ; then
            ACTION=$(./bootstrap 2>&1)
        fi
        # Configure with CFLAGS.
        if [[ -x "configure" ]] ; then
            ACTION=$(./configure ${BETA_CFLAGS} 2>&1)
        fi
        # Make.
        if [[ -f "Makefile" ]] ; then
            ACTION=$(make -C ${BETA_BUILD_DIRECTORY} 2>&1)
            # Install
            if [[ `grep -c "^install:" Makefile` -gt 0 ]] ; then
                ACTION=$(sudo make -C ${BETA_BUILD_DIRECTORY} install 2>&1)
            fi
        fi
    else
        echo -en "\e[33m  ${BETA_GITHUB_PROJECT} is already installed..."
    fi
    CheckReturnCode

    unset DO_INSTALL_FROM_GIT
    cd ${BETA_BUILD_DIRECTORY}
fi

### INSTALL AS A SERVICE

# Install service script.
if [[ -f "${BETA_SERVICE_SCRIPT_NAME}" ]] ; then
    # Check for local copy of service script.
    if [[ `grep -c "conf=${BETA_SERVICE_CONFIG_PATH}" ${BETA_SERVICE_SCRIPT_NAME}` -eq 1 ]] ; then
        echo -en "\e[33m  Installing service script at \"\e[37m${BETA_SERVICE_SCRIPT_PATH}\e[33m\"...\e[97m"
        ACTION=$(cp -v ${BETA_SERVICE_SCRIPT_NAME} ${BETA_SERVICE_SCRIPT_PATH})
        ACTION=$(sudo chmod -v +x ${BETA_SERVICE_SCRIPT_PATH} 2>&1)
    else
        echo -en "\e[33m  Invalid service script \"\e[37m${BETA_SERVICE_SCRIPT_NAME}\e[33m\"...\e[97m"
        false
    fi
elif [[ -n ${BETA_SERVICE_SCRIPT_URL} ]] ; then
    # Otherwise attempt to download service script.
    if [[ `echo ${BETA_SERVICE_SCRIPT_URL} | grep -c "^http"` -gt 0 ]] ; then
        echo -en "\e[33m  Downloading service script to \"\e[37m${BETA_SERVICE_SCRIPT_PATH}\e[33m\"...\e[97m"
        ACTION=$(sudo curl ${BETA_SERVICE_SCRIPT_URL} -o ${BETA_SERVICE_SCRIPT_PATH} 2>&1)
        ACTION=$(sudo chmod -v +x ${BETA_SERVICE_SCRIPT_PATH} 2>&1)
    else
        echo -en "\e[33m  Invalid service script url \"\e[37m${BETA_SERVICE_SCRIPT_URL}\e[33m\"...\e[97m"
        false
    fi
else
    # Otherwise error if unable to use local or downloaded service script
    echo -en "\e[33m  Unable to install service script at \"\e[37m${BETA_SERVICE_SCRIPT_PATH}\e[33m\"...\e[97m"
    false
fi
CheckReturnCode

# Generate and install service script configuration file.
if [[ -n ${BETA_SERVICE_CONFIG_PATH} ]] ; then
    echo -en "\e[33m  Creating service config file \"\e[37m${BETA_SERVICE_CONFIG_PATH}\e[33m\"...\e[97m"
    sudo tee ${BETA_SERVICE_CONFIG_PATH} > /dev/null 2>&1 <<EOF
#shellbox configuration file
#Starts commands inside a "box" with a telnet-like server.
#Contact the shell with: telnet <hostname> <port>
#Syntax:
#port  user     directory                 command       args
50600  pi       ${BETA_PROJECT_DIRECTORY} ./acarsdec    -o 2
EOF
    ACTION=$(chown -v pi:pi ${BETA_SERVICE_CONFIG_PATH})
else
    echo -en "\e[33m  Unable to create service config file...\e[97m"
    false
fi
CheckReturnCode

# Configure DECODER as a service.
echo -en "\e[33m  Configuring ${BETA_NAME} as a service...\e[97m"
ACTION=$(sudo update-rc.d ${BETA_SERVICE_NAME} defaults 2>&1)
CheckReturnCode

# Start the DECODER service.
echo -en "\e[33m  Starting the ${BETA_NAME} service...\e[97m"
ACTION=$(sudo /etc/init.d/${BETA_SERVICE_NAME} start 2>&1)
CheckReturnCode

## SETUP COMPLETE

# Return to the project root directory.
echo -en "\e[94m  Returning to ${RECEIVER_PROJECT_TITLE} root directory...\e[97m"
cd ${RECIEVER_ROOT_DIRECTORY}
ACTION=${PWD}
CheckReturnCode

echo -e "\e[93m  ------------------------------------------------------------------------------\n"
echo -e "\e[92m  ${BETA_NAME} setup is complete.\e[39m"
echo -e ""
if [[ ${RECEIVER_AUTOMATED_INSTALL} = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

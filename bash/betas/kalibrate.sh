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
BETA_NAME="Kalibrate"
BETA_GITHUB_URL="https://github.com/steve-m/kalibrate-rtl.git"

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
# Required for Kalibrate.
CheckPackage autoconf
CheckPackage automake
CheckPackage libfftw3-3
CheckPackage libfftw3-dev
CheckPackage libtool
echo -e ""
echo -e "\e[95m  Configuring this device to run the ${BETA_NAME} binaries...\e[97m"
echo -e ""

# Download from github and compile.
if [[ true ]] ; then
    BETA_GITHUB_URL_SHORT=`echo ${BETA_GITHUB_URL} | sed -e 's/http:\/\///g' -e 's/https:\/\///g' | tr '[A-Z]' '[a-z]'`
    BETA_GITHUB_PROJECT=`echo ${BETA_GITHUB_URL} | awk -F "/" '{print $NF}' | sed -e 's/\.git$//g'`
    BETA_BUILD_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/${BETA_GITHUB_PROJECT}"

    # Check if already installed and located where we would expect it to be.
    if [[ -x `which kal` ]] && [[ -d "${BETA_BUILD_DIRECTORY}" ]] ; then
        # Then perhaps we can update from github.
        cd ${BETA_BUILD_DIRECTORY}
        ACTION=$(git remote update 2>&1)
        if [[ `git status -uno | grep -c "is behind"` -gt 0 ]] ; then
            # Local branch is behind remote so update.
            echo -en "\e[33m  Updating ${BETA_GITHUB_PROJECT} from \"\e[37m${BETA_GITHUB_URL_SHORT}\e[33m\"...\e[97m"
            ACTION=$(git pull 2>&1)
            DO_INSTALL_FROM_GIT="true"
        else
            echo -en "\e[33m  Local copy of ${BETA_GITHUB_PROJECT} is up to date with \"\e[37m${BETA_GITHUB_URL_SHORT}\e[33m\"...\e[97m"
        fi
    else
        # Otherwise clone from github.
        echo -en "\e[33m  Building ${BETA_GITHUB_PROJECT} from \"\e[37m${BETA_GITHUB_URL_SHORT}\e[33m\"...\e[97m"
        ACTION=$(git clone https://${BETA_GITHUB_URL_SHORT} ${BETA_BUILD_DIRECTORY} 2>&1)
        DO_INSTALL_FROM_GIT="true"
    fi
    CheckReturnCode

    # Compile and install from source.
    if [[ ${DO_INSTALL_FROM_GIT} = "true" ]] ; then
        echo -en "\e[33m  Compiling source for ${BETA_GITHUB_PROJECT}..."        
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
        if [[ -f "Makefile" ]] ; then
            ACTION=$(make -C ${BETA_BUILD_DIRECTORY} 2>&1)
            # Install.
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

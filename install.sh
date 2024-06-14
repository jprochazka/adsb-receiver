#!/bin/bash

#####################################################################################
#                                   ADS-B RECEIVER                                  #
#####################################################################################
#                                                                                   #
#  A set of scripts created to automate the process of installing the software      #
#  needed to setup a Mode S decoder as well as feeders which are capable of         #
#  sharing your ADS-B results with many of the most popular ADS-B aggregate sites.  #
#                                                                                   #
#  Project Hosted On GitHub: https://github.com/jprochazka/adsb-receiver            #
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

AUTOMATED_INSTALL="false"
PROJECT_BRANCH="master"
CONFIGURATION_FILE="default"
ENABLE_LOGGING="false"

export RECEIVER_ROOT_DIRECTORY="${PWD}"
export RECEIVER_BASH_DIRECTORY="${PWD}/bash"
export RECEIVER_BUILD_DIRECTORY="${PWD}/build"
export RECEIVER_OS_CODE_NAME=`lsb_release -c -s`
export RECEIVER_OS_DISTRIBUTION=`. /etc/os-release; echo ${ID/*, /}`
export RECEIVER_OS_RELEASE=`. /etc/os-release; echo ${VERSION_ID/*, /}`

## SOURCE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/functions.sh

## FUNCTIONS

# Display the help message.
function DisplayHelp() {
    echo ""
    echo "Usage: $0 [OPTIONS] [ARGUMENTS]"
    echo ""
    echo "Option        GNU long option        Meaning"
    echo "-a            --automated-install    Use a configuration file to automate the install process somewhat."
    echo "-b <BRANCH>   --branch=<BRANCH>      Specifies the repository branch to be used."
    echo "-c <FILE>     --config-file=<FILE>   The configuration file to be use for an unattended installation."
    echo "-d            --development          Skips local repository update so changes are not overwrote."
    echo "-h            --help                 Shows this message."
    echo "-l            --log-output           Logs all output to a file in the logs directory."
    echo "-m <MTA>      --mta=<MTA>            Specify which email MTA to use currently Exim or Postfix."
    echo "-u            --apt-update           Forces the apt update command to be ran."
    echo "-v            --verbose              Provides extra confirmation at each stage of the install."
    echo ""
}

## CHECK FOR OPTIONS AND ARGUMENTS

while [[ $# -gt 0 ]] ; do
    case "$1" in
        -h|--help)
            # Display a help message.
            DisplayHelp
            exit 0
            ;;
        -a|--automated-install)
            # Automated install.
            AUTOMATED_INSTALL="true"
            shift 1
            ;;
        -b)
            # The specified branch of github.
            PROJECT_BRANCH="$2"
            shift 2
            ;;
        --branch*)
            # The specified branch of github.
            PROJECT_BRANCH=`echo $1 | sed -e 's/^[^=]*=//g'`
            shift 1
            ;;
        -c)
            # The specified installation configuration file.
            CONFIGURATION_FILE="$2"
            shift 2
            ;;
        --config-file*)
            # The specified installation configuration file.
            CONFIGURATION_FILE=`echo $1 | sed -e 's/^[^=]*=//g'`
            shift 1
            ;;
        -d|--development)
            # Skip adsb-receiver repository update.
            DEVELOPMENT_MODE="true"
            shift 1
            ;;
        -l|--log-output)
            # Enable logging to a file in the logs directory.
            ENABLE_LOGGING="true"
            shift 1
            ;;
        -m)
           # The MTA to use.
            MTA=${2^^}
            if [ $MTA != "EXIM" ] && [ $MTA != "POSTFIX" ]; then
                echo "MTA can only be either EXIM or POSTFIX."
                exit 1
            fi
            shift 2
            ;;
        --mta*)
            MTA=`echo ${1^^} | sed -e 's/^[^=]*=//g'`
            if [ $MTA != "EXIM" ] && [ $MTA != "POSTFIX" ]; then
                echo "MTA can only be either EXIM or POSTFIX."
                exit 1
            fi
            shift 1
            ;;
        -u|--apt-update)
            # Force apt update.
            FORCE_APT_UPDATE="true"
            shift 1
            ;;
        -v|--verbose)
            # Provides extra confirmation at each stage of the install.
            VERBOSE="true"
            shift 1
            ;;
        *)
            # Unknown options were set so exit.
            echo -e "Error: Unknown option: $1" >&2
            DisplayHelp
            exit 1
            ;;
    esac
done

## AUTOMATED INSTALL

# If the automated installation option was selected set the needed environmental variables.
if [[ "${AUTOMATED_INSTALL}" = "true" ]] ; then
    # If no configuration file was specified use the default configuration file path and name.
    if [[ -n "${CONFIGURATION_FILE}" ]] || [[ "${CONFIGURATION_FILE}" = "default" ]] ; then
        CONFIGURATION_FILE="${RECEIVER_ROOT_DIRECTORY}/install.config"
    # If either the -c or --config-file= flags were set a valid file must reside there.
    elif [[ ! -f "${CONFIGURATION_FILE}" ]] ; then
        echo "Unable to locate the installation configuration file."
        exit 1
    fi
fi

# Add any environmental variables needed by any child scripts.
export RECEIVER_AUTOMATED_INSTALL=${AUTOMATED_INSTALL}
export RECEIVER_PROJECT_BRANCH=${PROJECT_BRANCH}
export RECEIVER_CONFIGURATION_FILE=${CONFIGURATION_FILE}
export RECEIVER_MTA=${MTA}
export RECEIVER_FORCE_APT_UPDATE=$FORCE_APT_UPDATE
export RECEIVER_VERBOSE=${VERBOSE}

## EXECUTE BASH/INIT.SH

chmod +x ${RECEIVER_BASH_DIRECTORY}/init.sh
if [[ -n "${ENABLE_LOGGING}" ]] && [[ "${ENABLE_LOGGING}" = "true" ]] ; then
    # Execute init.sh logging all output to the log drectory as the file name specified.
    LOG_FILE="${RECEIVER_ROOT_DIRECTORY}/logs/install_$(date +"%m_%d_%Y_%H_%M_%S").log"
    ${RECEIVER_BASH_DIRECTORY}/init.sh 2>&1 | tee -a "${LOG_FILE}"
    echo -e "\e[95m  Cleaning up log file...\e[97m"
    CleanLogFile "${LOG_FILE}"
else
    # Execute init.sh without logging any output to the log directory.
    ${RECEIVER_BASH_DIRECTORY}/init.sh
fi

## CLEAN UP

# Remove any files created by whiptail.
for WHIPTAIL in FEEDER_CHOICES EXTRAS_CHOICES ; do
    if [[ -f "${RECEIVER_ROOT_DIRECTORY}/${WHIPTAIL}" ]] ; then
        rm -f ${RECEIVER_ROOT_DIRECTORY}/${WHIPTAIL}
    fi
done

# Remove any global variables assigned by this script.
unset RECEIVER_ROOT_DIRECTORY
unset RECEIVER_BASH_DIRECTORY
unset RECEIVER_BUILD_DIRECTORY
unset RECEIVER_PROJECT_BRANCH
unset RECEIVER_AUTOMATED_INSTALL
unset RECEIVER_CONFIGURATION_FILE
unset RECEIVER_FORCE_APT_UPDATE
unset RECEIVER_VERBOSE
unset RECEIVER_PROJECT_TITLE
unset RECEIVER_MTA
unset RECEIVER_OS_DISTRIBUTION
unset RECEIVER_OS_RELEASE

# Check if any errors were encountered by any child scripts.
# If no errors were encountered then exit this script cleanly.
if [[ $? -ne 0 ]] ; then
    exit 1
else
    exit 0
fi

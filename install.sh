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

PROJECTROOTDIRECTORY="$PWD"
BASHDIRECTORY="$PROJECTROOTDIRECTORY/bash"
LOGDIRECTORY="$PROJECTROOTDIRECTORY/logs"

## INCLUDE EXTERNAL SCRIPTS

source $BASHDIRECTORY/functions.sh

## CHECK FOR OPTIONS AND ARGUMENTS

while test $# -gt 0; do
    case "$1" in
        -h|--help)
            # Display a help message.
            echo "Usage: install.sh [OPTIONS] [ARGUMENTS]"
            echo ""
            echo "Option     GNU long option          Meaning"
            echo "-h         --help                   Shows this message."
            echo "-l         --log-output             Logs all output to a file in the logs directory."
            echo "-u         --unattended             Begins an unattended installation using a configuration file."
            echo "-c         --config-file=<FILE>     The configuration file to be use for an unattended installation."
            exit 0
            ;;
        -l|--log-output)
            # Enable logging to a log file.
            ENABLELOGGING="true"
            shift
            ;;
        -u|--unattended)
            # Enable logging to a log file.
            export ADSB_UNATTENDED="true"
            shift
            ;;
        -c|--config-file*)
            # The specified installation configuration file.
            export ADSB_CONFIGURATIONFILE=`echo $1 | sed -e 's/^[^=]*=//g'`
            shift
            ;;
        *)
            # No options were set so exit.
            break
            ;;
    esac
done

if [ $ADSB_UNATTENDED = "true" ]; then
    echo "The unattended installation option is still in development..."
    exit 1
fi

chmod +x $BASHDIRECTORY/init.sh
if [ ! -z $ENABLELOGGING ] && [ $ENABLELOGGING = "true" ]; then
    # Execute init.sh logging all output to the log drectory as the file name specified.
    LOGFILE="$LOGDIRECTORY/install_$(date +"%m_%d_%Y_%H_%M_%S").log"
    $BASHDIRECTORY/init.sh 2>&1 | tee -a "$LOGFILE"
    CleanLogFile "$LOGFILE"
else
    # Execute init.sh without logging any output to the log directory.
    $BASHDIRECTORY/init.sh
fi

# Remove any global variables assigned by this script.
unset ADSB_UNATTENDED
unset ADSB_CONFIGURATIONFILE

# Check if any errors were encountered by any child scripts.
# If no errors were encountered then exit this script cleanly.
if [ $? -ne 0 ]; then
    exit 1
else
    exit 0
fi

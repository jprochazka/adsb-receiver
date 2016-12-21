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

### VARIABLES

PROJECT_ROOT_DIRECTORY="$PWD"
BASH_DIRECTORY="$PROJECT_ROOT_DIRECTORY/bash"
LOG_DIRECTORY="$PROJECT_ROOT_DIRECTORY/logs"

ENABLE_LOGGING="false"
AUTOMATED_INSTALL="false"
CONFIGURATION_FILE="default"

### INCLUDE EXTERNAL SCRIPTS

source $BASH_DIRECTORY/functions.sh

### USAGE 

usage()
{   
    echo -e ""
    echo -e "Usage: $0 [OPTIONS] [ARGUMENTS]"
    echo -e ""
    echo -e "Option     GNU long option     	Meaning"
    echo -e "-c <FILE>  --config-file=<FILE>	The configuration file to be use for an unattended installation."
    echo -e "-d         --delay            	Add a pseudo-random delay of between 5 and 59 minutes."
    echo -e "-h         --help              	Shows this message."
    echo -e "-l         --log-output        	Logs all output to a file in the logs directory."
    echo -e "-u         --unattended        	Begins an unattended installation using a configuration file."
    echo -e "-v         --verbose           	Provides extra confirmation at each stage of the install."
    echo -e ""
}

### CHECK FOR OPTIONS AND ARGUMENTS

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            # Display a help message.
            usage
            exit 0
            ;;
        -a|--automated)
            # Enable logging to a log file.
            AUTOMATED_INSTALL="true"
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
        -d|--delay)
            DELAY="true"
            shift 1
            ;;
        -l|--log-output)
            # Enable logging to a file in the logs directory.
            ENABLE_LOGGING="true"
            shift 1
            ;;
        -v|--verbose)
            # Provides extra confirmation at each stage of the install.
            export VERBOSE="true"
            shift 1
            ;;
        *)
            # Unknown options were set so exit.
            echo -e "Error: Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

### AUTOMATED INSTALL

# If the automated installation option was selected set the needed environmental variables.
if [ $AUTOMATED_INSTALL = "true" ]; then

    ###################################################################
    ##            THIS FEATURE IS NOT READY FOR USE YET             ###
    echo "The automated installation option is still in development..."
    exit 1
    ###################################################################

    # If no configuration file was specified use the default configuration file path and name.
    if [ $CONFIGURATION_FILE = "default" ]; then
        CONFIGURATION_FILE="$PROJECT_ROOT_DIRECTORY/install.config"
    fi

    # If either the -c or --config-file= flags were set a valid file must reside there.
    if [ ! -f $CONFIGURATION_FILE ]; then
        echo "The specified configuration file does not exist."
        exit 1
    fi
fi

# Add any environmental variables needed by any child scripts.
export AUTOMATED_INSTALL
export CONFIGURATION_FILE

### EXECUTE BASH/INIT.SH

chmod +x $BASH_DIRECTORY/init.sh
if [[ ! -z $ENABLE_LOGGING ]] && [[ $ENABLE_LOGGING = "true" ]] ; then
    # Execute init.sh logging all output to the log drectory as the file name specified.
    LOG_FILE="$LOG_DIRECTORY/install_$(date +"%m_%d_%Y_%H_%M_%S").log"
    $BASH_DIRECTORY/init.sh 2>&1 | tee -a "$LOG_FILE"
    CleanLogFile "$LOG_FILE"
else
    # Execute init.sh without logging any output to the log directory.
    $BASH_DIRECTORY/init.sh
fi

### CLEAN UP

# Remove any global variables assigned by this script.
unset AUTOMATED_INSTALL
unset CONFIGURATION_FILE
unset VERBOSE
unset DELAY

# Check if any errors were encountered by any child scripts.
# If no errors were encountered then exit this script cleanly.
if [[ $? -ne 0 ]] ; then
    exit 1
else
    exit 0
fi

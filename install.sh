#!/bin/bash

## ASSIGN VARIABLE

project_version="2.8.9"

printf -v date_time '%(%Y-%m-%d_%H-%M-%S)T' -1
log_file="adsb-installer_${date_time}.log"
logging_enabled="true"
project_branch="master"


## FUNCTIONS

# Display the help message
function DisplayHelp() {
    echo "                                                                                           "
    echo "Usage: $0 [OPTION] [ARGUMENT]                                                              "
    echo "                                                                                           "
    echo "-------------------------------------------------------------------------------------------"
    echo "Option       GNU long option    Description                                                "
    echo "-------------------------------------------------------------------------------------------"
    echo "-b <BRANCH>  --branch=<BRANCH>  Specifies the repository branch to be used.                "
    echo "-d           --development      Skips local repository update so changes are not overwrote."
    echo "-h           --help             Shows this message.                                        "
    echo "-m <MTA>     --mta=<MTA>        Specify which email MTA to use currently Exim or Postfix.  "
    echo "-n           --no-logging       Disables writing output to a log file.                     "
    echo "-v           --version          Displays the version being used.                           "
    echo "-------------------------------------------------------------------------------------------"
    echo "                                                                                           "
}


## CHECK FOR OPTIONS AND ARGUMENTS

while [[ $# > 0 ]] ; do
    case $1 in
        --branch*)
            project_branch=`echo $1 | sed -e 's/^[^=]*=//g'`
            shift 1
            ;;
        -b)
            project_branch=$2
            shift 2
            ;;
        --development | -d)
            development_mode="true"
            shift 1
            ;;
        --help | -h)
            DisplayHelp
            exit 0
            ;;
        --mta*)
            mta=`echo ${1^^} | sed -e 's/^[^=]*=//g'`
            if [[ "${mta}" != "EXIM" && "${mta}" != "POSTFIX" ]]; then
                echo "MTA can only be either EXIM or POSTFIX."
                exit 1
            fi
            shift 1
            ;;
        --no-logging | -n)
            logging_enabled="false"
            shift 1
            ;;
        -m)
           # The MTA to use
            mta=${2^^}
            if [[ "${mta}" != "EXIM" && "${mta}" != "POSTFIX" ]]; then
                echo "MTA can only be either EXIM or POSTFIX."
                exit 1
            fi
            shift 2
            ;;
        --version | -v)
            # Display the version
            echo $project_version
            exit 0
            ;;
        *)
            # Unknown options were set so exit
            echo -e "Error: Unknown option: $1" >&2
            DisplayHelp
            exit 1
            ;;
    esac
done

export RECEIVER_PROJECT_BRANCH=$project_branch
export RECEIVER_DEVELOPMENT_MODE=$development_mode
export RECEIVER_LOGGING_ENABLED=$logging_enabled
export RECEIVER_MTA=$mta


## SET PROJECT VARIABLES

export RECEIVER_PROJECT_TITLE="ADS-B Receiver Installer v${project_version}"
export RECEIVER_ROOT_DIRECTORY=$PWD
export RECEIVER_BASH_DIRECTORY=$PWD/bash
export RECEIVER_BUILD_DIRECTORY=$PWD/build


## SOURCE EXTERNAL SCRIPTS

source $RECEIVER_BASH_DIRECTORY/functions.sh
source $RECEIVER_BASH_DIRECTORY/variables.sh


## CREATE THE LOG DIRECTORY

if [[ "${RECEIVER_LOGGING_ENABLED}" == "true" ]]; then
    export RECEIVER_LOG_FILE=$PWD/logs/$log_file
    if [ ! -d "$DIRECTORY" ]; then
        log_message "Creating logs directory"
        mkdir $PWD/logs
    fi
fi


## UPDATE PACKAGE LISTS AND INSTALL DEPENDENCIES

clear
log_project_title
log_title_heading "Starting ADS-B Receiver Installer package dependency check"
log_title_message "------------------------------------------------------------------------------"

log_heading "Updating package lists for all enabled repositories and PPAs"

log_message "Downloading the latest package lists for all enabled repositories and PPAs"
echo ""
sudo apt-get update 2>&1 | tee -a $RECEIVER_LOG_FILE

log_heading "Ensuring that all required packages are installed"

check_package bc
check_package git
check_package lsb-base
check_package lsb-release
check_package whiptail
echo ""

log_title_message "------------------------------------------------------------------------------"
log_title_heading "ADS-B Receiver Installer package dependency check complete"
echo ""
read -p "Press enter to continue..." discard


## SET OS VARIABLES

export RECEIVER_OS_CODE_NAME=`lsb_release -c -s`
export RECEIVER_OS_DISTRIBUTION=`. /etc/os-release; echo ${ID/*, /}`
export RECEIVER_OS_RELEASE=`. /etc/os-release; echo ${VERSION_ID/*, /}`


## SET HANDWARE VARIABLES

export RECIEVER_CPU_ARCHITECTURE=`uname -m | tr -d "\n\r"`
export RECEIVER_CPU_REVISION=`grep "^Revision" /proc/cpuinfo | awk '{print $3}'`

## INIT DECODER DEVICE ASSIGNMENT VARIABLES

export RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER
export RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER
export RECEIVER_DEVICE_ASSIGNED_TO_UAT_DECODER
export RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER
export RECEIVER_ACARS_DECODER_SOFTWARE
export RECEIVER_ADSB_DECODER_SOFTWARE
export RECEIVER_UAT_DECODER_SOFTWARE
export RECEIVER_VDLM2_DECODER_SOFTWARE


## EXECUTE BASH/INIT.SH

chmod +x $RECEIVER_BASH_DIRECTORY/init.sh
$RECEIVER_BASH_DIRECTORY/init.sh


## CLEAN UP

for choice in FEEDER_CHOICES EXTRAS_CHOICES ; do
    if [[ -f ${RECEIVER_ROOT_DIRECTORY}/${choice} ]] ; then
        rm -f ${RECEIVER_ROOT_DIRECTORY}/${choice}
    fi
done

unset RECEIVER_PROJECT_TITLE
unset RECEIVER_ROOT_DIRECTORY
unset RECEIVER_BASH_DIRECTORY
unset RECEIVER_BUILD_DIRECTORY
unset RECEIVER_OS_CODE_NAME
unset RECEIVER_OS_DISTRIBUTION
unset RECEIVER_OS_RELEASE
unset RECIEVER_CPU_ARCHITECTURE
unset RECEIVER_CPU_REVISION
unset RECEIVER_DEVICE_ASSIGNED_TO_ACARS_DECODER
unset RECEIVER_DEVICE_ASSIGNED_TO_ADSB_DECODER
unset RECEIVER_DEVICE_ASSIGNED_TO_UAT_DECODER
unset RECEIVER_DEVICE_ASSIGNED_TO_VDLM2_DECODER
unset RECEIVER_ACARS_DECODER_SOFTWARE
unset RECEIVER_ADSB_DECODER_SOFTWARE
unset RECEIVER_UAT_DECODER_SOFTWARE
unset RECEIVER_VDLM2_DECODER_SOFTWARE
unset RECEIVER_PROJECT_BRANCH
unset RECEIVER_DEVELOPMENT_MODE
unset RECEIVER_LOGGING_ENABLED
unset RECEIVER_LOG_FILE
unset RECEIVER_MTA

# Check if any errors were encountered by any child scripts
if [[ $? != 0 ]] ; then
    exit 1
else
    exit 0
fi

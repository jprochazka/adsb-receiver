#!/bin/bash

## ASSIGN VARIABLES

project_version="2.8.10"

printf -v date_time '%(%Y-%m-%d_%H-%M-%S)T' -1
log_file="adsb-installer_${date_time}.log"
logging_enabled="true"
project_branch="master"
development_mode=""
mta=""


## FUNCTIONS

# Display the help message
function display_help() {
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

# Normalize long options to short equivalents for getopts
if [[ $# -gt 0 ]]; then
    normalized_args=()
    for arg in "$@"; do
        case "$arg" in
            --branch=*)    normalized_args+=("-b" "${arg#*=}") ;;
            --development) normalized_args+=("-d") ;;
            --help)        normalized_args+=("-h") ;;
            --mta=*)       normalized_args+=("-m" "${arg#*=}") ;;
            --no-logging)  normalized_args+=("-n") ;;
            --version)     normalized_args+=("-v") ;;
            *)             normalized_args+=("$arg") ;;
        esac
    done
    set -- "${normalized_args[@]}"
fi

while getopts ":b:dhm:nv" opt; do
    case "$opt" in
        b)
            project_branch="$OPTARG"
            ;;
        d)
            development_mode="true"
            ;;
        h)
            display_help
            exit 0
            ;;
        m)
            mta="${OPTARG^^}"
            if [[ "${mta}" != "EXIM" && "${mta}" != "POSTFIX" ]]; then
                echo "MTA can only be either EXIM or POSTFIX."
                exit 1
            fi
            ;;
        n)
            logging_enabled="false"
            ;;
        v)
            echo "$project_version"
            exit 0
            ;;
        :)
            echo "Error: Option -${OPTARG} requires an argument." >&2
            display_help
            exit 1
            ;;
        \?)
            echo "Error: Unknown option: -${OPTARG}" >&2
            display_help
            exit 1
            ;;
    esac
done

export RECEIVER_PROJECT_BRANCH="${project_branch}"
export RECEIVER_DEVELOPMENT_MODE="${development_mode}"
export RECEIVER_LOGGING_ENABLED="${logging_enabled}"
export RECEIVER_MTA="${mta}"


## SET PROJECT VARIABLES

export RECEIVER_PROJECT_TITLE="ADS-B Receiver Installer v${project_version}"
export RECEIVER_ROOT_DIRECTORY="${PWD}"
export RECEIVER_BASH_DIRECTORY="${PWD}/bash"
export RECEIVER_BUILD_DIRECTORY="${PWD}/build"


## SOURCE EXTERNAL SCRIPTS

source "${RECEIVER_BASH_DIRECTORY}/functions.sh"
source "${RECEIVER_BASH_DIRECTORY}/variables.sh"


## CREATE THE LOG DIRECTORY

if [[ "${RECEIVER_LOGGING_ENABLED}" == "true" ]]; then
    export RECEIVER_LOG_FILE="${PWD}/logs/${log_file}"
    mkdir -p "${PWD}/logs"
    log_message "Creating logs directory"
fi


## UPDATE PACKAGE LISTS AND INSTALL DEPENDENCIES

clear
log_project_title
log_title_heading "Starting ADS-B Receiver Installer package dependency check"
log_title_message "------------------------------------------------------------------------------"

log_heading "Updating package lists for all enabled repositories and PPAs"

log_message "Downloading the latest package lists for all enabled repositories and PPAs"
echo ""
sudo apt-get update 2>&1 | log_pipe

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
if [[ -t 0 ]]; then
    read -r -p "Press enter to continue..." discard
fi


## SET OS VARIABLES

RECEIVER_OS_CODE_NAME=$(lsb_release -c -s)
export RECEIVER_OS_CODE_NAME
RECEIVER_OS_DISTRIBUTION=$(. /etc/os-release; echo "${ID/*, /}")
export RECEIVER_OS_DISTRIBUTION
RECEIVER_OS_RELEASE=$(. /etc/os-release; echo "${VERSION_ID/*, /}")
export RECEIVER_OS_RELEASE


## SET HARDWARE VARIABLES

RECEIVER_CPU_ARCHITECTURE=$(uname -m | tr -d "\n\r")
export RECEIVER_CPU_ARCHITECTURE
RECEIVER_CPU_REVISION=$(grep "^Revision" /proc/cpuinfo | awk '{print $3}')
export RECEIVER_CPU_REVISION


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

bash "${RECEIVER_BASH_DIRECTORY}/init.sh"
init_exit_code=$?


## CLEAN UP

for choice in feeder_choices.txt extras_choices.txt ; do
    rm -f "${RECEIVER_ROOT_DIRECTORY}/${choice}"
done

unset RECEIVER_PROJECT_TITLE
unset RECEIVER_ROOT_DIRECTORY
unset RECEIVER_BASH_DIRECTORY
unset RECEIVER_BUILD_DIRECTORY
unset RECEIVER_OS_CODE_NAME
unset RECEIVER_OS_DISTRIBUTION
unset RECEIVER_OS_RELEASE
unset RECEIVER_CPU_ARCHITECTURE
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

exit "$init_exit_code"
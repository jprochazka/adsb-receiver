#!/bin/bash

## INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh


## BEGIN SETUP

clear
LogProjectName ${RECEIVER_PROJECT_TITLE}
LogTitleHeading "Setting up the ADS-B Portal"
LogTitleMessage "------------------------------------------------------------------------------"
echo ""

if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "ADS-B Portal Setup" --yesno "The ADS-B Portal allows you to view performance graphs, system information, and live maps containing the current aircraft being tracked.\n\nBy enabling the portal's advanced features you can also view historical data on flight that has been seen in the past as well as view more detailed information on each of these aircraft.\n\nDo you wish to continue setting up the ADS-B Portal?" 23 78; then
    LogAlertHeading "INSTALLATION HALTED"
    LogAlertMessage "Setup has been halted at the request of the user"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "ADS-B Receiver Portal setup halted"
    echo ""
    exit 1
fi


## GATHER INSTALLATION INFORMATION FROM THE USER

# -----------------------------------------------------------------
# TODO: CHECK IF THE ADS-B PORTAL BACKEND AND FRONTEND IS INSTALLED
# -----------------------------------------------------------------

portal_installed = "false"
if [[ -f "" ]] ; then
    portal_installed = "true"
fi


## EXECUTE THE PROPER ADS-B PORTAL DATABASE CREATION SCRIPT

if [[ "${portal_installed}" = "false" ]]
    LogHeading "Performing database setup"

    LogMessage "Asking the user which type of database engine should be used"
    database_engine = $(whiptail \
        --backtitle "${RECEIVER_PROJECT_TITLE}" \
        --title "Choose Database Engine" \
        --nocancel \
        --menu "Choose which database engine to use" \
        11 80 2 \
        "MySQL" "" "PostgreSQL" "" "SQLite" "")
    LogMessage "Database engine set to ${database_engine}"

    LogMessage "Executing the ${database_engine} database engine setup script"
    chmod +x $RECEIVER_BASH_DIRECTORY/portal/databases/${database_engine,,}.sh
    ${RECEIVER_BASH_DIRECTORY}/portal/databases/${script_name,,}.sh
    if [[ $? -ne 0 ]] ; then
        exit 1
    fi
fi


## SETUP ADS-B PORTAL BACKEND


## SETUP ADS-B PORTAL FRONTEND


## EXECUTE THE PERFORMANCE GRAPHS SETUP SCRIPT
LogHeading "Performing performance graphs setup"

LogMessage "Executing the performance graphs setup script"
chmod +x ${RECEIVER_BASH_DIRECTORY}/portal/graphs.sh
${RECEIVER_BASH_DIRECTORY}/portal/graphs.sh
if [[ $? -ne 0 ]] ; then
    LogAlertHeading "THE SCRIPT GRAPHS.SH ENCOUNTERED AN ERROR"
    LogAlertMessage "Setup has been halted due to error reported by the graphs.sh script"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "ADS-B Portal setup has been halted"
    exit 1
fi


## SETUP COMPLETE

LogHeading "Performing post setup steps"
echo ""

LogMessage "Entering the ADS-B Receiver Project root directory"
cd ${RECEIVER_ROOT_DIRECTORY}
echo ""

LogTitleMessage "------------------------------------------------------------------------------"
LogTitleHeading "ADS-B Portal setup is complete"
echo ""

exit 0
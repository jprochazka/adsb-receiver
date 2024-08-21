#!/bin/bash

# TODO: UDPrepeater should now reside within the bin directory within the repository.
#       https://github.com/json-parser/json-parser
#       https://troydhanson.github.io/uthash/ (uthash-dev package available)

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
log_project_title
log_title_heading "Setting up UDPrepeater"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "UDPrepeater Setup" \
              --yesno "UDPrepeater is a general purpose, configurable UDP forwarding/repeating daemon for Linux. It is useful for repeating one-way streams of data from a single sender to multiple receivers, and for forwarding UDP traffic to different receivers based upon source or destination IP addresses or UDP ports.\n\n  https://github.com/UnionPacific/udp-repeater\n\nContinue UDPrepeater setup?" \
              15 78; then
    echo ""
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo -e ""
    echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
    echo -e "\e[92m  UDPrepeater setup halted.\e[39m"
    echo -e ""
    read -p "Press enter to continue..." discard
    exit 1
fi


## CLONE OR PULL THE UDPREPEATER DECODER SOURCE

log_heading "Preparing the UDPrepeater Git repository"

if [[ -d $RECEIVER_BUILD_DIRECTORY/udp-repeater && -d $RECEIVER_BUILD_DIRECTORY/udp-repeater/.git ]]; then
    log_message "Entering the UDPrepeater git repository directory"
    cd $RECEIVER_BUILD_DIRECTORY/udp-repeater
    log_message "Updating the local UDPrepeater git repository"
    echo ""
    git pull
else
    log_message "Entering the build directory"
    cd $RECEIVER_BUILD_DIRECTORY
    log_message "Cloning the UDPrepeater git repository locally"
    echo ""
    git clone https://github.com/UnionPacific/udp-repeater
fi


## BUILD THE UDPREPEATER BINARY

log_heading "Building the UDPrepeater binary"

log_message "Entering the UDPrepeater src repository"
cd $RECEIVER_BUILD_DIRECTORY/udp-repeater/src
log_message "Running the make command"
make

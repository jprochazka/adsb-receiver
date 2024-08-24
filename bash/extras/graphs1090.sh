#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
log_project_title
log_title_heading "Setting up Graphs1090"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "Beast-Splitter Setup" \
              --yesno "Graphs for readsb and dump1090-fa based on dump1090-tools by mutability.\n\nRepository: https://github.com/wiedehopf/graphs1090\n\nWould you like to begin the setup process now?" \
              15 78; then
    echo ""
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo -e ""
    echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
    echo -e "\e[92m  Graphs1090 setup halted.\e[39m"
    echo -e ""
    read -p "Press enter to continue..." discard
    exit 1
fi

## DOWNLOAD THEN EXECUTE THE INSTALLATION SCRIPT

log_heading "Preparing to install graphs1090"

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/graphs1090 ]]; then
    log_message "Creating the Graphs1090 build directory"
    mkdir $RECEIVER_BUILD_DIRECTORY/graphs1090
fi
log_message "Entering the Graphs1090 build directory"
cd $RECEIVER_BUILD_DIRECTORY/graphs1090
log_message "Downloading the Graphs1090 install script"
echo ""
wget -v -O $RECEIVER_BUILD_DIRECTORY/graphs1090/install.sh https://github.com/wiedehopf/graphs1090/raw/master/install.sh 2>&1 | tee -a $RECEIVER_LOG_FILE
log_message "Executing the Graphs1090 install script"
echo ""
sudo bash $RECEIVER_BUILD_DIRECTORY/graphs1090/install.sh
echo ""


## SETUP COMPLETE

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "Graphs1090 setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

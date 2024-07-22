#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
LogProjectTitle
LogTitleHeading "Setting up beast-splitter"
LogTitleMessage "------------------------------------------------------------------------------"
echo ""
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "Beast-Splitter Setup" \
              --yesno "beast-splitter is a helper utility for the Mode-S Beast.\n\nThe Beast provides a single data stream over a (USB) serial port. If you have more than one thing that wants to read that data stream, you need something to redistribute the data. This is what beast-splitter does.\n\n  https://github.com/flightaware/beast-splitter\n\nContinue beast-splitter setup?" \
              15 78; then
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo -e ""
    echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
    echo -e "\e[92m  beast-splitter setup halted.\e[39m"
    echo -e ""
    read -p "Press enter to continue..." discard
    exit 1
fi


## GATHER REQUIRED INFORMATION FROM THE USER

LogMessage "Asking user if beast-splitter should be enabled"
if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
            --title "Enable Beast Splitter" \
            --defaultno \
            --yesno "By default Beast Splitter is disabled. Would you like to enable Beast Splitter now?" 8 65; then
    enable_beastsplitter="true"
else
    enable_beastsplitter="false"
fi

LogMessage "Asking user for the beast-splitter input option"
input_options=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                         --title "Input Options for Beast Splitter" \
                         --inputbox "Enter the option telling Beast Splitter where to read data from. You should provide one of the following either --net or --serial.\n\nExamples:\n--serial /dev/beast\n--net remotehost:remoteport" \
                         8 78)
if [[ $input_options == 0 ]]; then
    LogAlertHeading "INSTALLATION HALTED"
    LogAlertMessage "Setup has been halted due to lack of required information"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "beast-splitter setup halted"
    exit 1
fi

LogMessage "Asking user for the beast-splitter output option"
output_options=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                          --title "Output Options for Beast Splitter" \
                          --nocancel --inputbox "Enter the option to tell Beast Splitter where to send output data. You can do so by establishing an outgoing connection or accepting inbound connections.\\Examples:\n--connect remotehost:remoteport\n --listen remotehost:remoteport" \
                          8 78)
if [[ $output_options == 0 ]]; then
    LogAlertHeading "INSTALLATION HALTED"
    LogAlertMessage "Setup has been halted due to lack of required information"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "beast-splitter setup halted"
    exit 1
fi



## CHECK FOR PREREQUISITE PACKAGES

LogHeading "Installing packages needed to fulfill beast-splitter dependencies"

CheckPackage build-essential
CheckPackage debhelper
CheckPackage libboost-system-dev
CheckPackage libboost-program-options-dev
CheckPackage libboost-regex-dev


## CLONE OR PULL THE FLIGHTAWARE DUMP978 DECODER SOURCE

LogHeading "Preparing the FlightAware Dump978 Git repository"

if [[ -d $RECEIVER_BUILD_DIRECTORY/beast-splitter/beast-splitter && -d $RECEIVER_BUILD_DIRECTORY/beast-splitter/beast-splitter/.git ]]; then
    LogMessage "Entering the beast-splitter git repository directory"
    cd $RECEIVER_BUILD_DIRECTORY/beast-splitter/beast-splitter
    LogMessage "Pulling the beast-splitter git repository"
    echo ""
    git pull 2>&1 | tee -a $RECEIVER_LOG_FILE
else
    LogMessage "Creating the beast-splitter build directory"
    echo ""
    mkdir -v $RECEIVER_BUILD_DIRECTORY/beast-splitter 2>&1 | tee -a $RECEIVER_LOG_FILE
    echo ""
    LogMessage "Entering the beast-splitter build directory"
    cd $RECEIVER_BUILD_DIRECTORY/beast-splitter
    LogMessage "Cloning the FlightAware dump978 git repository"
    echo ""
    git clone https://github.com/flightaware/beast-splitter.git 2>&1 | tee -a $RECEIVER_LOG_FILE
fi


## BUILD AND INSTALL THE BEAST-SPLITTER PACKAGE

LogHeading "Building the beast-splitter package"

LogMessage "Entering the beast-splitter Git repository"
cd $RECEIVER_BUILD_DIRECTORY/beast-splitter/beast-splitter

LogMessage "Building the beast-splitter package"
echo ""
dpkg-buildpackage -b 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""

LogMessage "Installing the beast-splitter Debian package"
sudo dpkg -i $RECEIVER_BUILD_DIRECTORY/beast-splitter/beast-splitter_*.deb 2>&1 | tee -a $RECEIVER_LOG_FILE

LogMessage "Checking that the beast-splitter Debian package was installed"
if [[ $(dpkg-query -W -f='${STATUS}' beast-splitter 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
    echo ""
    LogAlertHeading "INSTALLATION HALTED"
    echo ""
    LogAlertMessage "The beast-splitter Debian package failed to install"
    LogAlertMessage "Setup has been terminated"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "beast-splitter setup halted"
    echo ""
    read -p "Press enter to continue..." discard
    exit 1
fi

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/package-archive ]]; then
    LogMessage "Creating the Debian package archive directory"
    echo ""
    mkdir -v $RECEIVER_BUILD_DIRECTORY/package-archive 2>&1 | tee -a $RECEIVER_LOG_FILE
    echo ""
fi
LogMessage "Copying the beast-splitter Debian package into the Debian package archive directory"
echo ""
cp -vf $RECEIVER_BUILD_DIRECTORY/beast-splitter/*.deb $RECEIVER_BUILD_DIRECTORY/package-archive/ 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""


## CONFIGURATION

LogHeading "Configuring beast-splitter"

LogMessage "Setting ENABLED to ${enable_beastsplitter}"
ChangeConfig "ENABLED" "${enable_beastsplitter}" "/etc/default/beast-splitter"
LogMessage "Setting INPUT_OPTIONS to ${input_options}"
ChangeConfig "INPUT_OPTIONS" "${input_options}" "/etc/default/beast-splitter"
LogMessage "Setting OUTPUT_OPTIONS to ${output_options}"
ChangeConfig "OUTPUT_OPTIONS" "${output_options}" "/etc/default/beast-splitter"

if [[ "${enable_beastsplitter}" == "true" ]]; then
    LogMessage "Starting the beast-splitter process"
    sudo systemctl start beast-splitter
else
    LogMessage "Making sure beast-splitter is not running"
    sudo systemctl stop beast-splitter
fi


## SETUP COMPLETE

LogMessage "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
LogTitleMessage "------------------------------------------------------------------------------"
LogTitleHeading "beast-splitter setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

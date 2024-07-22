#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
LogProjectTitle
LogTitleHeading "Setting up the Airplanes.live client"
LogTitleMessage "------------------------------------------------------------------------------"
echo ""
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "Airplanes.live Feeder Client Setup" \
              --yesno "The airplanes.live feeder client takes data from a local dump1090 instance and shares this with airplanes.live. for more information please see their website:\n\n  https://airplanes.live/how-to-feed/\n\nContinue setup by installing the airplanes.live feeder client?" \
              13 78; then
    LogAlertHeading "INSTALLATION HALTED"
    LogAlertMessage "Setup has been halted at the request of the user"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "Airplanes.live client setup halted"
    echo ""
    exit 1
fi


## DOWNLOAD AND EXECUTE THE AIRPLANES.LIVE CLIENT INSTALL SCRIPT

LogHeading "Begining the airplanes.live client installation process"

LogMessage "Informing the user of how the installation process will work"
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "Airplanes.live Client Setup" \
         --msgbox "Scripts supplied by airplanes.live will be used in order to install or upgrade this system. Interaction with the script exececuted will be required in order to complete the installation." \
         10 78

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/airplaneslive ]]; then
    LogMessage "Creating the airplanes.live build directory"
    echo ""
    mkdir -v $RECEIVER_BUILD_DIRECTORY/airplaneslive 2>&1 | tee -a $RECEIVER_LOG_FILE
    echo ""
fi
LogMessage "Entering the airplanes.live build directory"
cd $RECEIVER_BUILD_DIRECTORY/airplaneslive

LogMessage "Downloading the airplanes.live client installation script"
echo ""
wget -v -O $RECEIVER_BUILD_DIRECTORY/airplaneslive/install.sh https://raw.githubusercontent.com/airplanes-live/feed/main/install.sh 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""

LogMessage "Executing the airplanes.live client installation script"
echo ""
sudo bash $RECEIVER_BUILD_DIRECTORY/airplaneslive/install.sh
echo ""


## CHECK THE STATUS OF THE CLIENT

LogHeading "Checking if the reciver is now feeding airplanes.live"

LogMessage "Checking for connections on ports 30004 and 31090 to IP address 78.46.234.18"
netstat_output = `netstat -t -n | grep -E '30004|31090'`
if [[ $netstat_output == *"78.46.234.18:30004 ESTABLISHED"* && $netstat_output == *"78.46.234.18:31090 ESTABLISHED"* ]]
    LogMessage "This device appears to be connected to  airplanes.live"
else
    LogAlertMessage "The receiver does not appear to be feeding airplanes.live at this time...\e[97m"
    LogAlertMessage "Please reboot your device and run the command 'netstat -t -n | grep -E '30004|31090' to see if a connection has been astablished."
    LogAlertMessage "If the issue presists supply the last 20 lines given by the following command on the airplanes.live discord."
    LogAlertMessage "  'sudo journalctl -u airplanes-feed --no-pager'"
    LogAlertMessage "  'sudo journalctl -u airplanes-mlat --no-pager'"
fi


## INSTALL THE AIRPLANES.LIVE WEB INTERFACE

LogHeading "Starting the airplanes.live web interface setup process"

LogMessage "Asking if the user wishes to install the ADS-B Exchange web interface"
if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
            --title "Airplanes.live Web Interface Setup" \
            --yesno "Airplanes.live offers the option to install an additional web interface.\n\nWould you like to install the web interface now?" \
            12 78; then
    echo ""
    LogMessage "Executing the airplanes.live web interface installation script"
    echo ""
    sudo bash sudo bash /usr/local/share/airplanes/git/install-or-update-interface.sh
else
    LogMessage "The user opted out of installing the airplanes.live web interface"
fi


## POST INSTALLATION OPERATIONS

whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "Airplanes.live Client Setup Complete" \
         --msgbox "Setup of the airplanes.live client is now complete. You can check your feeder status at https://airplanes.live/myfeed." \
         12 78


## SETUP COMPLETE

LogMessage "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
LogTitleMessage "------------------------------------------------------------------------------"
LogTitleHeading "Airplanes.live client setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

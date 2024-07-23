#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
LogProjectTitle
LogTitleHeading "Setting up the FlightRadar24 client"
LogTitleMessage "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "FlightRadar24 feeder client Setup" \
              --yesno "The FlightRadar24 feeder client takes data from a local dump1090 instance and shares this with FlightRadar24 using the fr24feed package, for more information please see their website:\n\n  https://www.flightradar24.com/share-your-data\n\nContinue setup by installing the FlightRadar24 feeder client?" \
              13 78; then
    echo ""
    LogAlertHeading "INSTALLATION HALTED"
    LogAlertMessage "Setup has been halted at the request of the user"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "FlightRadar24 client setup halted"
    echo ""
    exit 1
fi


## DOWNLOAD AND EXECUTE THE FLIGHTRADAR24 CLIENT INSTALL SCRIPT

LogHeading "Begining the FlightRadar24 client installation process"

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/flightradar24 ]]; then
    LogMessage "Creating the FlightRadar24 build directory"
    echo ""
    mkdir -v $RECEIVER_BUILD_DIRECTORY/flightradar24 2>&1 | tee -a $RECEIVER_LOG_FILE
    echo ""
fi
LogMessage "Entering the FlightRadar24 build directory"
cd $RECEIVER_BUILD_DIRECTORY/flightradar24

LogMessage "Downloading the airplanes.live client installation script"
echo ""
wget -v -O $RECEIVER_BUILD_DIRECTORY/flightradar24/install.sh https://fr24.com/install.sh 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""

LogMessage "Executing the airplanes.live client installation script"
echo ""
sudo bash $RECEIVER_BUILD_DIRECTORY/flightradar24/install.sh
echo ""


## CHECK THE STATUS OF THE CLIENT

LogHeading "Checking if the FlightRadar24 client was installed successfully"

echo -e "\e[94m  Checking that the FlightRadar24 client package was installed"
if [[ $(dpkg-query -W -f='${STATUS}' fr24feed 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
    echo ""
    LogAlertHeading "INSTALLATION HALTED"
    echo ""
    LogAlertMessage "FlightRadar24 package installation failed"
    LogAlertMessage "Setup has been terminated"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "FlightRadar24 client setup failed"
    echo ""
    read -p "Press enter to continue..." discard
    exit 1
fi


## POST INSTALLATION OPERATIONS

LogHeading "Performing post installation operations"

LogMessage "Flightradar24 asks that MLAT be disabled if sharing with other networks"
ChangeConfig "mlat" "no" "/etc/fr24feed.ini"
ChangeConfig "mlat-without-gps" "no" "/etc/fr24feed.ini"
LogMessage "Restarting the Flightradar24 client"
sudo systemctl restart fr24feed

LogWarningMessage "If the Flightradar24 client is the only feeder utilizing MLAT execute the following commands to enable MLAT"
LogWarningMessage 'sudo sed -i -e "s/\(mlat *= *\).*/\1\"yes\"/" /etc/fr24feed.ini'
LogWarningMessage 'sudo sed -i -e "s/\(mlat-without-gps *= *\).*/\1\"yes\"/" /etc/fr24feed.ini'


## SETUP COMPLETE

LogMessage "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
LogTitleMessage "------------------------------------------------------------------------------"
LogTitleHeading "FlightRadar24 client setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

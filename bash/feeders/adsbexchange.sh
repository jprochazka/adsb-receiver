#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
LogProjectName ${RECEIVER_PROJECT_TITLE}
LogTitleHeading "Setting up the ADS-B Exchange client"
LogTitleMessage "------------------------------------------------------------------------------"
echo ""
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "ADS-B Exchange Feed Setup" \
              --yesno "ADS-B Exchange is a co-op of ADS-B/Mode S/MLAT feeders from around the world, and the world’s largest source of unfiltered flight data.\n\n  http://www.adsbexchange.com/how-to-feed/\n\nContinue setting up the ADS-B Exchange feed?" \
              18 78; then
    LogAlertHeading "INSTALLATION HALTED"
    LogAlertMessage "Setup has been halted at the request of the user"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "ADS-B Exchange client setup halted"
    echo ""
    exit 1
fi


## DOWNLOAD AND EXECUTE THE ADS-B EXCHANGE CLIENT INSTALL SCRIPT

LogHeading "Downloading the proper ADS-B Exchange client script"

LogMessage "Informing the user of how the installation process will work"
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "ADS-B Exchange Feed Setup" \
         --msgbox "Scripts supplied by ADS-B Exchange will be used in order to install or upgrade this system. Interaction with the script exececuted will be required in order to complete the installation." \
         10 78

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/adsbexchange ]]; then
    LogMessage "Creating the ADSBExchange build directory"
    echo ""
    mkdir -vp $RECEIVER_BUILD_DIRECTORY/adsbexchange
    echo ""
fi
LogMessage "Entering the ADSBExchange build directory"
cd $RECEIVER_BUILD_DIRECTORY/adsbexchange

LogMessage "Determining whether the installation or upgrade script should be used"
action_to_perform="install"
if [[ -f /lib/systemd/system/adsbexchange-mlat.service && -f /lib/systemd/system/adsbexchange-feed.service ]]; then
    action_to_perform="upgrade"
fi

LogMessage "Downloading the ADS-B Exchange client ${action_to_perform} script"
echo ""
if [[ "${action_to_perform}" = "install" ]]; then
    wget -O $RECEIVER_BUILD_DIRECTORY/adsbexchange/feed-${action_to_perform}.sh https://www.adsbexchange.com/feed.sh
else
    wget -O $RECEIVER_BUILD_DIRECTORY/adsbexchange/feed-${action_to_perform}.sh https://www.adsbexchange.com/feed-update.sh
fi
echo ""

LogMessage "Executing the ADS-B Exchange client ${action_to_perform} script"
echo ""
sudo bash $RECEIVER_BUILD_DIRECTORY/adsbexchange/feed-${action_to_perform}.sh
echo ""


## INSTALL THE ADS-B EXCHANGE STATS PACKAGE

LogHeading "Starting the ADS-B Exchange stats package setup process"

LogMessage "Asking if the user wishes to install the ADS-B Exchange stats package"
if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
            --title "ADS-B Exchange Feed Setup" \
            --yesno "ADS-B Exchange offers the option to install their stats package in order to send your stats to their site.\n\nWould you like to install the stats package now?" \
            12 78; then
    LogMessage "Downloading the ADS-B Exchange stats package installation script"
    echo ""
    curl -L -o $RECEIVER_BUILD_DIRECTORY/adsbexchange/axstats.sh https://adsbexchange.com/stats.sh
    echo ""
    echo -e "Executing the ADS-B Exchange stats package installation script"
    echo ""
    sudo bash $RECEIVER_BUILD_DIRECTORY/adsbexchange/axstats.sh
    echo ""
else
    LogMessage "The user opted out of installing the ADS-B Exchange stats package"
fi


## INSTALL THE ADS-B EXCHANGE WEB INTERFACE

LogHeading "Starting the ADS-B Exchange web interface setup process"

LogMessage "Asking if the user wishes to install the ADS-B Exchange web interface"
if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
            --title "ADS-B Exchange Feed Setup" \
            --yesno "ADS-B Exchange offers the option to install an additional web interface.\n\nWould you like to install the web interface now?" \
            12 78; then
    echo -e "Executing the ADS-B Exchange web interface installation script"
    echo ""
    sudo bash /usr/local/share/adsbexchange/git/install-or-update-interface.sh
    echo ""
else
    LogMessage "The user opted out of installing the ADS-B Exchange web interface"
fi


## SETUP COMPLETE

LogMessage "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
LogTitleMessage "------------------------------------------------------------------------------"
LogTitleHeading "ADS-B Exchange client client setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

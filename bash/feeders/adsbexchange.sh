#!/bin/bash

### INCLUDE EXTERNAL SCRIPTS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh


## BEGIN SETUP

clear
echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
echo -e ""
echo -e "\e[92m  Setting up the ADS-B Exchange feed..."
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""
if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "ADS-B Exchange Feed Setup" --yesno "ADS-B Exchange is a co-op of ADS-B/Mode S/MLAT feeders from around the world, and the world’s largest source of unfiltered flight data.\n\n  http://www.adsbexchange.com/how-to-feed/\n\nContinue setting up the ADS-B Exchange feed?" 18 78 3>&1 1>&2 2>&3); then
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo -e ""
    echo -e "\e[93m  ------------------------------------------------------------------------------"
    echo -e "\e[92m  ADS-B Exchange feed setup halted.\e[39m"
    echo -e ""
    read -p "Press enter to continue..." discard
    exit 1
fi


## DOWNLOAD AND EXECUTE THE INSTALL SCRIPT

# Explain the process
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "ADS-B Exchange Feed Setup" --msgbox "Scripts supplied by ADS-B Exchange will be used in order to install or upgrade this system. Interaction with the script exececuted will be required in order to complete the installation." 10 78

echo -e "\e[95m  Preparing to execute either the install or upgrade script...\e[97m"
echo ""

# Create the build directory if needed then enter it
if [[ ! -d $RECEIVER_BUILD_DIRECTORY/adsbexchange ]]; then
    echo -e "\e[94m  Creating the ADSBExchange build directory...\e[97m"
    mkdir $RECEIVER_BUILD_DIRECTORY/adsbexchange
fi
echo -e "\e[94m  Entering the ADSBExchange build directory...\e[97m"
cd $RECEIVER_BUILD_DIRECTORY/adsbexchange

# Determine if the feeder is already installed or not
action_to_perform="install"
if [[ -f /lib/systemd/system/adsbexchange-mlat.service && -f /lib/systemd/system/adsbexchange-feed.service ]]; then
    action_to_perform="upgrade"
fi

# Begin the install or upgrade process
echo -e "\e[94m  Downloading the ${action_to_perform} script...\e[97m"
echo ""
if [[ "${action_to_perform}" = "install" ]]; then
    wget -O $RECEIVER_BUILD_DIRECTORY/adsbexchange/feed-${action_to_perform}.sh https://www.adsbexchange.com/feed.sh
else
    wget -O $RECEIVER_BUILD_DIRECTORY/adsbexchange/feed-${action_to_perform}.sh https://www.adsbexchange.com/feed-update.sh
fi

echo -e "\e[94m  Making the ${action_to_perform} script executable...\e[97m"
chmod -x $RECEIVER_BUILD_DIRECTORY/adsbexchange/feed-${action_to_perform}.sh
echo -e "\e[94m  Executing the ${action_to_perform} script...\e[97m"
echo ""
sudo bash $RECEIVER_BUILD_DIRECTORY/adsbexchange/feed-${action_to_perform}.sh
echo ""


## INSTALL THE ADS-B EXCHANGE STATS PACKAGE

if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "ADS-B Exchange Feed Setup" --yesno "ADS-B Exchange offers the option to install their stats package in order to send your stats to their site.\n\nWould you like to install the stats package now?" 12 78; then
    echo -e "\e[95m  Executing the ADS-B Exchange script to install their web interface...\e[97m"
    echo ""
    echo -e "\e[94m  Downloading the stats package installation script...\e[97m"
    echo ""
    curl -L -o $RECEIVER_BUILD_DIRECTORY/adsbexchange/axstats.sh https://adsbexchange.com/stats.sh
    echo ""
    echo -e "\e[94m  Executing the stats package installation script...\e[97m"
    echo ""
    sudo bash $RECEIVER_BUILD_DIRECTORY/adsbexchange/axstats.sh
    echo ""
fi


## INSTALL THE ADS-B EXCHANGE WEB INTERFACE

if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "ADS-B Exchange Feed Setup" --yesno "ADS-B Exchange offers the option to install an additional web interface.\n\nWould you like to install the web interface now?" 12 78; then
    echo -e "\e[95m  Executing the ADS-B Exchange script to install their web interface...\e[97m"
    echo ""
    echo -e "\e[94m  Executing the ADS-B Exchange web interface installation script...\e[97m"
    echo ""
    sudo bash /usr/local/share/adsbexchange/git/install-or-update-interface.sh
    echo ""
fi


## ADS-B EXCHANGE FEED SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
echo -e "\e[92m  ADS-B Exchange feed setup is complete.\e[39m"
echo ""
read -p "Press enter to continue..." discard

exit 0

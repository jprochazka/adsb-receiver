#!/bin/bash

## INCLUDE EXTERNAL SCRIPTS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh


## BEGIN SETUP

clear
echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
echo -e ""
echo -e "\e[92m  Setting up the airplanes.live feeder client..."
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""


# Confirm component installation.
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Airplanes.live Feeder Client Setup" --yesno "The airplanes.live feeder client takes data from a local dump1090 instance and shares this with airplanes.live. for more information please see their website:\n\n  https://airplanes.live/how-to-feed/\n\nContinue setup by installing the airplanes.live feeder client?" 13 78 3>&1 1>&2 2>&3; then
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo -e ""
    echo -e "\e[93m  ------------------------------------------------------------------------------"
    echo -e "\e[92m  Airplanes.live feeder client setup halted.\e[39m"
    echo -e ""
    read -p "Press enter to continue..." discard
    exit 1
fi


## START FEEDER INSTALLATION

echo -e ""
echo -e "\e[95m  Begining the airplanes.live feeder client installation process...\e[97m"
echo -e ""

# Create the component build directory if it does not exist
if [[ ! -d $RECEIVER_BUILD_DIRECTORY/airplaneslive ]]; then
    echo -e "\e[94m  Creating the airplanes.live feeder client build directory...\e[97m"
    echo ""
    mkdir -vp $RECEIVER_BUILD_DIRECTORY/airplaneslive
    echo ""
fi

# Change to the component build directory
echo -e "\e[94m  Entering the airplanes.live feeder client build directory...\e[97m"
cd $RECEIVER_BUILD_DIRECTORY/airplaneslive 2>&1
echo ""

# Download the official airplanes.live feeder installation script
echo -e "\e[95m  Beginning the airplanes.live feeder client installation...\e[97m"
echo -e ""

echo -e "\e[94m  Downloading the airplanes.live feeder client installation script...\e[97m"
echo ""
wget -v https://raw.githubusercontent.com/airplanes-live/feed/main/install.sh

echo -e "\e[94m  Executing the airplanes.live feeder client installation script...\e[97m"
echo ""
sudo bash $RECEIVER_BUILD_DIRECTORY/airplaneslive/install.sh
echo ""


## CHECK THE STATUS OF THE FEEDER

echo -e "\e[95m  Checking if the reciver is now feeding airplanes.live...\e[97m"
echo -e ""
"\e[95m  Checking for connections on ports 30004 and 31090 to IP address 78.46.234.18...\e[97m"
netstat_output = `netstat -t -n | grep -E '30004|31090'`
if [[ $netstat_output == *"78.46.234.18:30004 ESTABLISHED"* && $netstat_output == *"78.46.234.18:31090 ESTABLISHED"* ]]
    "\e[95m  The receiver appears to be feeding airplanes.live...\e[97m"
else
    "\e[91m  The receiver does not appear to be feeding airplanes.live at this time...\e[97m"
    "\e[95m  Please reboot your device and run the command ''netstat -t -n | grep -E '30004|31090' to see if a connection has been astablished.\e[97m"
    "\e[95m  If the issue presists supply the last 20 lines given by the following command on the airplanes.live discord.\e[97m"
    "\e[95m  'sudo journalctl -u airplanes-feed --no-pager'\e[97m"
    "\e[95m  'sudo journalctl -u airplanes-mlat --no-pager'\e[97m"
fi
echo ""


## INSTALL THE AIRPLANES.LIVE WEB INTERFACE

if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Airplanes.live Web Interface Setup" --yesno "Airplanes.live offers the option to install an additional web interface.\n\nWould you like to install the web interface now?" 12 78; then
    echo -e "\e[95m  Begining the airplanes.live web interface installation...\e[97m"
    echo ""
    echo -e "\e[94m  Executing the airplanes.live  web interface installation script...\e[97m"
    echo ""
    sudo bash sudo bash /usr/local/share/airplanes/git/install-or-update-interface.sh
    echo ""
fi


## POST INSTALLATION INFORMATION

whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Airplanes.live Feeder Setup Complete" --msgbox "Setup of the airplanes.live feeder client is now complete. You can check your feeder status at https://airplanes.live/myfeed." 12 78


## SETUP COMPLETE

# Return to the project root directory
echo -e "\e[94m  Returning to ${RECEIVER_PROJECT_TITLE} root directory...\e[97m"
cd $RECEIVER_ROOT_DIRECTORY 2>&1

echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  Airplanes.live feeder client setup is complete.\e[39m"
echo -e ""
read -p "Press enter to continue..." discard

exit 0

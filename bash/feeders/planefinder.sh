#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
log_project_title
log_title_heading "Setting up the PlaneFinder client"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "PlaneFinder ADS-B Client Setup" \
              --yesno "The PlaneFinder ADS-B Client is an easy and accurate way to share your ADS-B and MLAT data with Plane Finder. It comes with a beautiful user interface that helps you explore and interact with your data in realtime.\n\n  https://planefinder.net/sharing/client\n\nContinue setup by installing PlaneFinder ADS-B Client?" \
              13 78; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "PlaneFinder client setup halted"
    echo ""
    exit 1
fi


## CHECK FOR PREREQUISITE PACKAGES

log_heading "Installing packages needed to fulfill PlaneFinder client dependencies"

check_package wget

case "${RECIEVER_CPU_ARCHITECTURE}" in
    "aarch64")
        sudo dpkg --add-architecture armhf
        check_package libc6:armhf
        ;;
esac


## DOWNLOAD AND INSTALL THE PROPER PLANEFINDER CLIENT DEBIAN PACKAGE


log_heading "Begining the PlaneFinder client installation process"


log_message "Determining which Debian package to install"
case "${RECIEVER_CPU_ARCHITECTURE}" in
    "armv7l"|"armv6l")
        package_name="pfclient_${PLANEFINDER_CLIENT_VERSION_ARMHF}_armhf.deb"
        ;;
    "aarch64")
        package_name="pfclient_${PLANEFINDER_CLIENT_VERSION_ARM64}_armhf.deb"
        ;;
    "x86_64")
        package_name="pfclient_${PLANEFINDER_CLIENT_VERSION_AMD64}_amd64.deb"
        ;;
    "i386")
        package_name="pfclient_${PLANEFINDER_CLIENT_VERSION_I386}_i386.deb"
        ;;
    *)
        echo ""
        log_alert_heading "INSTALLATION HALTED"
        echo ""
        log_alert_message "Unsupported CPU Archetecture"
        log_alert_message "Archetecture Detected: ${CPU_ARCHITECTURE}"
        log_alert_message "Setup has been terminated"
        echo ""
        log_title_message "------------------------------------------------------------------------------"
        log_title_heading "PlaneFinder client setup failed"
        echo ""
        read -p "Press enter to continue..." discard
        exit 1
        ;;
esac

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/planefinder ]]; then
    log_message "Creating the PlaneFinder build directory"
    echo ""
    mkdir -vp $RECEIVER_BUILD_DIRECTORY/planefinder
    echo ""
fi
log_message "Entering the PlaneFinder build directory"
cd $RECEIVER_BUILD_DIRECTORY/planefinder

log_message "Downloading the appropriate PlaneFinder client Debian package"
echo ""
wget -v -O $RECEIVER_BUILD_DIRECTORY/planefinder/$package_name http://client.planefinder.net/$package_name 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""

log_message "Installing the PlaneFinder Client Debian package"
echo -e ""
sudo dpkg -i $RECEIVER_BUILD_DIRECTORY/planefinder/$package_name 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""

if [[ ! -d $RECEIVER_BUILD_DIRECTORY/package-archive ]]; then
    log_message "Creating the package archive directory"
    echo ""
    mkdir -v $RECEIVER_BUILD_DIRECTORY/package-archive 2>&1 | tee -a $RECEIVER_LOG_FILE
    echo ""
fi
log_message "Copying the PlaneFinder client Debian package into the archive directory"
echo ""
cp -vf $RECEIVER_BUILD_DIRECTORY/planefinder/$package_name $RECEIVER_BUILD_DIRECTORY/package-archive/ 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""


## POST INSTALLATION OPERATIONS

log_heading "Performing post installation operations"

log_message "Displaying the message informing the user on how to complete setup"
RECEIVER_IP_ADDRESS=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "PlaneFinder ADS-B Client Setup Instructions" \
         --msgbox "At this point the PlaneFinder ADS-B Client should be installed and running; however this script is only capable of installing the PlaneFinder ADS-B Client. There are still a few steps left which you must manually do through the PlaneFinder ADS-B Client at the following URL:\n\n  http://${RECEIVER_IP_ADDRESS}:30053\n\nThe follow the instructions supplied by the PlaneFinder ADS-B Client.\n\nUse the following settings when asked for them.\n\nData Format: Beast\nTcp Address: 127.0.0.1\nTcp Port: 30005" \
         20 78


## SETUP COMPLETE

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "PlaneFinder client setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

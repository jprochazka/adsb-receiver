#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh


## BEGIN SETUP

clear
LogProjectTitle
LogTitleHeading "Setting up the FlightAware Dump1090 decoder"
LogTitleMessage "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "FlightAware Dump1090 Decoder Setup" \
              --yesno "FlightAware Dump1090 is an ADS-B, Mode S, and Mode 3A/3C demodulator and decoder that will receive and decode aircraft transponder messages received via a directly connected software defined radio, or from data provided over a network connection.\n\nWebsite: https://www.flightaware.com/\nGitHub Repository: https://github.com/flightaware/dump1090\n\nWould you like to begin the setup process now?" \
              14 78; then
echo ""
LogAlertHeading "INSTALLATION HALTED"
    LogAlertMessage "Setup has been halted at the request of the user"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "FlightAware Dump1090 decoder setup halted"
    echo ""
    exit 1
fi

## CHECK FOR PREREQUISITE PACKAGES

LogHeading "Installing packages needed to fulfill FlightAware Dump1090 decoder dependencies"

CheckPackage build-essential
CheckPackage debhelper
CheckPackage devscripts
CheckPackage fakeroot
CheckPackage libbladerf-dev
CheckPackage libhackrf-dev
CheckPackage liblimesuite-dev
CheckPackage libncurses-dev
CheckPackage librtlsdr-dev
CheckPackage libsoapysdr-dev
CheckPackage lighttpd
CheckPackage pkg-config


## BLACKLIST UNWANTED RTL-SDR MODULES

LogHeading "Blacklist unwanted RTL-SDR kernel modules."

BlacklistModules


## CLONE OR PULL THE FLIGHTAWARE DUMP1090 DECODER SOURCE

LogHeading "Preparing the FlightAware Dump1090 Git repository"

if [[ -d $RECEIVER_BUILD_DIRECTORY/dump1090-fa/dump1090 && -d $RECEIVER_BUILD_DIRECTORY/dump1090-fa/dump1090/.git ]]; then
    LogMessage "Entering the dump1090 git repository directory"
    cd $RECEIVER_BUILD_DIRECTORY/dump1090-fa/dump1090
    LogMessage "Pulling the dump1090 git repository"
    echo ""
    git pull 2>&1 | tee -a $RECEIVER_LOG_FILE
else
    LogMessage "Creating the FlightAware dump1090 Project build directory"
    echo ""
    mkdir -v $RECEIVER_BUILD_DIRECTORY/dump1090-fa 2>&1 | tee -a $RECEIVER_LOG_FILE
    echo ""
    LogMessage "Entering the FlightAware dump1090 Project build directory"
    cd $RECEIVER_BUILD_DIRECTORY/dump1090-fa
    LogMessage "Cloning the dump1090 git repository"
    echo ""
    git clone https://github.com/flightaware/dump1090.git 2>&1 | tee -a $RECEIVER_LOG_FILE
fi


## BUILD AND INSTALL THE DUMP1090-FA PACKAGE

LogHeading "Building the FlightAware dump1090-fa package"

LogMessage "Entering the dump1090 Git repository"
cd $RECEIVER_BUILD_DIRECTORY/dump1090-fa/dump1090

LogMessage "Determining which distribution to build the package tree for"
case $RECEIVER_OS_CODE_NAME in
    focal)
        distro="buster"
        ;;
    bullseye|jammy|bookworm|noble)
        distro="bullseye"
        ;;
esac
LogMessage "Preparing to build dump1090-fa for ${distro}"
echo ""
./prepare-build.sh $distro 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""
LogMessage "Entering the package-${distro} directory"
cd $RECEIVER_BUILD_DIRECTORY/dump1090-fa/dump1090/package-$distro
LogMessage "Building the dump1090-fa Debian package"
echo ""
dpkg-buildpackage -b --no-sign 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""
LogMessage "Installing the dump1090-fa Debian package"
echo ""
sudo dpkg -i $RECEIVER_BUILD_DIRECTORY/dump1090-fa/dump1090/dump1090-fa_$DUMP1090_FA_VERSION_*.deb 2>&1 | tee -a $RECEIVER_LOG_FILE
echo ""

LogMessage "Checking that the dump1090-fa Debian package was installed"
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 0 ]]; then
    echo ""
    LogAlertHeading "INSTALLATION HALTED"
    echo ""
    LogAlertMessage "The dump1090-fa Debian package failed to install"
    LogAlertMessage "Setup has been terminated"
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "FlightAware Dump1090 decoder setup halted"
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
LogMessage "Copying the dump1090-fa Debian package into the Debian package archive directory"
echo ""
cp -vf $RECEIVER_BUILD_DIRECTORY/dump1090-fa/dump1090/*.deb $RECEIVER_BUILD_DIRECTORY/package-archive/ 2>&1 | tee -a $RECEIVER_LOG_FILE


## POST INSTALLATION OPERATIONS

LogHeading "Performing post installation operations"

LogMessage "Checking if a heywhatsthat upintheair.json file exists"
if [[ ! -f "/usr/share/dump1090-fa/html/upintheair.json" ]]; then
    LogMessage "Asking the user if they want to add heywhatsthat maximum range rings"
    if (whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                 --title "Setup heywhaststhat Maximum Range Rings" \
                 --yesno "Maximum range rings can be added to the FlightAware Dump1090 map usings data obtained from heywhatsthat. In order to add these rings to your FlightAware dump1090 map you will first need to visit http://www.heywhatsthat.com and generate a new panorama centered on the location of your receiver. Once your panorama has been generated a link to the panorama will be displayed in the top left hand portion of the page. You will need the view ID which is the series of letters and  numbers after ?view= in the URL.\n\nWould you like to add heywhatsthat maximum range rings to your map?" \
                 16 78); then
        LogMessage "Asking the user for the heywhatsthat panarama ID"
        heywhatsthat_panorama_id_title="Enter the heywhatsthat Panorama ID"
        while [[ -z $heywhatsthat_panorama_id ]] ; do
            heywhatsthat_panorama_id=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                --title "${heywhatsthat_panorama_id_title}" \
                                                --inputbox "Please enter your Heywhatsthat panorama ID." \
                                                8 78 3>&1 1>&2 2>&3)
            whiptail_exit_status=$?
            if [[ $whiptail_exit_status == 0 ]]; then
                LogAlertMessage "Setup of heywhatsthat maximum range rings was cancelled"
                break
            fi
            heywhatsthat_panorama_id_title="Enter the Heywhatsthat Panorama ID [REQUIRED]"
        done
	if [[ $whiptail_exit_status != 0 ]]; then
            LogMessage "Asking the user what the altitude is for the first ring"
            heywhatsthat_ring_one_altitude_title="First heywhatsthat Ring Altitude"
            while [[ -z $heywhatsthat_ring_one_altitude ]] ; do
                heywhatsthat_ring_one_altitude=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                          --title "${heywhatsthat_ring_one_altitude_title}" \
                                                          --nocancel \
                                                          --inputbox "Enter the first ring's altitude in meters.\n(default 3048 meters or 10000 feet)" \
                                                          8 78 \
                                                          "3048" 3>&1 1>&2 2>&3)
                heywhatsthat_ring_one_altitude_title="First heywhatsthat Ring Altitude [REQUIRED]"
            done
            LogMessage "Asking the user what the altitude is for the second ring"
            heywhatsthat_ring_two_altitude_title="Second heywhatsthat Ring Altitude"
            while [[ -z $heywhatsthat_ring_two_altitude ]] ; do
                heywhatsthat_ring_two_altitude=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                          --title "${heywhatsthat_ring_two_altitude_title}" \
                                                          --nocancel \
                                                          --inputbox "Enter the second ring's altitude in meters.\n(default 12192 meters or 40000 feet)" \
                                                          8 78 \
                                                          "12192" 3>&1 1>&2 2>&3)
                heywhatsthat_ring_two_altitude_title="Second heywhatsthat Ring Altitude [REQUIRED]"
            done

            LogMessage "Downloading JSON data file assigned to panorama ID ${heywhatsthat_panorama_id}"
            echo ""
            sudo wget -v -O /usr/share/skyaware/html/upintheair.json "http://www.heywhatsthat.com/api/upintheair.json?id=${heywhatsthat_panarama_id}&refraction=0.25&alts=${heywhatsthat_ring_one_altitude},${heywhatsthat_ring_two_altitude}" 2>&1 | tee -a $RECEIVER_LOG_FILE
            echo ""
            LogMessage "Heywhatsthat configuration complete"
        fi
    else
        LogMessage "Heywhatsthat maximum range rings was skipped"
    fi
fi


## SETUP COMPLETE

LogMessage "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
LogTitleMessage "------------------------------------------------------------------------------"
LogTitleHeading "FlightAware Dump1090 decoder setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

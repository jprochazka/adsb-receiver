#!/bin/bash

#####################################################################################
#                                  ADS-B RECEIVER                                   #
#####################################################################################
#                                                                                   #
#  This script is meant only to create offical Raspbian releases for this project.  # 
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                   #
# Copyright (c) 2015-2016 Joseph A. Prochazka                                       #
#                                                                                   #
# Permission is hereby granted, free of charge, to any person obtaining a copy      #
# of this software and associated documentation files (the "Software"), to deal     #
# in the Software without restriction, including without limitation the rights      #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell         #
# copies of the Software, and to permit persons to whom the Software is             #
# furnished to do so, subject to the following conditions:                          #
#                                                                                   #
# The above copyright notice and this permission notice shall be included in all    #
# copies or substantial portions of the Software.                                   #
#                                                                                   #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR        #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,          #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE       #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER            #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,     #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE     #
# SOFTWARE.                                                                         #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


          ################################################################
          ##  THIS SCRIPT IS ONLY MEANT FOR RASPBIAN IMAGE PREPERATION  ##
          ################################################################
          #                                                              #
          # This script must be ran from the projects root directory.    #
          #                                                              #
          # pi@darkstar: ./bash/tools/image_setup.sh                     #
          #                                                              #
          ################################################################


clear

## VARIABLES

RECEIVER_ROOT_DIRECTORY="${PWD}"
RECEIVER_BASH_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/bash"
RECEIVER_BUILD_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/build"

## INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

echo -e ""
echo -e "\e[91m  The ADS-B Receiver Project Image Preparation Script\e[97m"
echo -e ""

## UPDATE REPOSITORY LISTS AND OPERATING SYSTEM

echo -e "\e[95m  Updating repository lists and operating system...\e[97m"
echo -e ""
sudo apt-get update
sudo apt-get -y dist-upgrade

## INSTALL DUMP1090

echo -e ""
echo -e "\e[95m  Installing prerequisite packages...\e[97m"
echo -e ""
CheckPackage git
CheckPackage curl
CheckPackage build-essential
CheckPackage debhelper
CheckPackage cron
CheckPackage rtl-sdr
CheckPackage librtlsdr-dev
CheckPackage libusb-1.0-0-dev
CheckPackage pkg-config
CheckPackage lighttpd
CheckPackage fakeroot

# Ask which version of dump1090 to install.
DUMP1090OPTION=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Choose Dump1090 Version" --menu "Which version of dump1090 is to be installed?" 12 65 2 "dump1090-mutability" "(Mutability)" "dump1090-fa" "(FlightAware)" 3>&1 1>&2 2>&3)

case ${DUMP1090OPTION} in
    "dump1090-mutability")
        echo -e "\e[95m  Installing dump1090-mutability...\e[97m"
        echo -e ""

        # Dump1090-mutability
        echo -e ""
        echo -e "\e[95m  Installing dump1090-mutability...\e[97m"
        echo -e ""
        mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/dump1090-mutability
        cd ${RECEIVER_BUILD_DIRECTORY}/dump1090-mutability
        git clone https://github.com/mutability/dump1090.git
        cd ${RECEIVER_BUILD_DIRECTORY}/dump1090-mutability/dump1090
        dpkg-buildpackage -b
        cd ${RECEIVER_BUILD_DIRECTORY}/dump1090-mutability
        sudo dpkg -i dump1090-mutability_1.15~dev_*.deb
        ;;
    "dump1090-fa")
        echo -e "\e[95m  Installing dump1090-fa and PiAware...\e[97m"
        echo -e ""

        # Install prerequisite packages.
        echo -e "\e[95m  Installing additional dump1090-fa and PiAware prerequisite packages...\e[97m"
        echo -e ""
        CheckPackage tcl8.6-dev
        CheckPackage autoconf
        CheckPackage python3-dev
        CheckPackage python3-venv
        CheckPackage virtualenv
        CheckPackage dh-systemd
        CheckPackage zlib1g-dev
        CheckPackage tclx8.4
        CheckPackage tcllib
        CheckPackage tcl-tls
        CheckPackage itcl3

        # Dump1090-fa
        echo -e ""
        echo -e "\e[95m  Installing dump1090-fa...\e[97m"
        echo -e ""
        mkdir -vp ${RECEIVER_BUILD_DIRECTORY}/dump1090-fa
        cd ${RECEIVER_BUILD_DIRECTORY}/dump1090-fa
        git clone https://github.com/flightaware/dump1090.git
        cd ${RECEIVER_BUILD_DIRECTORY}/dump1090-fa/dump1090
        dpkg-buildpackage -b
        cd ${RECEIVER_BUILD_DIRECTORY}/dump1090-fa
        sudo dpkg -i dump1090-fa_*.deb

        # PiAware
        cd ${RECEIVER_BUILD_DIRECTORY}
        git clone https://github.com/flightaware/piaware_builder.git
        cd ${RECEIVER_BUILD_DIRECTORY}/piaware_builder
        ./sensible-build.sh jessie
        cd ${RECEIVER_BUILD_DIRECTORY}/piaware_builder/package-jessie
        dpkg-buildpackage -b
        sudo dpkg -i ${RECEIVER_BUILD_DIRECTORY}/piaware_builder/piaware_*.deb
        ;;
    *)
        # Nothing selected.
        exit 1
        ;;
esac

## INSTALL THE BASE PORTAL PREREQUISITES PACKAGES

echo -e ""
echo -e "\e[95m  Installing packages needed by the ADS-B Receiver Project Web Portal...\e[97m"
echo -e ""
CheckPackage lighttpd
CheckPackage collectd-core
CheckPackage rrdtool
CheckPackage libpython2.7
CheckPackage php5-cgi
CheckPackage php5-json

## SET LOCALE

echo -e ""
echo -e "\e[95m  Setting the locale to en_US.UTF-8...\e[97m"
echo -e ""
sudo su -c "sed --regexp-extended --expression='

   1  {
         i\
# This file lists locales that you wish to have built. You can find a list\
# of valid supported locales at /usr/share/i18n/SUPPORTED, and you can add\
# user defined locales to /usr/local/share/i18n/SUPPORTED. If you change\
# this file, you need to rerun locale-gen.\
\


      }

   /^(en_US+)?(\.UTF-8)?(@[^[:space:]]+)?[[:space:]]+UTF-8$/!   s/^/# /

' /usr/share/i18n/SUPPORTED > /etc/locale.gen"

sudo debconf-set-selections <<< 'locales locales/default_environment_locale select en_US.UTF-8'
sudo rm -f /etc/default/locale
sudo dpkg-reconfigure --frontend=noninteractive locales

sudo update-locale LC_NUMERIC='en_US.UTF-8'
sudo update-locale LC_TIME='en_US.UTF-8'
sudo update-locale LC_MONETARY='en_US.UTF-8'
sudo update-locale LC_PAPER='en_US.UTF-8'
sudo update-locale LC_NAME='en_US.UTF-8'
sudo update-locale LC_ADDRESS='en_US.UTF-8'
sudo update-locale LC_TELEPHONE='en_US.UTF-8'
sudo update-locale LC_MEASUREMENT='en_US.UTF-8'
sudo update-locale LC_IDENTIFICATION='en_US.UTF-8'

#sudo update-locale LANGUAGE='en_US'
#sudo locale-gen en_US.UTF-8

## CHANGE THE KEYBOARD LAYOUT

echo -e ""
echo -e "\e[95m  Changing the default keyboard layout to US/PC105...\e[97m"
ChangeConfig "XKBMODEL" "pc105" "/etc/default/keyboard"
ChangeConfig "XKBLAYOUT" "us" "/etc/default/keyboard"
ChangeConfig "XKBVARIANT" "" "/etc/default/keyboard"
ChangeConfig "XKBOPTIONS" "" "/etc/default/keyboard"
ChangeConfig "BACKSPACE" "guess" "/etc/default/keyboard"

sudo setupcon

## SET TIMEZONE

echo -e "\e[95m  Setting the timezone to America/New_York...\e[97m"
AREA="America"
ZONE="New_York"

ZONEINFO_FILE='/usr/share/zoneinfo/'"${AREA}"'/'"${ZONE}"
sudo ln --force --symbolic "${ZONEINFO_FILE}" '/etc/localtime'
sudo dpkg-reconfigure --frontend=noninteractive tzdata

## CHANGE THE PASSWORD FOR THE USER PI

echo "pi:adsbreceiver" | sudo chpasswd

## CLEAN UP THE SYSTEM TO MAKE THE IMAGE SMALLER

echo -e "\e[95m  Removing packages which are no longer needed...\e[97m"
echo -e ""
sudo apt-get -y clean
sudo apt-get -y autoclean
sudo apt-get -y autoremove
echo -e ""

## TOUCH THE IMAGE FILE

echo -e "\e[95m  Touching the \"image\" file...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY}
touch image

## CLEAR BASH HISTORY

history -c && history -w

## DONE

echo -e ""
echo -e "\e[91m  Image preparation completed.)\e[39m"
echo -e "\e[91m  Device will be shut down in 5 seconds.\e[39m"
echo -e ""

sleep 5
sudo halt

exit 0

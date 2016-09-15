#!/bin/bash

#####################################################################################
#                                  ADS-B RECEIVER                                   #
#####################################################################################
#                                                                                   #
#  A set of scripts created to automate the process of installing the software      #
#  needed to setup a Mode S decoder as well as feeders which are capable of         #
#  sharing your ADS-B results with many of the most popular ADS-B aggregate sites.  #
#                                                                                   #
#  Project Hosted On GitHub: https://github.com/jprochazka/adsb-feeder              #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                   #
# Copyright (c) 2015 Joseph A. Prochazka                                            #
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
          # This script must be ran using sudo.                          #
          #                                                              #
          # pi@darkstar: sudo ./bash/tools/image_setup.sh                #
          #                                                              #
          ################################################################


## CHECK IF SCRIPT WAS RAN USING SUDO

if [ "$(id -u)" != "0" ]; then
    echo -e "\033[33m"
    echo "This script must be ran using sudo or as root."
    echo -e "\033[37m"
    exit 1
fi

## VARIABLES

PROJECTROOTDIRECTORY="$PWD"
BASHDIRECTORY="$PROJECTROOTDIRECTORY/bash"
BUILDDIRECTORY="$PROJECTROOTDIRECTORY/build"

## INCLUDE EXTERNAL SCRIPTS

source $BASHDIRECTORY/variables.sh
source $BASHDIRECTORY/functions.sh

echo ""
echo -e "\e[91m  The ADS-B Receiver Project Image Preparation Script\e[97m"
echo ""

## UPDATE REPOSITORY LISTS AND OPERATING SYSTEM

echo -e "\e[95m  Updating repository lists and operating system...\e[97m"
echo ""
sudo apt-get update
sudo apt-get -y dist-upgrade

## INSTALL DUMP1090-MUTABILITY

echo -e "\e[95m  Installing dump1090-mutability...\e[97m"
echo ""
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
echo ""

cd $BUILDDIRECTORY
git clone https://github.com/mutability/dump1090.git
cd $BUILDDIRECTORY/dump1090
dpkg-buildpackage -b
cd $BUILDDIRECTORY
sudo dpkg -i dump1090-mutability_1.15~dev_*.deb

## INSTALL THE BASE PORTAL PREREQUISITES PACKAGES

echo ""
echo -e "\e[95m  Installing packages needed by the ADS-B Receiver Project Web Portal...\e[97m"
echo ""
CheckPackage lighttpd
CheckPackage collectd-core
CheckPackage rrdtool
CheckPackage libpython2.7
CheckPackage php5-cgi
CheckPackage php5-json

## SET LOCALE

echo ""
echo -e "\e[95m  Setting the locale to en_US.UTF-8...\e[97m"
echo ""
sudo sed --regexp-extended --expression='

   1  {
         i\
# This file lists locales that you wish to have built. You can find a list\
# of valid supported locales at /usr/share/i18n/SUPPORTED, and you can add\
# user defined locales to /usr/local/share/i18n/SUPPORTED. If you change\
# this file, you need to rerun locale-gen.\
\


      }

   /^(en_US+)?(\.UTF-8)?(@[^[:space:]]+)?[[:space:]]+UTF-8$/!   s/^/# /

' /usr/share/i18n/SUPPORTED >  /etc/locale.gen

sudo debconf-set-selections <<< 'locales locales/default_environment_locale select en_US.UTF-8'
sudo rm -f /etc/default/locale
sudo dpkg-reconfigure --frontend=noninteractive locales

update-locale LC_NUMERIC='en_US.UTF-8'
update-locale LC_TIME='en_US.UTF-8'
update-locale LC_MONETARY='en_US.UTF-8'
update-locale LC_PAPER='en_US.UTF-8'
update-locale LC_NAME='en_US.UTF-8'
update-locale LC_ADDRESS='en_US.UTF-8'
update-locale LC_TELEPHONE='en_US.UTF-8'
update-locale LC_MEASUREMENT='en_US.UTF-8'
update-locale LC_IDENTIFICATION='en_US.UTF-8'

#sudo update-locale LANGUAGE='en_US'
#sudo locale-gen en_US.UTF-8

## CHANGE THE KEYBOARD LAYOUT

echo ""
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

## TOUCH THE IMAGE FILE

echo -e "\e[95m  Touching the \"image\" file...\e[97m"
cd $PROJECTROOTDIRECTORY
touch image

## DONE

echo ""
echo -e "\e[91m  Image preparation completed.)\e[39m"
echo -e "\e[91m  A REBOOT IS REQUIRED! (Actually two wouldn't hurt to be safe...)\e[39m"
echo ""

exit 0

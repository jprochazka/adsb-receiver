#!/bin/bash

#####################################################################################
#                                  ADS-B RECEIVER                                   #
#####################################################################################
#                                                                                   #
# This script is not meant to be executed directly.                                 #
# Instead execute install.sh to begin the installation process.                     #
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

BUILDDIR=$PWD
DUMP1090DIR="$BUILDDIR/dump1090"

source ../bash/functions.sh

clear

echo -e "\033[31m"
echo "-------------------------------------------"
echo " Now ready to install dump1090-mutability."
echo "-------------------------------------------"
echo -e "\033[33mDump 1090 is a Mode S decoder specifically designed for RTLSDR devices."
echo "Dump1090-mutability is a fork of MalcolmRobb's version of dump1090 that adds new"
echo "functionality and is designed to be built as a Debian/Raspbian package."
echo ""
echo "https://github.com/mutability/dump1090"
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

## ASK WHICH WEB SERVER TO INSTALL

echo -e "\033[31m"
echo "Select Web Server"
echo -e "\033[33m"
echo "Select the web server you wish to use."
echo "Currently Lighttpd is the recommended web server."
echo ""
echo "  1) Lighttpd"
echo "  2) Nginx"
echo -e "\033[37m"
read -p "Which web server do you wish to use? [1] " WEBSERVER

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\033[33m"
echo "Installing packages needed to build and fulfill dependencies..."
echo -e "\033[37m"
CheckPackage git
CheckPackage curl
CheckPackage build-essential
CheckPackage debhelper
CheckPackage cron
CheckPackage rtl-sdr
CheckPackage librtlsdr-dev
CheckPackage libusb-1.0-0-dev
CheckPackage pkg-config

if [[ $WEBSERVER != "2" ]]; then
    CheckPackage lighttpd
else
    CheckPackage nginx
fi

CheckPackage fakeroot

## DOWNLOAD OR UPDATE THE DUMP1090-MUTABILITY SOURCE

# Check if the git repository already exists locally.
if [ -d $DUMP1090DIR ] && [ -d $DUMP1090DIR/.git ]; then
    # A directory with a git repository containing the source code exists.
    echo -e "\033[33m"
    echo "Updating the local dump1090-mutability git repository..."
    echo -e "\033[37m"
    cd $DUMP1090DIR
    git pull origin master
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\033[33m"
    echo "Cloning the dump1090-mutability git repository locally..."
    echo -e "\033[37m"
    git clone https://github.com/mutability/dump1090.git
fi

## BUILD THE DUMP1090-MUTABILITY PACKAGE

echo -e "\033[33m"
echo "Building the dump1090-mutability package..."
echo -e "\033[37m"
cd $DUMP1090DIR
dpkg-buildpackage -b

## INSTALL THE DUMP1090-MUTABILITY PACKAGE

echo -e "\033[33m"
echo "Installing the dump1090-mutability package..."
echo -e "\033[37m"
cd $BUILDDIR
sudo dpkg -i dump1090-mutability_1.15~dev_*.deb

## CHECK THAT THE PACKAGE INSTALLED

if [ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    echo "\033[31m"
    echo "#########################################"
    echo "# INSTALLATION HALTED!                  #"
    echo "# UNABLE TO INSTALL A REQUIRED PACKAGE. #"
    echo "#########################################"
    echo ""
    echo "The dump1090-mutability package did not install properly!"
    echo -e "\033[33m"
    echo "This script has exited due to the error encountered."
    echo "Please read over the above output in order to determine what went wrong."
    echo ""
    kill -9 `ps --pid $$ -oppid=`; exit
fi

## CONFIGURE THE WEB SERVER

if [[ $WEBSERVER != "2" ]]; then
    echo -e "\033[33m"
    echo "Configuring lighttpd..."
    echo -e "\033[37m"
    sudo lighty-enable-mod dump1090
    sudo /etc/init.d/lighttpd force-reload
else
    echo -e "\033[33m"
    echo "Configuring nginx..."
    echo -e "\033[37m"
    sudo rm /etc/nginx/sites-enabled/default
    sudo ln -s /etc/nginx/sites-available/dump1090-mutability /etc/nginx/sites-enabled/dump1090-mutability
    sudo /etc/init.d/nginx force-reload
fi

## DUMP1090-MUTABILITY POST INSTALLATION CONFIGURATION

# Set latitude and longitude.
echo -e "\033[31m"
echo "SET THE LATITUDE AND LONGITUDE OF YOUR FEEDER"
echo -e "\033[33m"
echo "In order for some performance graphs to work properly you will need to"
echo "set the latitude and longitude of your feeder. If you do not know the"
echo "latitude and longitude of your feeder you can find out this information"
echo "by using Geocode by Address tool found on my web site."
echo ""
echo "  https://www.swiftbyte.com/toolbox/geocode"
echo ""
echo "NOT SETTING LATITUDE AND LONGITUDE WILL BREAK THE RANGE PERFORMANCE GRAPH"
echo ""
echo -e "\033[37m"
read -p "Feeder Latitude: (Decimal Degrees XX-XXXXXXX) " FEEDERLAT
read -p "Feeder Longitude: (Decimal Degrees XX-XXXXXXX) " FEEDERLON
echo ""
ChangeConfig "LAT" $FEEDERLAT "/etc/default/dump1090-mutability"
ChangeConfig "LON" $FEEDERLON "/etc/default/dump1090-mutability"

# Set dump190-mutability's BEAST_INPUT_PORT to 30104.
echo -e "\033[33m"
echo "Configuring dump1090-mutability to listen for BEAST input on port 30104..."
echo -e "\033[37m"
ChangeConfig "BEAST_INPUT_PORT" "30104" "/etc/default/dump1090-mutability"

# Ask if dump1090-mutability should bind on all IP addresses.

echo -e "\033[33m"
echo "By default dump1090-mutability binds to the localhost IP address of 127.0.0.1 which is a good thing."
echo ""
echo "However..."
echo "Some people like for dump1090-mutability to bind to all available IP addresses for a multitude of reasons."
echo "The scripts can bind dump190-mutability to all available IP addresses however this is not recommended"
echo "unless you understand the possible consequences of doing so."
echo -e "\033[37m"
read -p "Would you like dump1090-mutability to bind to all available IP addresses? [y/N] " BINDTOALLIPS

if [[ $BINDTOALLIPS =~ ^[yY]$ ]]; then
    ChangeConfig "NET_BIND_ADDRESS" "0.0.0.0" "/etc/default/dump1090-mutability"
fi

## HEYWHATSTHAT.COM TERRAIN LIMIT RINGS

# Check if the heywhatsthis.com range position file has already been downloaded.
if [ ! -f /usr/share/dump1090-mutability/html/upintheair.json ]; then
    echo -e "\033[33m"
    echo "Dump1090-mutability is able to display terrain limit rings using data obtained"
    echo "from the website http://www.heywhatsthat.com. Some work will be required on your"
    echo "part including visiting http://www.heywhatsthat.com and generating a new"
    echo "panorama set to your location."
    echo -e "\033[37m"
    read -p "Do you wish to add terrain limit rings to the dump1090 map? [Y/n] " ADDTERRAINRINGS

    if [[ ! $ADDTERRAINRINGS =~ ^[Nn]$ ]]; then 
        echo -e "\033[31m"
        echo "READ THE FOLLOWING INSTRUCTION CAREFULLY!"
        echo -e "\033[33m"
        echo "To set up terrain limit rings you will need to first generate a panorama on the website"
        echo "heywhatsthat.com. To do so visit the following URL:"
        echo ""
        echo "  http://www.heywhatsthat.com"
        echo ""
        echo "Once the webpage has loaded click on the tab titled New panorama. Fill out the required"
        echo "information in the form to the left of the map."
        echo ""
        echo "After submitting the form your request will be put into a queue to be generated shortly."
        echo "You will be informed when the generation of your panorama has been completed."
        echo ""
        echo "Once generated visit your newly created panorama. Near the top left of the page you will"
        echo "see a URL displayed which will point you to your newly created panorama. Within this URL's"
        echo "query string you will see ?view=XXXXXXXX where XXXXXXXX is the identifier for this panorama."
        echo "Enter below the letters and numbers making up the view identifier displayed there."
        echo ""
        echo "Positions for terrain rings for both 10,000 and 40,000 feet will be downloaded by this"
        echo "script once the panorama has been generated and you are ready to continue."
        echo -e "\033[37m"
        read -p "Your heywhatsthat.com view identifier: " HEYWHATSTHATVIEWID
        read -e -p "First ring altitude in meters (default 3048 meters or 10000 feet): " -i "3048" HEYWHATSTHATRINGONE
        read -e -p "Second ring altitude in meters (default 12192 meters or 40000 feet): " -i "12192" HEYWHATSTHATRINGTWO

        # Download the generated panoramas JSON data.
        echo -e "\033[33m"
        echo "Downloading JSON data pertaining to the panorama ID you supplied..."
        echo -e "\033[37m"
        sudo wget -O /usr/share/dump1090-mutability/html/upintheair.json "http://www.heywhatsthat.com/api/upintheair.json?id=${HEYWHATSTHATVIEWID}&refraction=0.25&alts=$HEYWHATSTHATRINGONE,$HEYWHATSTHATRINGTWO"
    fi
else
    # Heywhatsthis.com upintheair.json file already exists.
    echo -e "\033[33m"
    echo "Exisitng heywhatsthat.com position data found."
    echo -e "Skipping terrain limit ring setup...\033[37m"
fi

## START DUMP1090-MUTABILITY

echo -e "\033[33m"
echo "Startng dump1090-mutability..."
echo -e "\033[37m"
sudo /etc/init.d/dump1090-mutability start

## DISPLAY MESSAGE STATING DUMP1090-MUTABILITY SETUP IS COMPLETE

echo -e "\033[33m"
echo "Installation of dump-1090-mutability is now complete."
echo "Please look over the output generated to be sure no errors were encountered."
echo ""
echo "After setup has completed you can run the following command to configure"
echo "other dump1090-mutability options."
echo -e "\033[32m"
echo "sudo dpkg-reconfigure dump1090-mutability"
echo ""
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

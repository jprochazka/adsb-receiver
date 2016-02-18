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

source bash/functions.sh

# Set latitude and longitude in the dump1090-mutability configuration file.

echo -e "\033[31m"
echo "SET THE LATITUDE AND LONGITUDE OF YOUR FEEDER"
echo -e "\033[33m"
echo "In order for some performance graphs to work properly you will need to"
echo "set the latitude and longitude of your feeder. If you do not know the"
echo "latitude and longitude of your feeder you can find out this information"
echo "by using Geocode by Address tool found on my web site."
echo ""
echo "  https://www.swiftbyte.com/toolbox/geocode"
echo -e "\033[37m"
read -p "Feeder Latitude: " FEEDERLAT
read -p "Feeder Longitude: " FEEDERLON
echo ""
ChangeConfig "LAT" $FEEDERLAT "/etc/default/dump1090-mutability"
ChangeConfig "LON" $FEEDERLON "/etc/default/dump1090-mutability"

# Ask if dump1090-mutability should bind on all IP addresses.

echo -e "\033[33m"
echo "By default dump1090-mutability on binds to the localhost IP address of 127.0.0.1 which is a good thing."
echo ""
echo "However..."
echo "Some people like for dump1090-mutability to bind on all available IP addresses for a mutitude of reasons."
echo "The scripts can bind dump190-mutability to all available IP addresses however this is not recommended"
echo "unless you understand the possible consequences of doing so."
echo -e "\033[37m"
read -p "Would you like dump1090-mutability to bind to all available IP addresses? [y/N] " BINDTOALLIPS

if [[ $BINDTOALLIPS =~ ^[yY]$ ]]; then
    ChangeConfig "NET_BIND_ADDRESS" "0.0.0.0" "/etc/default/dump1090-mutability"
fi

# Setup Heywhatsthat.com max range circles for dump1090-mutability.

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

# Restart dump1090-mutability.

echo -e "\033[33m"
echo "Restarting dump1090-mutability..."
echo -e "\033[37m"
sudo /etc/init.d/dump1090-mutability restart

# Remove the "image" file now that setup has been ran.

rm -f image

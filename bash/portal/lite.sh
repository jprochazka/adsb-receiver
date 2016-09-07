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

## VARIABLES

PROJECTROOTDIRECTORY="$PWD"
BASHDIRECTORY="$PROJECTROOTDIRECTORY/bash"
BUILDDIRECTORY="$PROJECTROOTDIRECTORY/build"
PORTALBUILDDIRECTORY="$BUILDDIRECTORY/portal"

## INCLUDE EXTERNAL SCRIPTS

source $BASHDIRECTORY/variables.sh
source $BASHDIRECTORY/functions.sh

## BEGIN SETUP

clear
echo -e "\n\e[91m  THE ADS-B RECIEVER PROJECT VERSION $PROJECTVERSION"
echo ""
echo -e "\e[92m  Setting up the ADS-B Receiver Project Portal (Lite)..."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo ""
whiptail --title "ADS-B ADS-B Receiver Project Portal (Lite) Setup" --yesno "" 12 78
CONTINUESETUP=$?
if [ $CONTINUESETUP = 1 ]; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  ADS-B Receiver Project Portal (Lite) setup halted.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to fulfill dependencies...\e[97m"
echo ""
# Performance graph dependencies.
CheckPackage collectd-core
CheckPackage rrdtool

# Portal dependencies.
CheckPackage lighttpd
CheckPackage libpython2.7

# Check if this is Ubuntu 16.04 LTS.
# This needs optimized and made to recognize releases made after 16.04 as well.
if [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    if [ $DISTRIB_ID == "Ubuntu" ] && [ $DISTRIB_RELEASE == "16.04"  ]; then
        CheckPackage php7.0-cgi
        CheckPackage php7.0-xml
    else
        CheckPackage php5-cgi
        CheckPackage php5-json
    fi
else
    CheckPackage php5-cgi
    CheckPackage php5-json
fi

# Restart Lighttpd after installing the prerequisite packages.
echo -e "\e[94m  Restarting Lighttpd...\e[97m"
sudo /etc/init.d/lighttpd restart
echo ""

## SETUP THE PORTAL WEBSITE

echo ""
echo -e "\e[95m  Setting up the web portal...\e[97m"
echo ""

# Assign the Lighthttpd document root directory to a variable.
RAWDOCUMENTROOT=`/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root`
LIGHTTPDDOCUMENTROOT=`sed 's/.*"\(.*\)"[^"]*$/\1/' <<< $RAWDOCUMENTROOT`

# Check if there is already an existing portal installation.
PORTALINSTALLED=`-f $LIGHTTPDDOCUMENTROOT/classes/settings.class.php`

# If this is an existing installation being upgraded backup the XML data files.
if [ PORTALINSTALLED = TRUE ]; then
    echo -e "\e[94m  Backing up the file $LIGHTTPDDOCUMENTROOT/data/administrators.xml...\e[97m"
    sudo mv $LIGHTTPDDOCUMENTROOT/data/administrators.xml $LIGHTTPDDOCUMENTROOT/data/administrators.backup.xml
    echo -e "\e[94m  Backing up the file $LIGHTTPDDOCUMENTROOT/data/blogPosts.xml...\e[97m"
    sudo mv $LIGHTTPDDOCUMENTROOT/data/blogPosts.xml $LIGHTTPDDOCUMENTROOT/data/blogPosts.backup.xml
    echo -e "\e[94m  Backing up the file $LIGHTTPDDOCUMENTROOT/data/flightNotifications.xml...\e[97m"
    sudo mv $LIGHTTPDDOCUMENTROOT/data/flightNotifications.xml $LIGHTTPDDOCUMENTROOT/data/flightNotifications.backup.xml
    echo -e "\e[94m  Backing up the file $LIGHTTPDDOCUMENTROOT/data/settings.xml...\e[97m"
    sudo mv $LIGHTTPDDOCUMENTROOT/data/settings.xml $LIGHTTPDDOCUMENTROOT/data/settings.backup.xml
fi

echo -e "\e[94m  Placing portal files in Lighttpd's root directory...\e[97m"
sudo cp -R $PORTALBUILDDIRECTORY/* $LIGHTTPDDOCUMENTROOT

# If this is an existing installation being upgraded restore the original XML data files.
if [ PORTALINSTALLED = TRUE ]; then
    echo -e "\e[94m  Restoring the backup copy of the file $LIGHTTPDDOCUMENTROOT/data/administrators.xml...\e[97m"
    sudo mv $LIGHTTPDDOCUMENTROOT/data/administrators.backup.xml $LIGHTTPDDOCUMENTROOT/data/administrators.xml
    echo -e "\e[94m  Restoring the backup copy of the file $LIGHTTPDDOCUMENTROOT/data/blogPosts.xml...\e[97m"
    sudo mv $LIGHTTPDDOCUMENTROOT/data/blogPosts.backup.xml $LIGHTTPDDOCUMENTROOT/data/blogPosts.xml
    echo -e "\e[94m  Restoring the backup copy of the file $LIGHTTPDDOCUMENTROOT/data/flightNotifications.xml...\e[97m"
    sudo mv $LIGHTTPDDOCUMENTROOT/data/flightNotifications.backup.xml $LIGHTTPDDOCUMENTROOT/data/flightNotifications.xml
    echo -e "\e[94m  Restoring the backup copy of the file $LIGHTTPDDOCUMENTROOT/data/settings.xml...\e[97m"
    sudo mv $LIGHTTPDDOCUMENTROOT/data/settings.backup.xml $LIGHTTPDDOCUMENTROOT/data/settings.xml
fi

echo -e "\e[94m  Making the directory $LIGHTTPDDOCUMENTROOT/graphs/ writable...\e[97m"
sudo chmod 777 $LIGHTTPDDOCUMENTROOT/graphs/
echo -e "\e[94m  Making the directory $LIGHTTPDDOCUMENTROOT/classes/ writable...\e[97m"
sudo chmod 777 $LIGHTTPDDOCUMENTROOT/classes/
echo -e "\e[94m  Making the directory $LIGHTTPDDOCUMENTROOT/data/ writable...\e[97m"
sudo chmod 777 $LIGHTTPDDOCUMENTROOT/data/
echo -e "\e[94m  Making the files contained within the directory $LIGHTTPDDOCUMENTROOT/data/ writable...\e[97m"
sudo chmod 666 $LIGHTTPDDOCUMENTROOT/data/*

echo -e "\e[94m  Checking if dump978 was set up...\e[97m"
if ! grep -q "$BUILDDIRECTORY/dump978/dump978-maint.sh &" /etc/rc.local; then
    # Check if a heywhatsthat.com range file exists in the dump1090 HTML folder.
    echo -e "\e[94m  Checking for the file upintheair.json in the dump1090 HTML folder...\e[97m"
    if [ -f /usr/share/dump1090-mutability/html/upintheair.json ]; then
        echo -e "\e[94m  Copying the file upintheair.json from the dump1090 HTML folder to the dump978 HTML folder...\e[97m"
        sudo cp /usr/share/dump1090-mutability/html/upintheair.json $LIGHTTPDDOCUMENTROOT/dump978/
    fi
fi

echo -e "\e[94m  Removing conflicting redirect from the Lighttpd dump1090.conf file...\e[97m"
# Remove this line completely.
sudo sed -i "/$(echo '  "^/dump1090$" => "/dump1090/gmap.html"' | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g')/d" /etc/lighttpd/conf-available/89-dump1090.conf
# Remove the trailing coma from this line.
sudo sed -i "s/$(echo '"^/dump1090/$" => "/dump1090/gmap.html",' | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g')/$(echo '"^/dump1090/$" => "/dump1090/gmap.html"' | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g')/g"  /etc/lighttpd/conf-available/89-dump1090.conf

echo -e "\e[94m  Adding the Lighttpd portal configuration file...\e[97m"
sudo tee /etc/lighttpd/conf-available/89-adsb-portal.conf > /dev/null <<EOF
# Block all access to the data directory accept for local requests.
\$HTTP["remoteip"] !~ "127.0.0.1" {
    \$HTTP["url"] =~ "^/data/" {
        url.access-deny = ( "" )
    }
}
EOF

echo -e "\e[94m  Enabling the Lighttpd portal configuration file...\e[97m"
sudo ln -s /etc/lighttpd/conf-available/89-adsb-portal.conf /etc/lighttpd/conf-enabled/89-adsb-portal.conf

echo -e "\e[94m  Enabling the Lighttpd fastcgi-php module...\e[97m"
sudo lighty-enable-mod fastcgi-php

if pgrep "lighttpd" > /dev/null; then
    echo -e "\e[94m  Reloading Lighttpd...\e[97m"
    echo ""
    sudo /etc/init.d/lighttpd force-reload
else
    echo -e "\e[94m  Starting Lighttpd...\e[97m"
    echo ""
    sudo /etc/init.d/lighttpd start
fi
echo ""

## SETUP THE PERFORMANCE GRAPHS USING THE SCRIPT GRAPHS.SH

chmod +x $BASHDIRECTORY/portal/graphs.sh
$BASHDIRECTORY/portal/graphs.sh
if [ $? -ne 0 ]; then
    echo ""
    echo -e "\e[91m  THE SCRIPT GRAPHS.SH ENCOUNTERED AND ERROR"
    echo ""
    exit 1
fi

## ADS-B RECEIVER PROJECT PORTAL (LITE) SETUP COMPLETE

echo ""
echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
echo -e "\e[92m  ADS-B Receiver Project Portal (Lite) setup is complete.\e[39m"
echo ""
read -p "Press enter to continue..." CONTINUE

exit 0

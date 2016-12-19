#!/bin/bash

#####################################################################################
#                                  ADS-B RECEIVER                                   #
#####################################################################################
#                                                                                   #
#  A set of scripts created to automate the process of installing the software      #
#  needed to setup a Mode S decoder as well as feeders which are capable of         #
#  sharing your ADS-B results with many of the most popular ADS-B aggregate sites.  #
#                                                                                   #
#  Project Hosted On GitHub: https://github.com/jprochazka/adsb-receiver            #
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

## VARIABLES

PROJECTROOTDIRECTORY="$PWD"
BASHDIRECTORY="$PROJECTROOTDIRECTORY/bash"

## INCLUDE EXTERNAL SCRIPTS

source $BASHDIRECTORY/variables.sh
source $BASHDIRECTORY/functions.sh

# Assign the Lighthttpd document root directory to a variable.
RAWDOCUMENTROOT=`/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root`
DOCUMENTROOT=`sed 's/.*"\(.*\)"[^"]*$/\1/' <<< $RAWDOCUMENTROOT`

## WELCOME MESSAGE

whiptail --backtitle "$ADSB_PROJECTTITLE" --title "ADS-B Receiver Project Image Setup" --msgbox "Thank you for choosing to use the ADS-B Receiver Project image.\n\nDuring this setup process the preinstalled dump1090-mutability installation will be configured and the ADS-B Project Web Portal will be installed. If you would like to add additional features to your receiver simply execute ./install.sh again after this initial setup process has been completed." 13 78

## ASK TO UPDATE THE OPERATING SYSTEM

if (whiptail --backtitle "$ADSB_PROJECTTITLE" --title "ADS-B Receiver Project Image Setup" --yesno "The image comes with the latest updates to Raspbian as of it's release. However updates may have been released for the operating system since the image was released. This being said it is highly recommended you allow the script to check for additional updates now in order to ensure you are in fact running the latest software available.\n\nWould you like the script to check for and install updates now?" 13 78) then
    clear
    echo -e "\n\e[91m  $ADSB_PROJECTTITLE"
    echo ""
    echo -e "\e[92m  Downloading and installing the latest updates for your operating system..."
    echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[97m"
    echo ""
    sudo apt-get update
    sudo apt-get -y dist-upgrade
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  Your operating system should now be up to date.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
fi

## ASK USER TO CONFIRM RECIEVER LATITUDE AND LONGITUDE

if [ -z $RECEIVERLATITUDE ] || [ -z $RECEIVERLONGITUDE ] ; then
# Set the receivers latitude and longitude.
    whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Receiver Latitude and Longitude" --msgbox "Your receivers latitude and longitude are required for certain features to function properly. You will now be asked to supply the latitude and longitude for your receiver. If you do not have this information you get it by using the web based \"Geocode by Address\" utility hosted on another of my websites.\n\n  https://www.swiftbyte.com/toolbox/geocode" 13 78
    RECEIVERLATITUDE_TITLE="Receiver Latitude"
    while [[ -z $RECEIVERLATITUDE ]]; do
        RECEIVERLATITUDE=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$RECEIVERLATITUDE_TITLE" --nocancel --inputbox "\nEnter your receiver's latitude.\n(Example: XX.XXXXXXX)" 9 78 3>&1 1>&2 2>&3)
        RECEIVERLATITUDE_TITLE="Receiver Latitude (REQUIRED)"
    done
    RECEIVERLONGITUDE_TITLE="Receiver Longitude"
    while [[ -z $RECEIVERLONGITUDE ]]; do
        RECEIVERLONGITUDE=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$RECEIVERLONGITUDE_TITLE" --nocancel --inputbox "\nEnter your receeiver's longitude.\n(Example: XX.XXXXXXX)" 9 78 3>&1 1>&2 2>&3)
        RECEIVERLONGITUDE_TITLE="Receiver Longitude (REQUIRED)"
    done
fi

## CONFIGURE DUMP1090

clear
echo -e "\n\e[91m   $ADSB_PROJECTTITLE"
echo ""
echo -e "\e[92m  Configure dump1090..."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo ""

# If dump1090-mutability is installed...

if [ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
    echo -e "\e[94m  Setting the receiver's latitude to $RECEIVERLATITUDE...\e[97m"
    ChangeConfig "LAT" $RECEIVERLATITUDE "/etc/default/dump1090-mutability"
    echo -e "\e[94m  Setting the receiver's longitude to $RECEIVERLONGITUDE...\e[97m"
    ChangeConfig "LON" $RECEIVERLONGITUDE "/etc/default/dump1090-mutability"

    # Ask if dump1090-mutability should bind on all IP addresses.
    if (whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Bind Dump1090-mutability To All IP Addresses" --defaultno --yesno "By default dump1090-mutability is bound only to the local loopback IP address(s) for security reasons. However some people wish to make dump1090-mutability's data accessable externally by other devices. To allow this dump1090-mutability can be configured to listen on all IP addresses bound to this device. It is recommended that unless you plan to access this device from an external source that dump1090-mutability remain bound only to the local loopback IP address(s).\n\nWould you like dump1090-mutability to listen on all IP addesses?" 15 78) then
        echo -e "\e[94m  Binding dump1090-mutability to all available IP addresses...\e[97m"
        CommentConfig "NET_BIND_ADDRESS" "/etc/default/dump1090-mutability"
    else
        echo -e "\e[94m  Binding dump1090-mutability to the localhost IP addresses...\e[97m"
        ChangeConfig "NET_BIND_ADDRESS" "127.0.0.1" "/etc/default/dump1090-mutability"
    fi

    # Reload dump1090-mutability to ensure all changes take effect.
    echo -e "\e[94m  Reloading dump1090-mutability...\e[97m"
    echo ""
    sudo /etc/init.d/dump1090-mutability force-reload
fi

# Download Heywhatsthat.com maximum range rings if the user wishes them to be displayed.
if [ ! -f /usr/share/dump1090-mutability/html/upintheair.json ] || [ ! -f /usr/share/dump1090-fa/html/upintheair.json ]; then
    if (whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Heywhaststhat.com Maimum Range Rings" --yesno "Maximum range rings can be added to dump1090-mutability usings data obtained from Heywhatsthat.com. In order to add these rings to your dump1090-mutability map you will first need to visit http://www.heywhatsthat.com and generate a new panarama centered on the location of your receiver. Once your panarama has been generated a link to the panarama will be displayed in the up left hand portion of the page. You will need the view id which is the series of letters and/or numbers after \"?view=\" in this URL.\n\nWould you like to add heywatsthat.com maximum range rings to your map?" 16 78); then
        HEYWHATSTHATID_TITLE="Heywhatsthat.com Panarama ID"
        while [[ -z $HEYWHATSTHATID ]]; do
            HEYWHATSTHATID=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$HEYWHATSTHATID_TITLE" --nocancel --inputbox "\nEnter your Heywhatsthat.com panarama ID." 8 78 3>&1 1>&2 2>&3)
            HEYWHATSTHATID_TITLE="Heywhatsthat.com Panarama ID (REQUIRED)"
        done
        HEYWHATSTHATRINGONE_TITLE="Heywhatsthat.com First Ring Altitude"
        while [[ -z $HEYWHATSTHATRINGONE ]]; do
            HEYWHATSTHATRINGONE=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$HEYWHATSTHATRINGONE_TITLE" --nocancel --inputbox "\nEnter the first ring's altitude in meters.\n(default 3048 meters or 10000 feet)" 8 78 "3048" 3>&1 1>&2 2>&3)
            HEYWHATSTHATRINGONE_TITLE="Heywhatsthat.com First Ring Altitude (REQUIRED)"
        done
        HEYWHATSTHATRINGTWO_TITLE="Heywhatsthat.com Second Ring Altitude"
        while [[ -z $HEYWHATSTHATRINGTWO ]]; do
            HEYWHATSTHATRINGTWO=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$HEYWHATSTHATRINGTWO_TITLE" --nocancel --inputbox "\nEnter the second ring's altitude in meters.\n(default 12192 meters or 40000 feet)" 8 78 "12192" 3>&1 1>&2 2>&3)
            HEYWHATSTHATRINGTWO_TITLE="Heywhatsthat.com Second Ring Altitude (REQUIRED)"
        done
        echo -e "\e[94m  Downloading JSON data pertaining to the supplied panorama ID...\e[97m"
        echo ""
        if [ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
            HTMLPATH="/usr/share/dump1090-mutability/html/upintheair.json"
        else
            HTMLPATH="/usr/share/dump1090-fa/html/upintheair.json"
        fi
        sudo wget -O $HTMLPATH "http://www.heywhatsthat.com/api/upintheair.json?id=${HEYWHATSTHATID}&refraction=0.25&alts=$HEYWHATSTHATRINGONE,$HEYWHATSTHATRINGTWO"
    fi
fi

# Dump1090 configuration is now complete.
echo ""
echo -e "\e[93m----------------------------------------------------------------------------------------------------"
echo -e "\e[92m  Dump1090 configuration complete.\e[39m"
echo ""
read -p "Press enter to continue..." CONTINUE


# CONFIGURE PIAWARE IF NEEDED

if [ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
    clear
    echo -e "\n\e[91m   $ADSB_PROJECTTITLE"
    echo ""
    echo -e "\e[92m  Configure PiAware..."
    echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
    echo ""

    whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Claim Your PiAware Device" --msgbox "Please supply your FlightAware login in order to claim this device. After supplying your login PiAware will ask you to enter your password for verification. If you decide not to supply a login and password at this time you should still be able to claim your feeder by visting the page http://flightaware.com/adsb/piaware/claim." 11 78
    # Ask for the users FlightAware login.
    FLIGHTAWARELOGIN=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Your FlightAware Login" --nocancel --inputbox "\nEnter your FlightAware login.\nLeave this blank to manually claim your PiAware device." 9 78 3>&1 1>&2 2>&3)
    if [ ! $FLIGHTAWARELOGIN = "" ]; then
        # If the user supplied their FlightAware login continue with the device claiming process.
        FLIGHTAWAREPASSWORD1_TITLE="Your FlightAware Password"
        while [[ -z $FLIGHTAWAREPASSWORD1 ]]; do
            FLIGHTAWAREPASSWORD1=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$FLIGHTAWAREPASSWORD1_TITLE" --nocancel --passwordbox "\nEnter your FlightAware password." 8 78 3>&1 1>&2 2>&3)
        done
        FLIGHTAWAREPASSWORD2_TITLE="Confirm Your FlightAware Password"
        while [[ -z $FLIGHTAWAREPASSWORD2 ]]; do
            FLIGHTAWAREPASSWORD2=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$FLIGHTAWAREPASSWORD2_TITLE" --nocancel --passwordbox "\nConfirm your FlightAware password." 8 78 3>&1 1>&2 2>&3)
        done
        while [ ! $FLIGHTAWAREPASSWORD1 = $FLIGHTAWAREPASSWORD2 ]; do
            FLIGHTAWAREPASSWORD1=""
            FLIGHTAWAREPASSWORD2=""
            # Display an error message if the passwords did not match.
            whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Claim Your PiAware Device" --msgbox "Passwords did not match.\nPlease enter your password again." 9 78
            FLIGHTAWAREPASSWORD1_TITLE="Your FlightAware Password (REQUIRED)"
            while [[ -z $FLIGHTAWAREPASSWORD1 ]]; do
                 FLIGHTAWAREPASSWORD1=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$FLIGHTAWAREPASSWORD1_TITLE" --nocancel --passwordbox "\nEnter your FlightAware password." 8 78 3>&1 1>&2 2>&3)
            done
            FLIGHTAWAREPASSWORD2_TITLE="Confirm Your FlightAware Password (REQUIRED)"
            while [[ -z $FLIGHTAWAREPASSWORD2 ]]; do
                 FLIGHTAWAREPASSWORD2=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$FLIGHTAWAREPASSWORD2_TITLE" --nocancel --passwordbox "\nConfirm your FlightAware password." 8 78 3>&1 1>&2 2>&3)
            done
        done

        # Set the supplied user name and password in the configuration.
        echo -e "\e[94m  Setting the flightaware-user setting using piaware-config...\e[97m"
        echo ""
        sudo piaware-config flightaware-user $FLIGHTAWARELOGIN
        echo ""
        echo -e "\e[94m  Setting the flightaware-password setting using piaware-config...\e[97m"
        echo ""
        sudo piaware-config flightaware-password $FLIGHTAWAREPASSWORD1
        echo ""
        echo -e "\e[94m  Restarting PiAware to ensure changes take effect...\e[97m"
        echo ""
        sudo /etc/init.d/piaware restart
        echo ""
    else
        # Display a message to the user stating they need to manually claim their device.
        whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Claim Your PiAware Device" --msgbox "Since you did not supply a login you will need to claim this PiAware device manually by visiting the following URL.\n\nhttp://flightaware.com/adsb/piaware/claim." 10 78
    fi

    # PiAware configuration is now complete.
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  PiAware configuration complete.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
fi

## SETUP THE ADS-B RECIEVER PROJECT WEB PORTAL

chmod +x $BASHDIRECTORY/portal/install.sh
$BASHDIRECTORY/portal/install.sh
if [ $? -ne 0 ]; then
    exit 1
fi

## FINALIZE IMAGE SETUP

# remove the "image" file.
rm -f image

whiptail --backtitle "$ADSB_PROJECTTITLE" --title "ADS-B Receiver Project Image Setup" --msgbox "Image setup is now complete. If you have any questions or comments on the project let us know on our website.\n\n  https://www.adsbreceiver.net\n\nRemember to install additional features simply run ./install.sh again." 12 78

exit 0

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
echo -e "\e[92m  Setting up the ADS-B Receiver Project Portal..."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo ""
whiptail --title "ADS-B ADS-B Receiver Project Portal Setup" --yesno "" 12 78
CONTINUESETUP=$?
if [ $CONTINUESETUP = 1 ]; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  ADS-B Receiver Project Portal setup halted.\e[39m"
    echo ""
    read -p "Press enter to continue..." CONTINUE
    exit 1
fi

## GATHER NEEDED INFORMATION FROM THE USER

# We will need to make sure Lighttpd is installed first before we go any further.
echo -e "\e[95m  Installing packages needed to fulfill dependencies...\e[97m"
echo ""
CheckPackage lighttpd

# Assign the Lighthttpd document root directory to a variable.
RAWDOCUMENTROOT=`/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root`
LIGHTTPDDOCUMENTROOT=`sed 's/.*"\(.*\)"[^"]*$/\1/' <<< $RAWDOCUMENTROOT`

# Check if there is already an existing portal installation.
PORTALINSTALLED=`-f $LIGHTTPDDOCUMENTROOT/classes/settings.class.php`

if [ $PORTALINSTALLED = TRUE ]; then

    # ASSIGN USING EXISTING CONFIGURATION DATA
    ADVANCED=""
    DATABASEENGINE=""

else
    # Ask if advanced features should be enabled.
    whiptail --title "ADS-B Receiver Portal Selection" --yesno "NOTE THAT THE ADVANCED FEATURES ARE STILL IN DEVELOPMENT AT THIS TIME\nADVANCED FEATURES SHOULD ONLY BE ENABLED BY DEVELOPERS AND TESTERS ONLY\n\nBy enabling advanced features the portal will log all flights seen as well as the path of the flight. This data is stored in either a MySQL or SQLite database. This will result in a lot more data being stored on your devices hard drive. Keep this and your devices hardware capabilities in mind before selecting to enable these features.\n\nENABLING ADVANCED FEATURES ON DEVICES USING SD CARDS CAN SHORTEN THE LIFE OF THE SD CARD IMMENSELY\n\nDo you wish to enable the portal advanced features?" 14 78
    RESPONSE=$?
    case $RESPONSE in
        0) ADVANCED=TRUE;;
        1) ADVANCED=FALSE;;
    esac

    if [ $ADVANCED = 1 ]; then
        # Ask which type of database to use.
        DATABASEENGINE=$(whiptail --title "Choose Database Type" --nocancel --menu "Choose which type of database to use." 11 80 2 "MySQL" "" "SQLite" "" 3>&1 1>&2 2>&3)
        if [ $DATABASEENGINE == "MySQL" ]; then
            # Ask if the database server will be installed locally.
            whiptail --title "MySQL Database Location" --yesno "Will the database be hosted locally on this device?" 7 80
            RESPONSE=$?
            case $RESPONSE in
                0) LOCALMYSQLSERVER=TRUE;;
                1) LOCALMYSQLSERVER=FALSE;;
            esac
            if [ $LOCALDATABASE = FALSE ]; then
                # Ask for the remote MySQL servers hostname.
                DATABASEHOSTNAME_TITLE="MySQL Database Server Hostname"
                while [[ -z $DATABASEHOSTNAME ]]; do
                    DATABASEHOSTNAME=$(whiptail --title "$DATABASEHOSTNAME_TITLE" --nocancel --inputbox "\nWhat is the remote MySQL server's hostname?" 10 60 3>&1 1>&2 2>&3)
                    DATABASEHOSTNAME_TITLE="MySQL Database Server Hostname (REQUIRED)"
                done

                # Ask if the remote MySQL database already exists.
                whiptail --title "Does MySQL Database Exist" --yesno "Has the database already been created?" 7 80
                RESPONSE=$?
                case $RESPONSE in
                    0) DATABASEEXISTS=TRUE;;
                    1) DATABASEEXISTS=FALSE;;
                esac

                # If the remote MySQL database does not exist ask for the MySQL administrator credentials.
                if [ $DATABASEEXISTS = FALSE ]; then
                    whiptail --title "Create Remote MySQL Database" --msgbox "This script can attempt to create the MySQL database for you.\n\nYou will now be asked for the credentials for a MySQL user who has the ability to create a database on the remote MySQL server." 9 78
                    DATABASEADMINUSER_TITLE="Remote MySQL Administrator User"
                    while [[ -z $DATABASEADMINUSER ]]; do
                        DATABASEADMINUSER=$(whiptail --title "$DATABASEADMINUSER_TITLE" --nocancel --inputbox "\nEnter the remote MySQL administrator user." 8 78 "root" 3>&1 1>&2 2>&3)
                        DATABASEADMINUSER_TITLE="Remote MySQL Administrator User (REQUIRED)"
                    done
                    DATABASEADMINPASSWORD1_TITLE="Remote MySQL Administrator Password"
                    while [[ -z $DATABASEADMINPASSWORD1 ]]; do
                        DATABASEADMINPASSWORD1=$(whiptail --title "$DATABASEADMINPASSWORD1_TITLE" --nocancel --passwordbox "\nEnter the password for the remote MySQL adminitrator user." 8 78 3>&1 1>&2 2>&3)
                        DATABASEADMINPASSWORD1_TITLE="Remote MySQL Administrator Password (REQUIRED)"
                    done
                    DATABASEADMINPASSWORD2_TITLE="Confirm The Remote MySQL Administrator Password"
                    while [[ -z $DATABASEADMINPASSWORD2 ]]; do
                        DATABASEADMINPASSWORD2=$(whiptail --title "$DATABASEADMINPASSWORD2_TITLE" --nocancel --passwordbox "\nConfirm the password for the remote MySQL adminitrator user." 8 78 3>&1 1>&2 2>&3)
                        DATABASEADMINPASSWORD2_TITLE="Confirm The Remote MySQL Administrator Password (REQUIRED)"
                    done
                    while [ ! $DATABASEADMINPASSWORD1 = $DATABASEADMINPASSWORD2 ]; do
                        DATABASEADMINPASSWORD1=""
                        DATABASEADMINPASSWORD2=""
                        whiptail --title "" --msgbox "Passwords did not match.\nPlease enter your password again." 9 78
                        DATABASEADMINPASSWORD1_TITLE="Remote MySQL Administrator Password"
                        while [[ -z $DATABASEADMINPASSWORD1 ]]; do
                            DATABASEADMINPASSWORD1=$(whiptail --title "$DATABASEADMINPASSWORD1_TITLE" --nocancel --passwordbox "\nEnter the password for the remote MySQL adminitrator user.." 8 78 3>&1 1>&2 2>&3)
                            DATABASEADMINPASSWORD1_TITLE="Remote MySQL Administrator Password (REQUIRED)"
                        done
                        DATABASEADMINPASSWORD2_TITLE="Confirm The Remote MySQL Administrator Password"
                        while [[ -z $DATABASEADMINPASSWORD2 ]]; do
                            DATABASEADMINPASSWORD2=$(whiptail --title "$DATABASEADMINPASSWORD2_TITLE" --nocancel --passwordbox "\nConfirm the password for the remote MySQL adminitrator user.." 8 78 3>&1 1>&2 2>&3)
                             DATABASEADMINPASSWORD2_TITLE="Confirm The Remote MySQL Administrator Password (REQUIRED)"
                        done
                    done
                fi
            else
                DATABASEHOSTNAME="localhost"
            fi
            DATABASENAME=$(whiptail --title "ADS-B Receiver Portal Database Name" --nocancel --inputbox "" 8 78 3>&1 1>&2 2>&3)
            DATABASEUSER=$(whiptail --title "ADS-B Receiver Portal Database User" --nocancel --inputbox "" 8 78 3>&1 1>&2 2>&3)
            DATABASEPASSWORD1=$(whiptail --title "ADS-B Receiver Portal Password" --nocancel --passwordbox "" 8 78 3>&1 1>&2 2>&3)
            DATABASEPASSWORD2=$(whiptail --title "Confirm The ADS-B Receiver Portal Password" --nocancel --passwordbox "" 8 78 3>&1 1>&2 2>&3)
        fi
    fi
fi

## CHECK FOR PREREQUISITE PACKAGES

# Performance graph dependencies.
CheckPackage collectd-core
CheckPackage rrdtool

# Portal dependencies.
CheckPackage libpython2.7
CheckPackage python-pyinotify

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

# Install packages needed for advanced portal setups.
if [ $ADVANCED = TRUE ]; then
    case $DATABASEENGINE in
        "MySQL")
            if [ $LOCALMYSQLSERVER = TRUE ]; then
                # Install MySQL locally.
                CheckPackage mysql-server
            fi
            CheckPackage mysql-client
            CheckPackage python-mysqldb

            # Check if this is Ubuntu 16.04 LTS.
            # This needs optimized and made to recognize releases made after 16.04 as well.
            if [ -f /etc/lsb-release ]; then
                . /etc/lsb-release
                if [ $DISTRIB_ID == "Ubuntu" ] && [ $DISTRIB_RELEASE == "16.04"  ]; then
                    CheckPackage php7.0-mysql
                else
                    CheckPackage php5-mysql
                fi
            else
                CheckPackage php5-mysql
            fi
            ;;
        "SQLite")
            CheckPackage sqlite3

            # Check if this is Ubuntu 16.04 LTS.
            # This needs optimized and made to recognize releases made after 16.04 as well.
            if [ -f /etc/lsb-release ]; then
                . /etc/lsb-release
                if [ $DISTRIB_ID == "Ubuntu" ] && [ $DISTRIB_RELEASE == "16.04"  ]; then
                    CheckPackage php7.0-sqlite
                else
                    CheckPackage php5-sqlite
                fi
            else
                CheckPackage php5-sqlite
            fi
            ;;
    esac
fi

# Restart Lighttpd after installing the prerequisite packages.
echo -e "\e[94m  Restarting Lighttpd...\e[97m"
sudo /etc/init.d/lighttpd restart
echo ""

## SETUP THE PORTAL WEBSITE

echo ""
echo -e "\e[95m  Setting up the web portal...\e[97m"
echo ""

# If this is an existing Lite installation being upgraded backup the XML data files.
if [ $PORTALINSTALLED = TRUE ] && [ $ADVANCED = FALSE ]; then
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
if [ $PORTALINSTALLED = TRUE ] && [ $ADVANCED = FALSE ]; then
    echo -e "\e[94m  Restoring the backup copy of the file $LIGHTTPDDOCUMENTROOT/data/administrators.xml...\e[97m"
    sudo mv $LIGHTTPDDOCUMENTROOT/data/administrators.backup.xml $LIGHTTPDDOCUMENTROOT/data/administrators.xml
    echo -e "\e[94m  Restoring the backup copy of the file $LIGHTTPDDOCUMENTROOT/data/blogPosts.xml...\e[97m"
    sudo mv $LIGHTTPDDOCUMENTROOT/data/blogPosts.backup.xml $LIGHTTPDDOCUMENTROOT/data/blogPosts.xml
    echo -e "\e[94m  Restoring the backup copy of the file $LIGHTTPDDOCUMENTROOT/data/flightNotifications.xml...\e[97m"
    sudo mv $LIGHTTPDDOCUMENTROOT/data/flightNotifications.backup.xml $LIGHTTPDDOCUMENTROOT/data/flightNotifications.xml
    echo -e "\e[94m  Restoring the backup copy of the file $LIGHTTPDDOCUMENTROOT/data/settings.xml...\e[97m"
    sudo mv $LIGHTTPDDOCUMENTROOT/data/settings.backup.xml $LIGHTTPDDOCUMENTROOT/data/settings.xml
fi

# Set the proper permissions on certain portal directories.
echo -e "\e[94m  Making the directory $LIGHTTPDDOCUMENTROOT/graphs/ writable...\e[97m"
sudo chmod 777 $LIGHTTPDDOCUMENTROOT/graphs/
echo -e "\e[94m  Making the directory $LIGHTTPDDOCUMENTROOT/classes/ writable...\e[97m"
sudo chmod 777 $LIGHTTPDDOCUMENTROOT/classes/
echo -e "\e[94m  Making the directory $LIGHTTPDDOCUMENTROOT/data/ writable...\e[97m"
sudo chmod 777 $LIGHTTPDDOCUMENTROOT/data/
echo -e "\e[94m  Making the files contained within the directory $LIGHTTPDDOCUMENTROOT/data/ writable...\e[97m"
sudo chmod 666 $LIGHTTPDDOCUMENTROOT/data/*

# Check if dump978 was setup.
echo -e "\e[94m  Checking if dump978 was set up...\e[97m"
if ! grep -q "$BUILDDIRECTORY/dump978/dump978-maint.sh &" /etc/rc.local; then
    # Check if a heywhatsthat.com range file exists in the dump1090 HTML folder.
    echo -e "\e[94m  Checking for the file upintheair.json in the dump1090 HTML folder...\e[97m"
    if [ -f /usr/share/dump1090-mutability/html/upintheair.json ]; then
        echo -e "\e[94m  Copying the file upintheair.json from the dump1090 HTML folder to the dump978 HTML folder...\e[97m"
        sudo cp /usr/share/dump1090-mutability/html/upintheair.json $LIGHTTPDDOCUMENTROOT/dump978/
    fi
fi

echo -e "\e[94m  Removing conflicting redirects from the Lighttpd dump1090.conf file...\e[97m"
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

if ! [ -L /etc/lighttpd/conf-enabled/89-adsb-portal.conf ]; then
    echo -e "\e[94m  Enabling the Lighttpd portal configuration file...\e[97m"
    sudo ln -s /etc/lighttpd/conf-available/89-adsb-portal.conf /etc/lighttpd/conf-enabled/89-adsb-portal.conf
fi

if [ $PORTALINSTALLED = FALSE ]; then
    echo -e "\e[94m  Enabling the Lighttpd fastcgi-php module...\e[97m"
    sudo lighty-enable-mod fastcgi-php
fi

# Reload or start Lighttpd.
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

## SEUP THE MYSQL DATABASE

if [ $PORTALINSTALLED = FALSE ] && [ $ADVANCED = TRUE ] && [ $DATABASEENGINE = "MySQL" ] && [ $DATABASEEXISTS = FALSE ]; then
    echo -e "\e[94m  Creating the MySQL database \"$DATABASENAME\"...\e[97m"
    mysql -u$DATABASEADMINUSER -p$DATABASEADMINPASSWORD -h $DATABASEHOSTNAME -e "CREATE DATABASE $DATABASENAME;"
    echo -e "\e[94m  Creating the MySQL user \"$DATABASEUSER\"...\e[97m"
    mysql -u$DATABASEADMINUSER -p$DATABASEADMINPASSWORD -h $DATABASEHOSTNAME -e "CREATE USER '$DATABASEUSER'@'localhost' IDENTIFIED BY \"$DATABASEPASSWORD1\";"
    echo -e "\e[94m  Granting priviledges on the MySQL database \"DATABASENAME\" to the user \"$DATABASEUSER\"...\e[97m"
    mysql -u$DATABASEADMINUSER -p$DATABASEADMINPASSWORD -h $DATABASEHOSTNAME -e "GRANT ALL PRIVILEGES ON $DATABASENAME.* TO '$DATABASEUSER'@'localhost';"
    echo -e "\e[94m  Flushing priviledges on the MySQL database server...\e[97m"
    mysql -u$DATABASEADMINUSER -p$DATABASEADMINPASSWORD -h $DATABASEHOSTNAME -e "FLUSH PRIVILEGES;"
fi

## SETUP THE PERFORMANCE GRAPHS USING THE SCRIPT GRAPHS.SH

chmod +x $BASHDIRECTORY/portal/graphs.sh
$BASHDIRECTORY/portal/graphs.sh
if [ $? -ne 0 ]; then
    echo ""
    echo -e "\e[91m  THE SCRIPT GRAPHS.SH ENCOUNTERED AND ERROR"
    echo ""
    exit 1
fi

## SETUP FLIGHT LOGGING USING THE SCRIPT LOGGING.SH

if [ $ADVANCED = TRUE ]; then
    chmod +x $BASHDIRECTORY/portal/logging.sh
    $BASHDIRECTORY/portal/logging.sh
    if [ $? -ne 0 ]; then
        echo ""
        echo -e "\e[91m  THE SCRIPT LOGGING.SH ENCOUNTERED AND ERROR"
        echo ""
        exit 1
    fi
fi

## ADS-B RECEIVER PROJECT PORTAL SETUP COMPLETE

echo ""
echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
echo -e "\e[92m  ADS-B Receiver Project Portal setup is complete.\e[39m"
echo ""
read -p "Press enter to continue..." CONTINUE

exit 0

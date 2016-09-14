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
echo -e "\n\e[91m  $ADSB_PROJECTTITLE"
echo ""
echo -e "\e[92m  Setting up the ADS-B Receiver Project Portal..."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo ""
whiptail --backtitle "$ADSB_PROJECTTITLE" --title "ADS-B ADS-B Receiver Project Portal Setup" --yesno "The ADS-B ADS-B Receiver Project Portal adds a web accessable portal to your receiver. The portal contains allows you to view performance graphs, system information, and live maps containing the current aircraft being tracked.\n\nBy enabling the portal's advanced features you can also view historical data on flight that have been seen in the past as well as view more detailed information on each of these aircraft.\n\nTHE ADVANCED PORTAL FEATURES ARE STILL IN DEVELOPMENT\n\nIt is recomended that only those wishing to contribute to the development of these features or those wishing to test out the new features enable them. Do not be surprised if you run into any major bugs after enabling the advanced features at this time!\n\nDo you wish to continue with the ADS-B Receiver Project Portal setup?" 23 78
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
if [ -f $LIGHTTPDDOCUMENTROOT/classes/settings.class.php ]; then
    PORTALINSTALLED=TRUE
else
    PORTALINSTALLED=FALSE
fi

if [ $PORTALINSTALLED = TRUE ]; then
    # Assign needed variables using the driver setting in settings.class.php.
    DATABASEENGINE=`grep 'db_driver' $LIGHTTPDDOCUMENTROOT/classes/settings.class.php | tail -n1 | cut -d\' -f2`
    if [ $DATABASEENGINE = "xml" ]; then
        ADVANCED=FALSE
    else
        ADVANCED=TRUE
    fi
    if [ $ADVANCED = TRUE ]; then
        case $DATABASEENGINE in
            "mysql") DATABASEENGINE="MySQL";;
            "sqlite") DATABASEENGINE="SQLite";;
        esac
        DATABASEHOSTNAME=`grep 'db_host' $LIGHTTPDDOCUMENTROOT/classes/settings.class.php | tail -n1 | cut -d\' -f2`
        DATABASEUSER=`grep 'db_username' $LIGHTTPDDOCUMENTROOT/classes/settings.class.php | tail -n1 | cut -d\' -f2`
        DATABASEPASSWORD1=`grep 'db_password' $LIGHTTPDDOCUMENTROOT/classes/settings.class.php | tail -n1 | cut -d\' -f2`
        DATABASENAME=`grep 'db_database' $LIGHTTPDDOCUMENTROOT/classes/settings.class.php | tail -n1 | cut -d\' -f2`
    fi


else
    # Ask if advanced features should be enabled.
    whiptail --backtitle "$ADSB_PROJECTTITLE" --title "ADS-B Receiver Portal Selection" --defaultno --yesno "NOTE THAT THE ADVANCED FEATURES ARE STILL IN DEVELOPMENT AT THIS TIME\nADVANCED FEATURES SHOULD ONLY BE ENABLED BY DEVELOPERS AND TESTERS ONLY\n\nBy enabling advanced features the portal will log all flights seen as well as the path of the flight. This data is stored in either a MySQL or SQLite database. This will result in a lot more data being stored on your devices hard drive. Keep this and your devices hardware capabilities in mind before selecting to enable these features.\n\nENABLING ADVANCED FEATURES ON DEVICES USING SD CARDS CAN SHORTEN THE LIFE OF THE SD CARD IMMENSELY\n\nDo you wish to enable the portal advanced features?" 19 78
    RESPONSE=$?
    case $RESPONSE in
        0) ADVANCED=TRUE;;
        1) ADVANCED=FALSE;;
    esac

    if [ $ADVANCED = TRUE ]; then
        # Ask which type of database to use.
        DATABASEENGINE=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Choose Database Type" --nocancel --menu "\nChoose which type of database to use." 11 80 2 "MySQL" "" "SQLite" "" 3>&1 1>&2 2>&3)

        if [ $DATABASEENGINE = "MySQL" ]; then
            # Ask if the database server will be installed locally.
            whiptail --backtitle "$ADSB_PROJECTTITLE" --title "MySQL Database Location" --yesno "Will the database be hosted locally on this device?" 7 80
            RESPONSE=$?
            case $RESPONSE in
                0) LOCALMYSQLSERVER=TRUE;;
                1) LOCALMYSQLSERVER=FALSE;;
            esac
            if [ $LOCALMYSQLSERVER = FALSE ]; then
                # Ask for the remote MySQL servers hostname.
                DATABASEHOSTNAME_TITLE="MySQL Database Server Hostname"
                while [[ -z $DATABASEHOSTNAME ]]; do
                    DATABASEHOSTNAME=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$DATABASEHOSTNAME_TITLE" --nocancel --inputbox "\nWhat is the remote MySQL server's hostname?" 10 60 3>&1 1>&2 2>&3)
                    DATABASEHOSTNAME_TITLE="MySQL Database Server Hostname (REQUIRED)"
                done

                # Ask if the remote MySQL database already exists.
                whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Does MySQL Database Exist" --yesno "Has the database already been created?" 7 80
                RESPONSE=$?
                case $RESPONSE in
                    0) DATABASEEXISTS=TRUE;;
                    1) DATABASEEXISTS=FALSE;;
                esac
            else
                # Install the MySQL serer now if it does not already exist.
                whiptail --backtitle "$ADSB_PROJECTTITLE" --title "MySQL Server Setup" --msgbox "This script will now check for the MySQL server package. If the MySQL server package is not installed it will be installed at this time." 8 78
                CheckPackage mysql-server

                # Since this is a local installation assume the MySQL database does not already exist.
                DATABASEEXISTS=FALSE

                # Since the MySQL database server will run locally assign localhost as it's hostname.
                DATABASEHOSTNAME="localhost"
            fi

            # Ask for the MySQL administrator credentials if the database does not already exist.
            if [ $LOCALMYSQLSERVER = TRUE ] || [ $DATABASEEXISTS = FALSE ]; then
                whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Create Remote MySQL Database" --msgbox "This script can attempt to create the MySQL database for you.\nYou will now be asked for the credentials for a MySQL user who has the ability to create a database on the MySQL server." 9 78
                DATABASEADMINUSER_TITLE="MySQL Administrator User"
                while [ -z "$DATABASEADMINUSER" ]; do
                    DATABASEADMINUSER=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$DATABASEADMINUSER_TITLE" --nocancel --inputbox "\nEnter the MySQL administrator user." 8 78 "root" 3>&1 1>&2 2>&3)
                    DATABASEADMINUSER_TITLE="MySQL Administrator User (REQUIRED)"
                done
                DATABASEADMINPASSWORD1_TITLE="MySQL Administrator Password"
                DATABASEADMINPASSWORD1_MESSAGE="\nEnter the password for the MySQL adminitrator user."
                while [ -z "$DATABASEADMINPASSWORD1" ]; do
                    DATABASEADMINPASSWORD1=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$DATABASEADMINPASSWORD1_TITLE" --nocancel --passwordbox "$DATABASEADMINPASSWORD1_MESSAGE" 8 78 3>&1 1>&2 2>&3)
                    DATABASEADMINPASSWORD1_TITLE="MySQL Administrator Password (REQUIRED)"
                done
                DATABASEADMINPASSWORD2_TITLE="Confirm The MySQL Administrator Password"
                DATABASEADMINPASSWORD2_MESSAGE="\nConfirm the password for the MySQL adminitrator user."
                while [ -z "$DATABASEADMINPASSWORD2" ]; do
                    DATABASEADMINPASSWORD2=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$DATABASEADMINPASSWORD2_TITLE" --nocancel --passwordbox "$DATABASEADMINPASSWORD2_MESSAGE" 8 78 3>&1 1>&2 2>&3)
                    DATABASEADMINPASSWORD2_TITLE="Confirm The MySQL Administrator Password (REQUIRED)"
                done
                while [ ! $DATABASEADMINPASSWORD1 = $DATABASEADMINPASSWORD2 ]; do
                    DATABASEADMINPASSWORD1=""
                    DATABASEADMINPASSWORD2=""
                    whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Passwords Did Not Match" --msgbox "Passwords did not match.\nPlease enter your password again." 9 78
                    DATABASEADMINPASSWORD1_TITLE="MySQL Administrator Password"
                    while [ -z "$DATABASEADMINPASSWORD1" ]; do
                        DATABASEADMINPASSWORD1=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$DATABASEADMINPASSWORD1_TITLE" --nocancel --passwordbox "DATABASEADMINPASSWORD1_MESSAGE" 8 78 3>&1 1>&2 2>&3)
                        DATABASEADMINPASSWORD1_TITLE="MySQL Administrator Password (REQUIRED)"
                    done
                    DATABASEADMINPASSWORD2_TITLE="Confirm The MySQL Administrator Password"
                    while [ -z "$DATABASEADMINPASSWORD2" ]; do
                        DATABASEADMINPASSWORD2=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$DATABASEADMINPASSWORD2_TITLE" --nocancel --passwordbox "DATABASEADMINPASSWORD2_MESSAGE" 8 78 3>&1 1>&2 2>&3)
                        DATABASEADMINPASSWORD2_TITLE="Confirm The MySQL Administrator Password (REQUIRED)"
                    done
                done
            fi

            # Get the login information pertaining to the MySQL database itself.
            whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Create Remote MySQL Database" --msgbox "You will now be asked to supply the name of the database which will store the portal data as well as the login credentials for the MySQL user that has access to this database." 9 78

            DATABASENAME_TITLE="ADS-B Receiver Portal Database Name"
            while [ -z "$DATABASENAME" ]; do
                DATABASENAME=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$DATABASENAME_TITLE" --nocancel --inputbox "\nEnter your ADS-B Receiver Portal database name." 8 78 3>&1 1>&2 2>&3)
                DATABASENAME_TITLE="ADS-B Receiver Portal Database Name (REQUIRED)"
            done
            DATABASEUSER_TITLE="ADS-B Receiver Portal Database User"
            while [ -z "$DATABASEUSER" ]; do
                DATABASEUSER=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$DATABASEUSER_TITLE" --nocancel --inputbox "\nEnter the user for the ADS-B Receiver Portal database." 8 78 3>&1 1>&2 2>&3)
                DATABASEUSER_TITLE="ADS-B Receiver Portal Database User (REQUIRED)"
            done
            DATABASEPASSWORD1_TITLE="ADS-B Receiver Portal Password"
            DATABASEPASSWORD1_MESSAGE="\nEnter your ADS-B Receiver Portal database password."
            while [ -z "$DATABASEPASSWORD1" ]; do
                DATABASEPASSWORD1=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$DATABASEPASSWORD1_TITLE" --nocancel --passwordbox "$DATABASEPASSWORD1_MESSAGE" 8 78 3>&1 1>&2 2>&3)
                DATABASEPASSWORD1_TITLE="ADS-B Receiver Portal Password (REQUIRED)"
            done
            DATABASEPASSWORD2_TITLE="Confirm The ADS-B Receiver Portal Password"
            DATABASEPASSWORD2_MESSAGE="\nConfirm your ADS-B Receiver Portal database password."
            while [ -z "$DATABASEPASSWORD2" ]; do
                DATABASEPASSWORD2=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$DATABASEPASSWORD2_TITLE" --nocancel --passwordbox "$DATABASEPASSWORD2_MESSAGE" 8 78 3>&1 1>&2 2>&3)
                DATABASEPASSWORD2_TITLE="Confirm The ADS-B Receiver Portal Password (REQUIRED)"
            done
            while [ ! $DATABASEPASSWORD1 = $DATABASEPASSWORD2 ]; do
                DATABASEPASSWORD1=""
                DATABASEPASSWORD2=""
                whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Passwords Did Not Match" --msgbox "Passwords did not match.\nPlease enter your password again." 9 78
                DATABASEPASSWORD1_TITLE="ADS-B Receiver Portal Password"
                while [ -z "$DATABASEPASSWORD1" ]; do
                    DATABASEPASSWORD1=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$DATABASEPASSWORD1_TITLE" --nocancel --passwordbox "$DATABASEPASSWORD1_MESSAGE" 8 78 3>&1 1>&2 2>&3)
                    DATABASEPASSWORD1_TITLE="ADS-B Receiver Portal Password (REQUIRED)"
                done
                DATABASEPASSWORD2_TITLE="Confirm The ADS-B Receiver Portal Password"
                while [ -z "$DATABASEPASSWORD2" ]; do
                    DATABASEPASSWORD2=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$DATABASEPASSWORD2_TITLE" --nocancel --passwordbox "$DATABASEPASSWORD2_MESSAGE" 8 78 3>&1 1>&2 2>&3)
                    DATABASEPASSWORD2_TITLE="Confirm The ADS-B Receiver Portal Password (REQUIRED)"
                done
            done
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
    if [ $DISTRIB_ID == "Ubuntu" ] && [ $DISTRIB_RELEASE == "16.04" ]; then
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

# Reload Lighttpd after installing the prerequisite packages.
echo -e "\e[94m  Reloading Lighttpd...\e[97m"
echo ""
sudo /etc/init.d/lighttpd force-reload

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
sudo cp -R $PORTALBUILDDIRECTORY/html/* $LIGHTTPDDOCUMENTROOT

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
    echo ""
    sudo lighty-enable-mod fastcgi-php
    echo ""
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

## SETUP THE MYSQL DATABASE

if [ $PORTALINSTALLED = FALSE ] && [ $ADVANCED = TRUE ] && [ $DATABASEENGINE = "MySQL" ] && [ $DATABASEEXISTS = FALSE ]; then

    # Attempt to login with the supplied MySQL administrator credentials.
    echo -e "\e[94m  Attempting to log into the MySQL server using the supplied administrator credentials...\e[97m"
    while ! mysql -u$DATABASEADMINUSER -p$DATABASEADMINPASSWORD1 -h $DATABASEHOSTNAME  -e ";" ; do
        echo -e "\e[94m  Unable to log into the MySQL server using the supplied administrator credentials...\e[97m"
        whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Create Remote MySQL Database" --msgbox "The script was not able to log into the MySQL server using the administrator credentials you supplied. You will now be asked to reenter the MySQL server administrator credentials." 9 78
        DATABASEADMINPASSWORD1=""
        DATABASEADMINPASSWORD2=""
        DATABASEADMINUSER_TITLE="MySQL Administrator User"
        while [ -z "$DATABASEADMINUSER" ]; do
            DATABASEADMINUSER=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$DATABASEADMINUSER_TITLE" --nocancel --inputbox "\nEnter the MySQL administrator user." 8 78 "$DATABASEADMINUSER" 3>&1 1>&2 2>&3)
            DATABASEADMINUSER_TITLE="MySQL Administrator User (REQUIRED)"
        done
        DATABASEADMINPASSWORD1_TITLE="MySQL Administrator Password"
        DATABASEADMINPASSWORD1_MESSAGE="\nEnter the password for the MySQL adminitrator user."
        while [ -z "$DATABASEADMINPASSWORD1" ]; do
            DATABASEADMINPASSWORD1=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$DATABASEADMINPASSWORD1_TITLE" --nocancel --passwordbox "$DATABASEADMINPASSWORD1_MESSAGE" 8 78 3>&1 1>&2 2>&3)
            DATABASEADMINPASSWORD1_TITLE="MySQL Administrator Password (REQUIRED)"
        done
        DATABASEADMINPASSWORD2_TITLE="Confirm The MySQL Administrator Password"
        DATABASEADMINPASSWORD2_MESSAGE="\nConfirm the password for the MySQL adminitrator user."
        while [ -z "$DATABASEADMINPASSWORD2" ]; do
            DATABASEADMINPASSWORD2=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$DATABASEADMINPASSWORD2_TITLE" --nocancel --passwordbox "$DATABASEADMINPASSWORD2_MESSAGE" 8 78 3>&1 1>&2 2>&3)
            DATABASEADMINPASSWORD2_TITLE="Confirm The MySQL Administrator Password (REQUIRED)"
        done
        while [ ! $DATABASEADMINPASSWORD1 = $DATABASEADMINPASSWORD2 ]; do
            DATABASEADMINPASSWORD1=""
            DATABASEADMINPASSWORD2=""
            whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Passwords Did Not Match" --msgbox "Passwords did not match.\nPlease enter your password again." 9 78
            DATABASEADMINPASSWORD1_TITLE="MySQL Administrator Password"
            while [ -z "$DATABASEADMINPASSWORD1" ]; do
                DATABASEADMINPASSWORD1=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$DATABASEADMINPASSWORD1_TITLE" --nocancel --passwordbox "DATABASEADMINPASSWORD1_MESSAGE" 8 78 3>&1 1>&2 2>&3)
                DATABASEADMINPASSWORD1_TITLE="MySQL Administrator Password (REQUIRED)"
            done
            DATABASEADMINPASSWORD2_TITLE="Confirm The MySQL Administrator Password"
            while [ -z "$DATABASEADMINPASSWORD2" ]; do
                DATABASEADMINPASSWORD2=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$DATABASEADMINPASSWORD2_TITLE" --nocancel --passwordbox "DATABASEADMINPASSWORD2_MESSAGE" 8 78 3>&1 1>&2 2>&3)
                DATABASEADMINPASSWORD2_TITLE="Confirm The MySQL Administrator Password (REQUIRED)"
            done
        done
        echo -e "\e[94m  Attempting to log into the MySQL server using the new administrator credentials...\e[97m"
    done

    # Create the database use and database using the information supplied by the user.
    echo -e "\e[94m  Creating the MySQL database \"$DATABASENAME\"...\e[97m"
    mysql -u$DATABASEADMINUSER -p$DATABASEADMINPASSWORD1 -h $DATABASEHOSTNAME -e "CREATE DATABASE $DATABASENAME;"
    echo -e "\e[94m  Creating the MySQL user \"$DATABASEUSER\"...\e[97m"
    mysql -u$DATABASEADMINUSER -p$DATABASEADMINPASSWORD1 -h $DATABASEHOSTNAME -e "CREATE USER '$DATABASEUSER'@'localhost' IDENTIFIED BY \"$DATABASEPASSWORD1\";"
    echo -e "\e[94m  Granting priviledges on the MySQL database \"DATABASENAME\" to the user \"$DATABASEUSER\"...\e[97m"
    mysql -u$DATABASEADMINUSER -p$DATABASEADMINPASSWORD1 -h $DATABASEHOSTNAME -e "GRANT ALL PRIVILEGES ON $DATABASENAME.* TO '$DATABASEUSER'@'localhost';"
    echo -e "\e[94m  Flushing priviledges on the MySQL database server...\e[97m"
    mysql -u$DATABASEADMINUSER -p$DATABASEADMINPASSWORD1 -h $DATABASEHOSTNAME -e "FLUSH PRIVILEGES;"
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
    # If SQLite is being used and the path is not already set to the variable $DATABASENAME set it to the default path.
    if [ $DATABASEENGINE = "SQLite" ] && [ -z "$DATABASENAME" ]; then
        $DATABASENAME="$LIGHTTPDDOCUMENTROOT/data/portal.sqlite"
    fi

    # Export variables needed by logging.sh.
    export ADSB_DATABASEENGINE=$DATABASEENGINE
    export ADSB_DATABASEHOSTNAME=$DATABASEHOSTNAME
    export ADSB_DATABASEUSER=$DATABASEUSER
    export ADSB_DATABASEPASSWORD1=$DATABASEPASSWORD1
    export ADSB_DATABASENAME=$DATABASENAME

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

# This assigns the first IP address in the list to the $IPADDRESS variable.
IPADDRESS=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`

# Display final portal setup instructions to the user.
whiptail --backtitle "$ADSB_PROJECTTITLE" --title "ADS-B Receiver Project Portal Setup" --msgbox "PORTAL SETUP IS NOT YET COMPLETE\n\nIn order to complete the portal setup process visit the following URL in your favorite web browser.\n\nhttp://${IPADDRESS}/install/\n\nFollow the instructions and enter the requested information to complete the ADS-B Receiver Project Portal setup." 13 78

# Enter into the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd $PROJECTROOTDIRECTORY

echo ""
echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
echo -e "\e[92m  ADS-B Receiver Project Portal setup is complete.\e[39m"
echo ""
read -p "Press enter to continue..." CONTINUE

exit 0

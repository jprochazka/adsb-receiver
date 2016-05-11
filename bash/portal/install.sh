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
BASHDIR=$BUILDDIR/../bash
HTMLDIR=$BUILDDIR/portal/html

# Assign the Lighthttpd document root directory to a variable.
RAWDOCUMENTROOT=`/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root`
DOCUMENTROOT=`sed 's/.*"\(.*\)"[^"]*$/\1/' <<< $RAWDOCUMENTROOT`

source ../bash/functions.sh

clear

echo -e "\033[31m"
echo "-------------------------------------------"
echo " Now ready to install ADS-B Portal."
echo "-------------------------------------------"
echo -e "\033[33mThe goal of the ADS-B Portal project is to create a very"
echo "light weight easy to manage web interface for dump-1090 installations."
echo "This project is at the moment very young with only a few of the planned"
echo "features currently available at this time."
echo ""
echo "https://github.com/jprochazka/adsb-receiver"
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

clear

## CHECK IF THE PORTAL HAS BEEN INSTALLED ALREADY

if [ -f $DOCUMENTROOT/classes/settings.class.php ]; then
    echo -e "\033[31m"
    echo "It appears a previous verison of the portal has been installled."
    echo -e "\033[33m"
    echo "The files and packages making up your portal installation will"
    echo "be updated. However you will still need to execute the PHP update"
    echo "script to complete the upgrade process by simply visiting the portal"
    echo -e "\033[37m"
    read -p "Press enter to continue..." CONTINUE

    # Set dome needed variables to be used shortly.
    INSTALLED="y"

    DRIVER=`grep 'db_driver' $DOCUMENTROOT/classes/settings.class.php | tail -n1 | cut -d\' -f2`
    HOST=`grep 'db_host' $DOCUMENTROOT/classes/settings.class.php | tail -n1 | cut -d\' -f2`

    if [ $DRIVER != "xml" ]; then
        ADVANCED="y"
    else
        ADVANCED="n"
    fi

    if [ $DRIVER == "sqlite" ]; then
        DATABASEENGINE=2
    else
        DATABASEENGINE=1
    fi

    if [ $HOST != "localhost" ] || [ $HOST != "127.0.0.1" ]; then
        LOCALDATABASE=1
    else
        LOCALDATABASE=2
    fi

else

    ## ASK IF ADVANCED FEATURES ARE TO BE USED

    INSTALLED="n"

    echo -e "\033[31m"
    echo "Do you wish to enable advanced features?"
    echo -e "\033[33m"
    echo "ENABLING ADVANCED FEATURES ON DEVICES USING SD CARDS CAN SHORTEN THE LIFE OF THE SD CARD IMMENSELY"
    echo ""
    echo "By enabling advanced features the portal will log all flights seen as well as the path of the flight."
    echo "This data is stored in either a MySQL or SQLite database. This will result in a lot more data being"
    echo "stored on your devices hard drive. Keep this and your devices hardware capabilities in mind before"
    echo "selecting to enable these features."
    echo -e "\033[31m"
    echo "You have been warned."
    echo -e "\033[37m"
    read -p "Use portal with advanced features? [y/N] " ADVANCED

    if [[ $ADVANCED =~ ^[yY]$ ]]; then
        echo -e "\033[31m"
        echo "Select Database Engine"
        echo -e "\033[33m"
        echo "  1) MySQL"
        echo "  2) SQLLite"
        echo -e "\033[37m"
        read -p "Which database engine will be used? [1] " DATABASEENGINE

        # Check if the user is using a remote MySQL database.
        if [[ $DATABASEENGINE != 2 ]]; then
            echo -e "\033[31m"
            echo "Will the database be hosted locally on this device or remotely?"
            echo -e "\033[33m"
            echo "  1) Locally"
            echo "  2) Remotely"
            echo -e "\033[37m"
            read -p "Where will the database hosted? [1] " LOCALDATABASE
        fi
    fi
fi

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\033[33m"
echo "Installing packages needed to build and fulfill dependencies..."
echo -e "\033[37m"
CheckPackage cron
CheckPackage collectd-core
CheckPackage rrdtool
CheckPackage postfix
CheckPackage lighttpd

# Check if this is Ubuntu 16.04 LTS.
# This needs optimized and made to recognize releases made after 16.04 as well.
if [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    if [ $DISTRIB_ID == "Ubuntu" ] && [ $DISTRIB_RELEASE == "16.04"  ]; then
        CheckPackage php7.0-cgi
        CheckPackage php7.0-xml
    else
        CheckPackage php5-cgi
    fi
else
    CheckPackage php5-cgi
fi

CheckPackage libpython2.7
if [[ $ADVANCED =~ ^[yY]$ ]]; then
    if [[ $DATABASEENGINE == 2 ]]; then
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

    else
       if [[ $LOCALDATABASE != 2 ]]; then
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

    fi
fi

if [[ $INSTALLED == "n" ]]; then

    ## CREATE THE DATABASE IF ADVANCED FEATURES WAS SELECTED

    if [[ $ADVANCED =~ ^[yY]$ ]]; then
        if [[ $DATABASEENGINE != 2 ]]; then
            echo -e "\033[31m"
            echo "Gathering Database Information"
            echo -e "\033[33m"
            echo "Please supply the information pertaining to the new password when asked."
            echo ""
            echo "If the database will be hosted locally on this device a database will be"
            echo "created automatically for you. If you are hosting your database remotely"
            echo "you will need to manually create the database and user on the remote device."
            echo -e "\033[37m"

            DATABASEHOST="localhost"
            if [[ $LOCALDATABASE == 2 ]]; then
                # Ask for remote MySQL address if the database is hosted remotely.
                read -p "Remote MySQL Server Address: " DATABASEHOST
            fi
            read -p "MySQL user login: [root] " MYSQLUSER
            read -p "Password for MySQL user: " MYSQLPASSWORD
            if [[ $LOCALDATABASE == "" ]]; then
                MYSQLUSER="root"
            fi

            # Check that the supplied password is correct.
            while ! mysql -u$MYSQLUSER -p$MYSQLPASSWORD -h $DATABASEHOST  -e ";" ; do
                echo -e "\033[31m"
                echo -e "Unable to connect to the MySQL server using the supplied login and password.\033[37m"
                read -p "MySQL user login: [root] " MYSQLUSER
                read -p "Password for MySQL user: " MYSQLPASSWORD
                if [[ $LOCALDATABASE == "" ]]; then
                    MYSQLUSER="root"
                fi
            done

            read -p "New Database Name: " DATABASENAME
            read -p "New Database User Name: " DATABASEUSER
            read -p "New Database User Password: " DATABASEPASSWORD

            # Create the database and user as well as assign permissions.
            if [[ $DATABASEENGINE == 1 ]] || [[ $DATABASEENGINE == "" ]]; then
                echo -e "\033[33m"
                echo -e "Creating MySQL database and user...\033[37m"
                mysql -u$MYSQLUSER -p${MYSQLROOTPASSWORD} -h $DATABASEHOST -e "CREATE DATABASE ${DATABASENAME};"
                mysql -u$MYSQLUSER -p${MYSQLROOTPASSWORD} -h $DATABASEHOST -e "CREATE USER '${DATABASEUSER}'@'localhost' IDENTIFIED BY \"${DATABASEPASSWORD}\";";
                mysql -u$MYSQLUSER -p${MYSQLROOTPASSWORD} -h $DATABASEHOST -e "GRANT ALL PRIVILEGES ON ${DATABASENAME}.* TO '${DATABASEUSER}'@'localhost';"
                mysql -u$MYSQLUSER -p${MYSQLROOTPASSWORD} -h $DATABASEHOST -e "FLUSH PRIVILEGES;"
            fi

            echo -e "\033[31m"
            echo "BE SURE TO WRITE THIS INFORMATION DOWN."
            echo -e "\033[33m"
            echo "This information will be needed in order to complete the installation of the portal."
            echo ""
            if [[ $LOCALDATABASE == 2 ]]; then
                echo -e "\033[31mNOTE:"
                echo "Being you are hosting your database remotely you will need this information to create"
                echo "both the database and database user on your remote database server."
                echo -e "\033[33m"
            fi
            echo "Database Server: ${DATABASEHOST}"
            echo "Database User: ${DATABASEUSER}"
            echo "Database Password: ${DATABASEPASSWORD}"
            echo "Database Name: ${DATABASENAME}"
            echo -e "\033[37m"
            read -p "Press enter to continue..." CONTINUE

        fi

        ## SETUP FLIGHT LOGGING SCRIPT

        echo -e "\033[33m"
        echo -e "Creating configuration file...\033[37m"
        case $DATABASEENGINE in
            "2")
                tee $BUILDDIR/portal/logging/config.json > /dev/null <<EOF
{
    "database":{"type":"sqlite",
                "host":"",
                "user":"",
                "passwd":"",
                "db":"${DOCUMENTROOT}/data/portal.sqlite"}
}
EOF
                ;;
            *)
                tee $BUILDDIR/portal/logging/config.json > /dev/null <<EOF
{
    "database":{"type":"mysql",
                "host":"${DATABASEHOST}",
                "user":"${DATABASEUSER}",
                "passwd":"${DATABASEPASSWORD}",
                "db":"${DATABASENAME}"}
}
EOF
                 ;;
        esac

        # Create and set permissions on the flight logging maintainance script.
        PYTHONPATH=`which python`
        tee $BUILDDIR/portal/logging/flights-maint.sh > /dev/null <<EOF
#!/bin/sh
while true
  do
    sleep 30
        ${PYTHONPATH} ${BUILDDIR}/portal/logging/flights.py
  done
EOF
        chmod +x $BUILDDIR/portal/logging/flights-maint.sh

        # Add flight logging maintainance script to rc.local.
        if ! grep -Fxq "${BUILDDIR}/portal/logging/flights-maint.sh &" /etc/rc.local; then
            echo -e "\033[33m"
            echo -e "Adding startup line to rc.local...\033[37m"
            lnum=($(sed -n '/exit 0/=' /etc/rc.local))
            ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i ${BUILDDIR}/portal/logging/flights-maint.sh &\n" /etc/rc.local
        fi

        # Start flight logging.
        echo -e "\033[33m"
        echo -e "Starting flight logging...\033[37m"
        nohup ${BUILDDIR}/portal/logging/flights-maint.sh > /dev/null 2>&1 &
    fi
fi

## SETUP THE PORTAL WEBSITE

echo -e "\033[33m"
echo -e "Placing portal files in Lighttpd's root directory...\033[37m"
sudo cp -R ${HTMLDIR}/* ${DOCUMENTROOT}

echo -e "\033[33m"
echo "Setting permissions on portal folders...\033[37m"
sudo chmod 777 ${DOCUMENTROOT}/graphs/
sudo chmod 777 ${DOCUMENTROOT}/classes/
sudo chmod 777 ${DOCUMENTROOT}/data/
sudo chmod 666 ${DOCUMENTROOT}/data/*

echo -e "\033[33m"
echo "Setting up performance graphs..."
echo -e "\033[37m"
chmod +x $BASHDIR/portal/graphs.sh
$BASHDIR/portal/graphs.sh

## CHECK IF DUMP978 HAS BEEN BUILT

if [ -f $BUILDDIR/dump978/dump978 ] && [ -f $BUILDDIR/dump978/uat2text ] && [ -f $BUILDDIR/dump978/uat2esnt ] && [ -f $BUILDDIR/dump978/uat2json ]; then
    echo -e "\033[33m"
    echo -e "Configuring dump978 map...\033[37m"
    # Check if the heywhatsthis.com range position file has already been downloaded.
    if [ ! -f ${HTMLDIR}/dump978/upintheair.json ]; then
        # Check if a heywhatsthat.com range file exists in the dump1090 HTML folder.
        if [ -f /usr/share/dump1090-mutability/html/upintheair.json ]; then
            echo -e "\033[33m"
            echo -e "Copying heywhatsthat.com range file from dump1090 installation...\033[37m"
            sudo cp /usr/share/dump1090-mutability/html/upintheair.json ${HTMLDIR}/dump978/
        else
            echo -e "\033[33m"
            echo "The dump978 map is able to display terrain limit rings using data obtained"
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
                sudo wget -O ${HTMLDIR}/dump978/upintheair.json "http://www.heywhatsthat.com/api/upintheair.json?id=${HEYWHATSTHATVIEWID}&refraction=0.25&alts=$HEYWHATSTHATRINGONE,$HEYWHATSTHATRINGTWO"
            fi
        fi
    fi
fi

echo -e "\033[33m"
echo -e "Setting permissions on data files...\033[37m"
sudo chmod 777 ${DOCUMENTROOT}/data/*.xml

echo -e "\033[33m"
echo -e "Removing conflicting redirect from the Lighttpd dump1090.conf file...\033[37m"
# Remove this line completely.
sudo sed -i "/$(echo '  "^/dump1090$" => "/dump1090/gmap.html"' | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g')/d" /etc/lighttpd/conf-available/89-dump1090.conf
# Remove the trailing coma from this line.
sudo sed -i "s/$(echo '"^/dump1090/$" => "/dump1090/gmap.html",' | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g')/$(echo '"^/dump1090/$" => "/dump1090/gmap.html"' | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g')/g"  /etc/lighttpd/conf-available/89-dump1090.conf

echo -e "\033[33m"
echo -e "Configuring Lighttpd...\033[37m"
sudo tee /etc/lighttpd/conf-available/89-adsb-portal.conf > /dev/null <<EOF
# Block all access to the data directory accept for local requests.
\$HTTP["remoteip"] !~ "127.0.0.1" {
    \$HTTP["url"] =~ "^/data/" {
        url.access-deny = ( "" )
    }
}
EOF

echo -e "\033[33m"
echo -e "Enabling Lighttpd portal configuration...\033[37m"
sudo ln -s /etc/lighttpd/conf-available/89-adsb-portal.conf /etc/lighttpd/conf-enabled/89-adsb-portal.conf

echo -e "\033[33m"
echo -e "Enabling the Lighttpd fastcgi-php module...\033[37m"
sudo lighty-enable-mod fastcgi-php

echo -e "\033[33m"
if pgrep "lighttpd" > /dev/null; then
    echo "Reloading Lighttpd..."
    echo -e "\033[37m"
    sudo /etc/init.d/lighttpd force-reload
else
    echo "Starting Lighttpd..."
    echo -e "\033[37m"
    sudo /etc/init.d/lighttpd start
fi

## SETUP COMPLETE

echo -e "\033[33m"
echo "Installation and configuration of the performance graphs is now complete."
echo "Please look over the output generated to be sure no errors were encountered."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

clear

# Display further portal setup instructions.
echo -e "\033[31m"
echo "PORTAL SETUP IS NOT YET COMPLETE"
echo -e "\033[33m"
echo "In order to complete the portal setup process visit the following URL in your favorite web browser."
echo ""
echo "http://<IP_ADDRESS_OF_THIS_DEVICE>/install/"
echo ""
echo "Enter the requested information and submit the form to complete the portal setup."
echo "It is recomended that after setting up the portal you delete the install directory."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

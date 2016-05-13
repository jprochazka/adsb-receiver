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

BUILDDIR="$PWD/build"

# Assign the Lighthttpd document root directory to a variable.
RAWDOCUMENTROOT=`/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root`
DOCUMENTROOT=`sed 's/.*"\(.*\)"[^"]*$/\1/' <<< $RAWDOCUMENTROOT`

## CONFIGURE DUMP1090-MUTABILITY

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
echo ""
echo "NOT SETTING LATITUDE AND LONGITUDE WILL BREAK THE RANGE PERFORMANCE GRAPH"
echo ""
echo -e "\033[37m"
read -p "Feeder Latitude: (Decimal Degrees XX-XXXXXXX) " FEEDERLAT
read -p "Feeder Longitude: (Decimal Degrees XX-XXXXXXX) " FEEDERLON
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

## SETUP THE PORTAL

echo -e "\033[31m"
echo "Do you wish to enable advanced features?"
echo -e "\033[33m"
echo "ENABLING ADVANCED FEATURES ON DEVICES USING SD CARDS CAN SHORTEN THE LIFE OF THE SD CARD IMMENSELY"
echo -e "\033[33m"
echo "By enabling advanced features the portal will log all flights seen as well as the path of the flight."
echo "This data is stored in either a MySQL or SQLite database. This will result in a lot more data being"
echo "stored on your devices hard drive. Keep this and your devices hardware capabilities in mind before"
echo "selecting to enable these features."
echo ""
echo "You have been warned."
echo -e "\033[37m"
read -p "Use portal with advanced features? [y/N] " ADVANCED

## ASK IF ADVANCED FEATURES ARE TO BE USED 

if [[ $ADVANCED =~ ^[yY]$ ]]; then
    echo -e "\033[31m"
    echo "Select Database Engine"
    echo -e "\033[33m"
    echo "  1) MySQL"
    echo "  2) SQLLite"
    echo -e "\033[37m"
    read -p "Use portal with advanced features? [1] " DATABASEENGINE

    # Check if the user is using a remote MySQL database.
    if [[ $DATABASEENGINE != 2 ]]; then
        echo -e "\033[31m"
        echo "Will the database be hosted locally on this device or remotely?"
        echo -e "\033[33m"
        echo "  1) Locally"
        echo "  2) Remotely"
        echo -e "\033[37m"
        read -p "Use portal with advanced features? [1] " LOCALDATABASE
    fi
fi

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\033[33m"
echo "Installing packages needed to build and fulfill dependencies..."
echo -e "\033[37m"
CheckPackage libpython2.7
if [[ $ADVANCED =~ ^[yY]$ ]]; then
    if [[ $DATABASEENGINE == 2 ]]; then
       CheckPackage sqlite3
       CheckPackage php5-sqlite
    else
       if [[ $LOCALDATABASE != 2 ]]; then
           # Install MySQL locally.
           CheckPackage mysql-server
       fi
       CheckPackage mysql-client
       CheckPackage php5-mysql
       CheckPackage python-mysqldb
    fi
fi

# Restart Lighttpd after installing the prerequisite packages.
echo -e "\033[33m"
echo -e "Restarting lighttpd...\033[37m"
sudo /etc/init.d/lighttpd restart

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
        read -p "Password for MySQL root user: " MYSQLROOTPASSWORD

        # Check that the supplied password is correct.
        while ! mysql -u root -p$MYSQLROOTPASSWORD -h $DATABASEHOST  -e ";" ; do
            echo -e "\033[31m"
            echo -e "Unable to connect to the MySQL server using the supplied password.\033[37m"
            read -p "Password for MySQL root user: " MYSQLROOTPASSWORD
        done

        read -p "New Database Name: " DATABASENAME
        read -p "New Database User Name: " DATABASEUSER
        read -p "New Database User Password: " DATABASEPASSWORD

        # Create the database and user as well as assign permissions.
        if [[ $DATABASEENGINE == 1 ]] || [[ $DATABASEENGINE == "" ]]; then
            echo -e "\033[33m"
            echo -e "Creating MySQL database and user...\033[37m"
            mysql -uroot -p${MYSQLROOTPASSWORD} -h $DATABASEHOST -e "CREATE DATABASE ${DATABASENAME};"
            mysql -uroot -p${MYSQLROOTPASSWORD} -h $DATABASEHOST -e "CREATE USER '${DATABASEUSER}'@'localhost' IDENTIFIED BY \"${DATABASEPASSWORD}\";";
            mysql -uroot -p${MYSQLROOTPASSWORD} -h $DATABASEHOST -e "GRANT ALL PRIVILEGES ON ${DATABASENAME}.* TO '${DATABASEUSER}'@'localhost';"
            mysql -uroot -p${MYSQLROOTPASSWORD} -h $DATABASEHOST -e "FLUSH PRIVILEGES;"
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

## FINISH CONFIGURATION

# Display further portal setup instructions.
echo -e "\033[33m"
echo "PORTAL SETUP IS NOT YET COMPLETE"
echo -e "\033[33m"
echo "In order to complete the portal setup process visit the following URL in your favorite web browser."
echo ""
echo "http://<IP_ADDRESS_OF_THIS_DEVICE>/install/"
echo ""
echo "Enter the requested information and submit the form to complete the portal setup."
echo "It is recomended that after setting up the portal you delete the install.php file."
echo -e "\033[37m"

# Remove the "image" file now that setup has been ran.
rm -f image

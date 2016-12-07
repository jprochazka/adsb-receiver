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

## VARIABLES

BACKUPDATE=$(date +"%Y-%m-%d-%H%M%S")
PROJECTROOTDIRECTORY="$PWD"
BACKUPSDIRECTORY="$PROJECTROOTDIRECTORY/backups"
TEMPORARYDIRECTORY="$PROJECTROOTDIRECTORY/backup_$BACKUPDATE"
RAWDOCUMENTROOT=`/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root`
LIGHTTPDDOCUMENTROOT=`sed 's/.*"\(.*\)"[^"]*$/\1/' <<< $RAWDOCUMENTROOT`

## BEGIN THE BACKUP PROCESS

clear
echo -e "\n\e[91m  ADSB Reciever Project Maintenance"
echo ""
echo -e "\e[92m  Backing up portal data..."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[97m"

echo ""
echo -e "\e[95m  Backing up current portal data...\e[97m"
echo ""

## PREPARE TO BEGIN CREATING BACKUPS

# Get the database type used.
echo -e "\e[94m  Declare the database engine being used...\e[97m"
DATABASEENGINE=`grep 'db_driver' $LIGHTTPDDOCUMENTROOT/classes/settings.class.php | tail -n1 | cut -d\' -f2`
echo -e "\e[94m  Declare whether or not the advnaced portal features were installed...\e[97m"

# Decide if the advanced portal features were installed or not.
echo -e "\e[94m  Declare whether or not the advnaced portal features were installed...\e[97m"
if [ $DATABASEENGINE = "xml" ]; then
    ADVANCED=FALSE
else
    ADVANCED=TRUE
fi

# Get the path to the SQLite database if SQLite is used for the database.
if [ $DATABASEENGINE = "sqlite" ]; then
    DATABASEPATH=`grep 'db_host' $LIGHTTPDDOCUMENTROOT/classes/settings.class.php | tail -n1 | cut -d\' -f2`
fi

# Assign the MySQL login credentials to variables if a MySQL database is being used.
if [ $DATABASEENGINE = "mysql" ]; then
    MYSQLDATABASE=`grep 'db_database' $LIGHTTPDDOCUMENTROOT/classes/settings.class.php | tail -n1 | cut -d\' -f2`
    MYSQLUSERNAME=`grep 'db_username' $LIGHTTPDDOCUMENTROOT/classes/settings.class.php | tail -n1 | cut -d\' -f2`
    MYSQLPASSWORD=`grep 'db_password' $LIGHTTPDDOCUMENTROOT/classes/settings.class.php | tail -n1 | cut -d\' -f2`
fi

# Check that the backup directory exists.
echo -e "\e[94m  Checking that the directory $BACKUPSDIRECTORY exists...\e[97m"
if [ ! -d "$BACKUPSDIRECTORY" ]; then
    # Create the backups directory.
    echo -e "\e[94m  Creating the directory $BACKUPSDIRECTORY...\e[97m"
    mkdir -p $BACKUPSDIRECTORY
fi

# Check that the temporary directory exists.
echo -e "\e[94m  Checking that the directory $TEMPORARYDIRECTORY exists...\e[97m"
if [ ! -d "$TEMPORARYDIRECTORY" ]; then
    # Create the tmp directory.
    echo -e "\e[94m  Creating the directory $TEMPORARYDIRECTORY...\e[97m"
    mkdir -p $TEMPORARYDIRECTORY
fi

## BACKUP THE FILES COMMON TO ALL PORTAL INSTALLATION SCENARIOS

# Copy the collectd round robin database files to the temporary directory.
echo -e "\e[94m  Checking that the directory $TEMPORARYDIRECTORY/var/lib/collectd/rrd/ exists...\e[97m"
if [ ! -d "$TEMPORARYDIRECTORY/var/lib/collectd/rrd/" ]; then
    mkdir -p $TEMPORARYDIRECTORY/var/lib/collectd/rrd/
fi
echo -e "\e[94m  Backing up the directory /var/lib/collectd/rrd/...\e[97m"
sudo cp -R /var/lib/collectd/rrd/ $TEMPORARYDIRECTORY/var/lib/collectd/rrd/

## BACKUP PORTAL USING LITE FEATURES AND XML FILES

if [ ADVANCED = "FALSE" ]; then
    # Copy the portal XML data files to the temporary directory.
    echo -e "\e[94m  Checking that the directory $TEMPORARYDIRECTORY/var/www/html/data/ exists...\e[97m"
    if [ ! -d "$TEMPORARYDIRECTORY/var/www/html/data/" ]; then
        mkdir -p $TEMPORARYDIRECTORY/var/www/html/data/
    fi
    echo -e "\e[94m  Backing up all XML data files to $TEMPORARYDIRECTORY/var/www/html/data/...\e[97m"
    sudo cp -R /var/www/html/data/*.xml $TEMPORARYDIRECTORY/var/www/html/data/
else

## BACKUP PORTAL USING ADVANCED FEATURES AND A SQLITE DATABASE

    if [ $DATABASEENGINE = "sqlite" ]; then
        # Copy the portal SQLite database file to the temporary directory.
        echo -e "\e[94m  Backing up the SQLite database file to $TEMPORARYDIRECTORY/var/www/html/data/portal.sqlite...\e[97m"
        sudo cp -R $DATABASEPATH $TEMPORARYDIRECTORY/var/www/html/data/portal.sqlite
    fi

## BACKUP PORTAL USING ADVANCED FEATURES AND A MYSQL DATABASE

    if [ $DATABASEENGINE = "mysql" ]; then
        # Dump the current MySQL database to a .sql text file.
        echo -e "\e[94m  Dumping the MySQL database $MYSQLDATABASE to the file $TEMPORARYDIRECTORY/$MYSQLDATABASE.sql...\e[97m"
        mysqldump -u$MYSQLUSERNAME -p$MYSQLPASSWORD $MYSQLDATABASE > $TEMPORARYDIRECTORY/$MYSQLDATABASE.sql
    fi
fi

## COMPRESS AND DATE THE BACKUP ARCHIVE

# Create the backup archive.
echo -e "\e[94m  Compressing the backed up files...\e[97m"
echo ""
tar -zcvf $BACKUPSDIRECTORY/adsb-receiver_data_$BACKUPDATE.tar.gz $TEMPORARYDIRECTORY
echo ""

# Remove the temporary directory.
echo -e "\e[94m  Removing the temporary backup directory...\e[97m"
sudo rm -rf $TEMPORARYDIRECTORY

## BACKUP PROCESS COMPLETE

echo -e "\e[32m"
echo -e "  BACKUP PROCESS COMPLETE\e[93m"
echo ""
echo -e "  An archive containing the data just backed up can be found at:"
echo -e "  $TEMPORARYDIRECTORY/adsb-receiver_data_$BACKUPDATE.tar.gz\e[97m"
echo ""

echo -e "\e[93m----------------------------------------------------------------------------------------------------"
echo -e "\e[92m  Finished backing up portal data.\e[39m"
echo ""
if [ ${VERBOSE} ] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

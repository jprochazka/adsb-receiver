#!/bin/bash

## VARIABLES

BACKUPDATE=$(date +"%Y-%m-%d-%H%M%S")
RECEIVER_ROOT_DIRECTORY="${PWD}"
BACKUPSDIRECTORY="${RECEIVER_ROOT_DIRECTORY}/backups"
TEMPORARY_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/backup_${BACKUPDATE}"
RAWDOCUMENTROOT=`/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root`
LIGHTTPDDOCUMENTROOT=`sed 's/.*"\(.*\)"[^"]*$/\1/' <<< ${RAWDOCUMENTROOT}`
COLLECTD_RRD_DIRECTORY="/var/lib/collectd/rrd"


## BEGIN THE BACKUP PROCESS

clear
echo -e "\n\e[91m  ADS-B Portal Maintenance"
echo -e ""
echo -e "\e[92m  Backing up portal data"
echo -e "\e[93m  ------------------------------------------------------------------------------\e[97m"

echo -e ""
echo -e "\e[95m  Backing up current portal data...\e[97m"
echo -e ""


## PREPARE TO BEGIN CREATING BACKUPS

echo -e "\e[94m  Declare the database engine being used...\e[97m"
DATABASEENGINE=`grep 'db_driver' ${LIGHTTPDDOCUMENTROOT}/classes/settings.class.php | tail -n1 | cut -d\' -f2`
echo -e "\e[94m  Declare whether or not the advanaced portal features were installed...\e[97m"

echo -e "\e[94m  Declare whether or not the advanaced portal features were installed...\e[97m"
if [[ "${DATABASEENGINE}" = "xml" ]] ; then
    ADVANCED=FALSE
else
    ADVANCED=TRUE
fi

if [[ "${DATABASEENGINE}" = "sqlite" ]] ; then
    DATABASEPATH=`grep 'db_host' ${LIGHTTPDDOCUMENTROOT}/classes/settings.class.php | tail -n1 | cut -d\' -f2`
fi

if [[ "${DATABASEENGINE}" = "mysql" ]] ; then
    MYSQLDATABASE=`grep 'db_database' ${LIGHTTPDDOCUMENTROOT}/classes/settings.class.php | tail -n1 | cut -d\' -f2`
    MYSQLUSERNAME=`grep 'db_username' ${LIGHTTPDDOCUMENTROOT}/classes/settings.class.php | tail -n1 | cut -d\' -f2`
    MYSQLPASSWORD=`grep 'db_password' ${LIGHTTPDDOCUMENTROOT}/classes/settings.class.php | tail -n1 | cut -d\' -f2`
fi

echo -e "\e[94m  Checking that the directory ${BACKUPSDIRECTORY} exists...\e[97m"
if [[ ! -d "${BACKUPSDIRECTORY}" ]] ; then
    echo -e "\e[94m  Creating the directory ${BACKUPSDIRECTORY}...\e[97m"
    mkdir -vp ${BACKUPSDIRECTORY}
fi

echo -e "\e[94m  Checking that the directory ${TEMPORARY_DIRECTORY} exists...\e[97m"
if [[ ! -d "${TEMPORARY_DIRECTORY}" ]] ; then
    echo -e "\e[94m  Creating the directory ${TEMPORARY_DIRECTORY}...\e[97m"
    mkdir -vp ${TEMPORARY_DIRECTORY}
fi


## BACKUP THE COLLECTD RRD FILES BY EXPORTING THEM TO XML.

RRD_FILE_LIST=`find ${COLLECTD_RRD_DIRECTORY} -name '*.rrd'`
if [[ -z "${RRD_FILE_LIST}" ]]; then
    echo -e "\e[94m  No RRD file found in ${COLLECTD_RRD_DIRECTORY}...\e[97m"
    echo -e "\e[94m  Skipping RRD file backups...\e[97m"
else
    for RRD_FILE in `find ${COLLECTD_RRD_DIRECTORY} -name '*.rrd'`; do
        echo -e "\e[94m  Exporting RRD files named $RRD_FILE to XML...\e[97m"
        RRD_FILE_NAME=`basename -s .rrd $RRD_FILE`
        RRD_FILE_DIRECTORY=`dirname $RRD_FILE`
        if [ ! -d ${TEMPORARY_DIRECTORY}/${RRD_FILE_DIRECTORY} ]; then
            mkdir ${TEMPORARY_DIRECTORY}/${RRD_FILE_DIRECTORY}
        fi
        sudo rrdtool dump $RRD_FILE > ${TEMPORARY_DIRECTORY}/${RRD_FILE_DIRECTORY}/${RRD_FILE_NAME}.xml
    done
fi


## BACKUP PORTAL USING LITE FEATURES AND XML FILES

if [[ "${ADVANCED}" = "FALSE" ]] ; then
    echo -e "\e[94m  Checking that the directory ${TEMPORARY_DIRECTORY}/var/www/html/data/ exists...\e[97m"
    if [[ ! -d "${TEMPORARY_DIRECTORY}/var/www/html/data/" ]] ; then
        mkdir -vp ${TEMPORARY_DIRECTORY}/var/www/html/data/
    fi
    echo -e "\e[94m  Backing up all XML data files to ${TEMPORARY_DIRECTORY}/var/www/html/data/...\e[97m"
    sudo cp -R /var/www/html/data/*.xml ${TEMPORARY_DIRECTORY}/var/www/html/data/
else


## BACKUP PORTAL USING ADVANCED FEATURES AND A SQLITE DATABASE

    if [[ "${DATABASEENGINE}" = "sqlite" ]] ; then
        echo -e "\e[94m  Backing up the SQLite database file to ${TEMPORARY_DIRECTORY}/var/www/html/data/portal.sqlite...\e[97m"
        sudo cp -R ${DATABASEPATH} ${TEMPORARY_DIRECTORY}/var/www/html/data/portal.sqlite
    fi


## BACKUP PORTAL USING ADVANCED FEATURES AND A MYSQL DATABASE

    if [[ "${DATABASEENGINE}" = "mysql" ]] ; then
        echo -e "\e[94m  Dumping the MySQL database ${MYSQLDATABASE} to the file ${TEMPORARY_DIRECTORY}/${MYSQLDATABASE}.sql...\e[97m"
        mysqldump -u${MYSQLUSERNAME} -p${MYSQLPASSWORD} ${MYSQLDATABASE} > ${TEMPORARY_DIRECTORY}/${MYSQLDATABASE}.sql
    fi
fi

## COMPRESS AND DATE THE BACKUP ARCHIVE

echo -e "\e[94m  Compressing the backed up files...\e[97m"
echo -e ""
tar -zcvf ${BACKUPSDIRECTORY}/adsb-receiver_data_${BACKUPDATE}.tar.gz ${TEMPORARY_DIRECTORY}
echo -e ""
echo -e "\e[94m  Removing the temporary backup directory...\e[97m"
sudo rm -rf ${TEMPORARY_DIRECTORY}


## BACKUP PROCESS COMPLETE

echo -e "\e[32m"
echo -e "  BACKUP PROCESS COMPLETE\e[93m"
echo -e ""
echo -e "  An archive containing the data just backed up can be found at:"
echo -e "  ${TEMPORARY_DIRECTORY}/adsb-receiver_data_${BACKUPDATE}.tar.gz\e[97m"
echo -e ""

echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  Finished backing up portal data.\e[39m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0

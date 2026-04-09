#!/bin/bash

## VARIABLES

backup_date=$(date +"%Y-%m-%d-%H%M%S")
receiver_root_directory="${PWD}"
backups_directory="${receiver_root_directory}/backups"
temporary_directory="${receiver_root_directory}/backup_${backup_date}"
lighttpd_document_root=$(/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root | sed 's/.*"\(.*\)"[^"]*$/\1/')
collectd_rrd_directory="/var/lib/collectd/rrd"


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
database_engine=$(grep 'db_driver' "${lighttpd_document_root}/classes/settings.class.php" | tail -n1 | cut -d\' -f2)

if [[ "${database_engine}" == "sqlite" ]] ; then
    database_path=$(grep 'db_host' "${lighttpd_document_root}/classes/settings.class.php" | tail -n1 | cut -d\' -f2)
fi

if [[ "${database_engine}" == "mysql" ]] ; then
    mysql_database=$(grep 'db_database' "${lighttpd_document_root}/classes/settings.class.php" | tail -n1 | cut -d\' -f2)
    mysql_username=$(grep 'db_username' "${lighttpd_document_root}/classes/settings.class.php" | tail -n1 | cut -d\' -f2)
    mysql_password=$(grep 'db_password' "${lighttpd_document_root}/classes/settings.class.php" | tail -n1 | cut -d\' -f2)
fi

echo -e "\e[94m  Checking that the directory ${backups_directory} exists...\e[97m"
if [[ ! -d "${backups_directory}" ]] ; then
    echo -e "\e[94m  Creating the directory ${backups_directory}...\e[97m"
    mkdir -vp "${backups_directory}"
fi

echo -e "\e[94m  Checking that the directory ${temporary_directory} exists...\e[97m"
if [[ ! -d "${temporary_directory}" ]] ; then
    echo -e "\e[94m  Creating the directory ${temporary_directory}...\e[97m"
    mkdir -vp "${temporary_directory}"
fi


## BACKUP THE COLLECTD RRD FILES BY EXPORTING THEM TO XML.

mapfile -t rrd_files < <(find "${collectd_rrd_directory}" -name '*.rrd')
if [[ ${#rrd_files[@]} -eq 0 ]]; then
    echo -e "\e[94m  No RRD file found in ${collectd_rrd_directory}...\e[97m"
    echo -e "\e[94m  Skipping RRD file backups...\e[97m"
else
    for rrd_file in "${rrd_files[@]}"; do
        echo -e "\e[94m  Exporting RRD files named ${rrd_file} to XML...\e[97m"
        rrd_file_name=$(basename -s .rrd "${rrd_file}")
        rrd_file_directory=$(dirname "${rrd_file}")
        if [[ ! -d "${temporary_directory}/${rrd_file_directory}" ]]; then
            mkdir -p "${temporary_directory}/${rrd_file_directory}"
        fi
        sudo rrdtool dump "${rrd_file}" > "${temporary_directory}/${rrd_file_directory}/${rrd_file_name}.xml"
    done
fi


## BACKUP PORTAL USING LITE FEATURES AND XML FILES

if [[ "${database_engine}" == "xml" ]] ; then
    echo -e "\e[94m  Checking that the directory ${temporary_directory}/var/www/html/data/ exists...\e[97m"
    if [[ ! -d "${temporary_directory}/var/www/html/data/" ]] ; then
        mkdir -vp "${temporary_directory}/var/www/html/data/"
    fi
    echo -e "\e[94m  Backing up all XML data files to ${temporary_directory}/var/www/html/data/...\e[97m"
    sudo cp -R /var/www/html/data/*.xml "${temporary_directory}/var/www/html/data/"
else


## BACKUP PORTAL USING ADVANCED FEATURES AND A SQLITE DATABASE

    if [[ "${database_engine}" == "sqlite" ]] ; then
        echo -e "\e[94m  Backing up the SQLite database file to ${temporary_directory}/var/www/html/data/portal.sqlite...\e[97m"
        sudo cp -R "${database_path}" "${temporary_directory}/var/www/html/data/portal.sqlite"
    fi


## BACKUP PORTAL USING ADVANCED FEATURES AND A MYSQL DATABASE

    if [[ "${database_engine}" == "mysql" ]] ; then
        echo -e "\e[94m  Dumping the MySQL database ${mysql_database} to the file ${temporary_directory}/${mysql_database}.sql...\e[97m"
        mysqldump -u"${mysql_username}" -p"${mysql_password}" "${mysql_database}" > "${temporary_directory}/${mysql_database}.sql"
    fi
fi

## COMPRESS AND DATE THE BACKUP ARCHIVE

echo -e "\e[94m  Compressing the backed up files...\e[97m"
echo -e ""
tar -zcvf "${backups_directory}/adsb-receiver_data_${backup_date}.tar.gz" "${temporary_directory}"
echo -e ""
echo -e "\e[94m  Removing the temporary backup directory...\e[97m"
sudo rm -rf "${temporary_directory}"


## BACKUP PROCESS COMPLETE

echo -e "\e[32m"
echo -e "  BACKUP PROCESS COMPLETE\e[93m"
echo -e ""
echo -e "  An archive containing the data just backed up can be found at:"
echo -e "  ${backups_directory}/adsb-receiver_data_${backup_date}.tar.gz\e[97m"
echo -e ""

echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  Finished backing up portal data.\e[39m"
echo -e ""
if [[ "${receiver_automated_install}" == "false" ]] ; then
    read -r -p "Press enter to continue..." discard
fi

exit 0

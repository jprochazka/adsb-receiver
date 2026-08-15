#!/bin/bash

## VARIABLES

backup_date=$(date +"%Y-%m-%d-%H%M%S")
receiver_root_directory="${PWD}"
backups_directory="${receiver_root_directory}/backups"
temporary_directory="${receiver_root_directory}/backup_${backup_date}"
collectd_rrd_directory="/var/lib/collectd/rrd"

# Resolve the lighttpd document root dynamically.
lighttpd_document_root=""
if command -v lighttpd >/dev/null 2>&1 && [[ -f /etc/lighttpd/lighttpd.conf ]]; then
    lighttpd_document_root=$(/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p 2>/dev/null \
        | grep 'server.document-root' \
        | sed 's/.*"\(.*\)"[^"]*$/\1/' \
        | head -n1)
fi
if [[ -z "${lighttpd_document_root}" ]]; then
    lighttpd_document_root="/var/www/html"
fi


## BEGIN THE BACKUP PROCESS

clear
echo -e "\n\e[91m  ADS-B Portal Maintenance"
echo -e ""
echo -e "\e[92m  Backing up portal data (legacy v2 portal)"
echo -e "\e[93m  ------------------------------------------------------------------------------\e[97m"

echo -e ""
echo -e "\e[95m  Backing up current portal data...\e[97m"
echo -e ""


## PREPARE TO BEGIN CREATING BACKUPS

echo -e "\e[94m  Detecting legacy portal configuration at ${lighttpd_document_root}...\e[97m"
settings_file="${lighttpd_document_root}/classes/settings.class.php"
if [[ ! -f "${settings_file}" ]]; then
    echo -e "\e[91m  ERROR: settings.class.php not found at ${settings_file}. Aborting.\e[97m"
    exit 1
fi

database_engine=$(grep 'db_driver' "${settings_file}" | tail -n1 | cut -d\' -f2)
echo -e "\e[94m  Database engine: ${database_engine}\e[97m"

if [[ "${database_engine}" == "sqlite" ]]; then
    # Old installer stored the full path in db_host for SQLite.
    database_path=$(grep 'db_host' "${settings_file}" | tail -n1 | cut -d\' -f2)
fi

if [[ "${database_engine}" == "mysql" ]]; then
    mysql_database=$(grep 'db_database' "${settings_file}" | tail -n1 | cut -d\' -f2)
    mysql_username=$(grep 'db_username' "${settings_file}" | tail -n1 | cut -d\' -f2)
    mysql_pass=$(grep 'db_password' "${settings_file}" | tail -n1 | cut -d\' -f2)
fi

if [[ "${database_engine}" == "pgsql" ]]; then
    pgsql_database=$(grep 'db_database' "${settings_file}" | tail -n1 | cut -d\' -f2)
    pgsql_username=$(grep 'db_username' "${settings_file}" | tail -n1 | cut -d\' -f2)
    pgsql_pass=$(grep 'db_password' "${settings_file}" | tail -n1 | cut -d\' -f2)
    pgsql_host=$(grep 'db_host'     "${settings_file}" | tail -n1 | cut -d\' -f2)
fi

echo -e "\e[94m  Checking that the directory ${backups_directory} exists...\e[97m"
if [[ ! -d "${backups_directory}" ]]; then
    echo -e "\e[94m  Creating the directory ${backups_directory}...\e[97m"
    mkdir -vp "${backups_directory}"
fi

echo -e "\e[94m  Checking that the directory ${temporary_directory} exists...\e[97m"
if [[ ! -d "${temporary_directory}" ]]; then
    echo -e "\e[94m  Creating the directory ${temporary_directory}...\e[97m"
    mkdir -vp "${temporary_directory}"
fi


## BACKUP settings.class.php (needed to reconnect to the DB on restore)

echo -e "\e[94m  Backing up portal settings file...\e[97m"
settings_backup_dir="${temporary_directory}${lighttpd_document_root}/classes"
mkdir -p "${settings_backup_dir}"
sudo cp "${settings_file}" "${settings_backup_dir}/settings.class.php"


## BACKUP THE COLLECTD RRD FILES BY EXPORTING THEM TO XML

mapfile -t rrd_files < <(find "${collectd_rrd_directory}" -name '*.rrd' 2>/dev/null)
if [[ ${#rrd_files[@]} -eq 0 ]]; then
    echo -e "\e[94m  No RRD files found in ${collectd_rrd_directory}...\e[97m"
    echo -e "\e[94m  Skipping RRD file backups...\e[97m"
else
    for rrd_file in "${rrd_files[@]}"; do
        echo -e "\e[94m  Exporting ${rrd_file} to XML...\e[97m"
        rrd_file_name=$(basename -s .rrd "${rrd_file}")
        rrd_file_directory=$(dirname "${rrd_file}")
        if [[ ! -d "${temporary_directory}/${rrd_file_directory}" ]]; then
            mkdir -p "${temporary_directory}/${rrd_file_directory}"
        fi
        sudo rrdtool dump "${rrd_file}" > "${temporary_directory}/${rrd_file_directory}/${rrd_file_name}.xml"
    done
fi


## BACKUP PORTAL DATA

data_backup_dir="${temporary_directory}${lighttpd_document_root}/data"
mkdir -p "${data_backup_dir}"

if [[ "${database_engine}" == "xml" ]]; then

    ## XML lite install — back up all XML data files

    echo -e "\e[94m  Backing up XML data files from ${lighttpd_document_root}/data/...\e[97m"
    sudo cp -R "${lighttpd_document_root}/data/"*.xml "${data_backup_dir}/"

elif [[ "${database_engine}" == "sqlite" ]]; then

    ## SQLite — copy the database file

    echo -e "\e[94m  Backing up SQLite database from ${database_path}...\e[97m"
    sudo cp -R "${database_path}" "${data_backup_dir}/portal.sqlite"

elif [[ "${database_engine}" == "mysql" ]]; then

    ## MySQL — dump the database

    echo -e "\e[94m  Dumping MySQL database ${mysql_database}...\e[97m"
    mysqldump -u"${mysql_username}" -p"${mysql_pass}" "${mysql_database}" \
        > "${temporary_directory}/${mysql_database}.sql"

elif [[ "${database_engine}" == "pgsql" ]]; then

    ## PostgreSQL — dump the database

    echo -e "\e[94m  Dumping PostgreSQL database ${pgsql_database}...\e[97m"
    PGPASSWORD="${pgsql_pass}" pg_dump \
        -h "${pgsql_host}" \
        -U "${pgsql_username}" \
        "${pgsql_database}" \
        > "${temporary_directory}/${pgsql_database}.sql"

else
    echo -e "\e[91m  WARNING: Unknown database engine '${database_engine}'. Database not backed up.\e[97m"
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
if [[ "${receiver_automated_install}" == "false" ]]; then
    read -r -p "Press enter to continue..." discard
fi

exit 0

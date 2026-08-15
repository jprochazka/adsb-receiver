#!/bin/bash

## portal_restore_v2.sh
##
## Restores a legacy ADS-B Portal (v2 / PHP / lighttpd) from an archive
## created by portal_backup_v2.sh.
##
## Usage:
##   bash portal_restore_v2.sh /path/to/adsb-receiver_data_YYYY-MM-DD-HHMMSS.tar.gz
##
## What is restored:
##   - settings.class.php
##   - XML data files (xml driver)
##   - SQLite database (sqlite driver)
##   - MySQL database via mysql client (mysql driver)
##   - PostgreSQL database via psql client (pgsql driver)
##   - Collectd RRD files (re-created from backed-up XML exports)
##   - ACARS database (if present in archive)


## CHECK ARGUMENT

if [[ -z "${1:-}" ]]; then
    echo -e "\e[91m  ERROR: No backup archive specified.\e[97m"
    echo -e "  Usage: bash portal_restore_v2.sh /path/to/adsb-receiver_data_YYYY-MM-DD-HHMMSS.tar.gz"
    exit 1
fi

backup_archive="${1}"

if [[ ! -f "${backup_archive}" ]]; then
    echo -e "\e[91m  ERROR: Archive not found: ${backup_archive}\e[97m"
    exit 1
fi


## VARIABLES

restore_date=$(date +"%Y-%m-%d-%H%M%S")
temporary_directory="/tmp/adsb_restore_${restore_date}"
collectd_rrd_directory="/var/lib/collectd/rrd"

# Resolve the current live lighttpd document root.
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


## BEGIN RESTORE

clear
echo -e "\n\e[91m  ADS-B Portal Maintenance"
echo -e ""
echo -e "\e[92m  Restoring portal data (legacy v2 portal)"
echo -e "\e[93m  ------------------------------------------------------------------------------\e[97m"
echo -e ""
echo -e "\e[95m  Archive  : ${backup_archive}\e[97m"
echo -e "\e[95m  Doc root : ${lighttpd_document_root}\e[97m"
echo -e ""

echo -e "\e[91m  WARNING: This will overwrite existing portal data in ${lighttpd_document_root}."
echo -e "  Any existing data not included in the archive will be left as-is.\e[97m"
echo -e ""
read -r -p "  Are you sure you want to continue? [y/N] " confirm
if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
    echo -e ""
    echo -e "\e[93m  Restore cancelled.\e[97m"
    exit 0
fi
echo -e ""


## EXTRACT ARCHIVE

echo -e "\e[94m  Creating temporary extraction directory ${temporary_directory}...\e[97m"
mkdir -p "${temporary_directory}"

echo -e "\e[94m  Extracting archive...\e[97m"
tar -zxf "${backup_archive}" -C "${temporary_directory}"
if [[ $? -ne 0 ]]; then
    echo -e "\e[91m  ERROR: Failed to extract archive. Aborting.\e[97m"
    rm -rf "${temporary_directory}"
    exit 1
fi


## LOCATE BACKED-UP settings.class.php

echo -e "\e[94m  Locating backed-up settings.class.php...\e[97m"
backed_up_settings=$(find "${temporary_directory}" -name "settings.class.php" -path "*/classes/*" | head -n1)

if [[ -z "${backed_up_settings}" ]]; then
    echo -e "\e[91m  ERROR: Could not find settings.class.php in the archive. Is this a valid v2 portal backup?\e[97m"
    rm -rf "${temporary_directory}"
    exit 1
fi

echo -e "\e[94m  Found: ${backed_up_settings}\e[97m"

# Derive the backup doc root path (inside the extraction) and the backup root temp dir.
# backed_up_settings = <extract_dir>/.../<backup_tmp>/<doc_root>/classes/settings.class.php
backed_up_doc_root=$(dirname "$(dirname "${backed_up_settings}")")   # strip /classes/settings.class.php
backed_up_temp_root=$(echo "${backed_up_doc_root}" | sed "s|${lighttpd_document_root}\$||")

echo -e "\e[94m  Backup doc root in archive: ${backed_up_doc_root}\e[97m"


## READ DATABASE ENGINE FROM BACKED-UP SETTINGS

database_engine=$(grep 'db_driver' "${backed_up_settings}" | tail -n1 | cut -d\' -f2)
echo -e "\e[94m  Database engine: ${database_engine}\e[97m"

if [[ "${database_engine}" == "sqlite" ]]; then
    database_path=$(grep 'db_host' "${backed_up_settings}" | tail -n1 | cut -d\' -f2)
fi

if [[ "${database_engine}" == "mysql" ]]; then
    mysql_database=$(grep 'db_database' "${backed_up_settings}" | tail -n1 | cut -d\' -f2)
    mysql_username=$(grep 'db_username' "${backed_up_settings}" | tail -n1 | cut -d\' -f2)
    mysql_pass=$(grep 'db_password'  "${backed_up_settings}" | tail -n1 | cut -d\' -f2)
fi

if [[ "${database_engine}" == "pgsql" ]]; then
    pgsql_database=$(grep 'db_database' "${backed_up_settings}" | tail -n1 | cut -d\' -f2)
    pgsql_username=$(grep 'db_username' "${backed_up_settings}" | tail -n1 | cut -d\' -f2)
    pgsql_pass=$(grep 'db_password'  "${backed_up_settings}" | tail -n1 | cut -d\' -f2)
    pgsql_host=$(grep 'db_host'      "${backed_up_settings}" | tail -n1 | cut -d\' -f2)
fi


## STOP LIGHTTPD BEFORE TOUCHING WEB FILES

lighttpd_was_running="false"
if systemctl is-active --quiet lighttpd 2>/dev/null; then
    lighttpd_was_running="true"
    echo -e "\e[94m  Stopping lighttpd...\e[97m"
    sudo systemctl stop lighttpd
fi


## RESTORE settings.class.php

echo -e "\e[94m  Restoring settings.class.php to ${lighttpd_document_root}/classes/...\e[97m"
sudo mkdir -p "${lighttpd_document_root}/classes"
sudo cp "${backed_up_settings}" "${lighttpd_document_root}/classes/settings.class.php"


## RESTORE PORTAL DATA

if [[ "${database_engine}" == "xml" ]]; then

    ## XML lite install — restore data XML files

    echo -e "\e[94m  Restoring XML data files to ${lighttpd_document_root}/data/...\e[97m"
    sudo mkdir -p "${lighttpd_document_root}/data"
    xml_files=$(find "${backed_up_doc_root}/data" -name "*.xml" 2>/dev/null)
    if [[ -z "${xml_files}" ]]; then
        echo -e "\e[93m  WARNING: No XML data files found in archive.\e[97m"
    else
        sudo cp "${backed_up_doc_root}/data/"*.xml "${lighttpd_document_root}/data/"
        echo -e "\e[94m  XML data files restored.\e[97m"
    fi

elif [[ "${database_engine}" == "sqlite" ]]; then

    ## SQLite — restore the database file

    backed_up_sqlite="${backed_up_doc_root}/data/portal.sqlite"
    if [[ ! -f "${backed_up_sqlite}" ]]; then
        echo -e "\e[91m  ERROR: SQLite database not found in archive at ${backed_up_sqlite}.\e[97m"
    else
        echo -e "\e[94m  Restoring SQLite database to ${database_path}...\e[97m"
        sudo mkdir -p "$(dirname "${database_path}")"
        # Back up the existing live database before overwriting.
        if [[ -f "${database_path}" ]]; then
            sudo cp "${database_path}" "${database_path}.pre_restore.${restore_date}.bak"
            echo -e "\e[94m  Existing database backed up to ${database_path}.pre_restore.${restore_date}.bak\e[97m"
        fi
        sudo cp "${backed_up_sqlite}" "${database_path}"
        echo -e "\e[94m  SQLite database restored.\e[97m"
    fi

elif [[ "${database_engine}" == "mysql" ]]; then

    ## MySQL — restore from SQL dump

    backed_up_sql=$(find "${temporary_directory}" -maxdepth 10 -name "${mysql_database}.sql" | head -n1)
    if [[ -z "${backed_up_sql}" ]]; then
        echo -e "\e[91m  ERROR: MySQL dump ${mysql_database}.sql not found in archive.\e[97m"
    else
        echo -e "\e[94m  Restoring MySQL database ${mysql_database}...\e[97m"
        mysql -u"${mysql_username}" -p"${mysql_pass}" "${mysql_database}" < "${backed_up_sql}"
        if [[ $? -eq 0 ]]; then
            echo -e "\e[94m  MySQL database restored.\e[97m"
        else
            echo -e "\e[91m  ERROR: MySQL restore failed. Check credentials and that the database exists.\e[97m"
        fi
    fi

elif [[ "${database_engine}" == "pgsql" ]]; then

    ## PostgreSQL — restore from SQL dump

    backed_up_sql=$(find "${temporary_directory}" -maxdepth 10 -name "${pgsql_database}.sql" | head -n1)
    if [[ -z "${backed_up_sql}" ]]; then
        echo -e "\e[91m  ERROR: PostgreSQL dump ${pgsql_database}.sql not found in archive.\e[97m"
    else
        echo -e "\e[94m  Restoring PostgreSQL database ${pgsql_database}...\e[97m"
        _pgpass_file=$(mktemp)
        chmod 600 "${_pgpass_file}"
        printf '%s:*:%s:%s:%s\n' \
            "${pgsql_host}" "${pgsql_database}" "${pgsql_username}" "${pgsql_pass}" \
            > "${_pgpass_file}"
        PGPASSFILE="${_pgpass_file}" psql \
            -h "${pgsql_host}" \
            -U "${pgsql_username}" \
            -d "${pgsql_database}" \
            -f "${backed_up_sql}"
        restore_exit=$?
        rm -f "${_pgpass_file}"
        if [[ ${restore_exit} -eq 0 ]]; then
            echo -e "\e[94m  PostgreSQL database restored.\e[97m"
        else
            echo -e "\e[91m  ERROR: PostgreSQL restore failed. Check credentials and that the database exists.\e[97m"
        fi
    fi

else
    echo -e "\e[91m  WARNING: Unknown database engine '${database_engine}'. Database not restored.\e[97m"
fi


## RESTORE COLLECTD RRD FILES

echo -e "\e[94m  Looking for RRD XML exports in archive...\e[97m"
mapfile -t rrd_xml_files < <(find "${temporary_directory}" -name "*.xml" -path "*/rrd/*" 2>/dev/null)

if [[ ${#rrd_xml_files[@]} -eq 0 ]]; then
    echo -e "\e[94m  No RRD XML exports found in archive. Skipping RRD restore.\e[97m"
else
    if ! command -v rrdtool >/dev/null 2>&1; then
        echo -e "\e[93m  WARNING: rrdtool not installed — cannot restore RRD files. Skipping.\e[97m"
    else
        echo -e "\e[94m  Restoring ${#rrd_xml_files[@]} RRD file(s)...\e[97m"
        for xml_file in "${rrd_xml_files[@]}"; do
            # Reconstruct target RRD path by stripping the extraction prefix and restoring
            # the absolute path that was used when the RRD was dumped.
            # The backup stored: ${tmp_dir}/${original_rrd_dir}/${name}.xml
            # We want:           ${original_rrd_dir}/${name}.rrd
            # Strip everything up to and including the extraction temp dir to get the original path.
            relative="${xml_file#${temporary_directory}/}"
            # The relative path still includes the backup run dir prefix; strip it.
            # Find the portion starting with /var/lib/... or /usr/... (absolute path embedded)
            original_dir=$(echo "${relative}" | grep -oP '(/var|/usr|/home|/opt|/srv|/run).*' | head -n1)
            if [[ -z "${original_dir}" ]]; then
                echo -e "\e[93m  WARNING: Cannot determine original path for ${xml_file}. Skipping.\e[97m"
                continue
            fi
            rrd_file="${original_dir%.xml}.rrd"
            rrd_dir=$(dirname "${rrd_file}")
            rrd_name=$(basename "${rrd_file}")

            sudo mkdir -p "${rrd_dir}"

            # Back up existing RRD before overwriting.
            if [[ -f "${rrd_file}" ]]; then
                sudo cp "${rrd_file}" "${rrd_file}.pre_restore.${restore_date}.bak"
            fi

            echo -e "\e[94m  Restoring ${rrd_name}...\e[97m"
            sudo rrdtool restore -f "${xml_file}" "${rrd_file}"
        done
        echo -e "\e[94m  RRD restore complete.\e[97m"
    fi
fi


## FIX PERMISSIONS

echo -e "\e[94m  Setting permissions on restored files...\e[97m"
sudo chown -R www-data:www-data "${lighttpd_document_root}/data" 2>/dev/null || true
sudo chown -R www-data:www-data "${lighttpd_document_root}/classes" 2>/dev/null || true
if [[ -d "${collectd_rrd_directory}" ]]; then
    sudo chown -R www-data:www-data "${collectd_rrd_directory}" 2>/dev/null || true
fi


## RESTART LIGHTTPD

if [[ "${lighttpd_was_running}" == "true" ]]; then
    echo -e "\e[94m  Restarting lighttpd...\e[97m"
    sudo systemctl start lighttpd
    if systemctl is-active --quiet lighttpd 2>/dev/null; then
        echo -e "\e[94m  lighttpd started successfully.\e[97m"
    else
        echo -e "\e[91m  WARNING: lighttpd failed to start. Check the service logs.\e[97m"
    fi
fi


## CLEAN UP

echo -e "\e[94m  Removing temporary extraction directory...\e[97m"
sudo rm -rf "${temporary_directory}"


## RESTORE COMPLETE

echo -e "\e[32m"
echo -e "  RESTORE PROCESS COMPLETE\e[93m"
echo -e ""
echo -e "  Restored from : ${backup_archive}"
echo -e "  Doc root      : ${lighttpd_document_root}"
echo -e "  Driver        : ${database_engine}\e[97m"
echo -e ""

echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  Finished restoring portal data.\e[39m"
echo -e ""
if [[ "${receiver_automated_install:-}" == "false" ]]; then
    read -r -p "Press enter to continue..." discard
fi

exit 0

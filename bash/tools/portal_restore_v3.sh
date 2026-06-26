#!/bin/bash

## portal_restore_v3.sh
##
## Restores the new ADS-B Portal (Flask/Angular, cleanup branch) from an
## archive created by portal_backup_v3.sh.
##
## Usage:
##   bash portal_restore_v3.sh /path/to/adsb-portal_v3_YYYY-MM-DD-HHMMSS.tar.gz \
##       [--backend-dir /path/to/backend]
##
## What is restored:
##   - config.yml
##   - SQLite database               (instance/adsbportal.sqlite3)
##   - MySQL database                (mysql client)
##   - PostgreSQL database           (psql via .pgpass)
##   - RRD files                     (rrdtool restore from XML exports)
##   - OpenSky classification cache  (instance/opensky/)
##   - ACARS database                (instance/acarsdec.sqlite or configured path)
##
## After database restore, flask db upgrade is run to ensure the schema
## is current relative to the installed migration head.
##
## --backend-dir is optional. When omitted the script discovers the backend
## directory from the running systemd service unit, then falls back to
## common installation paths.


## CHECK ARGUMENTS

if [[ -z "${1:-}" || "${1}" == --* ]]; then
    echo -e "\e[91m  ERROR: No backup archive specified.\e[97m"
    echo -e "  Usage: bash portal_restore_v3.sh /path/to/adsb-portal_v3_DATE.tar.gz [--backend-dir /path]"
    exit 1
fi

backup_archive="${1}"
shift

if [[ ! -f "${backup_archive}" ]]; then
    echo -e "\e[91m  ERROR: Archive not found: ${backup_archive}\e[97m"
    exit 1
fi


## PARSE REMAINING ARGUMENTS

backend_dir_override=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --backend-dir)
            backend_dir_override="$2"
            shift 2
            ;;
        *)
            echo -e "\e[91m  ERROR: Unknown argument: $1\e[97m"
            echo -e "  Usage: bash portal_restore_v3.sh /path/to/archive.tar.gz [--backend-dir /path]"
            exit 1
            ;;
    esac
done


## VARIABLES

restore_date=$(date +"%Y-%m-%d-%H%M%S")
temporary_directory="/tmp/adsb_restore_v3_${restore_date}"
systemd_service="adsb-portal-backend.service"


## LOCATE LIVE BACKEND DIRECTORY

if [[ -n "${backend_dir_override}" ]]; then
    backend_dir="${backend_dir_override}"
else
    backend_dir=""
    if systemctl is-active --quiet "${systemd_service}" 2>/dev/null || \
       systemctl is-enabled --quiet "${systemd_service}" 2>/dev/null; then
        backend_dir=$(systemctl cat "${systemd_service}" 2>/dev/null \
            | grep '^WorkingDirectory=' | head -n1 | cut -d= -f2-)
    fi

    if [[ -z "${backend_dir}" ]]; then
        for candidate in \
            "/usr/local/share/adsb-receiver/build/portal/backend" \
            "/opt/adsb-receiver/build/portal/backend" \
            "${HOME}/adsb-receiver/build/portal/backend"; do
            if [[ -f "${candidate}/config.yml" ]]; then
                backend_dir="${candidate}"
                break
            fi
        done
    fi
fi

if [[ -z "${backend_dir}" ]]; then
    echo -e "\e[91m  ERROR: Could not locate the portal backend directory."
    echo -e "  Please specify it with --backend-dir /path/to/backend\e[97m"
    exit 1
fi

instance_dir="${backend_dir}/instance"
venv_dir="${backend_dir}/.venv"
live_config="${backend_dir}/config.yml"


## BEGIN RESTORE

clear
echo -e "\n\e[91m  ADS-B Portal Maintenance"
echo -e ""
echo -e "\e[92m  Restoring portal data (v3 — Flask/Angular portal)"
echo -e "\e[93m  ------------------------------------------------------------------------------\e[97m"
echo -e ""
echo -e "\e[95m  Archive  : ${backup_archive}\e[97m"
echo -e "\e[95m  Backend  : ${backend_dir}\e[97m"
echo -e ""
echo -e "\e[91m  WARNING: This will overwrite the portal database, config, and cached data."
echo -e "  Existing files will be backed up to *.pre_restore.${restore_date}.bak before"
echo -e "  being replaced.\e[97m"
echo -e ""
read -r -p "  Are you sure you want to continue? [y/N] " confirm
if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
    echo -e ""
    echo -e "\e[93m  Restore cancelled.\e[97m"
    exit 0
fi
echo -e ""


## EXTRACT ARCHIVE

echo -e "\e[94m  Creating temporary extraction directory...\e[97m"
mkdir -p "${temporary_directory}"

echo -e "\e[94m  Extracting archive...\e[97m"
tar -zxf "${backup_archive}" -C "${temporary_directory}"
if [[ $? -ne 0 ]]; then
    echo -e "\e[91m  ERROR: Failed to extract archive. Aborting.\e[97m"
    rm -rf "${temporary_directory}"
    exit 1
fi


## LOCATE AND READ BACKED-UP config.yml

backed_up_config="${temporary_directory}/config.yml"
if [[ ! -f "${backed_up_config}" ]]; then
    echo -e "\e[91m  ERROR: config.yml not found in archive. Is this a valid v3 portal backup?\e[97m"
    rm -rf "${temporary_directory}"
    exit 1
fi

echo -e "\e[94m  Reading configuration from backed-up config.yml...\e[97m"

db_driver=$(python3 -c "
import yaml
with open('${backed_up_config}') as f: cfg = yaml.safe_load(f)
print(cfg.get('database', {}).get('use', 'sqlite'))
")

rrd_base_backed_up=$(python3 -c "
import yaml
with open('${backed_up_config}') as f: cfg = yaml.safe_load(f)
val = cfg.get('graphs', {}).get('rrd_base', 'instance/rrd')
print(val if val.startswith('/') else '${backend_dir}/' + val)
")

acars_db=$(python3 -c "
import yaml
with open('${backed_up_config}') as f: cfg = yaml.safe_load(f)
val = cfg.get('acars', {}).get('database', '')
if val and not val.startswith('/'):
    val = '${backend_dir}/' + val
print(val)
")

echo -e "\e[94m  DB driver : ${db_driver}\e[97m"
echo -e "\e[94m  RRD base  : ${rrd_base_backed_up}\e[97m"
echo -e "\e[94m  ACARS db  : ${acars_db}\e[97m"

# Read driver-specific credentials from the backed-up config.
if [[ "${db_driver}" == "mysql" ]]; then
    mysql_host=$(    python3 -c "import yaml; c=yaml.safe_load(open('${backed_up_config}')); m=c['database']['mysql']; print(m.get('host','127.0.0.1'))")
    mysql_database=$(python3 -c "import yaml; c=yaml.safe_load(open('${backed_up_config}')); m=c['database']['mysql']; print(m.get('database','adsbportal'))")
    mysql_username=$(python3 -c "import yaml; c=yaml.safe_load(open('${backed_up_config}')); m=c['database']['mysql']; print(m.get('user','portaluser'))")
    mysql_pass=$(    python3 -c "import yaml; c=yaml.safe_load(open('${backed_up_config}')); m=c['database']['mysql']; print(m.get('password',''))")
fi

if [[ "${db_driver}" == "postgresql" ]]; then
    pgsql_host=$(    python3 -c "import yaml; c=yaml.safe_load(open('${backed_up_config}')); p=c['database']['postgresql']; print(p.get('host','127.0.0.1'))")
    pgsql_database=$(python3 -c "import yaml; c=yaml.safe_load(open('${backed_up_config}')); p=c['database']['postgresql']; print(p.get('database','adsbportal'))")
    pgsql_username=$(python3 -c "import yaml; c=yaml.safe_load(open('${backed_up_config}')); p=c['database']['postgresql']; print(p.get('user','portaluser'))")
    pgsql_pass=$(    python3 -c "import yaml; c=yaml.safe_load(open('${backed_up_config}')); p=c['database']['postgresql']; print(p.get('password',''))")
fi


## STOP BACKEND SERVICE

service_was_running="false"
if systemctl is-active --quiet "${systemd_service}" 2>/dev/null; then
    service_was_running="true"
    echo -e "\e[94m  Stopping ${systemd_service}...\e[97m"
    sudo systemctl stop "${systemd_service}"
fi


## RESTORE config.yml

echo -e "\e[94m  Restoring config.yml...\e[97m"
if [[ -f "${live_config}" ]]; then
    sudo cp "${live_config}" "${live_config}.pre_restore.${restore_date}.bak"
    echo -e "\e[94m  Existing config.yml backed up.\e[97m"
fi
sudo cp "${backed_up_config}" "${live_config}"


## RESTORE DATABASE

if [[ "${db_driver}" == "sqlite" ]]; then

    sqlite_path="${instance_dir}/adsbportal.sqlite3"
    backed_up_sqlite="${temporary_directory}/instance/adsbportal.sqlite3"

    if [[ ! -f "${backed_up_sqlite}" ]]; then
        echo -e "\e[91m  ERROR: SQLite database not found in archive at instance/adsbportal.sqlite3.\e[97m"
    else
        echo -e "\e[94m  Restoring SQLite database...\e[97m"
        sudo mkdir -p "${instance_dir}"
        if [[ -f "${sqlite_path}" ]]; then
            sudo cp "${sqlite_path}" "${sqlite_path}.pre_restore.${restore_date}.bak"
            echo -e "\e[94m  Existing database backed up.\e[97m"
        fi
        sudo cp "${backed_up_sqlite}" "${sqlite_path}"
        echo -e "\e[94m  SQLite database restored.\e[97m"
    fi

elif [[ "${db_driver}" == "mysql" ]]; then

    backed_up_sql="${temporary_directory}/${mysql_database}.sql"
    if [[ ! -f "${backed_up_sql}" ]]; then
        echo -e "\e[91m  ERROR: MySQL dump ${mysql_database}.sql not found in archive.\e[97m"
    else
        echo -e "\e[94m  Restoring MySQL database ${mysql_database}...\e[97m"
        mysql \
            -h "${mysql_host}" \
            -u "${mysql_username}" \
            -p"${mysql_pass}" \
            "${mysql_database}" < "${backed_up_sql}"
        if [[ $? -eq 0 ]]; then
            echo -e "\e[94m  MySQL database restored.\e[97m"
        else
            echo -e "\e[91m  ERROR: MySQL restore failed. Check credentials and that the database exists.\e[97m"
        fi
    fi

elif [[ "${db_driver}" == "postgresql" ]]; then

    backed_up_sql="${temporary_directory}/${pgsql_database}.sql"
    if [[ ! -f "${backed_up_sql}" ]]; then
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
    echo -e "\e[93m  WARNING: Unknown database driver '${db_driver}'. Database not restored.\e[97m"
fi


## RUN FLASK DB UPGRADE (ensure schema is current after restore)

if [[ -f "${venv_dir}/bin/flask" ]]; then
    echo -e "\e[94m  Running flask db upgrade to ensure schema is current...\e[97m"
    (cd "${backend_dir}" && FLASK_APP=backend "${venv_dir}/bin/flask" db upgrade 2>&1)
    if [[ $? -eq 0 ]]; then
        echo -e "\e[94m  Schema migration check complete.\e[97m"
    else
        echo -e "\e[91m  WARNING: flask db upgrade reported an error. Check the migration state manually.\e[97m"
    fi
else
    echo -e "\e[93m  WARNING: Flask venv not found at ${venv_dir}. Skipping schema upgrade check.\e[97m"
fi


## RESTORE RRD FILES

rrd_archive_dir="${temporary_directory}/rrd"
if [[ ! -d "${rrd_archive_dir}" ]]; then
    echo -e "\e[94m  No RRD data found in archive. Skipping RRD restore.\e[97m"
else
    mapfile -t rrd_xml_files < <(find "${rrd_archive_dir}" -type f -name '*.xml' 2>/dev/null)
    if [[ ${#rrd_xml_files[@]} -eq 0 ]]; then
        echo -e "\e[94m  No RRD XML exports found in archive. Skipping.\e[97m"
    elif ! command -v rrdtool >/dev/null 2>&1; then
        echo -e "\e[93m  WARNING: rrdtool not installed — cannot restore RRD files. Skipping.\e[97m"
    else
        echo -e "\e[94m  Restoring ${#rrd_xml_files[@]} RRD file(s)...\e[97m"
        for xml_file in "${rrd_xml_files[@]}"; do
            # The backup stored RRDs as: ${tmp}/rrd/${rel_to_backend_dir}/${name}.xml
            # Reconstruct the target path as: ${backend_dir}/${rel_to_backend_dir}/${name}.rrd
            rel="${xml_file#${rrd_archive_dir}/}"    # e.g. instance/rrd/localhost/foo.xml
            target_rrd="${backend_dir}/${rel%.xml}.rrd"
            target_dir=$(dirname "${target_rrd}")

            sudo mkdir -p "${target_dir}"

            if [[ -f "${target_rrd}" ]]; then
                sudo cp "${target_rrd}" "${target_rrd}.pre_restore.${restore_date}.bak"
            fi

            echo -e "\e[94m  Restoring $(basename "${target_rrd}")...\e[97m"
            sudo rrdtool restore -f "${xml_file}" "${target_rrd}"
            if [[ $? -ne 0 ]]; then
                echo -e "\e[93m  WARNING: rrdtool restore failed for $(basename "${target_rrd}").\e[97m"
            fi
        done
        echo -e "\e[94m  RRD restore complete.\e[97m"
    fi
fi


## RESTORE OPENSKY CLASSIFICATION CACHE

backed_up_opensky="${temporary_directory}/instance/opensky"
if [[ -d "${backed_up_opensky}" ]]; then
    echo -e "\e[94m  Restoring OpenSky classification cache...\e[97m"
    sudo mkdir -p "${instance_dir}"
    if [[ -d "${instance_dir}/opensky" ]]; then
        sudo mv "${instance_dir}/opensky" "${instance_dir}/opensky.pre_restore.${restore_date}.bak"
    fi
    sudo cp -R "${backed_up_opensky}" "${instance_dir}/opensky"
    echo -e "\e[94m  OpenSky cache restored.\e[97m"
else
    echo -e "\e[94m  No OpenSky cache found in archive. Skipping.\e[97m"
fi


## RESTORE ACARS DATABASE

if [[ -n "${acars_db}" ]]; then
    acars_filename=$(basename "${acars_db}")
    backed_up_acars="${temporary_directory}/instance/${acars_filename}"
    if [[ -f "${backed_up_acars}" ]]; then
        echo -e "\e[94m  Restoring ACARS database to ${acars_db}...\e[97m"
        sudo mkdir -p "$(dirname "${acars_db}")"
        if [[ -f "${acars_db}" ]]; then
            sudo cp "${acars_db}" "${acars_db}.pre_restore.${restore_date}.bak"
            echo -e "\e[94m  Existing ACARS database backed up.\e[97m"
        fi
        sudo cp "${backed_up_acars}" "${acars_db}"
        echo -e "\e[94m  ACARS database restored.\e[97m"
    else
        echo -e "\e[94m  No ACARS database found in archive. Skipping.\e[97m"
    fi
fi


## FIX PERMISSIONS

echo -e "\e[94m  Setting ownership on restored files...\e[97m"
sudo chown -R www-data:www-data "${instance_dir}" 2>/dev/null || true
if [[ -d "${rrd_base_backed_up}" ]]; then
    sudo chown -R www-data:www-data "${rrd_base_backed_up}" 2>/dev/null || true
fi


## RESTART BACKEND SERVICE

if [[ "${service_was_running}" == "true" ]]; then
    echo -e "\e[94m  Restarting ${systemd_service}...\e[97m"
    sudo systemctl start "${systemd_service}"
    if systemctl is-active --quiet "${systemd_service}" 2>/dev/null; then
        echo -e "\e[94m  ${systemd_service} started.\e[97m"
    else
        echo -e "\e[91m  WARNING: ${systemd_service} failed to restart. Check the service logs:\e[97m"
        echo -e "  journalctl -u ${systemd_service} -n 50"
    fi
fi


## CLEAN UP

echo -e "\e[94m  Removing temporary extraction directory...\e[97m"
rm -rf "${temporary_directory}"


## RESTORE COMPLETE

echo -e "\e[32m"
echo -e "  RESTORE PROCESS COMPLETE\e[93m"
echo -e ""
echo -e "  Restored from : ${backup_archive}"
echo -e "  Backend       : ${backend_dir}"
echo -e "  Driver        : ${db_driver}\e[97m"
echo -e ""

echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  Finished restoring portal data.\e[39m"
echo -e ""
if [[ "${receiver_automated_install:-}" == "false" ]]; then
    read -r -p "Press enter to continue..." discard
fi

exit 0

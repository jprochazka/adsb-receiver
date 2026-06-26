#!/bin/bash

## portal_backup_v3.sh
##
## Backs up the new ADS-B Portal (Flask/Angular, cleanup branch).
##
## Run from any directory. The backup archive is written to:
##   <PWD>/backups/adsb-portal_v3_YYYY-MM-DD-HHMMSS.tar.gz
##
## What is backed up:
##   - config.yml                    (database credentials, paths, JWT secret)
##   - SQLite database               (instance/adsbportal.sqlite3)
##   - MySQL database                (mysqldump)
##   - PostgreSQL database           (pg_dump via .pgpass)
##   - RRD files                     (rrdtool dump to XML, path from config.yml)
##   - OpenSky classification cache  (instance/opensky/)
##   - ACARS database                (path from config.yml)
##
## The Angular frontend (/var/www/adsb-portal) is NOT backed up — it is a
## build artefact that can be rebuilt from source.
##
## Usage:
##   bash portal_backup_v3.sh [--backend-dir /path/to/backend]
##
## --backend-dir is optional. When omitted the script discovers the backend
## directory from the running systemd service unit, then falls back to a
## common installation path.


## PARSE ARGUMENTS

backend_dir_override=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --backend-dir)
            backend_dir_override="$2"
            shift 2
            ;;
        *)
            echo -e "\e[91m  ERROR: Unknown argument: $1\e[97m"
            echo -e "  Usage: bash portal_backup_v3.sh [--backend-dir /path/to/backend]"
            exit 1
            ;;
    esac
done


## VARIABLES

backup_date=$(date +"%Y-%m-%d-%H%M%S")
receiver_root_directory="${PWD}"
backups_directory="${receiver_root_directory}/backups"
temporary_directory="${receiver_root_directory}/backup_v3_${backup_date}"
systemd_service="adsb-portal-backend.service"


## LOCATE BACKEND DIRECTORY

if [[ -n "${backend_dir_override}" ]]; then
    backend_dir="${backend_dir_override}"
else
    # Try to read WorkingDirectory from the systemd unit.
    backend_dir=""
    if systemctl is-active --quiet "${systemd_service}" 2>/dev/null || \
       systemctl is-enabled --quiet "${systemd_service}" 2>/dev/null; then
        backend_dir=$(systemctl cat "${systemd_service}" 2>/dev/null \
            | grep '^WorkingDirectory=' | head -n1 | cut -d= -f2-)
    fi

    # Fallback: common install path.
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

if [[ -z "${backend_dir}" || ! -f "${backend_dir}/config.yml" ]]; then
    echo -e "\e[91m  ERROR: Could not locate the portal backend directory."
    echo -e "  Please specify it with --backend-dir /path/to/backend\e[97m"
    exit 1
fi

config_file="${backend_dir}/config.yml"
instance_dir="${backend_dir}/instance"


## BEGIN THE BACKUP PROCESS

clear
echo -e "\n\e[91m  ADS-B Portal Maintenance"
echo -e ""
echo -e "\e[92m  Backing up portal data (v3 — Flask/Angular portal)"
echo -e "\e[93m  ------------------------------------------------------------------------------\e[97m"
echo -e ""
echo -e "\e[95m  Backend  : ${backend_dir}\e[97m"
echo -e "\e[95m  Config   : ${config_file}\e[97m"
echo -e ""


## READ config.yml

echo -e "\e[94m  Reading configuration...\e[97m"

# Helper: extract a scalar value from a two-level YAML key (no external deps needed).
_yaml_get() {
    local file="$1" section="$2" key="$3"
    # Match the section header, then find the key within that section.
    python3 - "${file}" "${section}" "${key}" << 'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    cfg = yaml.safe_load(f)
section = cfg.get(sys.argv[2], {})
print(section.get(sys.argv[3], ""))
PY
}

db_driver=$(python3 -c "
import sys, yaml
with open('${config_file}') as f: cfg = yaml.safe_load(f)
print(cfg.get('database', {}).get('use', 'sqlite'))
")

rrd_base=$(python3 -c "
import sys, yaml
with open('${config_file}') as f: cfg = yaml.safe_load(f)
val = cfg.get('graphs', {}).get('rrd_base', 'instance/rrd')
print(val if val.startswith('/') else '${backend_dir}/' + val)
")

acars_db=$(python3 -c "
import sys, yaml
with open('${config_file}') as f: cfg = yaml.safe_load(f)
val = cfg.get('acars', {}).get('database', '')
if val and not val.startswith('/'):
    val = '${backend_dir}/' + val
print(val)
")

echo -e "\e[94m  DB driver : ${db_driver}\e[97m"
echo -e "\e[94m  RRD base  : ${rrd_base}\e[97m"
echo -e "\e[94m  ACARS db  : ${acars_db}\e[97m"

# Read driver-specific credentials
if [[ "${db_driver}" == "mysql" ]]; then
    mysql_host=$(    _yaml_get "${config_file}" "database.mysql"     "host"     2>/dev/null || \
                     python3 -c "import yaml; c=yaml.safe_load(open('${config_file}')); m=c['database']['mysql']; print(m.get('host','127.0.0.1'))")
    mysql_database=$(python3 -c "import yaml; c=yaml.safe_load(open('${config_file}')); m=c['database']['mysql']; print(m.get('database','adsbportal'))")
    mysql_username=$(python3 -c "import yaml; c=yaml.safe_load(open('${config_file}')); m=c['database']['mysql']; print(m.get('user','portaluser'))")
    mysql_pass=$(    python3 -c "import yaml; c=yaml.safe_load(open('${config_file}')); m=c['database']['mysql']; print(m.get('password',''))")
fi

if [[ "${db_driver}" == "postgresql" ]]; then
    pgsql_host=$(    python3 -c "import yaml; c=yaml.safe_load(open('${config_file}')); p=c['database']['postgresql']; print(p.get('host','127.0.0.1'))")
    pgsql_database=$(python3 -c "import yaml; c=yaml.safe_load(open('${config_file}')); p=c['database']['postgresql']; print(p.get('database','adsbportal'))")
    pgsql_username=$(python3 -c "import yaml; c=yaml.safe_load(open('${config_file}')); p=c['database']['postgresql']; print(p.get('user','portaluser'))")
    pgsql_pass=$(    python3 -c "import yaml; c=yaml.safe_load(open('${config_file}')); p=c['database']['postgresql']; print(p.get('password',''))")
fi


## STOP BACKEND SERVICE (prevents writes during backup)

service_was_running="false"
if systemctl is-active --quiet "${systemd_service}" 2>/dev/null; then
    service_was_running="true"
    echo -e "\e[94m  Stopping ${systemd_service} for a consistent backup...\e[97m"
    sudo systemctl stop "${systemd_service}"
fi


## PREPARE DIRECTORIES

echo -e "\e[94m  Creating backup staging directory ${temporary_directory}...\e[97m"
mkdir -p "${backups_directory}"
mkdir -p "${temporary_directory}"


## BACK UP config.yml

echo -e "\e[94m  Backing up config.yml...\e[97m"
cp "${config_file}" "${temporary_directory}/config.yml"


## BACK UP DATABASE

if [[ "${db_driver}" == "sqlite" ]]; then

    sqlite_path="${instance_dir}/adsbportal.sqlite3"
    if [[ -f "${sqlite_path}" ]]; then
        echo -e "\e[94m  Backing up SQLite database...\e[97m"
        mkdir -p "${temporary_directory}/instance"
        cp "${sqlite_path}" "${temporary_directory}/instance/adsbportal.sqlite3"
    else
        echo -e "\e[93m  WARNING: SQLite database not found at ${sqlite_path}. Skipping.\e[97m"
    fi

elif [[ "${db_driver}" == "mysql" ]]; then

    echo -e "\e[94m  Dumping MySQL database ${mysql_database}...\e[97m"
    mysqldump \
        -h "${mysql_host}" \
        -u "${mysql_username}" \
        -p"${mysql_pass}" \
        "${mysql_database}" \
        > "${temporary_directory}/${mysql_database}.sql"
    if [[ $? -ne 0 ]]; then
        echo -e "\e[91m  WARNING: mysqldump reported an error. Dump may be incomplete.\e[97m"
    else
        echo -e "\e[94m  MySQL dump complete.\e[97m"
    fi

elif [[ "${db_driver}" == "postgresql" ]]; then

    echo -e "\e[94m  Dumping PostgreSQL database ${pgsql_database}...\e[97m"
    _pgpass_file=$(mktemp)
    chmod 600 "${_pgpass_file}"
    printf '%s:*:%s:%s:%s\n' \
        "${pgsql_host}" "${pgsql_database}" "${pgsql_username}" "${pgsql_pass}" \
        > "${_pgpass_file}"
    PGPASSFILE="${_pgpass_file}" pg_dump \
        -h "${pgsql_host}" \
        -U "${pgsql_username}" \
        "${pgsql_database}" \
        > "${temporary_directory}/${pgsql_database}.sql"
    pg_exit=$?
    rm -f "${_pgpass_file}"
    if [[ ${pg_exit} -ne 0 ]]; then
        echo -e "\e[91m  WARNING: pg_dump reported an error. Dump may be incomplete.\e[97m"
    else
        echo -e "\e[94m  PostgreSQL dump complete.\e[97m"
    fi

else
    echo -e "\e[93m  WARNING: Unknown database driver '${db_driver}'. Database not backed up.\e[97m"
fi


## BACK UP RRD FILES (export to XML for portability)

if [[ -d "${rrd_base}" ]]; then
    mapfile -t rrd_files < <(find "${rrd_base}" -type f -name '*.rrd' 2>/dev/null)
    if [[ ${#rrd_files[@]} -eq 0 ]]; then
        echo -e "\e[94m  No RRD files found in ${rrd_base}. Skipping.\e[97m"
    else
        echo -e "\e[94m  Exporting ${#rrd_files[@]} RRD file(s) to XML...\e[97m"
        for rrd_file in "${rrd_files[@]}"; do
            rrd_name=$(basename -s .rrd "${rrd_file}")
            rrd_dir=$(dirname "${rrd_file}")
            rel_dir="${rrd_dir#${backend_dir}/}"   # path relative to backend_dir
            out_dir="${temporary_directory}/rrd/${rel_dir}"
            mkdir -p "${out_dir}"
            rrdtool dump "${rrd_file}" > "${out_dir}/${rrd_name}.xml"
        done
        echo -e "\e[94m  RRD export complete.\e[97m"
    fi
else
    echo -e "\e[94m  RRD directory not found at ${rrd_base}. Skipping.\e[97m"
fi


## BACK UP OPENSKY CLASSIFICATION CACHE

opensky_dir="${instance_dir}/opensky"
if [[ -d "${opensky_dir}" ]]; then
    echo -e "\e[94m  Backing up OpenSky classification cache...\e[97m"
    mkdir -p "${temporary_directory}/instance"
    cp -R "${opensky_dir}" "${temporary_directory}/instance/opensky"
else
    echo -e "\e[94m  No OpenSky cache directory found. Skipping.\e[97m"
fi


## BACK UP ACARS DATABASE

if [[ -n "${acars_db}" && -f "${acars_db}" ]]; then
    echo -e "\e[94m  Backing up ACARS database from ${acars_db}...\e[97m"
    mkdir -p "${temporary_directory}/instance"
    cp "${acars_db}" "${temporary_directory}/instance/$(basename "${acars_db}")"
else
    echo -e "\e[94m  No ACARS database found at ${acars_db}. Skipping.\e[97m"
fi


## RESTART BACKEND SERVICE

if [[ "${service_was_running}" == "true" ]]; then
    echo -e "\e[94m  Restarting ${systemd_service}...\e[97m"
    sudo systemctl start "${systemd_service}"
    if systemctl is-active --quiet "${systemd_service}" 2>/dev/null; then
        echo -e "\e[94m  ${systemd_service} started.\e[97m"
    else
        echo -e "\e[91m  WARNING: ${systemd_service} failed to restart. Check the service logs.\e[97m"
    fi
fi


## COMPRESS AND DATE THE BACKUP ARCHIVE

echo -e "\e[94m  Compressing backup...\e[97m"
echo -e ""
tar -zcvf "${backups_directory}/adsb-portal_v3_${backup_date}.tar.gz" \
    -C "${temporary_directory}" .
echo -e ""
echo -e "\e[94m  Removing temporary staging directory...\e[97m"
rm -rf "${temporary_directory}"


## BACKUP COMPLETE

archive_path="${backups_directory}/adsb-portal_v3_${backup_date}.tar.gz"

echo -e "\e[32m"
echo -e "  BACKUP PROCESS COMPLETE\e[93m"
echo -e ""
echo -e "  Archive saved to:"
echo -e "  ${archive_path}\e[97m"
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  Finished backing up portal data.\e[39m"
echo -e ""
if [[ "${receiver_automated_install:-}" == "false" ]]; then
    read -r -p "Press enter to continue..." discard
fi

exit 0

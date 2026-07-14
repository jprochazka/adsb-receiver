#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

set -euo pipefail

PORTAL_DIR="$RECEIVER_BUILD_DIRECTORY/portal"
BACKEND_DIR="${PORTAL_DIR}/backend"
FRONTEND_DIR="${PORTAL_DIR}/frontend"
VENV_DIR="${BACKEND_DIR}/.venv"
WEBROOT="/var/www/adsb-portal"
NGINX_SITE="adsb-portal"
SYSTEMD_SERVICE="adsb-portal-backend.service"
INSTANCE_DIR="${BACKEND_DIR}/instance"
RRD_BASE="${BACKEND_DIR}/instance/rrd"
OPENSKY_BASE="${BACKEND_DIR}/instance/opensky"
NODE_MAJOR=22
NODE_MIN_VERSION="22.22.3"
USE_EXISTING_SQLITE_DB="false"
DB_SKIP_PROVISION="false"
DB_INSTALL_MODE="New database initialized"
DB_TYPE_DEFAULT="sqlite"
DB_HOST_DEFAULT="127.0.0.1"
DB_NAME_DEFAULT="adsbportal"
DB_USER_DEFAULT="portaluser"
DB_PASS_DEFAULT=""
DB_ADMIN_USER_DEFAULT="root"
CONFIG_FILE="${BACKEND_DIR}/config.yml"
RRD_MIGRATE_SOURCE=""
RRD_MIGRATION_STATUS="No legacy RRD migration needed"
LE_ENABLE="false"
LE_DOMAIN=""
LEGACY_PORTAL_ROOT=""
LEGACY_DB_DRIVER=""
LEGACY_DB_DATABASE=""
LEGACY_DB_HOST=""
LEGACY_DB_USER=""
LEGACY_DB_PREFIX="adsb_"
LEGACY_IMPORT_ENABLED="false"
LEGACY_IMPORT_STATUS="No legacy portal detected"
LIGHTTPD_INSTALLED="false"
LIGHTTPD_ACTIVE_BEFORE="false"
LIGHTTPD_ENABLED_BEFORE="false"
LIGHTTPD_DOCROOT=""
LIGHTTPD_TAKEOVER_STATUS="No lighttpd takeover needed"

find_legacy_rrd_source() {
    # Build candidate list: well-known fixed paths first, then legacy-portal-root-relative
    # paths when LEGACY_PORTAL_ROOT has been set by find_legacy_portal_root().
    local -a candidates=(
        "/usr/local/share/graphs1090/rrd"
        "/var/lib/collectd/rrd"
        "/var/www/html/graphs/rrd"
        "/var/www/html/data/rrd"
        "/var/www/html/rrd"
    )

    # Add portal-root-relative candidates when the root is known.
    if [[ -n "${LEGACY_PORTAL_ROOT:-}" ]]; then
        candidates+=(
            "${LEGACY_PORTAL_ROOT}/data/rrd"
            "${LEGACY_PORTAL_ROOT}/graphs/rrd"
            "${LEGACY_PORTAL_ROOT}/rrd"
        )
    fi

    for candidate in "${candidates[@]}"; do
        if [[ "${candidate}" == "${RRD_BASE}" ]]; then
            continue
        fi

        if [[ -d "${candidate}" ]] && find "${candidate}" -type f -name '*.rrd' -print -quit | grep -q .; then
            echo "${candidate}"
            return 0
        fi
    done

    return 1
}

strip_yaml_value() {
    local raw_value="$1"
    raw_value="${raw_value#\"}"
    raw_value="${raw_value%\"}"
    echo "${raw_value}"
}

# Find the document root of a legacy PHP ADS-B Portal installation.
# Returns the root path on stdout and exits 0, or exits 1 if not found.
# This function is READ-ONLY — it never writes or modifies any file.
find_legacy_portal_root() {
    local -a candidates=()

    # If lighttpd is installed, ask it for its configured document root.
    if command -v lighttpd >/dev/null 2>&1 && [[ -f /etc/lighttpd/lighttpd.conf ]]; then
        local raw_root
        raw_root=$(/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p 2>/dev/null \
                   | grep 'server.document-root' | sed 's/.*"\(.*\)".*/\1/' | head -n1)
        [[ -n "${raw_root}" ]] && candidates+=("${raw_root}")
    fi

    # Well-known fallback paths used by old installers.
    candidates+=(
        "/var/www/html"
        "/var/www"
        "/usr/share/adsb-receiver/build/portal/html"
    )

    for candidate in "${candidates[@]}"; do
        if [[ -f "${candidate}/classes/settings.class.php" ]]; then
            echo "${candidate}"
            return 0
        fi
    done

    return 1
}

# Parse legacy PHP settings.class.php and populate LEGACY_* globals.
# Accepts the portal root path as $1.
# This function is READ-ONLY — it never writes or modifies any file.
load_legacy_portal_settings() {
    local root="$1"
    local settings_file="${root}/classes/settings.class.php"

    [[ -f "${settings_file}" ]] || return 1

    LEGACY_DB_DRIVER=$(grep 'db_driver'   "${settings_file}" | tail -n1 | cut -d"'" -f2)
    LEGACY_DB_DATABASE=$(grep 'db_database' "${settings_file}" | tail -n1 | cut -d"'" -f2)
    LEGACY_DB_HOST=$(grep 'db_host'      "${settings_file}" | tail -n1 | cut -d"'" -f2)
    LEGACY_DB_USER=$(grep 'db_username'  "${settings_file}" | tail -n1 | cut -d"'" -f2)
    local raw_prefix
    raw_prefix=$(grep 'db_prefix' "${settings_file}" | tail -n1 | cut -d"'" -f2)
    LEGACY_DB_PREFIX="${raw_prefix:-adsb_}"

    # For SQLite the old installer stored the full path in db_host.
    # If db_database is empty but db_host looks like a file path, use it.
    if [[ "${LEGACY_DB_DRIVER}" == "sqlite" && -z "${LEGACY_DB_DATABASE}" && -n "${LEGACY_DB_HOST}" ]]; then
        LEGACY_DB_DATABASE="${LEGACY_DB_HOST}"
        LEGACY_DB_HOST=""
    fi

    return 0
}

run_le_preflight() {
    local domain="$1"
    local domain_ips=""
    local public_ipv4=""
    local dns_status="FAILED"
    local ip_status="UNKNOWN"
    local port80_status="FAILED"
    local port443_status="FAILED"

    domain_ips=$(getent ahostsv4 "${domain}" 2>/dev/null | awk '{print $1}' | sort -u)
    if [[ -z "${domain_ips}" ]]; then
        domain_ips=$(getent ahosts "${domain}" 2>/dev/null | awk '/^[0-9.]+$/ {print $1}' | sort -u)
    fi
    if [[ -n "${domain_ips}" ]]; then
        dns_status="OK"
    fi

    public_ipv4=$(curl -4fsS --max-time 8 https://api.ipify.org 2>/dev/null || true)
    if [[ -n "${public_ipv4}" && -n "${domain_ips}" ]]; then
        ip_status="FAILED"
        while read -r ip; do
            if [[ "${ip}" == "${public_ipv4}" ]]; then
                ip_status="OK"
                break
            fi
        done <<< "${domain_ips}"
    fi

    if command -v ss >/dev/null 2>&1; then
        if ss -ltn | awk '{print $4}' | grep -Eq '(:80|\]:80)$'; then
            port80_status="OK"
        fi
        if ss -ltn | awk '{print $4}' | grep -Eq '(:443|\]:443)$'; then
            port443_status="OK"
        fi
    fi

    whiptail --title "Let's Encrypt Preflight" --msgbox "\
Domain: ${domain}

DNS resolution: ${dns_status}
Resolved IPv4: ${domain_ips:-none}

Public IPv4 (this host): ${public_ipv4:-unknown}
DNS includes host public IPv4: ${ip_status}

Local listener on :80: ${port80_status}
Local listener on :443: ${port443_status}

Notes:
- This is a best-effort local preflight.
- External reachability from the internet (NAT/firewall) still cannot be fully verified from this host alone." 22 78
}

if [[ -f "${CONFIG_FILE}" ]]; then
    existing_db_type=$(sed -nE 's/^    use:[[:space:]]*"?([^"#]+)"?$/\1/p' "${CONFIG_FILE}" | head -n 1)
    if [[ -n "${existing_db_type}" ]]; then
        existing_db_type="$(strip_yaml_value "${existing_db_type}")"
    fi

    existing_mysql_host=$(awk '
        /^    mysql:/ { section="mysql"; next }
        /^    postgresql:/ { section="postgresql"; next }
        /^    [a-z]/ { section="" }
        section=="mysql" && /^        host:/ {
            value=$0
            sub(/^        host:[[:space:]]*/, "", value)
            gsub(/^"|"$/, "", value)
            print value
            exit
        }
    ' "${CONFIG_FILE}")
    existing_mysql_name=$(awk '
        /^    mysql:/ { section="mysql"; next }
        /^    postgresql:/ { section="postgresql"; next }
        /^    [a-z]/ { section="" }
        section=="mysql" && /^        database:/ {
            value=$0
            sub(/^        database:[[:space:]]*/, "", value)
            gsub(/^"|"$/, "", value)
            print value
            exit
        }
    ' "${CONFIG_FILE}")
    existing_mysql_user=$(awk '
        /^    mysql:/ { section="mysql"; next }
        /^    postgresql:/ { section="postgresql"; next }
        /^    [a-z]/ { section="" }
        section=="mysql" && /^        user:/ {
            value=$0
            sub(/^        user:[[:space:]]*/, "", value)
            gsub(/^"|"$/, "", value)
            print value
            exit
        }
    ' "${CONFIG_FILE}")
    existing_mysql_pass=$(awk '
        /^    mysql:/ { section="mysql"; next }
        /^    postgresql:/ { section="postgresql"; next }
        /^    [a-z]/ { section="" }
        section=="mysql" && /^        password:/ {
            value=$0
            sub(/^        password:[[:space:]]*/, "", value)
            gsub(/^"|"$/, "", value)
            print value
            exit
        }
    ' "${CONFIG_FILE}")

    existing_pg_host=$(awk '
        /^    postgresql:/ { section="postgresql"; next }
        /^    [a-z]/ { section="" }
        section=="postgresql" && /^        host:/ {
            value=$0
            sub(/^        host:[[:space:]]*/, "", value)
            gsub(/^"|"$/, "", value)
            print value
            exit
        }
    ' "${CONFIG_FILE}")
    existing_pg_name=$(awk '
        /^    postgresql:/ { section="postgresql"; next }
        /^    [a-z]/ { section="" }
        section=="postgresql" && /^        database:/ {
            value=$0
            sub(/^        database:[[:space:]]*/, "", value)
            gsub(/^"|"$/, "", value)
            print value
            exit
        }
    ' "${CONFIG_FILE}")
    existing_pg_user=$(awk '
        /^    postgresql:/ { section="postgresql"; next }
        /^    [a-z]/ { section="" }
        section=="postgresql" && /^        user:/ {
            value=$0
            sub(/^        user:[[:space:]]*/, "", value)
            gsub(/^"|"$/, "", value)
            print value
            exit
        }
    ' "${CONFIG_FILE}")
    existing_pg_pass=$(awk '
        /^    postgresql:/ { section="postgresql"; next }
        /^    [a-z]/ { section="" }
        section=="postgresql" && /^        password:/ {
            value=$0
            sub(/^        password:[[:space:]]*/, "", value)
            gsub(/^"|"$/, "", value)
            print value
            exit
        }
    ' "${CONFIG_FILE}")
fi

clear
log_project_title
log_title_heading "Setting up the ADS-B Portal"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "ADS-B Portal Setup" \
              --yesno "ADS-B Portal is a web-based interface for viewing and managing ADS-B data.\n\n  http://www.adsbreceiver.org/\n\nContinue setting up the ADS-B Portal?" \
              18 78; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "ADS-B Portal setup halted"
    echo ""
    exit 1
fi


## GATHER REQUIRED INFORMATION FROM THE USER

log_heading "Beginning the ADS-B Portal installation process"

if [[ ! -d "$BACKEND_DIR" || ! -d "$FRONTEND_DIR" ]]; then
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "The ADS-B Portal build directory is incomplete"
    log_alert_message "Expected directories: ${BACKEND_DIR} and ${FRONTEND_DIR}"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "ADS-B Portal setup failed"
    echo ""
    read -p "Press enter to continue..." discard
    exit 1
fi

if ! command -v whiptail &>/dev/null; then
    log_message "Installing whiptail"
    check_package whiptail
fi

if [[ -f "${CONFIG_FILE}" && -n "${existing_db_type:-}" ]]; then
    if whiptail --title "Existing Portal Configuration Detected" \
                --yesno "An existing portal configuration file was found:\n\n  ${CONFIG_FILE}\n\nWould you like to use the current database settings as defaults?" \
                14 78; then
        DB_TYPE_DEFAULT="${existing_db_type}"
        if [[ "${existing_db_type}" == "mysql" ]]; then
            [[ -n "${existing_mysql_host:-}" ]] && DB_HOST_DEFAULT="${existing_mysql_host}"
            [[ -n "${existing_mysql_name:-}" ]] && DB_NAME_DEFAULT="${existing_mysql_name}"
            [[ -n "${existing_mysql_user:-}" ]] && DB_USER_DEFAULT="${existing_mysql_user}"
            DB_PASS_DEFAULT="${existing_mysql_pass:-}"
        elif [[ "${existing_db_type}" == "postgresql" ]]; then
            [[ -n "${existing_pg_host:-}" ]] && DB_HOST_DEFAULT="${existing_pg_host}"
            [[ -n "${existing_pg_name:-}" ]] && DB_NAME_DEFAULT="${existing_pg_name}"
            [[ -n "${existing_pg_user:-}" ]] && DB_USER_DEFAULT="${existing_pg_user}"
            DB_PASS_DEFAULT="${existing_pg_pass:-}"
        fi
    fi
fi

DB_TYPE=$(whiptail --title "ADSB Portal Setup" \
    --default-item "${DB_TYPE_DEFAULT}" \
    --menu "Select the database backend to use:" 12 60 3 \
    "sqlite"     "SQLite (simple, file-based)" \
    "mysql"      "MySQL / MariaDB" \
    "postgresql" "PostgreSQL" \
    3>&1 1>&2 2>&3) || {
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    exit 1
}

if [[ "${DB_TYPE}" == "mysql" || "${DB_TYPE}" == "postgresql" ]]; then
    DB_HOST=$(whiptail --title "Database Configuration" \
        --inputbox "Database host:" 8 60 "${DB_HOST_DEFAULT}" \
        3>&1 1>&2 2>&3) || {
        log_alert_heading "INSTALLATION HALTED"
        log_alert_message "Setup has been halted at the request of the user"
        exit 1
    }

    DB_NAME=$(whiptail --title "Database Configuration" \
        --inputbox "Database name:" 8 60 "${DB_NAME_DEFAULT}" \
        3>&1 1>&2 2>&3) || {
        log_alert_heading "INSTALLATION HALTED"
        log_alert_message "Setup has been halted at the request of the user"
        exit 1
    }

    DB_USER=$(whiptail --title "Database Configuration" \
        --inputbox "Database user:" 8 60 "${DB_USER_DEFAULT}" \
        3>&1 1>&2 2>&3) || {
        log_alert_heading "INSTALLATION HALTED"
        log_alert_message "Setup has been halted at the request of the user"
        exit 1
    }

    DB_PASS=$(whiptail --title "Database Configuration" \
        --passwordbox "Database password:" 8 60 "${DB_PASS_DEFAULT}" \
        3>&1 1>&2 2>&3) || {
        log_alert_heading "INSTALLATION HALTED"
        log_alert_message "Setup has been halted at the request of the user"
        exit 1
    }

    if whiptail --title "Database Provisioning Mode" \
                --yesno "Use an existing pre-provisioned ${DB_TYPE} database and user?\n\nIf YES, the installer will skip database/user creation and only test connectivity and apply migrations." \
                13 78; then
        DB_SKIP_PROVISION="true"
        DB_INSTALL_MODE="Existing ${DB_TYPE} database reused and upgraded"
    else
        DB_SKIP_PROVISION="false"
        DB_INSTALL_MODE="New ${DB_TYPE} database/user provisioned and migrated"
    fi
fi

if [[ "${DB_TYPE}" == "mysql" && "${DB_SKIP_PROVISION}" != "true" ]]; then
    DB_ADMIN_USER=$(whiptail --title "MySQL Admin Credentials" \
        --inputbox "MySQL admin username (used to create database and user):" 8 60 "${DB_ADMIN_USER_DEFAULT}" \
        3>&1 1>&2 2>&3) || {
        log_alert_heading "INSTALLATION HALTED"
        log_alert_message "Setup has been halted at the request of the user"
        exit 1
    }

    DB_ADMIN_PASS=$(whiptail --title "MySQL Admin Credentials" \
        --passwordbox "MySQL admin password:" 8 60 \
        3>&1 1>&2 2>&3) || {
        log_alert_heading "INSTALLATION HALTED"
        log_alert_message "Setup has been halted at the request of the user"
        exit 1
    }
fi

if [[ "${DB_TYPE}" == "postgresql" && "${DB_SKIP_PROVISION}" != "true" ]]; then
    if [[ "${DB_HOST}" != "127.0.0.1" && "${DB_HOST}" != "localhost" && "${DB_HOST}" != "::1" ]]; then
        whiptail --title "PostgreSQL Provisioning Notice" \
                 --msgbox "Automatic PostgreSQL database/user provisioning is only supported for local hosts.\n\nFor remote PostgreSQL hosts, the installer will use existing credentials and skip provisioning." \
                 12 78
        DB_SKIP_PROVISION="true"
        DB_INSTALL_MODE="Existing postgresql database reused and upgraded"
    fi
fi

if [[ "${DB_TYPE}" == "sqlite" ]]; then
    SQLITE_DB_PATH="${INSTANCE_DIR}/adsbportal.sqlite3"
    if [[ -f "${SQLITE_DB_PATH}" && -s "${SQLITE_DB_PATH}" ]]; then
        if whiptail --title "Existing SQLite Database Detected" \
                    --yesno "An existing ADS-B Portal SQLite database was found:\n\n  ${SQLITE_DB_PATH}\n\nWould you like to reuse and upgrade this database for the new portal?" \
                    14 78; then
            USE_EXISTING_SQLITE_DB="true"
            DB_INSTALL_MODE="Existing SQLite database reused and upgraded"
        else
            sqlite_backup="${SQLITE_DB_PATH}.bak.$(date +%Y%m%d_%H%M%S)"
            log_message "Backing up existing SQLite database to ${sqlite_backup}"
            cp -f "${SQLITE_DB_PATH}" "${sqlite_backup}"
            DB_INSTALL_MODE="Existing SQLite database backed up; new database initialized"
        fi
    fi
fi

## LEGACY PORTAL DISCOVERY (read-only; no data written here)

LEGACY_PORTAL_ROOT=$(find_legacy_portal_root || true)
if [[ -n "${LEGACY_PORTAL_ROOT}" ]]; then
    if load_legacy_portal_settings "${LEGACY_PORTAL_ROOT}"; then
        log_message "Legacy portal found at ${LEGACY_PORTAL_ROOT} (driver: ${LEGACY_DB_DRIVER})"
        LEGACY_IMPORT_STATUS="Legacy portal detected: driver=${LEGACY_DB_DRIVER} root=${LEGACY_PORTAL_ROOT}"
    else
        log_message "Legacy portal root found but settings.class.php could not be parsed; skipping import"
        LEGACY_PORTAL_ROOT=""
        LEGACY_IMPORT_STATUS="Legacy portal root found but settings unreadable"
    fi
else
    log_message "No legacy portal installation detected"
fi

## LEGACY PORTAL IMPORT DECISION

if [[ -n "${LEGACY_PORTAL_ROOT}" ]]; then

    # Build a human-readable summary of what was detected.
    legacy_summary="Legacy ADS-B Portal detected:\n\n"
    legacy_summary+="  Location : ${LEGACY_PORTAL_ROOT}\n"
    legacy_summary+="  Driver   : ${LEGACY_DB_DRIVER}\n"
    case "${LEGACY_DB_DRIVER}" in
        xml)
            legacy_summary+="  Data     : XML files under ${LEGACY_PORTAL_ROOT}/data/\n"
            ;;
        sqlite)
            legacy_summary+="  Database : ${LEGACY_DB_DATABASE}\n"
            ;;
        mysql)
            legacy_summary+="  Database : ${LEGACY_DB_DATABASE} on ${LEGACY_DB_HOST}\n"
            legacy_summary+="  User     : ${LEGACY_DB_USER}\n"
            ;;
        pgsql|postgresql)
            legacy_summary+="  Database : ${LEGACY_DB_DATABASE} on ${LEGACY_DB_HOST}\n"
            legacy_summary+="  User     : ${LEGACY_DB_USER}\n"
            ;;
    esac
    legacy_summary+="\nWould you like to import this data into the new portal?"

    if whiptail --title "Legacy Portal Data Found" \
                --yesno "${legacy_summary}" \
                20 78; then

        # Require explicit confirmation before any import takes place.
        if whiptail --title "Confirm Import" \
                    --defaultno \
                    --yesno "Importing will write legacy data into the new portal database.\n\nA backup of the target database will be created before any data is written.\nLegacy source data will NOT be deleted or modified.\n\nProceed with import?" \
                    14 78; then
            LEGACY_IMPORT_ENABLED="true"
            LEGACY_IMPORT_STATUS="Legacy portal import confirmed: driver=${LEGACY_DB_DRIVER} root=${LEGACY_PORTAL_ROOT}"
            log_message "User confirmed legacy portal import (driver: ${LEGACY_DB_DRIVER})"
        else
            LEGACY_IMPORT_STATUS="Legacy portal detected but import was declined at confirmation"
            log_message "User declined import at confirmation step; continuing fresh install"
        fi

    else
        LEGACY_IMPORT_STATUS="Legacy portal detected but import was declined by user"
        log_message "User declined legacy portal import; continuing fresh install"
    fi
fi

## LEGACY RRD DISCOVERY (runs after portal root known; uses root-relative candidates)

legacy_rrd_source=$(find_legacy_rrd_source || true)
if [[ -n "${legacy_rrd_source}" ]]; then
    if whiptail --title "Legacy RRD Files Detected" \
                --yesno "Legacy RRD files were found:\n\n  ${legacy_rrd_source}\n\nNew portal location:\n  ${RRD_BASE}\n\nWould you like to migrate these RRD files for use with the new portal graphs?" \
                16 78; then
        RRD_MIGRATE_SOURCE="${legacy_rrd_source}"
        RRD_MIGRATION_STATUS="Legacy RRD files migrated from ${legacy_rrd_source}"
    else
        RRD_MIGRATION_STATUS="Legacy RRD files detected but migration was skipped"
    fi
fi

while true; do
    JWT_SECRET=$(whiptail --title "Security Configuration" \
        --passwordbox "JWT secret key (minimum 32 characters):" 8 60 \
        3>&1 1>&2 2>&3) || {
        log_alert_heading "INSTALLATION HALTED"
        log_alert_message "Setup has been halted at the request of the user"
        exit 1
    }
    if [[ ${#JWT_SECRET} -ge 32 ]]; then
        break
    fi
    whiptail --title "Invalid Input" \
        --msgbox "JWT secret key must be at least 32 characters. Please try again." 8 60
done

if whiptail --title "HTTPS Configuration" \
            --yesno "Would you like to configure HTTPS with Let's Encrypt now?\n\nFor now this installer only records your choice and does not perform automatic certificate provisioning." \
            16 78; then
    LE_ENABLE="true"
    while [[ -z "${LE_DOMAIN}" ]]; do
        LE_DOMAIN=$(whiptail --title "Let's Encrypt Domain" \
            --inputbox "Enter the domain you plan to use for HTTPS preflight checks:" 8 78 \
            3>&1 1>&2 2>&3) || {
            log_alert_heading "INSTALLATION HALTED"
            log_alert_message "Setup has been halted at the request of the user"
            exit 1
        }
    done
fi

## LIGHTTPD DETECTION (before install begins; state vars consumed later in _install)

if dpkg-query -W -f='${Status}' lighttpd 2>/dev/null | grep -q "install ok installed"; then
    LIGHTTPD_INSTALLED="true"
    if systemctl is-active --quiet lighttpd 2>/dev/null; then
        LIGHTTPD_ACTIVE_BEFORE="true"
    fi
    if systemctl is-enabled --quiet lighttpd 2>/dev/null; then
        LIGHTTPD_ENABLED_BEFORE="true"
    fi
    # Capture document root now — we need it before lighttpd is stopped.
    if [[ -f /etc/lighttpd/lighttpd.conf ]]; then
        _raw=$(/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p 2>/dev/null \
               | grep 'server.document-root' | sed 's/.*"\(.*\)".*/\1/' | head -n1)
        [[ -n "${_raw}" ]] && LIGHTTPD_DOCROOT="${_raw}"
    fi
    [[ -z "${LIGHTTPD_DOCROOT}" ]] && LIGHTTPD_DOCROOT="/var/www/html"
    log_message "lighttpd detected: active=${LIGHTTPD_ACTIVE_BEFORE} docroot=${LIGHTTPD_DOCROOT}"
fi

MYSQL_HOST="${DB_HOST:-127.0.0.1}"
MYSQL_USER="${DB_USER:-portaluser}"
MYSQL_PASS="${DB_PASS:-password}"
MYSQL_NAME="${DB_NAME:-adsbportal}"
MYSQL_ADMIN_USER="${DB_ADMIN_USER:-root}"
MYSQL_ADMIN_PASS="${DB_ADMIN_PASS:-}"
PG_HOST="${DB_HOST:-127.0.0.1}"
PG_USER="${DB_USER:-portaluser}"
PG_PASS="${DB_PASS:-password}"
PG_NAME="${DB_NAME:-adsbportal}"

if [[ "${DB_TYPE}" == "mysql" ]]; then
    MYSQL_HOST="${DB_HOST}"; MYSQL_USER="${DB_USER}"; MYSQL_PASS="${DB_PASS}"; MYSQL_NAME="${DB_NAME}"
    MYSQL_ADMIN_USER="${DB_ADMIN_USER}"; MYSQL_ADMIN_PASS="${DB_ADMIN_PASS}"
elif [[ "${DB_TYPE}" == "postgresql" ]]; then
    PG_HOST="${DB_HOST}"; PG_USER="${DB_USER}"; PG_PASS="${DB_PASS}"; PG_NAME="${DB_NAME}"
fi


## INSTALL ADS-B PORTAL

LOG_FILE="/tmp/adsb-portal-install.log"
> "${LOG_FILE}"

_install() {
    set -euo pipefail

    _gauge() { printf 'XXX\n%s\n%s\nXXX\n' "$1" "$2"; }

    _gauge 3 "Writing configuration..."
    cat > "${BACKEND_DIR}/config.yml" << YMLEOF
database:
    use: "${DB_TYPE}"
    mysql:
        host: "${MYSQL_HOST}"
        user: "${MYSQL_USER}"
        password: "${MYSQL_PASS}"
        database: "${MYSQL_NAME}"
    postgresql:
        host: "${PG_HOST}"
        user: "${PG_USER}"
        password: "${PG_PASS}"
        database: "${PG_NAME}"
    maintenance:
        purge_old_aircraft: True
        days_to_save: 30

acars:
    database: "instance/acarsdec.sqlite"

graphs:
    rrd_base: "${RRD_BASE}"
    dump1090_instance: "localhost"
    dump978_instance: "localhost"

rrd_writer:
    enabled: true
    step_seconds: 30
    http_timeout_seconds: 5
    dump1090_url: "http://127.0.0.1/dump1090"
    dump978_url: "http://127.0.0.1/dump978"

security:
    jwt_secret_key: "${JWT_SECRET}"
YMLEOF

    _gauge 8 "Updating package list..."
    sudo apt-get update >> "${LOG_FILE}" 2>&1

    _gauge 14 "Installing system packages..."
    CORE_PKGS="nginx python3-venv python3-pip python3-dev build-essential pkg-config curl whiptail rrdtool gnupg ca-certificates"
    PY_DB_BUILD_PKGS="default-libmysqlclient-dev libpq-dev"
    DB_CLIENT_PKGS=""
    DB_SERVER_PKGS=""

    if [[ "${DB_TYPE}" == "mysql" ]]; then
        DB_CLIENT_PKGS="default-mysql-client"
        if [[ "${DB_SKIP_PROVISION}" != "true" ]]; then
            DB_SERVER_PKGS="default-mysql-server"
        fi
    elif [[ "${DB_TYPE}" == "postgresql" ]]; then
        DB_CLIENT_PKGS="postgresql-client"
        if [[ "${DB_SKIP_PROVISION}" != "true" ]]; then
            DB_SERVER_PKGS="postgresql"
        fi
    fi

    for pkg in ${CORE_PKGS} ${PY_DB_BUILD_PKGS} ${DB_CLIENT_PKGS} ${DB_SERVER_PKGS}; do
        if [[ -n "${pkg}" ]]; then
            check_package "${pkg}"
        fi
    done

    _gauge 18 "Configuring NodeSource repository..."
    sudo install -d -m 0755 /etc/apt/keyrings
    curl -fsSL "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/nodesource.gpg
    cat << NODESOURCEEOF | sudo tee /etc/apt/sources.list.d/nodesource.list >/dev/null
deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main
NODESOURCEEOF
    sudo apt-get update >> "${LOG_FILE}" 2>&1
    sudo apt-get install -y nodejs >> "${LOG_FILE}" 2>&1

    NODE_VERSION="$(node --version | sed 's/^v//')"
    if ! dpkg --compare-versions "${NODE_VERSION}" ge "${NODE_MIN_VERSION}"; then
        echo "Node.js ${NODE_MIN_VERSION}+ is required for Angular 22; found ${NODE_VERSION}" >> "${LOG_FILE}"
        exit 1
    fi

    _gauge 24 "Setting up Python virtual environment..."
    if [[ ! -d "${VENV_DIR}" ]]; then
        python3 -m venv "${VENV_DIR}" >> "${LOG_FILE}" 2>&1
    fi

    _gauge 29 "Upgrading pip, setuptools, and wheel..."
    "${VENV_DIR}/bin/pip" install --upgrade pip setuptools wheel >> "${LOG_FILE}" 2>&1

    _gauge 37 "Installing Python dependencies..."
    if [[ -f "${BACKEND_DIR}/requirements.txt" ]]; then
        "${VENV_DIR}/bin/pip" install -r "${BACKEND_DIR}/requirements.txt" >> "${LOG_FILE}" 2>&1
    fi

    _gauge 47 "Installing Gunicorn..."
    "${VENV_DIR}/bin/pip" install "gunicorn[gthread]" >> "${LOG_FILE}" 2>&1

    _gauge 51 "Preparing backend data directories..."
    mkdir -p "${INSTANCE_DIR}"
    mkdir -p "${RRD_BASE}"
    mkdir -p "${OPENSKY_BASE}"

    if [[ -n "${RRD_MIGRATE_SOURCE}" ]]; then
        _gauge 53 "Migrating legacy RRD files..."

        _rrd_src_count=$(find "${RRD_MIGRATE_SOURCE}" -type f -name '*.rrd' | wc -l)

        if command -v rsync &>/dev/null; then
            # --ignore-existing preserves new files; -a preserves timestamps/perms.
            rsync -a --ignore-existing \
                  --log-file="${LOG_FILE}" \
                  "${RRD_MIGRATE_SOURCE}/" "${RRD_BASE}/" 2>&1 || true
            # Count files now present in target after sync.
            _rrd_dst_count=$(find "${RRD_BASE}" -type f -name '*.rrd' | wc -l)
        else
            cp -an "${RRD_MIGRATE_SOURCE}/." "${RRD_BASE}/" >> "${LOG_FILE}" 2>&1 || true
            _rrd_dst_count=$(find "${RRD_BASE}" -type f -name '*.rrd' | wc -l)
        fi

        # Update the human-readable status with counts.
        RRD_MIGRATION_STATUS="Legacy RRD files migrated from ${RRD_MIGRATE_SOURCE} (source: ${_rrd_src_count} files; target now: ${_rrd_dst_count} files)"
        log_message "RRD migration: source=${_rrd_src_count} target=${_rrd_dst_count}"
    fi

    sudo chown -R www-data:www-data "${RRD_BASE}" "${OPENSKY_BASE}"
    sudo chmod -R 755 "${RRD_BASE}" "${OPENSKY_BASE}"

    if [[ "${DB_TYPE}" == "mysql" && "${DB_SKIP_PROVISION}" != "true" ]]; then
        _gauge 51 "Creating MySQL database and user..."
        mysql -h"${MYSQL_HOST}" -u"${MYSQL_ADMIN_USER}" -p"${MYSQL_ADMIN_PASS}" >> "${LOG_FILE}" 2>&1 << SQLEOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_NAME}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASS}';
GRANT ALL PRIVILEGES ON \`${MYSQL_NAME}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQLEOF
    elif [[ "${DB_TYPE}" == "postgresql" && "${DB_SKIP_PROVISION}" != "true" ]]; then
        _gauge 51 "Creating PostgreSQL database and user..."
        sudo -u postgres createdb "${PG_NAME}" >> "${LOG_FILE}" 2>&1 || true
        sudo -u postgres psql -c "CREATE USER \"${PG_USER}\" WITH PASSWORD '${PG_PASS}';" >> "${LOG_FILE}" 2>&1 || true
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"${PG_NAME}\" TO \"${PG_USER}\";" >> "${LOG_FILE}" 2>&1
    fi

    if [[ "${DB_TYPE}" == "mysql" ]]; then
        _gauge 56 "Testing MySQL connectivity..."
        mysql -h"${MYSQL_HOST}" -u"${MYSQL_USER}" -p"${MYSQL_PASS}" -D"${MYSQL_NAME}" -e "SELECT 1;" >> "${LOG_FILE}" 2>&1

        _gauge 57 "Checking MySQL schema migration state..."
        MYSQL_NEEDS_STAMP=$(mysql -h"${MYSQL_HOST}" -u"${MYSQL_USER}" -p"${MYSQL_PASS}" -D"${MYSQL_NAME}" -N -e "
SELECT CASE
    WHEN EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema='${MYSQL_NAME}' AND table_name='alembic_version'
    ) THEN 'no'
    WHEN EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema='${MYSQL_NAME}'
          AND table_name IN ('users','dump1090_flights','settings')
    ) THEN 'yes'
    ELSE 'no'
END;")

        if [[ "${MYSQL_NEEDS_STAMP}" == "yes" ]]; then
            _gauge 58 "Stamping existing MySQL schema..."
            (cd "${BACKEND_DIR}" && FLASK_APP=backend "${VENV_DIR}/bin/flask" db stamp 0001 >> "${LOG_FILE}" 2>&1)
        fi
    elif [[ "${DB_TYPE}" == "postgresql" ]]; then
        _gauge 56 "Testing PostgreSQL connectivity..."
        PGPASSWORD="${PG_PASS}" psql -h "${PG_HOST}" -U "${PG_USER}" -d "${PG_NAME}" -c "SELECT 1;" >> "${LOG_FILE}" 2>&1

        _gauge 57 "Checking PostgreSQL schema migration state..."
        PG_NEEDS_STAMP=$(PGPASSWORD="${PG_PASS}" psql -h "${PG_HOST}" -U "${PG_USER}" -d "${PG_NAME}" -tA -c "
SELECT CASE
    WHEN EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema='public' AND table_name='alembic_version'
    ) THEN 'no'
    WHEN EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema='public'
          AND table_name IN ('users','dump1090_flights','settings')
    ) THEN 'yes'
    ELSE 'no'
END;")

        if [[ "${PG_NEEDS_STAMP}" == "yes" ]]; then
            _gauge 58 "Stamping existing PostgreSQL schema..."
            (cd "${BACKEND_DIR}" && FLASK_APP=backend "${VENV_DIR}/bin/flask" db stamp 0001 >> "${LOG_FILE}" 2>&1)
        fi
    fi

    if [[ "${DB_TYPE}" == "sqlite" && "${USE_EXISTING_SQLITE_DB}" == "true" ]]; then
        _gauge 56 "Preparing existing SQLite database for migration..."
        SQLITE_NEEDS_STAMP=$(python3 - "${INSTANCE_DIR}/adsbportal.sqlite3" << 'PY'
import sqlite3
import sys

db_path = sys.argv[1]
conn = sqlite3.connect(db_path)
cur = conn.cursor()

cur.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='alembic_version'")
has_alembic = cur.fetchone()[0] > 0

cur.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('users', 'dump1090_flights', 'settings')")
legacy_table_count = cur.fetchone()[0]

conn.close()

if (not has_alembic) and legacy_table_count > 0:
    print("yes")
else:
    print("no")
PY
)

        if [[ "${SQLITE_NEEDS_STAMP}" == "yes" ]]; then
            _gauge 57 "Stamping existing SQLite schema..."
            (cd "${BACKEND_DIR}" && FLASK_APP=backend "${VENV_DIR}/bin/flask" db stamp 0001 >> "${LOG_FILE}" 2>&1)
        fi
    fi

    _gauge 59 "Applying database migrations..."
    (cd "${BACKEND_DIR}" && FLASK_APP=backend "${VENV_DIR}/bin/flask" db upgrade >> "${LOG_FILE}" 2>&1)

    ## LEGACY PORTAL IMPORT (runs after schema is ready; only when user confirmed)
    if [[ "${LEGACY_IMPORT_ENABLED}" == "true" && -n "${LEGACY_PORTAL_ROOT}" ]]; then
        _gauge 62 "Importing legacy portal data..."

        LEGACY_IMPORT_TOOL="${BACKEND_DIR}/tools/legacy_portal_import.py"
        LEGACY_IMPORT_LOG="${LOG_FILE%.log}.legacy_import.log"

        if [[ ! -f "${LEGACY_IMPORT_TOOL}" ]]; then
            echo "WARNING: legacy_portal_import.py not found at ${LEGACY_IMPORT_TOOL}" >> "${LOG_FILE}"
            LEGACY_IMPORT_STATUS="Import skipped: tool not found"
        else
            LEGACY_IMPORT_JSON=$(
                "${VENV_DIR}/bin/python3" "${LEGACY_IMPORT_TOOL}" \
                    --config "${BACKEND_DIR}/config.yml" \
                    --root  "${LEGACY_PORTAL_ROOT}" \
                    2>> "${LEGACY_IMPORT_LOG}"
            ) || true

            echo "${LEGACY_IMPORT_JSON}" >> "${LEGACY_IMPORT_LOG}"

            if echo "${LEGACY_IMPORT_JSON}" | python3 -c \
                "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('success') else 1)" \
                2>/dev/null; then
                LEGACY_IMPORT_STATUS="Legacy data imported successfully from ${LEGACY_PORTAL_ROOT}"
                log_message "Legacy portal import succeeded"
            else
                LEGACY_IMPORT_STATUS="Legacy import attempted but reported an error — see ${LEGACY_IMPORT_LOG}"
                log_message "Legacy portal import reported failure; check ${LEGACY_IMPORT_LOG}"
            fi
        fi
    fi

    _gauge 67 "Applying backend data permissions..."
    sudo chown -R www-data:www-data "${INSTANCE_DIR}"
    sudo chmod -R 755 "${INSTANCE_DIR}"

    _gauge 70 "Installing npm packages..."
    (cd "${FRONTEND_DIR}" && npm ci >> "${LOG_FILE}" 2>&1)

    _gauge 75 "Building Angular frontend (this may take a while)..."
    if [[ ! -d "${FRONTEND_DIR}" ]]; then
        echo "Frontend directory not found: ${FRONTEND_DIR}" >> "${LOG_FILE}"
        exit 1
    fi
    (cd "${FRONTEND_DIR}" && npm run build -- --configuration production >> "${LOG_FILE}" 2>&1)

    _gauge 90 "Deploying frontend files..."
    sudo mkdir -p "${WEBROOT}"

    FRONTEND_BUILD_DIR=""
    for candidate in \
        "${FRONTEND_DIR}/dist/frontend/browser" \
        "${FRONTEND_DIR}/dist/frontend" \
        "${FRONTEND_DIR}/dist/adsb-portal/browser" \
        "${FRONTEND_DIR}/dist/adsb-portal"; do
        if [[ -f "${candidate}/index.html" ]]; then
            FRONTEND_BUILD_DIR="${candidate}"
            break
        fi
    done

    if [[ -z "${FRONTEND_BUILD_DIR}" ]]; then
        echo "Angular build output not found. Build may have failed." >> "${LOG_FILE}"
        exit 1
    fi

    sudo rm -rf "${WEBROOT:?}"/*
    sudo cp -r "${FRONTEND_BUILD_DIR}"/* "${WEBROOT}/"
    sudo chown -R www-data:www-data "${WEBROOT}"
    sudo chmod -R 755 "${WEBROOT}"

    _gauge 94 "Configuring Nginx..."
    cat << NGINXEOF | sudo tee "/etc/nginx/sites-available/${NGINX_SITE}" >/dev/null
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    location / {
        root /var/www/adsb-portal;
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }
}
NGINXEOF
    if [[ ! -L "/etc/nginx/sites-enabled/${NGINX_SITE}" ]]; then
        sudo ln -s "/etc/nginx/sites-available/${NGINX_SITE}" "/etc/nginx/sites-enabled/${NGINX_SITE}"
    fi
    if [[ -L "/etc/nginx/sites-enabled/default" ]]; then
        sudo rm "/etc/nginx/sites-enabled/default"
    fi
    sudo nginx -t >> "${LOG_FILE}" 2>&1

    ## LIGHTTPD-TO-NGINX TAKEOVER (runs after legacy data handling; before nginx restart)
    if [[ "${LIGHTTPD_INSTALLED}" == "true" && "${LIGHTTPD_ACTIVE_BEFORE}" == "true" ]]; then
        _gauge 96 "Stopping lighttpd to hand port 80 to Nginx..."

        if sudo systemctl stop lighttpd >> "${LOG_FILE}" 2>&1 && \
           sudo systemctl disable lighttpd >> "${LOG_FILE}" 2>&1; then
            LIGHTTPD_TAKEOVER_STATUS="lighttpd stopped and disabled; Nginx will own port 80"
            log_message "lighttpd stopped and disabled"
        else
            LIGHTTPD_TAKEOVER_STATUS="WARNING: failed to stop/disable lighttpd — Nginx may fail to bind port 80"
            log_message "WARNING: could not stop lighttpd"
        fi
    fi

    _gauge 97 "Creating systemd service..."
    cat << SVCEOF | sudo tee "/etc/systemd/system/${SYSTEMD_SERVICE}" >/dev/null
[Unit]
Description=ADSB Portal Flask Backend
After=network.target

[Service]
Type=notify
User=www-data
Group=www-data
WorkingDirectory=${BACKEND_DIR}
Environment="PATH=${VENV_DIR}/bin"
Environment="RRD_BASE=${RRD_BASE}"
ExecStart=${VENV_DIR}/bin/gunicorn -w 2 -k gthread --threads 2 --bind 127.0.0.1:8000 'backend:create_app()'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SVCEOF

    _gauge 99 "Starting services..."
    sudo systemctl daemon-reload >> "${LOG_FILE}" 2>&1
    sudo systemctl enable nginx >> "${LOG_FILE}" 2>&1

    if ! sudo systemctl restart nginx >> "${LOG_FILE}" 2>&1; then
        # Nginx failed to start — attempt lighttpd rollback if we stopped it.
        if [[ "${LIGHTTPD_ACTIVE_BEFORE}" == "true" ]]; then
            log_message "Nginx failed; attempting lighttpd rollback..."
            if sudo systemctl enable lighttpd >> "${LOG_FILE}" 2>&1 && \
               sudo systemctl start  lighttpd >> "${LOG_FILE}" 2>&1; then
                LIGHTTPD_TAKEOVER_STATUS="Nginx failed; lighttpd rolled back and re-started"
            else
                LIGHTTPD_TAKEOVER_STATUS="Nginx failed AND lighttpd rollback failed — port 80 may be unserved"
            fi
        fi
        echo "Nginx failed to restart — see ${LOG_FILE}" >> "${LOG_FILE}"
        exit 1
    fi
    sudo systemctl enable "${SYSTEMD_SERVICE}" >> "${LOG_FILE}" 2>&1
    sudo systemctl start "${SYSTEMD_SERVICE}" >> "${LOG_FILE}" 2>&1

    _gauge 100 "Installation complete!"
}

set +e
_install | whiptail --title "Installing ADSB Portal" \
    --gauge "Please wait..." 8 70 0
_PIPE_STATUS=("${PIPESTATUS[@]}")
set -e

if [[ ${_PIPE_STATUS[0]} -ne 0 ]]; then
    whiptail --title "Installation Failed" \
        --scrolltext \
        --textbox "${LOG_FILE}" 20 74
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "The ADS-B Portal installation failed"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "ADS-B Portal setup failed"
    echo ""
    read -p "Press enter to continue..." discard
    exit 1
fi

PORTAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
whiptail --title "Installation Complete" --msgbox "\
ADSB Portal has been installed successfully!

Portal URL:  http://${PORTAL_IP}/

No user, flight history, or ACARS records were seeded during installation.

Useful commands:
  systemctl status ${SYSTEMD_SERVICE}
  systemctl status nginx
  journalctl -u ${SYSTEMD_SERVICE} -f

Full installation log: ${LOG_FILE}" 18 64

if [[ "${LE_ENABLE}" == "true" ]]; then
    whiptail --title "Let's Encrypt Selection" --msgbox "\
You selected Let's Encrypt setup.

Automatic certificate provisioning is not enabled in this installer yet.

Complete HTTPS setup manually after installation using certbot when your DNS and firewall are ready." 14 78
    run_le_preflight "${LE_DOMAIN}"
fi

whiptail --title "Database Status" --msgbox "\
Database handling result:

    ${DB_INSTALL_MODE}

Selected database backend: ${DB_TYPE}

If an existing SQLite database was reused, migrations were applied to bring it to the current portal schema." 14 78

whiptail --title "RRD Status" --msgbox "\
RRD handling result:

    ${RRD_MIGRATION_STATUS}

RRD files used by the portal are stored under:
    ${RRD_BASE}" 12 78

whiptail --title "Legacy Portal Import Status" --msgbox "\
Legacy PHP portal detection result:

    ${LEGACY_IMPORT_STATUS}

No legacy data has been modified or deleted." 12 78

whiptail --title "Web Server Takeover Status" --msgbox "\
lighttpd-to-Nginx takeover result:

    ${LIGHTTPD_TAKEOVER_STATUS}

lighttpd packages and configuration were not removed." 12 78


## SETUP COMPLETE

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "ADS-B Portal setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

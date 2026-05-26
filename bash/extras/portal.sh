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
NODE_MAJOR=20
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

find_legacy_rrd_source() {
    local -a candidates=(
        "/usr/local/share/graphs1090/rrd"
    )

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
    sudo apt-get install -y whiptail 2>&1 | log_pipe
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
    DB_PKGS=""
    if [[ "${DB_TYPE}" == "mysql" ]]; then
        DB_PKGS="default-mysql-client"
    elif [[ "${DB_TYPE}" == "postgresql" ]]; then
        DB_PKGS="postgresql-client"
    fi
    # shellcheck disable=SC2086
    sudo apt-get install -y nginx python3-venv python3-pip curl whiptail rrdtool gnupg ca-certificates ${DB_PKGS} >> "${LOG_FILE}" 2>&1

    _gauge 18 "Configuring NodeSource repository..."
    sudo install -d -m 0755 /etc/apt/keyrings
    curl -fsSL "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    cat << NODESOURCEEOF | sudo tee /etc/apt/sources.list.d/nodesource.list >/dev/null
deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main
NODESOURCEEOF
    sudo apt-get update >> "${LOG_FILE}" 2>&1
    sudo apt-get install -y nodejs >> "${LOG_FILE}" 2>&1

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
        if command -v rsync &>/dev/null; then
            rsync -a --ignore-existing "${RRD_MIGRATE_SOURCE}/" "${RRD_BASE}/" >> "${LOG_FILE}" 2>&1
        else
            cp -an "${RRD_MIGRATE_SOURCE}/." "${RRD_BASE}/" >> "${LOG_FILE}" 2>&1
        fi
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

    _gauge 67 "Applying backend data permissions..."
    sudo chown -R www-data:www-data "${INSTANCE_DIR}"
    sudo chmod -R 755 "${INSTANCE_DIR}"

    if [[ ! -d "${FRONTEND_DIR}/node_modules" ]]; then
        _gauge 70 "Installing npm packages..."
        (cd "${FRONTEND_DIR}" && npm ci >> "${LOG_FILE}" 2>&1)
    fi

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
    cat << 'NGINXEOF' | sudo tee "/etc/nginx/sites-available/${NGINX_SITE}" >/dev/null
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
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
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
    sudo systemctl restart nginx >> "${LOG_FILE}" 2>&1
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


## SETUP COMPLETE

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "ADS-B Portal setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

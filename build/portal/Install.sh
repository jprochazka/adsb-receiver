#!/usr/bin/env bash

set -euo pipefail

# ADSB Portal Installation Script
# Installs Flask backend with Gunicorn, Angular frontend, and Nginx reverse proxy
# on Debian/Raspberry Pi hardware.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="${SCRIPT_DIR}/backend"
FRONTEND_DIR="${SCRIPT_DIR}/frontend"
VENV_DIR="${BACKEND_DIR}/.venv"
WEBROOT="/var/www/adsb-portal"
NGINX_SITE="adsb-portal"
SYSTEMD_SERVICE="adsb-portal-backend.service"
INSTANCE_DIR="${BACKEND_DIR}/instance"
RRD_BASE="${BACKEND_DIR}/instance/rrd"
OPENSKY_BASE="${BACKEND_DIR}/instance/opensky"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root."
    exit 1
fi

print_info "Starting ADSB Portal installation..."

# ---------------------------------------------------------------------------
# Gather configuration from the user
# ---------------------------------------------------------------------------

# Ensure whiptail is available before showing any dialogs
if ! command -v whiptail &>/dev/null; then
    print_info "Installing whiptail..."
    apt-get install -y whiptail
fi

# Database type selection
DB_TYPE=$(whiptail --title "ADSB Portal Setup" \
    --menu "Select the database backend to use:" 12 60 3 \
    "sqlite"     "SQLite (simple, file-based)" \
    "mysql"      "MySQL / MariaDB" \
    "postgresql" "PostgreSQL" \
    3>&1 1>&2 2>&3) || { print_error "Installation cancelled."; exit 1; }

if [[ "${DB_TYPE}" == "mysql" || "${DB_TYPE}" == "postgresql" ]]; then
    DB_HOST=$(whiptail --title "Database Configuration" \
        --inputbox "Database host:" 8 60 "127.0.0.1" \
        3>&1 1>&2 2>&3) || { print_error "Installation cancelled."; exit 1; }

    DB_NAME=$(whiptail --title "Database Configuration" \
        --inputbox "Database name:" 8 60 "adsbportal" \
        3>&1 1>&2 2>&3) || { print_error "Installation cancelled."; exit 1; }

    DB_USER=$(whiptail --title "Database Configuration" \
        --inputbox "Database user:" 8 60 "portaluser" \
        3>&1 1>&2 2>&3) || { print_error "Installation cancelled."; exit 1; }

    DB_PASS=$(whiptail --title "Database Configuration" \
        --passwordbox "Database password:" 8 60 \
        3>&1 1>&2 2>&3) || { print_error "Installation cancelled."; exit 1; }
fi

# MySQL admin credentials (needed to create the database and application user)
if [[ "${DB_TYPE}" == "mysql" ]]; then
    DB_ADMIN_USER=$(whiptail --title "MySQL Admin Credentials" \
        --inputbox "MySQL admin username (used to create database and user):" 8 60 "root" \
        3>&1 1>&2 2>&3) || { print_error "Installation cancelled."; exit 1; }

    DB_ADMIN_PASS=$(whiptail --title "MySQL Admin Credentials" \
        --passwordbox "MySQL admin password:" 8 60 \
        3>&1 1>&2 2>&3) || { print_error "Installation cancelled."; exit 1; }
fi

# JWT secret key (minimum 32 characters)
while true; do
    JWT_SECRET=$(whiptail --title "Security Configuration" \
        --passwordbox "JWT secret key (minimum 32 characters):" 8 60 \
        3>&1 1>&2 2>&3) || { print_error "Installation cancelled."; exit 1; }
    if [[ ${#JWT_SECRET} -ge 32 ]]; then
        break
    fi
    whiptail --title "Invalid Input" \
        --msgbox "JWT secret key must be at least 32 characters. Please try again." 8 60
done

# Pre-compute DB variables before entering the gauge subshell
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

# ---------------------------------------------------------------------------
# Run installation steps with a whiptail progress gauge
# Each "XXX / percent / message / XXX" block updates the bar and status text.
# All command output is captured to LOG_FILE; shown on failure.
# ---------------------------------------------------------------------------

LOG_FILE="/tmp/adsb-portal-install.log"
> "${LOG_FILE}"

_install() {
    set -euo pipefail

    # Helper: update gauge (percent and status line)
    _gauge() { printf 'XXX\n%s\n%s\nXXX\n' "$1" "$2"; }

    # --- Write config.yml ---
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

    # --- Update package list ---
    _gauge 8 "Updating package list..."
    apt-get update >> "${LOG_FILE}" 2>&1

    # --- System packages ---
    _gauge 14 "Installing system packages..."
    DB_PKGS=""
    if [[ "${DB_TYPE}" == "mysql" ]]; then
        DB_PKGS="default-mysql-client"
    elif [[ "${DB_TYPE}" == "postgresql" ]]; then
        DB_PKGS="postgresql-client"
    fi
    # shellcheck disable=SC2086
    apt-get install -y nginx python3-venv python3-pip curl whiptail rrdtool ${DB_PKGS} >> "${LOG_FILE}" 2>&1

    # --- Python virtual environment ---
    _gauge 20 "Setting up Python virtual environment..."
    if [[ ! -d "${VENV_DIR}" ]]; then
        python3 -m venv "${VENV_DIR}" >> "${LOG_FILE}" 2>&1
    fi

    # --- pip bootstrap ---
    _gauge 25 "Upgrading pip, setuptools, and wheel..."
    "${VENV_DIR}/bin/pip" install --upgrade pip setuptools wheel >> "${LOG_FILE}" 2>&1

    # --- Python dependencies ---
    _gauge 33 "Installing Python dependencies..."
    if [[ -f "${BACKEND_DIR}/requirements.txt" ]]; then
        "${VENV_DIR}/bin/pip" install -r "${BACKEND_DIR}/requirements.txt" >> "${LOG_FILE}" 2>&1
    fi

    # --- Gunicorn ---
    _gauge 43 "Installing Gunicorn..."
    "${VENV_DIR}/bin/pip" install "gunicorn[gthread]" >> "${LOG_FILE}" 2>&1

    # --- Backend runtime data directories ---
    _gauge 47 "Preparing backend data directories..."
    mkdir -p "${INSTANCE_DIR}"
    mkdir -p "${RRD_BASE}"
    mkdir -p "${OPENSKY_BASE}"
    chown -R www-data:www-data "${RRD_BASE}" "${OPENSKY_BASE}"
    chmod -R 755 "${RRD_BASE}" "${OPENSKY_BASE}"

    # --- Create database (MySQL / PostgreSQL; SQLite is created automatically by Alembic) ---
    if [[ "${DB_TYPE}" == "mysql" ]]; then
        _gauge 51 "Creating MySQL database and user..."
        mysql -h"${MYSQL_HOST}" -u"${MYSQL_ADMIN_USER}" -p"${MYSQL_ADMIN_PASS}" >> "${LOG_FILE}" 2>&1 << SQLEOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_NAME}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASS}';
GRANT ALL PRIVILEGES ON \`${MYSQL_NAME}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
SQLEOF
    elif [[ "${DB_TYPE}" == "postgresql" ]]; then
        _gauge 51 "Creating PostgreSQL database and user..."
        sudo -u postgres createdb "${PG_NAME}" >> "${LOG_FILE}" 2>&1 || true
        sudo -u postgres psql -c "CREATE USER \"${PG_USER}\" WITH PASSWORD '${PG_PASS}';" >> "${LOG_FILE}" 2>&1 || true
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"${PG_NAME}\" TO \"${PG_USER}\";" >> "${LOG_FILE}" 2>&1
    fi

    # --- Database migrations ---
    _gauge 55 "Applying database migrations..."
    (cd "${BACKEND_DIR}" && FLASK_APP=backend "${VENV_DIR}/bin/flask" db upgrade >> "${LOG_FILE}" 2>&1)

    # --- Runtime ownership for SQLite/instance writes (includes OpenSky DB downloads) ---
    _gauge 63 "Applying backend data permissions..."
    chown -R www-data:www-data "${INSTANCE_DIR}"
    chmod -R 755 "${INSTANCE_DIR}"

    # --- npm dependencies (skipped if already present) ---
    if [[ ! -d "${FRONTEND_DIR}/node_modules" ]]; then
        _gauge 66 "Installing npm packages..."
        (cd "${FRONTEND_DIR}" && npm ci >> "${LOG_FILE}" 2>&1)
    fi

    # --- Angular production build ---
    _gauge 71 "Building Angular frontend (this may take a while)..."
    if [[ ! -d "${FRONTEND_DIR}" ]]; then
        echo "Frontend directory not found: ${FRONTEND_DIR}" >> "${LOG_FILE}"
        exit 1
    fi
    (cd "${FRONTEND_DIR}" && npm run build -- --configuration production >> "${LOG_FILE}" 2>&1)

    # --- Deploy frontend ---
    _gauge 86 "Deploying frontend files..."
    mkdir -p "${WEBROOT}"

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

    rm -rf "${WEBROOT:?}"/*
    cp -r "${FRONTEND_BUILD_DIR}"/* "${WEBROOT}/"
    chown -R www-data:www-data "${WEBROOT}"
    chmod -R 755 "${WEBROOT}"

    # --- Nginx configuration ---
    _gauge 90 "Configuring Nginx..."
    cat > "/etc/nginx/sites-available/${NGINX_SITE}" << 'NGINXEOF'
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
        ln -s "/etc/nginx/sites-available/${NGINX_SITE}" "/etc/nginx/sites-enabled/${NGINX_SITE}"
    fi
    if [[ -L "/etc/nginx/sites-enabled/default" ]]; then
        rm "/etc/nginx/sites-enabled/default"
    fi
    nginx -t >> "${LOG_FILE}" 2>&1

    # --- Systemd service ---
    _gauge 93 "Creating systemd service..."
    cat > "/etc/systemd/system/${SYSTEMD_SERVICE}" << SVCEOF
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

    # --- Enable and start services ---
    _gauge 97 "Starting services..."
    systemctl daemon-reload >> "${LOG_FILE}" 2>&1
    systemctl enable nginx >> "${LOG_FILE}" 2>&1
    systemctl restart nginx >> "${LOG_FILE}" 2>&1
    systemctl enable "${SYSTEMD_SERVICE}" >> "${LOG_FILE}" 2>&1
    systemctl start "${SYSTEMD_SERVICE}" >> "${LOG_FILE}" 2>&1

    _gauge 100 "Installation complete!"
}

# Run _install piped into whiptail --gauge.
# set -e is suspended around the pipeline so we can inspect PIPESTATUS.
set +e
_install | whiptail --title "Installing ADSB Portal" \
    --gauge "Please wait..." 8 70 0
_PIPE_STATUS=("${PIPESTATUS[@]}")
set -e

if [[ ${_PIPE_STATUS[0]} -ne 0 ]]; then
    whiptail --title "Installation Failed" \
        --scrolltext \
        --textbox "${LOG_FILE}" 20 74
    exit 1
fi

# ---------------------------------------------------------------------------
# Success dialog
# ---------------------------------------------------------------------------
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

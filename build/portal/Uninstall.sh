#!/usr/bin/env bash

set -euo pipefail

# ADSB Portal Uninstallation Script
# Removes Flask backend service, Nginx configuration, and optionally deployed files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/backend/.venv"
WEBROOT="/var/www/adsb-portal"
NGINX_SITE="adsb-portal"
SYSTEMD_SERVICE="adsb-portal-backend.service"
RRD_BASE="${SCRIPT_DIR}/backend/instance/rrd"
OPENSKY_BASE="${SCRIPT_DIR}/backend/instance/opensky"

# Flags
REMOVE_WEBROOT=false
REMOVE_VENV=false
REMOVE_RRD=false
REMOVE_OPENSKY=false
PURGE_PACKAGES=false
INTERACTIVE=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --remove-webroot)
            REMOVE_WEBROOT=true
            shift
            ;;
        --remove-venv)
            REMOVE_VENV=true
            shift
            ;;
        --remove-rrd)
            REMOVE_RRD=true
            shift
            ;;
        --remove-opensky)
            REMOVE_OPENSKY=true
            shift
            ;;
        --purge-packages)
            PURGE_PACKAGES=true
            shift
            ;;
        --yes)
            INTERACTIVE=false
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Ensure whiptail is available
if ! command -v whiptail &>/dev/null; then
    apt-get install -y whiptail
fi

# ---------------------------------------------------------------------------
# Interactive prompts (skipped when --yes is passed)
# ---------------------------------------------------------------------------

if [[ "${INTERACTIVE}" == true ]]; then
    # Optional-removal checklist
    CHOICES=$(whiptail --title "ADSB Portal Uninstaller" \
        --checklist "The systemd service and Nginx config will always be removed.\nSelect any additional items to also remove:" 14 72 5 \
        "webroot"  "Frontend files (${WEBROOT})"                 "OFF" \
        "venv"     "Python virtual environment (${VENV_DIR})"    "OFF" \
        "rrd"      "RRD data directory (${RRD_BASE})"             "OFF" \
        "opensky"  "OpenSky database files (${OPENSKY_BASE})"     "OFF" \
        "packages" "System packages (nginx, python3-venv, python3-pip, curl, rrdtool, nodejs, npm)"  "OFF" \
        3>&1 1>&2 2>&3) || { echo "Uninstallation cancelled."; exit 0; }

    [[ "${CHOICES}" == *'"webroot"'*  ]] && REMOVE_WEBROOT=true
    [[ "${CHOICES}" == *'"venv"'*     ]] && REMOVE_VENV=true
    [[ "${CHOICES}" == *'"rrd"'*      ]] && REMOVE_RRD=true
    [[ "${CHOICES}" == *'"opensky"'*  ]] && REMOVE_OPENSKY=true
    [[ "${CHOICES}" == *'"packages"'* ]] && PURGE_PACKAGES=true

    # Build a summary of what will be removed
    SUMMARY="The following will be removed:\n\n  - systemd service: ${SYSTEMD_SERVICE}\n  - Nginx site config: ${NGINX_SITE}"
    [[ "${REMOVE_WEBROOT}"  == true ]] && SUMMARY+="\n  - Frontend files: ${WEBROOT}"
    [[ "${REMOVE_VENV}"     == true ]] && SUMMARY+="\n  - Virtual environment: ${VENV_DIR}"
    [[ "${REMOVE_RRD}"      == true ]] && SUMMARY+="\n  - RRD data directory: ${RRD_BASE}"
    [[ "${REMOVE_OPENSKY}"  == true ]] && SUMMARY+="\n  - OpenSky database files: ${OPENSKY_BASE}"
    [[ "${PURGE_PACKAGES}"  == true ]] && SUMMARY+="\n  - System packages: nginx, python3-venv, python3-pip, curl, rrdtool, nodejs, npm"

    whiptail --title "Confirm Uninstallation" \
        --yesno "${SUMMARY}\n\nContinue?" 16 64 || { echo "Uninstallation cancelled."; exit 0; }
fi

# ---------------------------------------------------------------------------
# Run uninstallation steps with a whiptail progress gauge
# ---------------------------------------------------------------------------

LOG_FILE="/tmp/adsb-portal-uninstall.log"
> "${LOG_FILE}"

_uninstall() {
    set -euo pipefail

    _gauge() { printf 'XXX\n%s\n%s\nXXX\n' "$1" "$2"; }

    # --- Stop and disable backend service ---
    _gauge 10 "Stopping backend service..."
    if systemctl is-active --quiet "${SYSTEMD_SERVICE}" 2>/dev/null; then
        systemctl stop "${SYSTEMD_SERVICE}" >> "${LOG_FILE}" 2>&1
    fi
    if systemctl is-enabled --quiet "${SYSTEMD_SERVICE}" 2>/dev/null; then
        systemctl disable "${SYSTEMD_SERVICE}" >> "${LOG_FILE}" 2>&1
    fi

    # --- Remove systemd service file ---
    _gauge 25 "Removing systemd service file..."
    if [[ -f "/etc/systemd/system/${SYSTEMD_SERVICE}" ]]; then
        rm "/etc/systemd/system/${SYSTEMD_SERVICE}"
    fi
    systemctl daemon-reload >> "${LOG_FILE}" 2>&1

    # --- Remove Nginx configuration ---
    _gauge 45 "Removing Nginx configuration..."
    if [[ -L "/etc/nginx/sites-enabled/${NGINX_SITE}" ]]; then
        rm "/etc/nginx/sites-enabled/${NGINX_SITE}"
    fi
    if [[ -f "/etc/nginx/sites-available/${NGINX_SITE}" ]]; then
        rm "/etc/nginx/sites-available/${NGINX_SITE}"
    fi
    # Restore default Nginx site if absent
    if [[ -f "/etc/nginx/sites-available/default" ]] && [[ ! -L "/etc/nginx/sites-enabled/default" ]]; then
        ln -s "/etc/nginx/sites-available/default" "/etc/nginx/sites-enabled/default"
    fi
    if systemctl is-active --quiet nginx 2>/dev/null; then
        nginx -t >> "${LOG_FILE}" 2>&1 && systemctl reload nginx >> "${LOG_FILE}" 2>&1 \
            || systemctl restart nginx >> "${LOG_FILE}" 2>&1
    fi

    # --- Remove webroot (optional) ---
    _gauge 65 "Removing frontend files..."
    if [[ "${REMOVE_WEBROOT}" == true ]] && [[ -d "${WEBROOT}" ]]; then
        rm -rf "${WEBROOT}"
    fi

    # --- Remove venv (optional) ---
    _gauge 78 "Removing Python virtual environment..."
    if [[ "${REMOVE_VENV}" == true ]] && [[ -d "${VENV_DIR}" ]]; then
        rm -rf "${VENV_DIR}"
    fi

    # --- Remove RRD data directory (optional) ---
    _gauge 84 "Removing RRD data directory..."
    if [[ "${REMOVE_RRD}" == true ]] && [[ -d "${RRD_BASE}" ]]; then
        rm -rf "${RRD_BASE}"
    fi

    # --- Remove OpenSky data directory (optional) ---
    _gauge 86 "Removing OpenSky database files..."
    if [[ "${REMOVE_OPENSKY}" == true ]] && [[ -d "${OPENSKY_BASE}" ]]; then
        rm -rf "${OPENSKY_BASE}"
    fi

    # --- Purge packages (optional) ---
    _gauge 90 "Removing system packages..."
    if [[ "${PURGE_PACKAGES}" == true ]]; then
        apt-get remove -y nginx python3-venv python3-pip curl rrdtool nodejs npm >> "${LOG_FILE}" 2>&1 || true
        apt-get autoremove -y >> "${LOG_FILE}" 2>&1 || true
    fi

    _gauge 100 "Uninstallation complete!"
}

set +e
_uninstall | whiptail --title "Uninstalling ADSB Portal" \
    --gauge "Please wait..." 8 64 0
_PIPE_STATUS=("${PIPESTATUS[@]}")
set -e

if [[ ${_PIPE_STATUS[0]} -ne 0 ]]; then
    whiptail --title "Uninstallation Failed" \
        --scrolltext \
        --textbox "${LOG_FILE}" 20 74
    exit 1
fi

# ---------------------------------------------------------------------------
# Success dialog
# ---------------------------------------------------------------------------

SUMMARY="ADSB Portal has been uninstalled.\n\nRemoved:\n  - systemd service\n  - Nginx configuration"
[[ "${REMOVE_WEBROOT}"  == true ]] && SUMMARY+="\n  - Frontend files"
[[ "${REMOVE_VENV}"     == true ]] && SUMMARY+="\n  - Python virtual environment"
[[ "${REMOVE_RRD}"      == true ]] && SUMMARY+="\n  - RRD data directory"
[[ "${REMOVE_OPENSKY}"  == true ]] && SUMMARY+="\n  - OpenSky database files"
[[ "${PURGE_PACKAGES}"  == true ]] && SUMMARY+="\n  - System packages"
SUMMARY+="\n\nFull log: ${LOG_FILE}"

whiptail --title "Uninstallation Complete" --msgbox "${SUMMARY}" 16 64

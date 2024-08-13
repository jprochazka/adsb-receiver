#!/bin/bash

### INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

## VARIABLES

PORTAL_BUILD_DIRECTORY="${RECEIVER_BUILD_DIRECTORY}/portal"
PORTAL_PYTHON_DIRECTORY="${PORTAL_BUILD_DIRECTORY}/python"


## SETUP FLIGHT LOGGING

log_heading "Setting up core advanced portal features"

case $ADSB_PORTAL_DATABASE_ENGINE in
    "MySQL")
        log_message "Creating the flight Python configuration file for MySQL"
        tee ${PORTAL_PYTHON_DIRECTORY}/config.json > /dev/null <<EOF
{
    "database":{"type":"mysql",
                "host":"${ADSB_PORTAL_DATABASE_HOSTNAME}",
                "user":"${ADSB_PORTAL_DATABASE_USER}",
                "passwd":"${ADSB_PORTAL_DATABASE_PASSWORD1}",
                "db":"${ADSB_PORTAL_DATABASE_NAME}"}
}
EOF
            ;;
    "SQLite")
        log_message "Creating the Python configuration file for SQLite"
        tee ${PORTAL_PYTHON_DIRECTORY}/config.json > /dev/null <<EOF
{
    "database":{"type":"sqlite",
                "host":"${ADSB_PORTAL_DATABASE_HOSTNAME}",
                "user":"${ADSB_PORTAL_DATABASE_USER}",
                "passwd":"${ADSB_PORTAL_DATABASE_PASSWORD1}",
                "db":"${ADSB_PORTAL_DATABASE_NAME}"}
}
EOF
        ;;
    *)
        log_message "No core setup required"
        ;;
esac

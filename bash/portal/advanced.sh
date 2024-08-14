#!/bin/bash

## INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh


## VARIABLES

python_path=`which python3`

## SETUP ADVANCED PORTAL FEATURES

log_heading "Setting up advanced portal features"

log_message "Creating the Python configuration file needed for logging"
tee ${RECEIVER_BUILD_DIRECTORY}/portal/python/config.json > /dev/null <<EOF
{
    "database":{"type":"${ADSB_PORTAL_DATABASE_ENGINE,,}",
                "host":"${ADSB_PORTAL_DATABASE_HOSTNAME}",
                "user":"${ADSB_PORTAL_DATABASE_USER}",
                "passwd":"${ADSB_PORTAL_DATABASE_PASSWORD1}",
                "db":"${ADSB_PORTAL_DATABASE_NAME}"}
}
EOF

# Create the cron jobs responsible for logging and maintenance.
log_message "Creating cron file needed to run the Python logging scripts"
sudo tee /etc/cron.d/adsb-receiver-flight-logging > /dev/null <<EOF
* * * * * root ${python_path} ${RECEIVER_BUILD_DIRECTORY}/portal/python/flights.py
0 0 * * * root ${python_path} ${RECEIVER_BUILD_DIRECTORY}/portal/python/maintenance.py
EOF

#!/bin/bash

## VARIABLES

python_path=`which python3`


## SETUP FLIGHT LOGGING

log_heading "Setting up portal flight logging and maintenance"

# Create the cron jobs responsible for logging and maintenance.
log_message "Creating the portal script cron file"
sudo tee /etc/cron.d/adsb-receiver-flight-logging > /dev/null <<EOF
* * * * * root ${python_path} ${RECEIVER_BUILD_DIRECTORY}/portal/python/flights.py
0 0 * * * root ${python_path} ${RECEIVER_BUILD_DIRECTORY}/portal/python/maintenance.py
EOF

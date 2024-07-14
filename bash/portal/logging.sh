#!/bin/bash

## VARIABLES

python_path=`which python3`

## SETUP FLIGHT LOGGING

echo -e ""
echo -e "\e[95m  Setting up portal flight logging and maintenance...\e[97m"
echo -e ""

# Create the cron jobs responsible for logging and maintenance.
echo -e "\e[94m  Creating the portal script cron file...\e[97m"
sudo tee /etc/cron.d/adsb-receiver-flight-logging > /dev/null <<EOF
* * * * * root ${python_path} ${RECEIVER_BUILD_DIRECTORY}/portal/python/flights.py
0 0 * * * root ${python_path} ${RECEIVER_BUILD_DIRECTORY}/portal/python/maintenance.py
EOF

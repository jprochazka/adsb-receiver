#!/bin/bash

## DISPLAY COLORS

readonly display_default="\033[0m"
readonly display_heading="\033[1;36m"
readonly display_message="\033[2;36m"
readonly display_project_name="\033[1;31m"
readonly display_title_heading="\033[1;32m"
readonly display_title_message="\033[2;32m"
readonly display_warning_heading="\033[1;33m"
readonly display_warning_message="\033[2;33m"
readonly display_alert_heading="\033[1;31m"
readonly display_alert_message="\033[2;31m"
readonly display_false_inline="\033[2;31m"
readonly display_true_inline="\033[2;32m"

## SOFTWARE VERSIONS

# FlightAware
readonly dump1090_fa_current_version="10.2"
readonly dump978_fa_current_version="10.2"
readonly piaware_current_version="10.2"

# PlaneFinder Client
readonly pfclient_current_version_armhf="5.3.29"
readonly pfclient_current_version_arm64="5.3.29"
readonly pfclient_current_version_amd64="5.3.29"

# Flightradar24 Client
readonly fr24feed_current_version="1.0.54-0"

# OpenSky Network Client
readonly opensky_feeder_current_version="2.1.7-1"
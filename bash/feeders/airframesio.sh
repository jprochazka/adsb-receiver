#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

get_service_file() {
	local service_name="$1"
	if [[ -f "/etc/systemd/system/${service_name}" ]]; then
		echo "/etc/systemd/system/${service_name}"
	elif [[ -f "/lib/systemd/system/${service_name}" ]]; then
		echo "/lib/systemd/system/${service_name}"
	else
		echo ""
	fi
}

get_exec_start_line() {
	local service_file="$1"
	grep -E '^ExecStart=' "${service_file}" | head -n 1
}

replace_exec_start_line() {
	local service_file="$1"
	local updated_exec_start="$2"
	local escaped_line=""

	escaped_line=$(printf '%s\n' "${updated_exec_start}" | sed -e 's/[\/&]/\\&/g')
	sudo sed -i -E "s#^ExecStart=.*#${escaped_line}#" "${service_file}"
}

configure_acarsdec_for_airframes() {
	local service_file="$1"
	local station_id="$2"
	local exec_start=""
	local updated_exec_start=""
	local backup_file=""

	exec_start=$(get_exec_start_line "${service_file}")
	if [[ -z "${exec_start}" ]]; then
		log_warning_message "Could not find ExecStart in ${service_file}; skipping ACARS configuration"
		return
	fi

	updated_exec_start="${exec_start}"

	if [[ "${updated_exec_start}" =~ [[:space:]]-o[[:space:]]*[0-9]+ ]]; then
		updated_exec_start=$(echo "${updated_exec_start}" | sed -E 's/[[:space:]]-o[[:space:]]*[0-9]+/ -o 4/g')
	else
		updated_exec_start="${updated_exec_start} -o 4"
	fi

	if [[ "${updated_exec_start}" =~ [[:space:]]-j[[:space:]]+[^[:space:]]+ ]]; then
		updated_exec_start=$(echo "${updated_exec_start}" | sed -E 's#[[:space:]]-j[[:space:]]+[^[:space:]]+# -j feed.airframes.io:5550#g')
	else
		updated_exec_start="${updated_exec_start} -j feed.airframes.io:5550"
	fi

	if [[ "${updated_exec_start}" =~ [[:space:]]-i[[:space:]]+[^[:space:]]+ ]]; then
		updated_exec_start=$(echo "${updated_exec_start}" | sed -E "s#[[:space:]]-i[[:space:]]+[^[:space:]]+# -i ${station_id}#g")
	else
		updated_exec_start="${updated_exec_start} -i ${station_id}"
	fi

	backup_file="${service_file}.airframesio.bak"
	log_message "Creating backup at ${backup_file}"
	sudo cp -f "${service_file}" "${backup_file}"

	log_message "Updating ACARSDEC service output for Airframes.io"
	replace_exec_start_line "${service_file}" "${updated_exec_start}"
}

configure_dumpvdl2_for_airframes() {
	local service_file="$1"
	local station_id="$2"
	local exec_start=""
	local updated_exec_start=""
	local backup_file=""

	exec_start=$(get_exec_start_line "${service_file}")
	if [[ -z "${exec_start}" ]]; then
		log_warning_message "Could not find ExecStart in ${service_file}; skipping dumpvdl2 configuration"
		return
	fi

	updated_exec_start="${exec_start}"

	if [[ "${updated_exec_start}" != *"decoded:json:udp:address=feed.airframes.io,port=5552"* ]]; then
		updated_exec_start="${updated_exec_start} --output decoded:json:udp:address=feed.airframes.io,port=5552"
	fi

	if [[ "${updated_exec_start}" =~ [[:space:]]--station-id[[:space:]]+[^[:space:]]+ ]]; then
		updated_exec_start=$(echo "${updated_exec_start}" | sed -E "s#[[:space:]]--station-id[[:space:]]+[^[:space:]]+# --station-id ${station_id}#g")
	else
		updated_exec_start="${updated_exec_start} --station-id ${station_id}"
	fi

	backup_file="${service_file}.airframesio.bak"
	log_message "Creating backup at ${backup_file}"
	sudo cp -f "${service_file}" "${backup_file}"

	log_message "Updating dumpvdl2 service output for Airframes.io"
	replace_exec_start_line "${service_file}" "${updated_exec_start}"
}

clear
log_project_title
log_title_heading "Setting up Airframes.io feeding"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
			  --title "Airframes.io Feed Setup" \
			  --yesno "Airframes.io accepts direct feeds from decoder outputs (ACARS/VDL2/HFDL).\n\nThis setup script auto-detects compatible installed decoders and can modify their service configuration to feed Airframes.io endpoints.\n\nContinue with Airframes.io setup?" \
			  14 78; then
	echo ""
	log_alert_heading "INSTALLATION HALTED"
	log_alert_message "Setup has been halted at the request of the user"
	echo ""
	log_title_message "------------------------------------------------------------------------------"
	log_title_heading "Airframes.io setup halted"
	echo ""
	exit 1
fi


## CHECK FOR PREREQUISITE PACKAGES

log_heading "Installing packages needed for Airframes.io setup"

check_package curl


## DETECT INSTALLED DECODERS

log_heading "Detecting compatible decoders"

acars_service_file=$(get_service_file "acarsdec.service")
dumpvdl2_service_file=$(get_service_file "dumpvdl2.service")

decoder_summary="Detected decoder services:\n\n"

if [[ -n "${acars_service_file}" ]]; then
	decoder_summary+="- ACARSDEC: found (${acars_service_file})\n"
else
	decoder_summary+="- ACARSDEC: not found\n"
fi

if [[ -n "${dumpvdl2_service_file}" ]]; then
	decoder_summary+="- dumpvdl2: found (${dumpvdl2_service_file})\n"
else
	decoder_summary+="- dumpvdl2: not found\n"
fi

if [[ -z "${acars_service_file}" && -z "${dumpvdl2_service_file}" ]]; then
	if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
				--title "No Compatible Decoders Found" \
				--yesno "No supported decoder services were detected.\n\nWould you like to run the official Airframes installer now?\n\nThis can install decoder and feeder dependencies interactively." \
				12 78; then
		log_message "Executing official Airframes installer"
		echo ""
		curl -sSL https://install.airframes.sh/installer | bash
		echo ""
	else
		log_warning_message "No compatible decoder services were found"
	fi
	exit 1
fi

whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
		 --title "Detected Decoder Services" \
		 --msgbox "${decoder_summary}" \
		 16 78


## GATHER STATION IDS

acars_station_id=""
vdl2_station_id=""

if [[ -n "${acars_service_file}" ]]; then
	acars_station_id=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
		--title "ACARS Station ID" \
		--inputbox "Enter Airframes.io station ID for ACARS feed (example: KE-KSEA-ACARS):" \
		8 78 "XX-YYYY-ACARS" 3>&1 1>&2 2>&3)
	if [[ $? -ne 0 || -z "${acars_station_id}" ]]; then
		log_alert_heading "INSTALLATION HALTED"
		log_alert_message "Setup has been halted due to lack of required information"
		exit 1
	fi
fi

if [[ -n "${dumpvdl2_service_file}" ]]; then
	vdl2_station_id=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
		--title "VDL2 Station ID" \
		--inputbox "Enter Airframes.io station ID for VDL2 feed (example: KE-KSEA-VDL2):" \
		8 78 "XX-YYYY-VDL2" 3>&1 1>&2 2>&3)
	if [[ $? -ne 0 || -z "${vdl2_station_id}" ]]; then
		log_alert_heading "INSTALLATION HALTED"
		log_alert_message "Setup has been halted due to lack of required information"
		exit 1
	fi
fi

## APPLY CONFIGURATION

log_heading "Configuring decoder services for Airframes.io"

needs_reload="false"

if [[ -n "${acars_service_file}" ]]; then
	if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
				--title "Configure ACARSDEC" \
				--yesno "Apply Airframes.io settings to ACARSDEC now?\n\nThis sets:\n  -o 4\n  -j feed.airframes.io:5550\n  -i ${acars_station_id}\n\nNote: This may change existing local ACARS routing behavior." \
				15 78; then
		configure_acarsdec_for_airframes "${acars_service_file}" "${acars_station_id}"
		needs_reload="true"
	fi
fi

if [[ -n "${dumpvdl2_service_file}" ]]; then
	if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
				--title "Configure dumpvdl2" \
				--yesno "Apply Airframes.io settings to dumpvdl2 now?\n\nThis adds:\n  --output decoded:json:udp:address=feed.airframes.io,port=5552\n  --station-id ${vdl2_station_id}" \
				13 78; then
		configure_dumpvdl2_for_airframes "${dumpvdl2_service_file}" "${vdl2_station_id}"
		needs_reload="true"
	fi
fi

if [[ "${needs_reload}" == "true" ]]; then
	log_message "Reloading systemd daemon"
	sudo systemctl daemon-reload

	if [[ -n "${acars_service_file}" ]]; then
		log_message "Restarting acarsdec.service"
		sudo systemctl restart acarsdec.service
	fi
	if [[ -n "${dumpvdl2_service_file}" ]]; then
		log_message "Restarting dumpvdl2.service"
		sudo systemctl restart dumpvdl2.service
	fi
fi


## POST INSTALLATION OPERATIONS

summary_message="Airframes.io setup complete.\n\nConfigured endpoints:\n"

if [[ -n "${acars_service_file}" ]]; then
	summary_message+="- ACARS: feed.airframes.io:5550 (UDP)\n"
fi
if [[ -n "${dumpvdl2_service_file}" ]]; then
	summary_message+="- VDL2: feed.airframes.io:5552 (UDP)\n"
fi
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
		 --title "Airframes.io Feed Setup Complete" \
		 --msgbox "${summary_message}" \
		 14 78


## SETUP COMPLETE

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "Airframes.io setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

STREAM1090_BUILD_DIR="$RECEIVER_BUILD_DIRECTORY/stream1090"
STREAM1090_REPO_DIR="$STREAM1090_BUILD_DIR/stream1090"
STREAM1090_CONFIG_DIR="$STREAM1090_REPO_DIR/configs"
STREAM1090_SERVICE_FILE="/etc/systemd/system/stream1090.service"
STREAM1090_DECODER_PORT="30001"

backup_file() {
	local file_path="$1"

	if [[ -f "${file_path}" ]]; then
		log_message "Creating backup of ${file_path}"
		sudo cp -f "${file_path}" "${file_path}.stream1090.bak"
	fi
}

ensure_option_present() {
	local current_value="$1"
	local option_value="$2"

	if [[ " ${current_value} " != *" ${option_value} "* ]]; then
		if [[ -n "${current_value}" ]]; then
			echo "${current_value} ${option_value}"
		else
			echo "${option_value}"
		fi
	else
		echo "${current_value}"
	fi
}

set_ini_value() {
	local config_file="$1"
	local key="$2"
	local value="$3"

	if grep -Eq "^[#;[:space:]]*${key}[[:space:]]*=" "${config_file}"; then
		sudo sed -i -E "s#^[#;[:space:]]*${key}[[:space:]]*=.*#${key} = ${value}#" "${config_file}"
	else
		echo "${key} = ${value}" | sudo tee -a "${config_file}" >/dev/null
	fi
}

remove_ini_key() {
	local config_file="$1"
	local key="$2"

	sudo sed -i -E "/^[#;[:space:]]*${key}[[:space:]]*=.*/d" "${config_file}"
}

disable_decoder_service() {
	local service_name="$1"

	if systemctl list-unit-files "${service_name}.service" >/dev/null 2>&1; then
		log_message "Stopping ${service_name}.service to prevent SDR conflicts"
		sudo systemctl stop "${service_name}.service" >/dev/null 2>&1 || true
		log_message "Disabling ${service_name}.service to prevent SDR conflicts"
		sudo systemctl disable "${service_name}.service" >/dev/null 2>&1 || true
	fi
}

configure_stream1090_device_config() {
	local config_file="$1"

	backup_file "${config_file}"

	set_ini_value "${config_file}" "bias_tee" "${stream1090_bias_tee}"

	if [[ -n "${stream1090_device_serial}" ]]; then
		set_ini_value "${config_file}" "serial" "${stream1090_device_serial}"
	else
		remove_ini_key "${config_file}" "serial"
	fi

	case "${device_type}" in
		"RTL-SDR")
			set_ini_value "${config_file}" "agc" "${stream1090_rtlsdr_agc}"
			if [[ "${stream1090_rtlsdr_agc}" == "true" ]]; then
				remove_ini_key "${config_file}" "gain"
			else
				set_ini_value "${config_file}" "gain" "${stream1090_rtlsdr_gain}"
			fi

			if [[ -n "${stream1090_rtlsdr_ppm}" ]]; then
				set_ini_value "${config_file}" "ppm" "${stream1090_rtlsdr_ppm}"
			else
				remove_ini_key "${config_file}" "ppm"
			fi
			;;
		"Airspy")
			set_ini_value "${config_file}" "linearity_gain" "${stream1090_airspy_linearity_gain}"
			remove_ini_key "${config_file}" "sensitivity_gain"
			;;
	esac
}

configure_readsb_for_stream1090() {
	local config_file="/etc/default/readsb"
	local net_options=""

	if [[ ! -f "${config_file}" ]]; then
		log_alert_heading "INSTALLATION HALTED"
		log_alert_message "Readsb configuration file not found at ${config_file}"
		exit 1
	fi

	backup_file "${config_file}"

	net_options=$(get_config "NET_OPTIONS" "${config_file}")
	net_options=$(ensure_option_present "${net_options}" "--net-only")
	net_options=$(ensure_option_present "${net_options}" "--net-ri-port 30001")

	log_message "Setting Readsb to network-input mode for stream1090"
	change_config "RECEIVER_OPTIONS" "" "${config_file}"
	change_config "NET_OPTIONS" "${net_options}" "${config_file}"
}

configure_dump1090_for_stream1090() {
	local config_file="/etc/default/dump1090-fa"

	if [[ ! -f "${config_file}" ]]; then
		log_alert_heading "INSTALLATION HALTED"
		log_alert_message "dump1090-fa configuration file not found at ${config_file}"
		exit 1
	fi

	backup_file "${config_file}"

	log_message "Setting dump1090-fa to network-input mode for stream1090"
	change_config "RECEIVER" "none" "${config_file}"
	change_config "NET_RAW_INPUT_PORTS" "30001" "${config_file}"
}

detect_stream1090_decoder() {
	local readsb_installed="false"
	local dump1090_installed="false"

	if [[ -f /etc/default/readsb && $(dpkg-query -W -f='${STATUS}' readsb 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
		readsb_installed="true"
	fi

	if [[ -f /etc/default/dump1090-fa && $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
		dump1090_installed="true"
	fi

	if [[ "${readsb_installed}" == "true" && "${dump1090_installed}" == "false" ]]; then
		echo "readsb"
		return
	fi

	if [[ "${readsb_installed}" == "false" && "${dump1090_installed}" == "true" ]]; then
		echo "dump1090-fa"
		return
	fi

	if [[ "${readsb_installed}" == "true" && "${dump1090_installed}" == "true" ]]; then
		if systemctl is-active --quiet readsb 2>/dev/null && ! systemctl is-active --quiet dump1090-fa 2>/dev/null; then
			echo "readsb"
			return
		fi

		if systemctl is-active --quiet dump1090-fa 2>/dev/null && ! systemctl is-active --quiet readsb 2>/dev/null; then
			echo "dump1090-fa"
			return
		fi

		if systemctl is-enabled --quiet readsb 2>/dev/null && ! systemctl is-enabled --quiet dump1090-fa 2>/dev/null; then
			echo "readsb"
			return
		fi

		if systemctl is-enabled --quiet dump1090-fa 2>/dev/null && ! systemctl is-enabled --quiet readsb 2>/dev/null; then
			echo "dump1090-fa"
			return
		fi

		echo "readsb"
		return
	fi

	echo ""
}

clear
log_project_title
log_title_heading "Setting up stream1090"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
			  --title "stream1090 Setup" \
			  --yesno "stream1090 is a demodulator that feeds Mode-S frames into a decoder such as Readsb or dump1090-fa.\n\nThis setup will build stream1090, configure an existing ADS-B decoder for network input, and install a stream1090 systemd service.\n\nContinue stream1090 setup?" \
			  14 78; then
	echo ""
	log_alert_heading "INSTALLATION HALTED"
	log_alert_message "Setup has been halted at the request of the user"
	echo ""
	log_title_message "------------------------------------------------------------------------------"
	log_title_heading "stream1090 setup halted"
	echo ""
	exit 1
fi


## DETECT INSTALLED DECODERS

log_heading "Detecting compatible ADS-B decoders"


selected_decoder=$(detect_stream1090_decoder)

if [[ -z "${selected_decoder}" ]]; then
	log_alert_heading "INSTALLATION HALTED"
	log_alert_message "stream1090 requires either Readsb or dump1090-fa to already be installed"
	log_alert_message "Setup has been terminated"
	exit 1
fi

log_message "Auto-detected ${selected_decoder} as the decoder behind stream1090"

other_decoder=""
other_service_name=""
case "${selected_decoder}" in
	"readsb")
		if [[ -f /etc/default/dump1090-fa && $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
			other_decoder="dump1090-fa"
			other_service_name="dump1090-fa"
		fi
		;;
	"dump1090-fa")
		if [[ -f /etc/default/readsb && $(dpkg-query -W -f='${STATUS}' readsb 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
			other_decoder="Readsb"
			other_service_name="readsb"
		fi
		;;
esac

if [[ -n "${other_service_name}" ]]; then
	if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
				--title "Potential SDR Conflict" \
				--yesno "${other_decoder} is also installed. If it is enabled with direct SDR access, it can conflict with stream1090.\n\nWould you like this setup to stop and disable ${other_decoder} now?" \
				12 78; then
		disable_decoder_service "${other_service_name}"
	else
		log_warning_message "${other_decoder} was left enabled; if it still claims the SDR, stream1090 may fail to start"
	fi
fi


## GATHER REQUIRED INFORMATION

log_heading "Gather information required to configure stream1090"

device_type=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
	--title "stream1090 Device Type" \
	--menu "Choose the SDR device type stream1090 will use:" \
	12 78 3 \
	"RTL-SDR" "Use librtlsdr with the bundled rtlsdr.ini" \
	"Airspy" "Use libairspy with the bundled airspy.ini" \
	3>&1 1>&2 2>&3)

if [[ $? -ne 0 || -z "${device_type}" ]]; then
	log_alert_heading "INSTALLATION HALTED"
	log_alert_message "Setup has been halted due to lack of required information"
	exit 1
fi

case "${device_type}" in
	"RTL-SDR")
		default_sample_rate="2.56"
		default_upsample_rate="12"
		default_config_file="${STREAM1090_CONFIG_DIR}/rtlsdr.ini"
		required_device_package="librtlsdr-dev"
		default_rtlsdr_gain="40"
		;;
	"Airspy")
		default_sample_rate="6"
		default_upsample_rate="24"
		default_config_file="${STREAM1090_CONFIG_DIR}/airspy.ini"
		required_device_package="libairspy-dev"
		default_airspy_linearity_gain="16"
		;;
esac

stream1090_device_serial=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
	--title "stream1090 Device Serial" \
	--inputbox "Optional: enter an SDR serial to bind stream1090 to.\n\nLeave blank to use the first compatible device. This is recommended when multiple SDRs are connected." \
	10 78 "" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then
	log_alert_heading "INSTALLATION HALTED"
	log_alert_message "Setup has been halted due to lack of required information"
	exit 1
fi

sample_rate=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
	--title "stream1090 Sample Rate" \
	--inputbox "Enter the input sample rate in MHz for ${device_type}:" \
	8 78 "${default_sample_rate}" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 || -z "${sample_rate}" ]]; then
	log_alert_heading "INSTALLATION HALTED"
	log_alert_message "Setup has been halted due to lack of required information"
	exit 1
fi

upsample_rate=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
	--title "stream1090 Upsample Rate" \
	--inputbox "Enter the upsample rate in MHz for ${device_type}:" \
	8 78 "${default_upsample_rate}" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 || -z "${upsample_rate}" ]]; then
	log_alert_heading "INSTALLATION HALTED"
	log_alert_message "Setup has been halted due to lack of required information"
	exit 1
fi

enable_iq_filter="false"
if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
			--title "stream1090 IQ Filter" \
			--yesno "Enable stream1090 built-in IQ FIR filter?\n\nThis can improve message yield at the cost of higher CPU usage." \
			10 78; then
	enable_iq_filter="true"
fi

stream1090_bias_tee="false"
if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
			--title "stream1090 Bias Tee" \
			--yesno "Enable 5V bias tee for the selected SDR?\n\nOnly enable this if your hardware and LNA setup require it." \
			10 78; then
	stream1090_bias_tee="true"
fi

case "${device_type}" in
	"RTL-SDR")
		stream1090_rtlsdr_agc="true"
		if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
					--title "stream1090 RTL-SDR Gain" \
					--yesno "Use RTL-SDR AGC for stream1090?\n\nSelect No to enter a fixed tuner gain instead." \
					10 78; then
			stream1090_rtlsdr_agc="false"
			stream1090_rtlsdr_gain=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
				--title "stream1090 RTL-SDR Gain" \
				--inputbox "Enter fixed RTL-SDR gain in dB for stream1090:" \
				8 78 "${default_rtlsdr_gain}" 3>&1 1>&2 2>&3)
			if [[ $? -ne 0 || -z "${stream1090_rtlsdr_gain}" ]]; then
				log_alert_heading "INSTALLATION HALTED"
				log_alert_message "Setup has been halted due to lack of required information"
				exit 1
			fi
		fi

		stream1090_rtlsdr_ppm=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
			--title "stream1090 RTL-SDR PPM" \
			--inputbox "Optional: enter RTL-SDR frequency correction in PPM.\n\nLeave blank to omit this setting." \
			9 78 "" 3>&1 1>&2 2>&3)
		if [[ $? -ne 0 ]]; then
			log_alert_heading "INSTALLATION HALTED"
			log_alert_message "Setup has been halted due to lack of required information"
			exit 1
		fi
		;;
	"Airspy")
		stream1090_airspy_linearity_gain=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
			--title "stream1090 Airspy Linearity Gain" \
			--inputbox "Enter Airspy linearity gain (0-21) for stream1090:" \
			8 78 "${default_airspy_linearity_gain}" 3>&1 1>&2 2>&3)
		if [[ $? -ne 0 || -z "${stream1090_airspy_linearity_gain}" ]]; then
			log_alert_heading "INSTALLATION HALTED"
			log_alert_message "Setup has been halted due to lack of required information"
			exit 1
		fi
		;;
esac


## CHECK FOR PREREQUISITE PACKAGES

log_heading "Installing packages needed to fulfill stream1090 dependencies"

check_package build-essential
check_package cmake
check_package git
check_package socat
check_package "${required_device_package}"


## BLACKLIST UNWANTED RTL-SDR MODULES

if [[ "${device_type}" == "RTL-SDR" ]]; then
	log_heading "Blacklist unwanted RTL-SDR kernel modules"
	blacklist_modules
fi


## CLONE OR PULL THE STREAM1090 SOURCE

log_heading "Preparing the stream1090 Git repository"

if [[ -d ${STREAM1090_REPO_DIR} && -d ${STREAM1090_REPO_DIR}/.git ]]; then
	log_message "Entering the stream1090 git repository directory"
	cd ${STREAM1090_REPO_DIR}
	log_message "Pulling the stream1090 git repository"
	echo ""
	git pull 2>&1 | log_pipe
else
	log_message "Creating the stream1090 build directory"
	echo ""
	mkdir -vp ${STREAM1090_BUILD_DIR} 2>&1 | log_pipe
	echo ""
	log_message "Entering the stream1090 build directory"
	cd ${STREAM1090_BUILD_DIR}
	log_message "Cloning the stream1090 git repository"
	echo ""
	git clone https://github.com/mgrone/stream1090.git 2>&1 | log_pipe
fi


## BUILD STREAM1090

log_heading "Building stream1090"

if [[ ! -d ${STREAM1090_REPO_DIR}/build ]]; then
	log_message "Creating the stream1090 build directory"
	echo ""
	mkdir -vp ${STREAM1090_REPO_DIR}/build 2>&1 | log_pipe
	echo ""
fi

cd ${STREAM1090_REPO_DIR}/build
log_message "Running cmake"
echo ""
cmake ../ 2>&1 | log_pipe
echo ""
log_message "Running make"
echo ""
make 2>&1 | log_pipe
echo ""

if [[ ! -x ${STREAM1090_REPO_DIR}/build/stream1090 ]]; then
	log_alert_heading "INSTALLATION HALTED"
	log_alert_message "The stream1090 binary was not created successfully"
	log_alert_message "Setup has been terminated"
	exit 1
fi


## CONFIGURE STREAM1090 DEVICE SETTINGS

log_heading "Configuring stream1090 device settings"

configure_stream1090_device_config "${default_config_file}"


## CONFIGURE DECODER STACK

log_heading "Configuring the decoder stack for stream1090"

case "${selected_decoder}" in
	"readsb")
		configure_readsb_for_stream1090
		;;
	"dump1090-fa")
		configure_dump1090_for_stream1090
		;;
esac


## INSTALL SYSTEMD SERVICE

log_heading "Creating the stream1090 systemd service"

stream1090_command="${STREAM1090_REPO_DIR}/build/stream1090 -s ${sample_rate} -u ${upsample_rate} -d ${default_config_file}"
if [[ "${enable_iq_filter}" == "true" ]]; then
	stream1090_command="${stream1090_command} -q"
fi

backup_file "${STREAM1090_SERVICE_FILE}"

sudo tee "${STREAM1090_SERVICE_FILE}" > /dev/null <<EOF
[Unit]
Description=stream1090 demodulator feeding ${selected_decoder}
After=network.target

[Service]
ExecStart=/bin/bash -lc '${stream1090_command} | socat -u - TCP4:127.0.0.1:30001'
WorkingDirectory=${STREAM1090_REPO_DIR}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


## START SERVICES

log_heading "Reloading services"

sudo systemctl daemon-reload
sudo systemctl enable stream1090.service
sudo systemctl restart stream1090.service

case "${selected_decoder}" in
	"readsb")
		sudo systemctl enable readsb
		sudo systemctl restart readsb
		;;
	"dump1090-fa")
		sudo systemctl enable dump1090-fa
		sudo systemctl restart dump1090-fa
		;;
esac


## SETUP COMPLETE

whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
		 --title "stream1090 Setup Complete" \
		 --msgbox "stream1090 is now set up to feed ${selected_decoder} via TCP on 127.0.0.1:${STREAM1090_DECODER_PORT}.\n\nConfig file: ${default_config_file}\nBuild directory: ${STREAM1090_REPO_DIR}\nService: ${STREAM1090_SERVICE_FILE}" \
		 12 78

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd ${RECEIVER_ROOT_DIRECTORY}

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "stream1090 setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0

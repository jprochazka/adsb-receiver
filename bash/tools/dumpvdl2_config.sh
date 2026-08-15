#!/bin/bash

set -euo pipefail

config_file="/etc/default/dumpvdl2"

if [[ ${EUID} -ne 0 ]]; then
    echo "This helper must run as root" >&2
    exit 1
fi

if [[ $# -ne 1 || -z "${1}" ]]; then
    echo "Usage: $0 <comma-separated frequencies in MHz>" >&2
    exit 1
fi

if [[ ! -f "${config_file}" ]]; then
    echo "${config_file} does not exist" >&2
    exit 1
fi

IFS=',' read -r -a requested_frequencies <<< "${1}"
if [[ ${#requested_frequencies[@]} -lt 1 || ${#requested_frequencies[@]} -gt 20 ]]; then
    echo "Between 1 and 20 frequencies are required" >&2
    exit 1
fi

canonical_frequencies=()
for frequency in "${requested_frequencies[@]}"; do
    if [[ ! "${frequency}" =~ ^[0-9]{3}([.][0-9]{1,3})?$ ]]; then
        echo "Invalid frequency: ${frequency}" >&2
        exit 1
    fi
    if ! awk -v frequency="${frequency}" 'BEGIN { exit !(frequency >= 118 && frequency <= 137) }'; then
        echo "Frequency outside the supported 118-137 MHz range: ${frequency}" >&2
        exit 1
    fi
    canonical_frequencies+=("$(printf '%.3fM' "${frequency}")")
done

mapfile -t canonical_frequencies < <(
    printf '%s\n' "${canonical_frequencies[@]}" | sort -t M -k 1,1n -u
)
frequency_line="DUMPVDL2_FREQUENCIES=\"${canonical_frequencies[*]}\""

temporary_file=$(mktemp "${config_file}.XXXXXX")
trap 'rm -f "${temporary_file}"' EXIT

while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" != DUMPVDL2_FREQUENCIES=* ]]; then
        printf '%s\n' "${line}" >> "${temporary_file}"
    fi
done < "${config_file}"
printf '%s\n' "${frequency_line}" >> "${temporary_file}"

chmod 0644 "${temporary_file}"
chown root:root "${temporary_file}"
mv -f "${temporary_file}" "${config_file}"
trap - EXIT

systemctl restart dumpvdl2.service

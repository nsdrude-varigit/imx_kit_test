#!/bin/bash

# Helper script for creating release log

readonly LOG_FILE_SUMMARY=/var/log/release_summary.log
readonly LOG_FILE_VERBOSE=/var/log/release_verbose.log

function log_line {
        KEY=$1
        RESULTS=$2
        DATA=$3
        printf "%-20s | %-4s | %s\n" "$KEY" "$RESULTS" "$DATA" >> ${LOG_FILE_SUMMARY}
        sync
}

function log_cmd {
        echo "-> $1" >> ${LOG_FILE_VERBOSE}
}

function log_print {
        cat ${LOG_FILE_SUMMARY}
}

function get_current_root_block
{
	for i in `cat /proc/cmdline`; do
		if [ ${i:0:5} = "root=" ]; then
			BOOT_BLOCK="${i:5:-2}"
		fi
	done
}

rm -f ${LOG_FILE_SUMMARY}
rm -f ${LOG_FILE_VERBOSE}

log_line "date" "" "$(date)"
log_line "Test Script" "" "${ABSOLUTE_FILENAME}"
log_line "Test Commit ID" "" "$(git describe --long --dirty --abbrev=10 --tags --always)"
log_line "soc" "" "$(cat /sys/devices/soc0/soc_id)"
log_line "machine" "" "$(cat /sys/devices/soc0/machine)"
log_line "kernel" "" "$(uname -srv)"
log_line "uboot spl" "" "$(get_current_root_block && grep -m1 -ia "U-Boot SPL" ${BOOT_BLOCK})"
log_line "cmdline" "" "$(cat /proc/cmdline)"
log_line "memory" "" "$(awk '/MemTotal/ {print $2}' /proc/meminfo)"

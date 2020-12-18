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


flush_to_verbose_log() {
        cat ${LOG_FILE_TMP} >> ${LOG_FILE_VERBOSE}
        echo "" > ${LOG_FILE_TMP}
}

test_pass()
{
        name="$1"
        echo -e "$OK"
        log_line "$name" "PASS" $(cat ${LOG_FILE_TMP})
        flush_to_verbose_log
}

test_fail()
{
        name="$1"
        echo -e "$FAIL"
        log_line "$name" "FAIL" $(cat ${LOG_FILE_TMP})
        flush_to_verbose_log
}

# Run test, log pass/fail
run_test()
{
	name="$1"
	shift
	echo -n -e "$name: "
        log_cmd "'$*'"
	eval "$@" > ${LOG_FILE_VERBOSE} && test_pass "$name" || test_fail "$name"
}

# Same as run test, but save output to log file
run_test_log_output()
{
	name="$1"
	shift
	echo -n -e "$name: "
        log_cmd "'$*'"
	eval "$@" > ${LOG_FILE_TMP} && test_pass "$name" || test_fail "$name"
}

# Log command and run
run()
{
        log_cmd "'$*'"
	"$@" >> ${LOG_FILE_VERBOSE}
}

# use for commands that redirect to a file (like backlight)
run_eval()
{
        CMD=$1
        log_cmd "${CMD}"
	eval "${CMD}"
}

run_test_with_prompt()
{
        name="$1"
        description="$2"
        prompt="$3"
        shift;shift;shift
        finished=false
        while ! $finished; do
                echo "-> $description"
                log_cmd "'$*'"
                eval "$@" >> ${LOG_FILE_VERBOSE} 2>&1
                read -p "$prompt (yes/no/retry)" -n 1 -r
                echo    # (optional) move to a new line
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                        test_pass "$name"
                        finished=true
                elif [[ $REPLY =~ ^[Nn]$ ]]; then
                        test_fail "$name"
                        finished=true
                fi
        done
}

function print_test_header {
        TITLE=$1
        INSTRUCTIONS=$2
        echo
        echo "$TITLE: $INSTRUCTIONS"
        echo "************************"
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

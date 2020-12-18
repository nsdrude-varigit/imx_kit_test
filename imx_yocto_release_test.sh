#!/bin/sh

# iMX board test script

set -e

RED="\\033[0;31m"
NOCOLOR="\\033[0;39m"
GREEN="\\033[0;32m"
GRAY="\\033[0;37m"
OK="${GREEN}OK$NOCOLOR"
FAIL="${RED}FAIL$NOCOLOR"

readonly ABSOLUTE_FILENAME=`readlink -e "$0"`
readonly ABSOLUTE_DIRECTORY=`dirname ${ABSOLUTE_FILENAME}`
readonly SCRIPT_POINT=${ABSOLUTE_DIRECTORY}
readonly TMP_LOG_FILE="/tmp/yocto_release_test.tmp"

source ${SCRIPT_POINT}/release_log.sh

if [ `grep i.MX8MN /sys/devices/soc0/soc_id` ]; then
	SOC=MX8MN
	ETHERNET_PORTS=1
	USB_DEVS=1
	USBC_PORTS=1
	IS_PCI_PRESENT=false
	MAX_BACKLIGHT_VAL=100
	BACKLIGHT_STEP=10
	EMMC_DEV=/dev/mmcblk2
	HAS_RTC_IRQ=false
	HAS_CAMERA=true
fi

test_pass()
{
        echo -e "$OK"
        log_line $1 "PASS" $(cat ${TMP_LOG_FILE})
}

test_fail()
{
        echo -e "$FAIL"
        log_line $1 "FAIL" $(cat ${TMP_LOG_FILE})
}

# Run test, log pass/fail
run_test()
{
	name="$1"
	shift
	echo -n -e "$name: "
        echo "" > ${TMP_LOG_FILE}
	eval "$@" > /dev/null && test_pass $name || test_fail $name
}

# Same as run test, but save output to log file
run_test_log_output()
{
	name="$1"
	shift
	echo -n -e "$name: "
	eval "$@" > ${TMP_LOG_FILE} && test_pass $name || test_fail $name
}

# Just to avoid piping after each command
run()
{
	"$@" >> /var/log/test.log 2>&1
}

log_print
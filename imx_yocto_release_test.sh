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
readonly LOG_FILE_TMP="/tmp/yocto_release_test.tmp"

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
        HAS_THERMAL=true
fi

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

if [ "$HAS_THERMAL" = "true" ]; then
        run_test_log_output "Thermal" cat /sys/devices/virtual/thermal/thermal_zone0/temp
fi


echo
echo "Testing Sound Output - Connect a speaker to line out"
echo "***********************"
if [ "$SOC" = "MX8M" -o "$SOC" = "MX8MM" -o "$SOC" = "MX8MN" -o "$SOC" = "MX8X" -o "$SOC" = "MX8QM" ]; then
	run amixer set Headphone 63
else
	run amixer set Master 125
	run amixer set 'Output Mixer HiFi' on
fi
run_test_with_prompt "Sound Out" "Playing from file" "Did you hear the sound?" "aplay /usr/share/sounds/alsa/Front_Center.wav"


echo
echo "Testing Sound Input - Connect a speaker to line out, and play audio on line in"
echo "***********************"
run amixer set Headphone 35;run amixer set 'Capture Input' ADC;run amixer set 'DMIC Mux' DMIC2;
run_test_with_prompt "Sound In -> Out" "Playing from Line In" "Did you hear the sound?" \
"arecord -c 2 -f cd -d 5 | aplay -f cd"


echo
echo "Testing Microphone Input - Connect a speaker to line out"
echo "***********************"
run amixer set Headphone 35;run amixer set 'Capture Input' DMIC;run amixer set 'DMIC Mux' DMIC1;
run_test_with_prompt "Microphone" "Speak into microphone..." "Did you hear the recorded sound?" \
"arecord -f cd -d 5 test.wav; aplay test.wav"


echo
echo "Hit Enter to test backlight"
echo "***************************"
read
function cycle_backlight {
        for f in /sys/class/backlight/backlight*/brightness
        do
                for i in `seq $MAX_BACKLIGHT_VAL -$BACKLIGHT_STEP 0`;
                do
                        run_eval "echo $i > $f"
                        run_eval "sleep 0.05"
                done
                for i in `seq 1 $BACKLIGHT_STEP $MAX_BACKLIGHT_VAL`;
                do
                        run_eval "echo $i > $f"
                        run_eval "sleep 0.05"
                done
        done
}
run_test_with_prompt "Backlight" "Cycling backlight brightness" "Did the backlight change?" "cycle_backlight"

log_print

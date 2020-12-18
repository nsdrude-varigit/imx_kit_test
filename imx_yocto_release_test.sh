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
        TESTS=(
                "test_thermal"
                "test_audio_speaker_out"
                "test_audio_line_in"
                "test_audio_microphone"
                "test_backlight"
                "test_suspend"
        )
fi

function test_thermal {
        print_test_header "Thermal sysfs interface" ""
        run_test_log_output "Thermal sysfs" cat /sys/devices/virtual/thermal/thermal_zone0/temp
}

function test_audio_speaker_out {
        print_test_header "Testing Sound Output" "Connect a speaker to line out"
        if [ "$SOC" = "MX8M" -o "$SOC" = "MX8MM" -o "$SOC" = "MX8MN" -o "$SOC" = "MX8X" -o "$SOC" = "MX8QM" ]; then
                run amixer set Headphone 63
        else
                run amixer set Master 125
                run amixer set 'Output Mixer HiFi' on
        fi
        run_test_with_prompt "Sound Out" "Playing from file" "Did you hear the sound?" "aplay /usr/share/sounds/alsa/Front_Center.wav"
}

function test_audio_line_in {
        print_test_header "Testing Sound Input" "Connect a speaker to line out, and play audio on line in"
        run amixer set Headphone 35;run amixer set 'Capture Input' ADC;run amixer set 'DMIC Mux' DMIC2;
        run_test_with_prompt "Sound In -> Out" "Playing from Line In" "Did you hear the sound?" \
        "arecord -c 2 -f cd -d 5 | aplay -f cd"
}

function test_audio_microphone {
        print_test_header "Testing Microphone Input" "Connect a speaker to line out"
        run amixer set Headphone 35;run amixer set 'Capture Input' DMIC;run amixer set 'DMIC Mux' DMIC1;
        run_test_with_prompt "Microphone" "Speak into microphone..." "Did you hear the recorded sound?" \
        "arecord -f cd -d 5 test.wav; aplay test.wav"
}

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

function test_backlight {
        print_test_header "Testing Backlight" "Verify display brightness changes"
        run_test_with_prompt "Backlight" "Cycling backlight brightness" "Did the backlight change?" "cycle_backlight"
}

function test_suspend {
        print_test_header "Testing Ten Suspend Cycles" "Wake using touchscreen, on/off button, and gpio keys"
        for i in {1..10}; do
                run pm-suspend
                if [ "$i" -lt "10" ]; then
                        echo "Awake $i/10, waiting 5 seconds and then suspending again"
                        run sleep 5
                fi
        done
}

# Iterate through all tests
for TEST in "${TESTS[@]}"; do
        $TEST
done

log_print

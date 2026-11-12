#!/bin/bash
# boot-apply v2 — config-driven boot settings re-application.
# Called by watchdog-v2.sh when it detects a tablet reboot.
#
# What it does:
#   - Stops mpdecision so cores stay online
#   - Brings all configured cores online
#   - Sets CPU governor to performance
#   - Disables animations (big perceptual speed gain)
#   - Keeps screen on while plugged in
#   - Disables Doze
#   - Launches the kiosk app

set -u
CONFIG=${1:?"Usage: $0 <config-file>"}
# shellcheck disable=SC1090
source "$CONFIG"

D="$TABLET_IP:$ADB_PORT"
A() { adb -s "$D" shell "$@" 2>&1; }

# Backward compat — older configs used FULLY_*
KIOSK_PACKAGE=${KIOSK_PACKAGE:-${FULLY_PACKAGE:?KIOSK_PACKAGE or FULLY_PACKAGE required}}
KIOSK_MAIN_ACTIVITY=${KIOSK_MAIN_ACTIVITY:-${FULLY_MAIN_ACTIVITY:?KIOSK_MAIN_ACTIVITY or FULLY_MAIN_ACTIVITY required}}

echo "boot-apply: $DEVICE_LABEL"

# Stop mpdecision so cores stay online
A "setprop ctl.stop mpdecision" || true

# Bring all configured cores online
if [[ "${BRING_CORES_ONLINE:-0}" == "1" ]]; then
    for i in $(seq 0 ${MAX_CORE_INDEX:-3}); do
        A "echo 1 > /sys/devices/system/cpu/cpu$i/online" 2>/dev/null
    done
fi

# Set CPU governor on all cores
for i in $(seq 0 ${MAX_CORE_INDEX:-3}); do
    A "echo ${CPU_GOVERNOR:-performance} > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor" 2>/dev/null
done

# Animations off (big perceptual speed gain on Snapdragon 400)
A "settings put global window_animation_scale 0"
A "settings put global transition_animation_scale 0"
A "settings put global animator_duration_scale 0"
A "settings put global stay_on_while_plugged_in 7"
A "settings put system screen_off_timeout 2147483647"

# Doze off, kiosk app allowlisted
A "dumpsys deviceidle disable all"
A "dumpsys deviceidle whitelist +$KIOSK_PACKAGE"

# Disable launcher (if configured — only needed if kiosk app isn't CATEGORY_HOME itself)
if [[ "${DISABLE_LAUNCHER:-0}" == "1" && -n "${LAUNCHER_PACKAGE:-}" ]]; then
    A "pm disable-user --user 0 $LAUNCHER_PACKAGE 2>/dev/null"
fi

# Launch kiosk
A "am start -n $KIOSK_MAIN_ACTIVITY"

echo "boot-apply complete"

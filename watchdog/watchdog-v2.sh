#!/bin/bash
# tablet-watchdog v2 — config-driven, multi-tablet, with ntfy throttling.
#
# Run per-device:  bash watchdog-v2.sh config/kitchen-tablet.conf
# Run all configs: bash watchdog-v2.sh --all
#
# Configs in ./config/*.conf. One background process per config under --all.

set -u

HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
CONFIG_DIR="$HERE/config"
mkdir -p "$HERE/logs" "$HERE/state"

if [[ "${1:-}" == "--all" ]]; then
    PIDS=()
    for cfg in "$CONFIG_DIR"/*.conf; do
        [[ -f "$cfg" ]] || continue
        echo "launching watchdog for $(basename "$cfg")"
        bash "$0" "$cfg" &
        PIDS+=($!)
    done
    trap 'kill "${PIDS[@]}" 2>/dev/null' INT TERM
    wait
    exit 0
fi

CONFIG=${1:?"Usage: $0 <config-file>  OR  $0 --all"}
[[ -f "$CONFIG" ]] || { echo "Config not found: $CONFIG" >&2; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG"

# Backward compat — older configs used FULLY_*
KIOSK_PACKAGE=${KIOSK_PACKAGE:-${FULLY_PACKAGE:?KIOSK_PACKAGE or FULLY_PACKAGE required}}
KIOSK_MAIN_ACTIVITY=${KIOSK_MAIN_ACTIVITY:-${FULLY_MAIN_ACTIVITY:?KIOSK_MAIN_ACTIVITY or FULLY_MAIN_ACTIVITY required}}

LOG="$HERE/logs/$DEVICE_ID.log"
STATE="$HERE/state/$DEVICE_ID.state"
D="$TABLET_IP:$ADB_PORT"

log()  { echo "$(date -Iseconds) [$DEVICE_ID] $*" | tee -a "$LOG"; }
A()    { adb -s "$D" shell "$@" 2>&1; }

throttled_notify() {
    # $1 key, $2 priority, $3 title, $4 body
    [[ "${NTFY_ENABLED:-0}" == "1" ]] || return
    [[ -n "${NTFY_URL:-}" && -n "${NTFY_TOPIC:-}" ]] || return
    local key=$1 pri=$2 title=$3 body=$4
    local last_file="$HERE/state/$DEVICE_ID.alert.$key"
    local now=$(date +%s)
    if [[ -f "$last_file" ]]; then
        local last=$(cat "$last_file" 2>/dev/null || echo 0)
        (( now - last < ALERT_DEDUPE_HR * 3600 )) && return
    fi
    echo "$now" > "$last_file"
    curl -sS -o /dev/null --max-time 10 \
        -H "Title: $title" \
        -H "Priority: $pri" \
        -H "Tags: tablet,$DEVICE_ID" \
        -d "$body" \
        "$NTFY_URL/$NTFY_TOPIC" 2>>"$LOG" || true
    log "ntfy sent: $title"
}

# ---------- loop state ----------
LAST_UPTIME=0
LAST_KIOSK_PID=""
CRASH_TIMES_CSV=""
OFFLINE_SINCE=""

log "watchdog v2 starting (device=$DEVICE_LABEL $TABLET_IP, kiosk=$KIOSK_PACKAGE)"

while true; do
    NOW=$(date +%s)

    # --- A) ADB reachability ---
    if ! adb -s "$D" shell true 2>/dev/null; then
        OFFLINE_SINCE=${OFFLINE_SINCE:-$NOW}
        OFFLINE_MIN=$(( (NOW - OFFLINE_SINCE) / 60 ))
        log "ADB unreachable, offline ${OFFLINE_MIN} min"
        if (( OFFLINE_MIN >= ALERT_OFFLINE_MIN )); then
            throttled_notify offline high "$DEVICE_LABEL offline" \
                "Tablet not responding for $OFFLINE_MIN min"
        fi
        adb disconnect "$D" 2>/dev/null
        adb connect "$D" >/dev/null 2>&1
        sleep 15
        continue
    fi
    OFFLINE_SINCE=""

    # --- B) Reboot detection + boot-apply ---
    UPTIME=$(A "cat /proc/uptime" 2>/dev/null | awk '{print int($1)}')
    UPTIME=${UPTIME:-$LAST_UPTIME}
    if [[ "$UPTIME" -lt "$LAST_UPTIME" ]]; then
        log "Reboot detected ($LAST_UPTIME -> $UPTIME s), applying boot config"
        bash "$HERE/boot-apply-v2.sh" "$CONFIG" >> "$LOG" 2>&1
        throttled_notify reboot default "$DEVICE_LABEL rebooted" \
            "Boot config reapplied."
    fi
    LAST_UPTIME=$UPTIME

    # --- C) Kiosk alive? ---
    KIOSK_PID=$(A "pidof $KIOSK_PACKAGE" 2>/dev/null | tr -d '\r' | awk '{print $1}')
    if [[ -z "$KIOSK_PID" ]]; then
        log "Kiosk not running, launching"
        A "am start -n $KIOSK_MAIN_ACTIVITY" >> "$LOG" 2>&1
        CRASH_TIMES_CSV="${CRASH_TIMES_CSV}${CRASH_TIMES_CSV:+,}$NOW"
    elif [[ -n "$LAST_KIOSK_PID" && "$KIOSK_PID" != "$LAST_KIOSK_PID" ]]; then
        log "Kiosk PID changed $LAST_KIOSK_PID -> $KIOSK_PID (restart)"
        CRASH_TIMES_CSV="${CRASH_TIMES_CSV}${CRASH_TIMES_CSV:+,}$NOW"
    fi
    LAST_KIOSK_PID=$KIOSK_PID

    # Trim old crashes and count
    CUTOFF=$(( NOW - ALERT_CRASH_WINDOW_MIN * 60 ))
    KEEP=""
    IFS=',' read -ra TIMES <<< "$CRASH_TIMES_CSV"
    for t in "${TIMES[@]}"; do
        [[ -n "$t" ]] || continue
        (( t > CUTOFF )) && KEEP="${KEEP}${KEEP:+,}$t"
    done
    CRASH_TIMES_CSV="$KEEP"
    CRASH_COUNT=$(echo "$CRASH_TIMES_CSV" | tr ',' '\n' | grep -c . || echo 0)
    if (( CRASH_COUNT >= ALERT_CRASH_COUNT )); then
        throttled_notify crashloop high "$DEVICE_LABEL unstable" \
            "Kiosk crashed $CRASH_COUNT times in ${ALERT_CRASH_WINDOW_MIN} min"
    fi

    # --- D) 10-min full status + thermal/battery/mem alerts ---
    if (( SECONDS % 600 < 30 )); then
        BAT=$(A "dumpsys battery" 2>/dev/null | awk '
            /AC powered:/ {ac=$3}
            /USB powered:/ {usb=$3}
            /level:/ {lvl=$2}
            /temperature:/ {t=$2}
            END {printf "ac=%s usb=%s pct=%s temp_dC=%s", ac, usb, lvl, t}')
        TEMP=$(A "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null" | tr -d '\r')
        MEM=$(A "grep -E 'MemFree|MemAvailable' /proc/meminfo" 2>/dev/null | tr '\n' ' ' | tr -s ' ')
        MEM_FREE=$(echo "$MEM" | grep -oE 'MemFree: *[0-9]+' | grep -oE '[0-9]+')

        log "status: pid=$KIOSK_PID up=${UPTIME}s $BAT tz0=${TEMP}C ${MEM}"

        # Thermal alert
        if [[ -n "$TEMP" ]] && (( TEMP > ALERT_TEMP_C )); then
            throttled_notify thermal high "$DEVICE_LABEL overheating" \
                "thermal_zone0 = ${TEMP}C (threshold ${ALERT_TEMP_C}C)"
        fi

        # Unplugged + low battery alert
        BAT_AC=$(echo "$BAT" | grep -oE 'ac=(true|false)' | cut -d= -f2)
        BAT_USB=$(echo "$BAT" | grep -oE 'usb=(true|false)' | cut -d= -f2)
        BAT_PCT=$(echo "$BAT" | grep -oE 'pct=[0-9]+' | cut -d= -f2)
        if [[ "$BAT_AC" == "false" && "$BAT_USB" == "false" && -n "$BAT_PCT" ]] \
           && (( BAT_PCT < ALERT_BATTERY_LOW_PCT )); then
            throttled_notify unplugged high "$DEVICE_LABEL unplugged" \
                "Charger disconnected! Battery: ${BAT_PCT}%"
        fi

        # Memory pressure alert
        if [[ -n "$MEM_FREE" ]] && (( MEM_FREE < ALERT_MEM_FREE_LOW_KB )); then
            throttled_notify memlow default "$DEVICE_LABEL low RAM" \
                "MemFree = ${MEM_FREE} kB (threshold ${ALERT_MEM_FREE_LOW_KB} kB)"
        fi
    fi

    sleep 30
done

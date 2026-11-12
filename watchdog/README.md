# Watchdog scripts

ThinkPad-side (or any Linux box) monitoring for one or more kiosk tablets. No modifications to the tablet's `/system` needed — everything runs over ADB.

## What it does

- Polls each configured tablet every 30 seconds
- Detects reboots (uptime drop) and re-applies CPU tuning + launches kiosk
- Detects kiosk crashes (PID changed or process gone) and relaunches
- Every 10 minutes: logs thermal, battery, and memory status
- Sends throttled ntfy alerts for sustained problems (not every blip)

## Setup

```bash
# 1. Install prereqs
sudo apt install -y adb tmux curl

# 2. Copy config template
cd watchdog
mkdir -p config
cp config.example.conf config/my-tablet.conf
$EDITOR config/my-tablet.conf

# 3. Enable ADB over TCP on tablet (one-time, via USB first)
adb tcpip 5555
adb connect <tablet-ip>:5555

# 4. Run under tmux so it survives logouts
tmux new -d -s kiosk-watch 'bash watchdog-v2.sh --all'

# 5. Verify
tail -f logs/*.log
```

## Multi-tablet

Just drop more `config/<slug>.conf` files and `--all` picks them up. Each gets its own log, state, and alert throttle.

## Alerts

Alerts go to ntfy with throttling: one alert per kind per `ALERT_DEDUPE_HR` hours. See `config.example.conf` for all thresholds.

Types:
- `offline` — tablet unreachable 5+ min
- `crashloop` — kiosk crashed 3+ times in 60 min
- `thermal` — thermal_zone0 > 45°C
- `unplugged` — AC+USB both false and battery < 30%
- `memlow` — MemFree < 60 MB
- `reboot` — tablet rebooted (informational)

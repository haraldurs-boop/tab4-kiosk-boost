# tab4-kiosk-boost

**Making a 2014 Samsung Galaxy Tab 4 (SM-T530) feel less like a potato when it's running a home dashboard on LineageOS 17.1.**

Logbook of a live AI-assisted tuning project. Not a polished framework — a record of what worked, what didn't, and what we ended up building instead. If you have the same tablet rotting on a wall somewhere displaying a home dashboard, this is for you.

## TL;DR

After trying to tune Fully Kiosk Browser and bumping into its "Plus license" watermark, and after WallPanel couldn't even get its setup wizard past "no keyboard appears when tapping the URL field," we ended up **building our own minimal Android kiosk app** in ~100 lines of Java. It works. See `kiosk-app/`.

The journey (sprints 1-10) is documented in `docs/journey.md` because the dead ends are more interesting than the final code.

## The situation

- **Device:** Samsung Galaxy Tab 4 10.1 WiFi (SM-T530NU), codename `matissewifi` / `matissewifiue`
- **SoC:** Qualcomm Snapdragon 400 (MSM8226) — 4× Cortex-A7 @ 1.2 GHz, ARMv7 32-bit
- **RAM:** 1.4 GB
- **Kernel:** Linux 3.4.113 (Qualcomm downstream BSP)
- **ROM:** Unofficial LineageOS 17.1 (Android 10)
- **Job:** Full-screen a home dashboard 24/7

**Goal:** make it feel *instant*. Bricking is an acceptable outcome.

## What's in here

```
tab4-kiosk-boost/
├── kiosk-app/           # The Android app we built — the final answer
│   ├── app/src/main/...
│   ├── build.sh         # Bootstraps Android SDK + gradle on Linux, builds APK
│   ├── install.sh       # adb install + launch
│   └── README.md
├── watchdog/            # Thinkpad-side monitoring scripts
│   ├── watchdog-v2.sh   # Multi-tablet, config-driven, ntfy-throttled
│   ├── boot-apply-v2.sh # CPU governor + core onlining after reboot
│   └── config.example.conf
├── docs/
│   ├── journey.md                # Sprint-by-sprint of what we tried
│   ├── load-average-myth.md      # Why top shows 6+ while CPU is 85% idle
│   ├── fully-kiosk-broadcasts.md # They don't exist — stop looking
│   └── your-ime-is-disabled.md   # 90 min of debugging a missing keyboard
└── LICENSE
```

## Quick start — install our kiosk app

```bash
# Prereqs: Linux workstation, adb installed, tablet with ADB over TCP:5555
# JDK 11 required (AGP 4.2 won't build with 17+)
sudo apt install -y openjdk-11-jdk-headless adb

# 1. Clone
git clone https://github.com/haraldurs-boop/tab4-kiosk-boost
cd tab4-kiosk-boost/kiosk-app

# 2. Edit MainActivity.java — set START_URL to your dashboard
$EDITOR app/src/main/java/is/openclaw/b12kiosk/MainActivity.java

# 3. Build (first time ~5 min, downloads ~1GB SDK into .tools/)
bash build.sh

# 4. Install (adb must be connected to tablet)
adb connect <tablet-ip>:5555
bash install.sh <tablet-ip>:5555

# 5. Make it the home launcher
adb -s <tablet-ip>:5555 shell cmd package set-home-activity is.openclaw.b12kiosk/.MainActivity
```

**To exit the app** on the tablet: 5 rapid back-presses → PIN prompt (default: `1234`, change in `MainActivity.java`).

## Why not Fully Kiosk / WallPanel?

- **Fully Kiosk** works great, but some settings trigger a Plus license watermark that we couldn't clear via `pm clear` or XML editing. If you don't need those settings, Fully is fine.
- **WallPanel** is open source and watermark-free, but on our LineageOS 17 build the URL input field in its setup wizard didn't bring up the IME. Could not get past setup.
- **Our app** is 100% ours, ~100 lines of Java, no license tier, no setup wizard — just loads the URL and shuts up.

We wouldn't recommend building your own app over Fully for most people. We did it because we hit a specific failure mode and were curious how deep the rabbit hole goes. Turned out: not deep.

## What we learned that might help you

- **The load average on Snapdragon 400 downstream kernels is noise.** Don't chase it. See `docs/load-average-myth.md`.
- **mpdecision hot-plugs cores off.** On a plugged-in kiosk you want the opposite. See `watchdog/boot-apply-v2.sh`.
- **Fully Kiosk has no ADB broadcast API.** Previous versions had `com.fullykiosk.setting` but modern builds don't. Edit `shared_prefs/*.xml` directly with root instead.
- **If the IME disappears**, check `adb shell ime list -s`. A disabled `com.android.inputmethod.latin` was our 90-minute mystery.

## Collaborators

Live pair-programming session:

- **Vinur** — tablet owner, operator, risk tolerance, Icelandic UI copy
- **Claude Opus 4.7** — command generation, Android app authoring, this README
- **Claude Sonnet 4.6** — early-sprint shell scripting
- **Claude Fable 5.2** — called in once for the LineageOS-vs-postmarketOS decision (verdict: stay on LineageOS, the bottleneck is the web render path on Adreno 305, not Android services)

Models talked to each other via the operator pasting outputs between sessions.

## License

MIT. See `LICENSE`.

## Pull requests welcome

If you have a matissewifi doing kiosk duty and you tried something that worked (or didn't), open an issue or PR. Especially interested in:
- Getting the WebView to render faster (any `WebSettings` incantations we missed)
- Alternative kiosk apps that work on pre-Android-8 LineageOS
- Hardware-accelerated video playback tricks

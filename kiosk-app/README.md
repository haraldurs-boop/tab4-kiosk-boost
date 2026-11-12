# kiosk-app

Minimal Android WebView kiosk. ~100 lines of Java. Builds on Linux command line without Android Studio.

## What it is

One Activity, one BroadcastReceiver. Opens your dashboard URL in a fullscreen immersive WebView at boot. Registered as `CATEGORY_HOME` so Android launches it automatically. PIN exit: 5 rapid back-presses → prompt → unlock code.

## Build

```bash
# Requires JDK 11 — AGP 4.2 breaks on JDK 17+
sudo apt install -y openjdk-11-jdk-headless adb

bash build.sh
```

First run downloads Android SDK command-line tools + gradle 6.9.4 into `.tools/` (~1 GB disk). Subsequent runs take ~30s.

## Install

```bash
bash install.sh <tablet-ip>:5555
```

Make it the home launcher (so it auto-starts at boot):

```bash
adb -s <tablet-ip>:5555 shell cmd package set-home-activity is.openclaw.b12kiosk/.MainActivity
```

## Customize

### Change the dashboard URL

Edit `app/src/main/java/is/openclaw/b12kiosk/MainActivity.java`:

```java
private static final String START_URL = "https://your-dashboard.example.com/";
```

Then `bash build.sh && bash install.sh <ip>`.

### Change the exit PIN

Same file:

```java
private static final String UNLOCK_PIN = "1234";
```

### Change the package name

The repo uses `is.openclaw.b12kiosk` as a concrete working example. To rename:

1. Rename the directory: `mv app/src/main/java/is/openclaw/b12kiosk app/src/main/java/<your/package>`
2. Update `package` statement at top of `MainActivity.java` and `BootReceiver.java`
3. Update `applicationId` in `app/build.gradle`
4. Update `package=` in `app/src/main/AndroidManifest.xml`

## Exit the app

5 rapid back-presses within 2 seconds → PIN prompt. Enter the PIN → admin menu (reload, clear cache, open Android settings, quit).

If the on-screen keyboard doesn't appear on the PIN prompt, your IME may be disabled. See `../docs/your-ime-is-disabled.md`.

## Caveats

- Hardcoded landscape-portrait sensing via `sensorPortrait` — change to `sensorLandscape` or `fullSensor` in AndroidManifest.xml if you want other orientations.
- `usesCleartextTraffic="true"` is enabled for LAN dashboards. Remove if you're always on HTTPS.
- `onReceivedSslError` accepts all SSL errors — fine for Tailscale/self-signed, not fine for the public internet. Comment it out for stricter checking.
- No CSRF/XSS hardening — assumes you trust the dashboard content.

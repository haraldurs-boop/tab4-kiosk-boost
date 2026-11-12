# Driving Fully Kiosk Browser from ADB

Fully Kiosk ships with an intent-based API that works even without the paid REST API enabled. On this project it's the primary way we poke the app, because the tablet's touchscreen is 💀 and the dashboard it displays doesn't authenticate changes back.

## Intent action

`com.fullykiosk.setting` — **singular**. (The plural form `com.fullykiosk.settings.setting` does *not* work on 1.61.4-play; broadcasts report `result=0` but the setting doesn't change.)

## Setting one key

```bash
adb shell am broadcast \
  -a com.fullykiosk.setting \
  -e key kioskMode \
  -e value true
```

`-e value true/false` for booleans, `-e value <number>` for ints (textZoom etc.), `-e value "string"` for strings.

## Settings worth setting on a dashboard kiosk

| Key | Value | Why |
|---|---|---|
| `kioskMode` | true | Lock the app. Nothing else can show. |
| `keepScreenOn` | true | Wake lock. Screen stays bright. |
| `preventSleepWhileScreenOff` | true | Don't let Doze kill you if the screen does turn off. |
| `webviewHardwareAccel` | true | Should be on by default but confirm. |
| `disableNotifications` | true | No popups on a kiosk. |
| `disableStatusBar` | true | More pixels for the dashboard. |
| `showNavigationBar` | false | Ditto. |
| `disableCameraAccess` | true | Kill one more background service. |
| `enableBackgroundRequests` | false | We only want foreground. |
| `remoteAdminEnabled` | true | Turns on the HTTP admin on :2323 — useful when touch doesn't work. |
| `remoteAdminLan` | true | Only expose the admin on LAN. |

## Starting Fully as HOME

The home-category activity is `de.ozerov.fully/.MainActivity` — not `.FullyActivity`. Confirm with:

```bash
adb shell cmd package resolve-activity --brief -c android.intent.category.HOME -a android.intent.action.MAIN
```

Then:

```bash
adb shell cmd package set-home-activity 'de.ozerov.fully/.MainActivity'
```

Followed by force-stopping Launcher3 to actually reclaim the memory:

```bash
adb shell am force-stop com.android.launcher3
```

(Leaving Launcher3 enabled as a safety net — if Fully ever crashes and the home-activity override is lost, Launcher3 takes over.)

## Starting the activity directly

```bash
adb shell am start -n de.ozerov.fully/.MainActivity \
  -a android.intent.action.MAIN \
  -c android.intent.category.HOME
```

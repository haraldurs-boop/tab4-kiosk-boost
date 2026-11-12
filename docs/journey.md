# The journey — sprint by sprint

A full log of what we tried, what worked, and what didn't. The final product (`kiosk-app/`) was sprint 10. Everything before that was learning.

## Sprint 1: Quick wins on Fully Kiosk

Governor to `performance`, bring offline cores online, disable Doze, whitelist Fully from battery optimization, kill 10 unused apps.

**Result:** +227 MB free RAM, 4 CPU cores up. Felt snappier, but load_avg still looked bad (6+).

## Sprint 2: Diagnose the load

`top -b -n 1 -H` showed 346% idle of 400% available. Load average was being inflated by D-state kernel threads (`mdss_fb0`, `ngd_rx_thread1`, SLIMbus audio IPC). This is a known Qualcomm 3.4 downstream BSP quirk.

**Result:** Load_avg on this kernel is cosmetic. See `load-average-myth.md`.

## Sprint 3-4: Boot persistence

Made the CPU tuning persist across reboots via `watchdog-v2.sh` detecting an uptime drop and re-running `boot-apply-v2.sh`.

**Result:** Works. No root modifications to `/system` needed.

## Sprint 5-6: Watchdog + ntfy

Added config-driven multi-tablet watchdog with throttled ntfy alerts for: offline >5 min, crashloop (3+ restarts in 60 min), temp >45°C, unplugged + low battery, memory pressure.

**Result:** Catches real failures without spamming on every blip.

## Sprint 7: Fully REST admin API

Tried the `com.fullykiosk.setting` broadcast API. Returns `result=0` but settings don't change — modern Fully builds have no settings broadcast receiver despite docs suggesting otherwise.

**Fix:** Edit `/data/data/de.ozerov.fully/shared_prefs/*.xml` directly with root.

## Sprint 8: Lighthouse profiling

Set up @puppeteer/browsers to download Chrome-for-Testing, fetched B12 dashboard snapshot (after bypassing PIN wall with auth script), ran Lighthouse with 6× CPU slowdown to simulate Snapdragon 400.

**Result:** Dashboard CSS has `backdrop-filter: blur(14px)` on a "photo pill" element, plus 2s pulse keyframes, plus Google Fonts — all brutal on Adreno 305.

## Sprint 9: Kiosk-lite CSS override + Plus watermark

Wrote dashboard-side `kiosk-lite.css` + `kiosk-lite.js` that:
- Strips `backdrop-filter`
- Slows pulse animations 2s→6s
- Overrides fonts to system-ui
- Adds `contain: layout paint` to cards

**Result:** CSS works. But toggling Fully's REST admin triggered a "Please get a license" watermark. Tried sprint 9.5 (disable 3 flags), sprint 9.6 (pristine `pm clear` + restore), sprint 9.7 (nuclear). Watermark persisted.

## Sprint 10a: WallPanel

Tried WallPanel 0.12 (open source, no license tier). Install worked. But the setup wizard's "Dashboard URL" field didn't bring up the IME. `adb shell input text` also didn't help because the input field needed focus and tap coords were fiddly.

**Dead end.** Turns out the IME was disabled at the package level (see `your-ime-is-disabled.md`). Had we known that sooner, we'd have kept WallPanel.

## Sprint 10b: Custom app (the final answer)

~100 lines of Java:
- One Activity with a fullscreen WebView
- One BroadcastReceiver for BOOT_COMPLETED
- Immersive mode, portrait only, WAKE_LOCK
- `CATEGORY_HOME` in manifest = home launcher = auto-ran at boot
- PIN exit: 5 rapid back-presses → EditText prompt → unlock

Built on the ThinkPad with Android SDK command-line tools + gradle, no Android Studio. ~5 min first build, ~30s subsequent. JDK 11 is required — AGP 4.2 breaks on JDK 17+.

**Result:** Works. No watermark, no license tier, no setup wizard. We own it.

## What took longest

1. **90 min: IME was disabled.** Classic.
2. **40 min: JDK version hell.** JDK 21 is default on Ubuntu 24.04; AGP 4.2 needs 11.
3. **30 min: Fully's Plus watermark trigger.** Still don't know exactly which flag set it off.
4. **20 min: WallPanel's F-Droid URL scheme changed.** APK fetch script needed GitHub releases fallback.

## What we'd do differently next time

1. **Run `ime list -s` first.** Before touching any kiosk app.
2. **Pin JDK version explicitly** in `build.sh` from day one, don't rely on system default.
3. **Skip Fully, skip WallPanel, go straight to custom app** on devices with broken package management. The custom app is simpler than fighting kiosk app licensing.
4. **Memorize the dpm remove-active-admin limitation.** You can't force-uninstall a device admin from adb on stock LineageOS. Go through Settings UI.

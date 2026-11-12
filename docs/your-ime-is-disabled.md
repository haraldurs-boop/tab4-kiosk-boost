# Your IME is disabled (how we lost 90 minutes)

## The symptom

Tap a text input in Fully Kiosk / WallPanel / our own app → **no keyboard appears**.

## What we tried

1. Added `windowSoftInputMode="adjustResize"` to the activity. No effect.
2. Set `webView.setFocusableInTouchMode(true)` + `requestFocus()`. No effect.
3. Removed `FLAG_SHOW_WHEN_LOCKED` and `FLAG_TURN_SCREEN_ON` from the window (which can set NOT_FOCUSABLE as a side effect). No effect.
4. Verified `dumpsys window` — flags looked right. No effect.
5. Wondered if WebView's IME handling on API 22 was just broken.

## What was actually wrong

```
$ adb shell ime list -s
(empty)

$ adb shell settings get secure default_input_method
(empty)
```

**There was no input method installed or enabled.** Someone (previous owner, or a kiosk app, or us during an earlier sprint) had disabled `com.android.inputmethod.latin` at the package level. No IME = no keyboard, no matter what the app or window flags say.

## The fix

```bash
adb shell pm enable com.android.inputmethod.latin
adb shell ime enable com.android.inputmethod.latin/.LatinIME
adb shell ime set com.android.inputmethod.latin/.LatinIME

# Verify
adb shell ime list -s
# Should show: com.android.inputmethod.latin/.LatinIME
```

Note: on the first `ime enable` right after `pm enable`, the IME service may not be registered yet, so the command fails with "Unknown input method." Just run `ime enable` again a second or two later.

## The lesson

Before debugging IME visibility in your app, always check `adb shell ime list -s`. If it's empty, nothing you do in Java matters.

## Why was it disabled in the first place?

Unknown. The Tab 4 came with LineageOS 17.1 unofficial build. The most likely explanation is that an earlier owner ran `pm disable-user com.android.inputmethod.latin` to shave a few MB of RAM and forgot to document it. Kiosk-mode tutorials sometimes recommend disabling the IME to prevent user escape via the search bar.

#!/usr/bin/env bash
# Install B12 Kiosk on the tablet and launch it.
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APK="$PROJECT_DIR/app/build/outputs/apk/debug/app-debug.apk"
DEVICE="${1:?Usage: $0 <tablet-ip>:5555}"

if [ ! -f "$APK" ]; then
    echo "APK ekki til. Keyrðu fyrst: bash build.sh"
    exit 1
fi

echo ">>> Tengi við $DEVICE..."
adb connect "$DEVICE"

echo ">>> Fjarlægi gamla útgáfu (ef er)..."
adb -s "$DEVICE" uninstall is.openclaw.b12kiosk 2>/dev/null || true

echo ">>> Set upp APK..."
adb -s "$DEVICE" install -r "$APK"

echo ">>> Opna appið..."
adb -s "$DEVICE" shell am start -n is.openclaw.b12kiosk/.MainActivity

echo ""
echo "=== BÚIÐ ==="
echo "Appið ætti núna að vera opið á spjaldtölvunni."
echo ""
echo "Stjórn:"
echo "  - 5 back-takkar fljótt í röð => PIN prompt (default: 1234)"
echo "  - PIN opnar admin menu (reload, clear cache, settings, hætta)"
echo ""
echo "Til að gera það að home launcher (svo það ræsist sjálfkrafa):"
echo "  adb -s $DEVICE shell cmd package set-home-activity is.openclaw.b12kiosk/.MainActivity"
echo ""
echo "Til að fjarlægja:"
echo "  adb -s $DEVICE uninstall is.openclaw.b12kiosk"

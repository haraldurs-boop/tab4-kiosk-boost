#!/usr/bin/env bash
# B12 Kiosk App — bootstrap + build script
# Sets up Android SDK + gradle on Linux without Android Studio, builds APK.
# Usage: bash build.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLS_DIR="$PROJECT_DIR/.tools"
ANDROID_SDK="$TOOLS_DIR/android-sdk"
export ANDROID_HOME="$ANDROID_SDK"
export ANDROID_SDK_ROOT="$ANDROID_SDK"

mkdir -p "$TOOLS_DIR"

echo "=== B12 Kiosk build ==="
echo "Project: $PROJECT_DIR"

# ---------- 1. JDK ----------
# Pin to JDK 11 first (AGP 4.2 compatibility). JDK 17+ causes module access errors.
JDK_CANDIDATES=(
    "/usr/lib/jvm/java-11-openjdk-amd64"
    "/usr/lib/jvm/temurin-11-jdk-amd64"
    "/usr/lib/jvm/java-1.11.0-openjdk-amd64"
    "/usr/lib/jvm/java-17-openjdk-amd64"
    "/usr/lib/jvm/temurin-17-jdk-amd64"
)
for jdk in "${JDK_CANDIDATES[@]}"; do
    if [ -x "$jdk/bin/javac" ]; then
        export JAVA_HOME="$jdk"
        export PATH="$JAVA_HOME/bin:$PATH"
        echo "Nota JDK: $JAVA_HOME"
        break
    fi
done

if ! command -v javac >/dev/null 2>&1; then
    echo ">>> Þarf að setja upp JDK 11. Keyrðu:"
    echo "    sudo apt install -y openjdk-11-jdk-headless"
    echo "og endurkeyrðu þetta script."
    exit 1
fi

JAVA_VER=$(javac -version 2>&1 | awk '{print $2}' | cut -d. -f1)
echo "JDK útgáfa: $(javac -version 2>&1)"

if [ "$JAVA_VER" -gt 17 ]; then
    echo ""
    echo "VILLA: JDK $JAVA_VER er of nýtt fyrir AGP 4.2."
    echo "Settu upp JDK 11: sudo apt install -y openjdk-11-jdk-headless"
    exit 1
fi

# ---------- 2. Android SDK command-line tools ----------
if [ ! -x "$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
    echo ">>> Sæki Android SDK command-line tools..."
    mkdir -p "$ANDROID_SDK/cmdline-tools"
    cd "$TOOLS_DIR"
    if [ ! -f "cmdline-tools.zip" ]; then
        curl -L -o cmdline-tools.zip \
            "https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip"
    fi
    unzip -q -o cmdline-tools.zip -d "$ANDROID_SDK/cmdline-tools"
    mv "$ANDROID_SDK/cmdline-tools/cmdline-tools" "$ANDROID_SDK/cmdline-tools/latest"
    cd "$PROJECT_DIR"
fi

export PATH="$ANDROID_SDK/cmdline-tools/latest/bin:$ANDROID_SDK/platform-tools:$PATH"

# ---------- 3. Accept licenses + install components ----------
if [ ! -d "$ANDROID_SDK/platforms/android-30" ] || [ ! -d "$ANDROID_SDK/build-tools/30.0.3" ]; then
    echo ">>> Samþykki Android SDK licenses..."
    mkdir -p "$ANDROID_SDK/licenses"
    yes 2>/dev/null | sdkmanager --licenses >/dev/null 2>&1 || true

    echo ">>> Sæki Android SDK components (platform-30, build-tools 30.0.3, platform-tools)..."
    sdkmanager "platforms;android-30" "build-tools;30.0.3" "platform-tools"
fi

# ---------- 4. Gradle wrapper jar ----------
if [ ! -f "$PROJECT_DIR/gradle/wrapper/gradle-wrapper.jar" ]; then
    echo ">>> Sæki gradle-wrapper.jar..."
    curl -L -o "$PROJECT_DIR/gradle/wrapper/gradle-wrapper.jar" \
        "https://github.com/gradle/gradle/raw/v6.9.4/gradle/wrapper/gradle-wrapper.jar"
fi

# ---------- 5. gradlew script ----------
if [ ! -x "$PROJECT_DIR/gradlew" ]; then
    echo ">>> Sæki gradlew..."
    curl -L -o "$PROJECT_DIR/gradlew" \
        "https://github.com/gradle/gradle/raw/v6.9.4/gradlew"
    chmod +x "$PROJECT_DIR/gradlew"
fi

# ---------- 6. local.properties ----------
if [ ! -f "$PROJECT_DIR/local.properties" ]; then
    echo "sdk.dir=$ANDROID_SDK" > "$PROJECT_DIR/local.properties"
fi

# ---------- 7. Build ----------
echo ""
echo ">>> Byggi APK..."
cd "$PROJECT_DIR"
./gradlew assembleDebug --no-daemon

APK="$PROJECT_DIR/app/build/outputs/apk/debug/app-debug.apk"
if [ -f "$APK" ]; then
    echo ""
    echo "=== BÚIÐ ==="
    echo "APK: $APK"
    echo "Stærð: $(ls -lh "$APK" | awk '{print $5}')"
    echo ""
    echo "Setja upp á spjaldtölvuna:"
    echo "  bash install.sh"
else
    echo "VILLA: APK ekki smíðað."
    exit 1
fi

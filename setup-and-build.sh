#!/usr/bin/env bash
# Сборка Android APK без Android Studio и без sudo
set -e

ANDROID_HOME="$HOME/android-sdk"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip"
BUILD_TOOLS="34.0.0"
PLATFORM="android-34"

# ── 1. JDK 17 (formula, без sudo) ──────────────────────────────────────────
echo "=== 1. JDK 17 ==="
if ! command -v java &>/dev/null || ! java -version 2>&1 | grep -qE "17\.|21\."; then
    brew install openjdk@17
fi
# Homebrew formula — нет симлинка по умолчанию, задаём JAVA_HOME явно
BREW_JAVA="$(brew --prefix openjdk@17 2>/dev/null || echo '')"
if [ -d "$BREW_JAVA/bin" ]; then
    export JAVA_HOME="$BREW_JAVA"
    export PATH="$JAVA_HOME/bin:$PATH"
fi
java -version

# ── 2. Android command-line tools (прямо с Google, без sudo) ───────────────
echo ""
echo "=== 2. Android SDK command-line tools ==="
SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
if [ ! -f "$SDKMANAGER" ]; then
    echo "Скачиваю cmdline-tools..."
    curl -L -o /tmp/cmdline-tools.zip "$CMDLINE_TOOLS_URL"
    mkdir -p "$ANDROID_HOME/cmdline-tools"
    unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdtools_tmp
    mv /tmp/cmdtools_tmp/cmdline-tools "$ANDROID_HOME/cmdline-tools/latest"
    rm -rf /tmp/cmdtools_tmp /tmp/cmdline-tools.zip
fi
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
echo "sdkmanager: $(sdkmanager --version)"

# ── 3. SDK платформа + build-tools ─────────────────────────────────────────
echo ""
echo "=== 3. SDK: platform-$PLATFORM + build-tools $BUILD_TOOLS ==="
export ANDROID_HOME
yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses >/dev/null 2>&1 || true
sdkmanager --sdk_root="$ANDROID_HOME" \
    "platform-tools" \
    "platforms;$PLATFORM" \
    "build-tools;$BUILD_TOOLS"

# ── 4. Gradle (formula, без sudo) ──────────────────────────────────────────
echo ""
echo "=== 4. Gradle ==="
if ! command -v gradle &>/dev/null; then
    brew install gradle
fi
gradle --version | head -2

# Генерируем gradle wrapper в проекте
cd "$(dirname "$0")"
gradle wrapper --gradle-version 8.4 --distribution-type bin
echo "Gradle wrapper создан"

# ── 5. Сборка ───────────────────────────────────────────────────────────────
echo ""
echo "=== 5. Сборка APK (debug) ==="
./gradlew assembleDebug

APK="app/build/outputs/apk/debug/app-debug.apk"
echo ""
echo "✅  APK готов: $(pwd)/$APK"
echo ""
echo "Установить на телефон (USB, включить отладку по USB):"
echo "  $ANDROID_HOME/platform-tools/adb install $APK"

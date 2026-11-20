#!/usr/bin/env bash
# Build the full-flavor debug APK, install it on the running emulator and launch it.
set -euo pipefail
cd "$(dirname "$0")/.."
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

./gradlew installFullDebug --console=plain -q
# Note: debug builds also ship LeakCanary's launcher icon, so launch the activity explicitly.
adb shell am start -n de.lukasneugebauer.nextcloudcookbook.debug/de.lukasneugebauer.nextcloudcookbook.core.presentation.MainActivity

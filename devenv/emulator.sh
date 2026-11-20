#!/usr/bin/env bash
# Start the headless 'cookbook' emulator (if not already running) and wait for boot.
#   ./devenv/emulator.sh        start + wait
#   ./devenv/emulator.sh stop   shut it down
set -euo pipefail
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
LOG="${TMPDIR:-/tmp}/emulator-cookbook.log"

if [ "${1:-}" = "stop" ]; then
  adb emu kill 2>/dev/null || true
  exit 0
fi

if adb devices | grep -q '^emulator-'; then
  echo "Emulator already running."
else
  # -no-window: headless; view it with scrcpy (see README). swiftshader = software GPU (no host GPU needed).
  cmd="emulator -avd cookbook -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect"
  if id -nG | grep -qw kvm; then
    nohup $cmd >"$LOG" 2>&1 &
  else
    # Group membership not active in this session yet (needs re-login) — use sg.
    nohup sg kvm -c "$cmd" >"$LOG" 2>&1 &
  fi
  echo "Emulator starting (log: $LOG)..."
fi

adb wait-for-device
until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
echo "Emulator booted: $(adb devices | grep emulator-)"

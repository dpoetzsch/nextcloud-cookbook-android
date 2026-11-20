#!/usr/bin/env bash
# Tiny adb UI driver for headless testing.
#   ui.sh tap "<text or content-desc>" [n|last]   tap the n-th (default 1st) element whose text/desc contains it
#   ui.sh type "<text>"                  type into the focused field
#   ui.sh shot <file.png>                save a screenshot
#   ui.sh dump                           print visible texts / descriptions
set -euo pipefail
export PATH="${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools:$PATH"

pick() { if [ "$1" = last ]; then tail -1; else sed -n "${1}p"; fi; }
dump_xml() { adb exec-out uiautomator dump /dev/tty 2>/dev/null | sed 's/UI hierchary dumped.*//'; }

case "${1:-}" in
  tap)
    xml="$(dump_xml)"
    bounds="$(printf '%s' "$xml" | tr '>' '\n' \
      | grep -E "(text|content-desc)=\"[^\"]*$2[^\"]*\"" | pick "${3:-1}" \
      | grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' || true)"
    [ -z "$bounds" ] && { echo "not found: $2" >&2; exit 1; }
    read -r x1 y1 x2 y2 <<<"$(echo "$bounds" | grep -oE '[0-9]+' | tr '\n' ' ')"
    adb shell input tap $(((x1 + x2) / 2)) $(((y1 + y2) / 2))
    ;;
  type) adb shell input text "$(printf '%s' "$2" | sed 's/ /%s/g')" ;;
  shot) adb exec-out screencap -p >"$2" && echo "saved $2" ;;
  dump) dump_xml | tr '>' '\n' | grep -oE '(text|content-desc)="[^"]+"' ;;
  *) sed -n '2,7p' "$0"; exit 1 ;;
esac

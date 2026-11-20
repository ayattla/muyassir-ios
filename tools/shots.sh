#!/usr/bin/env bash
# Launches the app on the simulators, opens each tool with `-tool <id>` and saves a screenshot.
# Fails if the app crashes on any tool screen.
set -u
APP=build/Build/Products/Debug-iphonesimulator/Muyassir.app
IDS=$(grep -o 'Tool(id: "[a-z_0-9]*"' Muyassir/App/Tools.swift | cut -d'"' -f2)
mkdir -p shots/iphone shots/ipad
fail=0
shoot() { # udid dir
  local dev=$1 dir=$2
  xcrun simctl boot "$dev" 2>/dev/null; xcrun simctl bootstatus "$dev" -b >/dev/null
  xcrun simctl status_bar "$dev" override --time 9:41 --batteryState charged --batteryLevel 100 2>/dev/null || true
  xcrun simctl install "$dev" "$APP"
  xcrun simctl privacy "$dev" grant all com.muyassir.app 2>/dev/null || true
  xcrun simctl launch --terminate-running-process "$dev" com.muyassir.app >/dev/null; sleep 6
  xcrun simctl io "$dev" screenshot "shots/$dir/00-home.png" >/dev/null 2>&1
  for c in $(grep -o 'Category(id: "[a-z]*"' Muyassir/App/Tools.swift | cut -d'"' -f2); do
    xcrun simctl launch --terminate-running-process "$dev" com.muyassir.app -cat "$c" >/dev/null; sleep 3
    xcrun simctl io "$dev" screenshot "shots/$dir/cat-$c.png" >/dev/null 2>&1
  done
  for id in $IDS; do
    xcrun simctl launch --terminate-running-process "$dev" com.muyassir.app -tool "$id" >/dev/null || { echo "launch failed: $id"; fail=1; continue; }
    sleep 2.5
    xcrun simctl io "$dev" screenshot "shots/$dir/$id.png" >/dev/null 2>&1
  done
  xcrun simctl terminate "$dev" com.muyassir.app 2>/dev/null; xcrun simctl shutdown "$dev" 2>/dev/null
}
shoot "$IPHONE" iphone
[ -n "${IPAD:-}" ] && shoot "$IPAD" ipad
echo "screens: $(ls shots/iphone | wc -l) iPhone, $(ls shots/ipad 2>/dev/null | wc -l) iPad"
exit $fail

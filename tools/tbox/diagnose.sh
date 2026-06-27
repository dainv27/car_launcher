#!/usr/bin/env bash
set -euo pipefail

ADB="${ADB:-adb}"
PACKAGE="com.carlauncher.car_launcher"

device="$("$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
if [[ -z "${device:-}" ]]; then
  echo "No authorized TBox found. Connect USB/Wi-Fi ADB and accept the authorization prompt."
  exit 1
fi

shell() {
  "$ADB" -s "$device" shell "$@"
}

echo "TBox: $device"
echo "Model: $(shell getprop ro.product.manufacturer) $(shell getprop ro.product.model)"
echo "Android: $(shell getprop ro.build.version.release) (API $(shell getprop ro.build.version.sdk))"
echo "Build: $(shell getprop ro.build.display.id)"
echo "Root: $(shell su -c id 2>/dev/null || echo unavailable)"
echo

echo "Window features:"
shell pm list features | grep -E 'freeform|picture_in_picture|activities_on_secondary_displays' || true
echo

echo "Window settings:"
for key in enable_freeform_support force_resizable_activities; do
  value="$(shell settings get global "$key" 2>/dev/null || true)"
  echo "$key=${value:-unset}"
done
echo

echo "Launcher package:"
shell dumpsys package "$PACKAGE" 2>/dev/null | grep -E 'pkgFlags|privateFlags|MANAGE_ACTIVITY_TASKS|SYSTEM_ALERT_WINDOW|INJECT_EVENTS|ADD_TRUSTED_DISPLAY|ACTIVITY_EMBEDDING' || {
  echo "$PACKAGE is not installed."
}
echo

echo "Google Maps:"
shell pm path com.google.android.apps.maps 2>/dev/null || echo "not installed"
echo "YouTube:"
shell pm path com.google.android.youtube 2>/dev/null || echo "not installed"
echo

echo "Recent multi-window logs:"
shell logcat -d -t 300 -s VirtualDisplayAppView MultiWindowLauncher ActivityViewHelper GoogleMapsPlatformView 2>/dev/null || true

#!/usr/bin/env bash
set -euo pipefail

ADB="${ADB:-adb}"
PACKAGE="com.carlauncher.car_launcher"

device="$("$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
if [[ -z "${device:-}" ]]; then
  echo "No authorized TBox found."
  exit 1
fi

shell() {
  "$ADB" -s "$device" shell "$@"
}

echo "Configuring multi-window on $device..."
shell settings put global enable_freeform_support 1
shell settings put global force_resizable_activities 1
shell appops set "$PACKAGE" SYSTEM_ALERT_WINDOW allow 2>/dev/null || true

echo "Attempting privileged grants. Failures are expected on non-root firmware."
shell pm grant "$PACKAGE" android.permission.SYSTEM_ALERT_WINDOW 2>/dev/null || true
shell pm grant "$PACKAGE" android.permission.MANAGE_ACTIVITY_TASKS 2>/dev/null || true
shell pm grant "$PACKAGE" android.permission.INJECT_EVENTS 2>/dev/null || true
shell pm grant "$PACKAGE" android.permission.ADD_TRUSTED_DISPLAY 2>/dev/null || true
shell pm grant "$PACKAGE" android.permission.ACTIVITY_EMBEDDING 2>/dev/null || true

echo
echo "Current settings:"
echo "enable_freeform_support=$(shell settings get global enable_freeform_support)"
echo "force_resizable_activities=$(shell settings get global force_resizable_activities)"
echo
echo "Reboot the TBox for framework window settings to take effect:"
echo "  adb -s $device reboot"

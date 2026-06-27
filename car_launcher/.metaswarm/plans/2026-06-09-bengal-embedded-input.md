# Bengal embedded app input

## Goal

Make the Maps and YouTube panes respond to touch on the Android 13 Bengal TBox.

## Evidence

- The compatibility VirtualDisplay renders both apps.
- The installed launcher is a regular APK and does not hold `INJECT_EVENTS`.
- Cross-display input injection therefore fails on every touch.

## Plan

1. Keep the privileged VirtualDisplay path when `INJECT_EVENTS` is granted.
2. Without that permission, use an enabled Accessibility Service to dispatch gestures to each virtual display.
3. Keep the native app visible and open Accessibility Settings on the first touch when the bridge is disabled.
4. Verify native touch behavior on Bengal and run Flutter/Android quality gates.

## Test-first contract

The Android host source must keep native apps visible and route gestures through
an enabled input bridge when privileged cross-display injection is unavailable.

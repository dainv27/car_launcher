# Keyboard and system sidebar stability

## Goal

Keep the launcher UI and TBox sidebar stable when an embedded app opens the
software keyboard.

## Plan

1. Prevent the main launcher activity from resizing for the IME.
2. Prevent IME-driven SurfaceView changes from shrinking embedded displays.
3. Keep the system sidebar overlay outside IME and system-bar inset changes.
4. Update only existing sidebar icon state when the active route changes.
5. Verify on Bengal with the Maps search keyboard.

## Test-first contract

The manifest uses `adjustNothing`; the native sidebar ignores insets and active
route updates mutate existing icon views instead of rebuilding the sidebar.

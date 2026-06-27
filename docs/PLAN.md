# Car Launcher Plan

Updated: 2026-06-16

## Current Direction

Car Launcher is a normal Android app with full-width Flutter UI, in-app
settings, and no persistent native taskbar. The Android manifest must remain a
standard app manifest with `MAIN`/`LAUNCHER` only.

## Completed In Current Architecture

- Normal Android app entry point.
- No HOME/default launcher registration.
- No boot-start receiver.
- No system overlay permission.
- No native taskbar/sidebar services.
- Dashboard, Apps, Media, Navigation, and Settings reachable in app.
- Compact top bar menu for narrow displays.
- Settings moved fully into `/settings`.

## Active Follow-Up Areas

1. Keep embedded app surfaces stable on TBox firmware variants.
2. Improve fullscreen fallbacks for devices without privileged embedding.
3. Expand widget tests once Flutter CLI execution is stable on the workstation.
4. Continue polishing Settings content and responsive layouts.
5. Validate on real S60/TBox display dimensions.

## Out Of Scope

- Default HOME launcher behavior.
- Auto-start on boot.
- Persistent taskbar/sidebar outside the app.
- System overlay media controls.

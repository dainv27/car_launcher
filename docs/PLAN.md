# Car Launcher Plan

Updated: 2026-09-24

## Current Direction

Car Launcher registers as an Android HOME/default launcher (`MAIN` + `HOME` +
`DEFAULT` + `LAUNCHER`), can replace the device's stock launcher without root,
and restarts itself as the Home surface after boot via `BootReceiver`. Primary
navigation stays inside the full-width Flutter UI with in-app settings; there
is still no persistent native taskbar, sidebar, or system overlay. A separate
`system` build flavor (`sharedUserId=android.uid.system`, platform-signed)
exists for devices where CarCar-parity privileged embedding permissions are
required; the default flavor does not request them.

## Completed In Current Architecture

- HOME/default launcher registration, opt-in via the in-app "Set as Default
  Launcher" action or Settings > Apps > Default apps > Home app.
- `BootReceiver` restarts the app as the Home surface after boot.
- `system` build flavor for platform-signed, privileged-permission builds
  matching CarCar's manifest.
- No system overlay permission (`SYSTEM_ALERT_WINDOW`) and no persistent
  native taskbar/sidebar services.
- Dashboard, Apps, Media, Navigation, and Settings reachable in app.
- Compact top bar menu for narrow displays.
- Settings moved fully into `/settings`.
- Vehicle trips, route map, geofences, and alerts surfaced from the vehicle
  detail screen (see [Vehicle Tracking](VEHICLE_TRACKING.md)).

## Active Follow-Up Areas

1. Validate the Home-role prompt and default-launcher switch across Android
   versions and the S60/TBox display sizes.
2. Verify the `system` flavor installs and boots correctly when signed with a
   ROM's platform key.
3. Keep embedded app surfaces stable on TBox firmware variants.
4. Improve fullscreen fallbacks for devices without privileged embedding.
5. Expand widget tests once Flutter CLI execution is stable on the workstation.
6. Continue polishing Settings content and responsive layouts.

## Out Of Scope

- Persistent taskbar/sidebar outside the app.
- System overlay (`SYSTEM_ALERT_WINDOW`) media controls or UI.
- Forcing HOME/default-launcher registration without user confirmation.

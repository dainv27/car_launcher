# Car Launcher Features

Updated: 2026-06-16

## Home Launcher Shell

Car Launcher registers as a Home launcher (`MAIN` + `HOME` + `DEFAULT` +
`LAUNCHER` intent categories) and can replace the device's default launcher.
On any device the user selects it under Settings > Apps > Default apps > Home
app — no root required. The platform-signed `system` build can additionally
take the HOME role programmatically. The activity uses `singleTask` +
`stateNotNeeded` and a boot receiver so it comes up as the home surface after
boot. It does not create persistent system overlays or a native taskbar.

## Dashboard

- Full-width dashboard content with no reserved taskbar rail.
- Shared top app bar for primary in-app destinations.
- Compact top bar menu for narrow displays.
- Map, media, weather, clock, and status widgets remain available inside the
  dashboard layouts.

## Apps

- Installed-app grid.
- Search.
- Favorites.
- In-app Back and Settings actions.

## Media

- Media session display.
- Playback controls.
- In-app Back and Settings actions.
- Notification access shortcut from the dashboard top bar.

## Navigation

- Navigation route with the shared top bar.
- Embedded map surface when supported by the device.
- Fullscreen Maps fallback when embedding is unavailable.

## Vehicle Tracking

- Settings can load vehicles from the server, register a vehicle, and assign one
  vehicle to the current device.
- Tracking points are stored offline in SQLite and synced in batches.
- Native background service records and syncs points while tracking is enabled.
- API mapping follows the Postman collection paths documented in
  [Vehicle Tracking](VEHICLE_TRACKING.md).

## Settings

All settings are inside `/settings`:

- appearance;
- dashboard layout;
- navigation app selection;
- media app selection;
- connectivity;
- account;
- system info, hidden apps, and logs.

Removed setting groups:

- native taskbar appearance;
- sidebar button visibility;
- system overlay controls.

## Native Integration

The app keeps native bridge support for installed apps, media sessions,
notification access settings, voice assistant launch, and privileged embedded
app surfaces. These APIs do not create persistent system overlays.

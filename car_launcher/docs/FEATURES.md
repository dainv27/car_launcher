# Car Launcher Features

Updated: 2026-06-16

## Normal Android App Shell

Car Launcher launches like any other Android app. The manifest exposes a normal
`MAIN`/`LAUNCHER` activity and does not register HOME categories, boot
receivers, system overlay permissions, or persistent native taskbar services.

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

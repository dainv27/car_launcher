# Car Launcher Features

Updated: 2026-09-24

## Home Launcher Shell

Car Launcher registers as a Home launcher (`MAIN` + `HOME` + `DEFAULT` +
`LAUNCHER` intent categories) and can replace the device's default launcher.
On any device the user can either go to Settings > Apps > Default apps > Home
app, or use the in-app "Set as Default Launcher" button under Settings >
System Info, which triggers the standard `RoleManager` Home-role prompt on
Android 10+ (falling back to the same system settings screen otherwise) — no
root or platform signing required for either path. The activity uses
`singleTask` + `stateNotNeeded` and a boot receiver so it comes up as the
home surface after boot. It does not create persistent system overlays or a
native taskbar.

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

## Account

- Sign in via Keycloak OIDC (Authorization Code + PKCE) at `/login`, with
  session restore and automatic token refresh.
- `/vehicles`, `/history/:vehicleId`, and the Vehicle/Tracking settings
  categories require an active session.

## Vehicle Tracking

- Vehicle list and detail (`/vehicles`, `/vehicles/:id`), also reachable from
  Settings, can load vehicles from the server, register a vehicle, and assign
  one vehicle to the current device.
- Each vehicle's detail page links to its trips (`/vehicles/:id/trips`, trip
  detail at `/trips/:tripId`), geofences (`/vehicles/:id/geofences`), and
  alerts (`/vehicles/:id/alerts`).
- Tracking history (`/history/:vehicleId`) shows a route map or a list of raw
  points, filterable by date range.
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

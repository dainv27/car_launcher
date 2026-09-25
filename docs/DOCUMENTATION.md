# Car Launcher Documentation

Updated: 2026-09-24

## Current Architecture

Car Launcher registers as the Android Home/default launcher (`MAIN`+`HOME`+
`DEFAULT`+`LAUNCHER`) and can replace the device's stock launcher without
root — via Settings > Apps > Default apps > Home app, or the in-app
"Set as Default Launcher" button under Settings > System Info. It keeps
primary navigation inside the Flutter app.

The app still does not:

- request `SYSTEM_ALERT_WINDOW`;
- run a persistent native taskbar, sidebar, or media system overlay;
- reserve layout width for a taskbar rail.

It does start itself from `BOOT_COMPLETED`/`LOCKED_BOOT_COMPLETED` via
`BootReceiver`, to come back up as the Home surface after a reboot.

## Primary Routes

| Route | Purpose |
|---|---|
| `/splash` | Startup splash, then redirects to `/` |
| `/` | Main dashboard |
| `/apps` | Installed app drawer |
| `/media` | Media center |
| `/navigation` | Full-screen navigation dashboard (child: `/navigation/youtube`) |
| `/vehicles` | Vehicle list (requires login) |
| `/vehicles/:id` | Vehicle detail, with `trips`, `geofences`, `alerts` sub-routes |
| `/trips/:tripId` | Trip detail (requires login) |
| `/history/:vehicleId` | Tracking history (requires login) |
| `/login` | Account login (Keycloak OIDC) |
| `/callback` | OAuth redirect target, then routes to `/` |
| `/settings` | In-app settings |
| `/settings/account` | Account settings |
| `/settings/clock-network` | Clock and network settings |
| `/settings/logs` | Log viewer |
| `/settings/vehicle` | Vehicle settings |
| `/settings/tracking` | Tracking settings |

`/vehicles`, `/trips/:tripId`, and `/history/:vehicleId` redirect to `/login`
when there is no active session; other protected screens (e.g.
`/vehicles/:id`) gate at the page level instead. See
[docs/design/features/02-navigation-and-routing.md](design/features/02-navigation-and-routing.md)
for the full routing design.

The dashboard top bar provides Home, Apps, Media, Navigation, and Settings.
On narrow screens it keeps Home visible and moves the remaining destinations
into a compact menu.

Apps and Media pages include in-app Back and Settings actions so users are not
dependent on Android system navigation. Settings uses the shared top bar and
therefore always exposes Home.

## Native Boundary

The Android native layer still supports privileged embedded-app surfaces where
the device firmware allows them. That behavior is separate from system overlays:
fallbacks open apps or maps as normal fullscreen Android activities.

Removed native components:

- `SystemSidebarService`
- `MediaOverlayService`
- taskbar/sidebar route APIs

`BootReceiver` and the default-launcher role/prompt APIs
(`isDefaultLauncher`/`requestDefaultLauncher`) are present — see
[docs/tbox/README.md](tbox/README.md).

## Settings

All settings live inside the app under `/settings`. Native taskbar/sidebar
appearance controls were removed because there is no persistent taskbar.

Settings still covers:

- appearance and theme;
- dashboard layout;
- navigation defaults;
- media defaults;
- connectivity status;
- account login;
- system info, hidden apps, and logs.

## Validation Contract

The normal-app behavior is covered by `test/normal_app_contract_test.dart` and
native lifecycle/security contract tests. Android validation should include:

```powershell
.\gradlew.bat :app:compileDebugKotlin :app:processDebugMainManifest :app:assembleDebug
```

Flutter validation should include:

```powershell
flutter test
flutter analyze
```

## Design documentation

Per-feature design docs (goals, UX flow, architecture, data flow, state
management, native/API integration, persistence, trade-offs, edge cases, tests)
live in [`docs/design/features/`](design/features/README.md). Static UI mockups
are in [`docs/design/`](design/).

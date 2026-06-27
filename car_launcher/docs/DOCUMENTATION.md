# Car Launcher Documentation

Updated: 2026-06-16

## Current Architecture

Car Launcher is now a normal Android application. It is launched from the
standard app launcher, exposes only the regular `MAIN`/`LAUNCHER` entry point,
and keeps primary navigation inside the Flutter app.

The app no longer:

- registers as the Android HOME/default launcher;
- starts itself from `BOOT_COMPLETED`;
- requests `SYSTEM_ALERT_WINDOW`;
- runs a persistent native taskbar, sidebar, or media system overlay;
- reserves layout width for a taskbar rail.

## Primary Routes

| Route | Purpose |
|---|---|
| `/` | Main dashboard |
| `/apps` | Installed app drawer |
| `/media` | Media center |
| `/navigation` | Full-screen navigation dashboard |
| `/settings` | In-app settings |
| `/settings/account` | Account settings |
| `/settings/clock-network` | Clock and network settings |
| `/settings/logs` | Log viewer |

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

- `BootReceiver`
- `SystemSidebarService`
- `MediaOverlayService`
- default launcher role/prompt APIs
- taskbar/sidebar route APIs

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

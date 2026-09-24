# Car Launcher Backlog

Updated: 2026-09-24

## P1

| ID | Title | Area |
|---|---|---|
| home-launcher-role-qa | Validate the Home-role prompt and default-launcher switch across Android versions | Native |
| system-flavor-signing-qa | Verify the `system` build flavor installs/boots when signed with a ROM platform key | Native |
| normal-app-s60-qa | Validate compact top bar and Settings on S60/TBox display sizes | UI |
| embedded-fallback-qa | Verify Maps/app fullscreen fallbacks on non-privileged firmware | Native |
| flutter-cli-stability | Fix local Flutter CLI timeout during test/analyze runs | Tooling |

## P2

| ID | Title | Area |
|---|---|---|
| media-session-polish | Improve live MediaSession metadata and controls | Media |
| settings-content-polish | Finish Settings categories and copy | Settings |
| app-drawer-icons | Improve installed app icon loading and caching | Apps |
| weather-provider | Connect weather provider to production data source | Dashboard |

## Explicitly Out Of Scope

No backlog item should reintroduce a persistent native taskbar/sidebar
service or request `SYSTEM_ALERT_WINDOW`/system overlay UI. HOME/default
launcher registration and the boot-start receiver are intentional and already
implemented — see [Plan](PLAN.md).

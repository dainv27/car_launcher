# TBox Documentation

This folder documents the TBox target for the current normal-app architecture.

Car Launcher is installed and opened as a regular Android application. It does
not register as HOME, does not auto-start from boot, and does not draw a
persistent taskbar or system overlay. TBox-specific work focuses on embedded
app surfaces, fullscreen fallbacks, platform signing, debugging, and recovery.

## Documents

| Need | Document |
|---|---|
| Architecture and current status | [01_OVERVIEW.md](01_OVERVIEW.md) |
| SDK, debug/release builds, platform signing | [02_SDK_AND_BUILD.md](02_SDK_AND_BUILD.md) |
| MethodChannel, EventChannel, PlatformView APIs | [03_NATIVE_API.md](03_NATIVE_API.md) |
| Maps, YouTube, and embedded-app fallbacks | [04_EMBEDDED_APPS.md](04_EMBEDDED_APPS.md) |
| In-app navigation and settings | [05_SIDEBAR_AND_OVERLAYS.md](05_SIDEBAR_AND_OVERLAYS.md) |
| ROM permissions and platform signing | [06_ROM_PERMISSIONS.md](06_ROM_PERMISSIONS.md) |
| ADB, install, diagnostics, and logs | [07_OPERATIONS_AND_DEBUGGING.md](07_OPERATIONS_AND_DEBUGGING.md) |
| Root/recovery notes | [08_ROOT_BENGAL_CARLINK_TBOX_AMBIENT.md](08_ROOT_BENGAL_CARLINK_TBOX_AMBIENT.md) |
| CarCar technical reference | [CARCAR_LAUNCHER_ANALYSIS.md](CARCAR_LAUNCHER_ANALYSIS.md) |

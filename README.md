# Car Launcher

Car Launcher is a Flutter Android app for in-car TBox/head-unit devices. It can
register as the Android HOME/default launcher (no root required) and restarts
itself as the Home surface after boot, while keeping all primary navigation —
Dashboard, Apps, Media, Navigation, Settings — inside the app. It also manages
vehicle registration, device pairing, and offline-first location tracking
against the vehicle service backend (trips, route map, geofences, alerts).

## Documentation

- [`docs/DOCUMENTATION.md`](docs/DOCUMENTATION.md) — architecture and routes.
- [`docs/FEATURES.md`](docs/FEATURES.md) — feature overview.
- [`docs/USE_CASES.md`](docs/USE_CASES.md) — user-facing flows.
- [`docs/VEHICLE_TRACKING.md`](docs/VEHICLE_TRACKING.md) — vehicle service API
  integration and offline sync.
- [`docs/PLAN.md`](docs/PLAN.md) / [`docs/BACKLOG.md`](docs/BACKLOG.md) —
  current direction and open work.
- [`docs/design/features/`](docs/design/features/README.md) — per-feature
  design docs (architecture, data flow, state management).
- [`docs/tbox/README.md`](docs/tbox/README.md) — TBox integration, native API,
  embedded apps, ROM permissions, and diagnostics.

## Getting Started

This is a standard Flutter project (`flutter pub get`, `flutter run`). See
[`docs/tbox/02_SDK_AND_BUILD.md`](docs/tbox/02_SDK_AND_BUILD.md) for the
Android build flavors and TBox-specific build/signing requirements, and
[`docs/DOCUMENTATION.md`](docs/DOCUMENTATION.md#validation-contract) for the
test/analyze/build validation commands.

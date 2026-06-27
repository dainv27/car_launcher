# Design Review: Unified Splash and Real Connectivity

## Decision

- Use the DaiNV image as the identical bitmap for Android launch background and
  Flutter splash.
- Centralize Android connectivity collection in `ConnectivityStatusReader`.
- Expose Wi-Fi and cellular levels on a 0-4 scale, plus validated internet,
  Bluetooth adapter/connection state, active transport, and battery.
- Let Flutter consume native events with polling as a fallback.
- Let the native sidebar read the same snapshot directly.

## Risk Review

- Permission failures return unavailable levels instead of fabricated values.
- Bluetooth enabled is kept separate from Bluetooth connected.
- UI surfaces remain usable when no network is available.

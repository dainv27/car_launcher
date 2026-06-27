# Real Data Audit

## Implemented Real Sources

| Surface | Source |
|---|---|
| Installed apps and icons | Android `PackageManager` |
| Connectivity | Android `ConnectivityManager`, including validated internet state |
| Battery | Android `BatteryManager` |
| Location and top-bar place name | Android `LocationManager` + Android `Geocoder`; cached locations older than five minutes are rejected |
| Weather | OpenWeatherMap using real coordinates or configured city |
| Media metadata and playback controls | Android active `MediaSession` |
| Maps and YouTube content | Embedded Android applications |
| Sidebar state | Native Android overlay service |

## Removed Fabricated Data

- Dashboard footer no longer displays hardcoded climate, TPMS, or system-online
  values.
- Battery starts as unavailable instead of `100%`.
- Weather no longer defaults to Hanoi when no real/configured location exists.
- Flutter media controls no longer mutate local playback state optimistically.
- Production navigation controller no longer exposes `setMockState`.
- Navigation provider changes only after Android confirms the app launched.
- Unsupported stop-navigation actions return failure instead of false success.
- The top-bar media-access action reports whether Android Notification Access is
  granted and opens the exact system permission screen when it is missing.

## Vendor API Blockers

The project currently has no TBox/vendor SDK contract for:

- TPMS pressures and fault state
- HVAC temperature and mode
- CAN vehicle speed, RPM, fuel, doors, or warnings
- Google Maps turn-by-turn state from another app
- Reading the Android notification shade from a regular application

Android Notification Access must be granted once by the end user before active
MediaSession metadata and controls become available.

These values must stay unavailable until a documented vendor SDK, CAN/OBD
bridge, or another authorized data source is supplied. The launcher must not
invent them.

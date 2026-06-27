# Real Data Design Review

## Scope

Replace user-visible mock dashboard state and local-only controls with Android
system data and actions already available to an end-user launcher.

## Design Gate

- Never invent climate or TPMS data when the TBox exposes no vehicle API.
- Display Android connectivity and battery state with an explicit unavailable state.
- Route notification, voice assistant, and media controls to Android.
- Keep platform failures non-fatal because ROM capabilities vary.

## Out Of Scope

Real TPMS, HVAC, CAN speed, and vehicle telemetry require a vendor SDK or a
defined CAN/OBD data source. No such API exists in the current TBox integration.

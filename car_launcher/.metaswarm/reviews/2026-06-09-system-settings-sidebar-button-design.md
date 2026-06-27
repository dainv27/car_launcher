# Design Review: System Settings Sidebar Button

## Decision

Place the Android System Settings button directly above the launcher Settings
button in the fixed bottom action group. Use a distinct sliders icon and keep it
inactive because Android Settings is outside the launcher's route hierarchy.

## Risks Reviewed

- System Settings may be unavailable on customized ROMs: catch launch failures
  and log them without crashing the overlay service.
- Launcher Settings highlight must remain route-driven and unchanged.
- The action must launch from a service context with `FLAG_ACTIVITY_NEW_TASK`.

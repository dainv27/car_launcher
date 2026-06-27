# VirtualDisplay Guide

Car Launcher may use privileged embedded-app surfaces on compatible TBox ROMs.
This guide applies to the current normal Android app architecture.

## Goals

- Create embedded app surfaces only after the Flutter view and Android surface
  are ready.
- Recover cleanly when surfaces are recreated.
- Fall back to fullscreen app launch when embedding is unavailable.
- Avoid duplicate VirtualDisplay creation.

## Readiness Checks

Before creating an embedded surface, verify:

- Activity is resumed.
- Root view is attached and measured.
- PlatformView surface exists.
- DisplayManager reports a usable display.
- Target package is launchable.

## Recovery

- Tear down stale hosts before recreating a surface.
- Retry only on lifecycle or surface events.
- Use bounded retry attempts with structured logs.
- Prefer fullscreen fallback when privileged APIs are unavailable.

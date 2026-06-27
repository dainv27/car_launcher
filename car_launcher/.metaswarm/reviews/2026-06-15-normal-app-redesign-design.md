# Design Review: Normal App Redesign

Status: PASS

The application will stop registering as Android HOME, stop auto-starting at
boot, and remove all system overlay taskbar/media services. The Flutter app
uses its full window and exposes Settings from the in-app top bar.

Privileged VirtualDisplay embedding remains intentionally in scope because
removing platform identity would disable existing embedded-app functionality.
Deprivileging is a separate product change.

Acceptance criteria:

- Manifest exposes MAIN/LAUNCHER but not HOME.
- No boot receiver, system sidebar service, media overlay service, or overlay
  permission remains.
- No persistent taskbar/sidebar remains.
- Settings is reachable from the in-app top bar.
- Settings contains no native taskbar configuration.
- No Flutter or native code starts or synchronizes a system sidebar.
- Existing embedded-app functionality remains available.

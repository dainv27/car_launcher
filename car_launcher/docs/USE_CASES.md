# Car Launcher Use Cases

Updated: 2026-06-16

## Scope

Car Launcher behaves as a regular Android app. It does not replace the system
HOME screen, does not auto-start after boot, and does not draw persistent
system overlays. All navigation and settings are handled inside the app.

## UC-01 Open App

Actor: driver or passenger

Trigger: user taps the Car Launcher icon from Android.

Flow:

1. Android starts `MainActivity` through the `MAIN`/`LAUNCHER` intent.
2. Flutter shows the splash route.
3. The app routes to the main dashboard.

## UC-02 Navigate Between Primary Areas

Actor: user

Trigger: user taps a destination in the app top bar.

Flow:

1. User taps Home, Apps, Media, Navigation, or Settings.
2. The app navigates with GoRouter.
3. On narrow screens, Home stays visible and other destinations are available
   from the top bar menu.

## UC-03 Open Installed Apps

Actor: user

Trigger: user opens `/apps`.

Flow:

1. The app lists installed launchable apps.
2. User searches, launches, or favorites an app.
3. After launch, Car Launcher returns to its dashboard route when appropriate.

## UC-04 Use Media Center

Actor: user

Trigger: user opens `/media`.

Flow:

1. The Media route shows current media session state.
2. User controls playback where native media access is available.
3. User can return with the in-app Back action or open Settings.

## UC-05 Use Navigation

Actor: user

Trigger: user opens `/navigation`.

Flow:

1. The Navigation dashboard opens with the app top bar.
2. The embedded map attempts to use privileged embedding when available.
3. If embedding is unavailable, the fallback launches Maps as a fullscreen app.
4. User can leave Navigation via the in-app top bar.

## UC-06 Change Settings

Actor: user

Trigger: user opens `/settings`.

Flow:

1. Settings opens as an in-app route.
2. User selects a settings category.
3. Changes persist through the existing Riverpod/shared-preference providers.
4. User can return Home through the shared top bar.

## Removed Use Cases

The following legacy behaviors are intentionally out of scope:

- becoming the Android default HOME application;
- handling physical HOME as a launcher replacement;
- starting from boot broadcasts;
- showing a persistent taskbar/sidebar outside the app;
- requesting system overlay permission for media controls or taskbar UI.

# Car Launcher Use Cases

Updated: 2026-09-24

## Scope

Car Launcher can replace the system HOME screen (no root required) and
auto-starts after boot once selected as the default Home app. It does not
draw persistent system overlays. All navigation and settings are handled
inside the app.

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

## UC-07 Set as Default Launcher

Actor: user

Trigger: user opens Settings > System Info and taps "Set as Default
Launcher" (shown only while Car Launcher is not already the Home app).

Flow:

1. Settings > System Info shows whether Car Launcher is currently the
   device's Home app (polled via `isDefaultLauncher`).
2. On Android 10+, tapping the button opens the system's Home-role
   confirmation dialog (`RoleManager`); on older versions, or if the role
   API is unavailable, it opens Settings > Apps > Default apps > Home app
   instead.
3. The status updates automatically once the user confirms (or returns
   from Settings).

## UC-08 Sign In

Actor: user

Trigger: user opens `/login`, or navigates to a protected route
(`/vehicles`, `/history/:vehicleId`) while signed out.

Flow:

1. Signed-out access to a protected route redirects to `/login`; other
   vehicle/tracking screens (e.g. `/vehicles/:id`) show a login-required
   placeholder instead of redirecting.
2. User taps Sign In; the system browser opens Keycloak OIDC login
   (Authorization Code + PKCE).
3. Keycloak redirects to `carlauncher://oauth/callback`, which Android hands
   to the pending login request; the `/callback` route only controls what is
   shown before returning to `/`.
4. On success the session is available to the HTTP client and the native
   vehicle-tracking service; on cancel or error the login page shows a
   message instead of navigating away.

## UC-09 Manage Vehicles

Actor: signed-in user

Trigger: user opens `/vehicles` (also reachable from `/settings/vehicle`).

Flow:

1. The app loads the signed-in user's vehicles from the vehicle service.
2. User can register a new vehicle or open a vehicle's detail page
   (`/vehicles/:id`) to view/assign the current device and jump to its trips,
   geofences, and alerts.

## UC-10 Review Trips, Tracking History, Geofences, and Alerts

Actor: signed-in user

Trigger: user opens a vehicle's trips (`/vehicles/:id/trips`, then
`/trips/:tripId` for detail), tracking history (`/history/:vehicleId`),
geofences (`/vehicles/:id/geofences`), or alerts (`/vehicles/:id/alerts`).

Flow:

1. Each screen requires an active session (redirect or login-required
   placeholder, depending on route).
2. Tracking history renders either a route on a map or a list of raw points,
   filterable by date range.
3. Trip, geofence, and alert data is fetched from the vehicle service backend
   (see [Vehicle Tracking](VEHICLE_TRACKING.md)).

## Removed Use Cases

The following legacy behaviors are intentionally out of scope:

- showing a persistent taskbar/sidebar outside the app;
- requesting system overlay permission for media controls or taskbar UI.

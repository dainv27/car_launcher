# Vehicle Management and Tracking

## API Base

The app uses the vehicle service client APIs.

Default base URL:

```text
https://car-apis.202corp.com/vehicle-service/client-api/v1
```

The sync client also accepts OpenAPI server bases such as:

```text
https://dev-car-apis.202corp.com/vehicle-service
```

When a service base is provided, the app normalizes it to include
`/client-api/v1` before calling vehicle endpoints.

The Settings screen does not expose API configuration; the app uses this base URL by default.

All server requests use Bearer authentication from the current login access token.

## Vehicle Management

Vehicle information is stored on the server. The device keeps only the currently assigned vehicle locally so background tracking can continue when Flutter UI is not active.

Implemented API mapping:

```text
GET    /vehicles?page=0&size=10
GET    /vehicles/:id
POST   /vehicles
PATCH  /vehicles/:id
GET    /devices?vehicleId=:id
```

Currently used by the app:

- `GET /vehicles?page=0&size=10` to load vehicles in Settings.
- `POST /vehicles` to register a vehicle. The server generates the vehicle id.
- `PATCH /vehicles/:id` to edit an existing vehicle (no delete endpoint is
  exposed by the client API).
- `GET /devices?vehicleId=:id` to list the devices attached to a vehicle on
  its detail screen.

Registration request body:

```json
{
  "plateNumber": "51A-12345",
  "name": "Family car",
  "brand": "Toyota",
  "model": "Vios",
  "metadata": {
    "year": "2026"
  }
}
```

Vehicle ids are not sent when registering a vehicle. The app expects the server
response to include `id` or `vehicleId`, then stores that returned id locally.

Example server response:

```json
{
  "id": "car-001",
  "vehicleId": "car-001",
  "plateNumber": "51A-12345",
  "name": "Family car",
  "brand": "Toyota",
  "model": "Vios",
  "metadata": {
    "year": "2026"
  }
}
```

The app accepts either `id` or `vehicleId` from server responses.

## Assigning Vehicle To Device

Selecting a vehicle in Settings assigns it locally to this device and pushes the selected vehicle profile to the native background service.

Separately, on every app start the device registers itself with vehicle-service
via a `SELF_SIGNED_PKI` attestation handshake (`POST
/public-api/v1/devices/enroll{,/challenge}`, `X-Device-Assertion` signed by a
per-install Android Keystore key) — this is unrelated to the vehicle CRUD
above and creates the device *unclaimed*, before any user assigns it to a
vehicle. See [14-device-registration.md](design/features/14-device-registration.md)
for the full flow. The older client-api `POST /devices` create path (`Build.ID`
-based device id) still exists on `DeviceService` but nothing calls it anymore
— it is dead code as of 2026-09-24. `GET /devices?vehicleId=:id` (see
[Vehicle Management](#vehicle-management) above) is the one client-api device
call still in active use, listing devices already assigned to a vehicle.

All later tracking payloads are tied to this assigned vehicle.

## Location Tracking

Tracking data is stored offline in SQLite:

```text
vehicle_tracking.sqlite
pending_points
synced_points
```

Background tracking writes location points into `pending_points`. Sync moves successfully uploaded points into `synced_points`.

Implemented API mapping:

```text
GET  /vehicles/:vehicleId/tracking-points?from&to&page=0&size=50   (history list)
GET  /vehicles/:vehicleId/tracking-points/latest                   (latest fix)
```

> **Reads are vehicle-scoped.** The current client API exposes tracking-point
> history under `/vehicles/{vehicleId}/…`; the app used to call a device-scoped
> path (`/devices/{deviceId}/tracking-points`) which no longer exists.
> `VehicleTrackingSyncClient.listVehicleTrackingPoints` /
> `getLatestVehicleTrackingPoint` and `TrackingRepository` now take a
> `vehicleId`.

> **Ingestion (the upload path) has migrated to device attestation.** The
> owner-JWT `POST /client-api/v1/vehicles/{id}/tracking-points` was removed
> when the service moved device onboarding to Android Key Attestation.
> Uploading points now goes through the **public API**
> (`POST /public-api/v1/devices/me/tracking-points`) with a per-request
> `X-Device-Assertion` JWS — both the native `VehicleTrackingService` upload
> loop and `TrackingSyncClient.sync()` (Flutter, currently unused by the
> native-only upload path but available for tests/tooling) already POST here.
> The server derives the vehicle from the device's enrollment link, so uploads
> keep working with no user session active. Device enrollment itself (`POST
> /public-api/v1/devices/enroll`) — see
> [14-device-registration.md](design/features/14-device-registration.md) —
> reads its bootstrap PKI material from `assets/attestation/` (the private key
> is provisioned per build and gitignored there; `assets/security/` holds a
> leftover copy of the same material outside the app's asset bundle and is not
> what the app loads).

Sync sends pending records in local batches, but each HTTP request follows the
vehicle service single-point request schema:

```json
{
  "latitude": 10.0,
  "longitude": 106.0,
  "eventTime": "2026-06-22T12:00:00.000Z",
  "metadata": {
    "clientPointId": "1780000000000000_10.000000_106.000000",
    "displayName": "Garage"
  }
}
```

## Background Sync (Offline-First)

Native Android `VehicleTrackingService` is the **only** component that captures
location and uploads tracking points. It is offline-first: points are written
to `pending_points` immediately regardless of connectivity, then uploaded
opportunistically — every 30 seconds, right after each new point, and on
request via `syncVehicleTrackingNow`. A failed upload simply leaves the point
in `pending_points` for the next attempt; nothing is lost.

Flutter's `VehicleTrackingNotifier` does **not** capture location or upload
points itself, and does not hold or forward any login token to native for this
purpose. It only:

- pushes the ready-to-POST tracking-points URL to native
  (`updateVehicleTrackingSyncConfig`) whenever the assigned vehicle changes
  (empty until a vehicle is assigned);
- periodically re-reads `pending_points`/`synced_points` to reflect state in
  the UI (distance, point count, pending count);
- optionally nudges native to sync sooner (`syncVehicleTrackingNow`) — e.g.
  the Settings "Sync now" button.

Native authenticates every upload itself with a device-assertion JWS
(`X-Device-Assertion`, minted from its own Android Keystore key) — see
[Device Registration (Attestation)](#device-registration-attestation) — so
sync does not depend on anyone being logged in on the head unit.

This single-writer design exists because Flutter and native previously ran
independent capture-and-sync loops against the same SQLite file, which could
double-record the same trip and race each other uploading to the server.

Sync only runs when:

- tracking is enabled;
- a vehicle is assigned to this device (Flutter only pushes a non-empty
  tracking-points URL once a vehicle is assigned — see
  [Assigning Vehicle To Device](#assigning-vehicle-to-device));
- pending points exist.

Each successful local batch is moved from `pending_points` to `synced_points`. Failed batches remain pending for retry.

## Trips, Route, Geofences and Alerts

These read/manage features consume the owner-JWT `client-api/v1` endpoints
(same bearer auth as vehicle management) and are surfaced from the vehicle
detail screen. As of 2026-09-24 each area is its own top-level feature —
`features/{trip,geofence,alert}/{domain,data,presentation/{providers,views,widgets}}`
— rather than nested under `features/vehicle`; route/reverse-geocode moved to
`features/tracking/data/{map_api_client,map_repository}.dart`. Each still
follows the same thin `*ApiClient` (HTTP + URL shaping via
`UrlUtils.vehicleUri`) + `*Repository` (DTO → domain) + Riverpod providers +
screen shape. See [15-trip.md](design/features/15-trip.md),
[16-geofence.md](design/features/16-geofence.md),
[17-alert.md](design/features/17-alert.md) for the per-feature source lists.

| Feature | Screen / route | Endpoints |
| --- | --- | --- |
| Trips | `Trips` button → `/vehicles/:id/trips`; a row → `/trips/:tripId` | `GET /vehicles/{id}/trips`, `GET /trips/{tripId}`, `GET /trips/{tripId}/tracking-points` |
| Route on map | `History` screen → **Map** toggle (also on trip detail) | `GET /vehicles/{id}/tracking-points/route` (Douglas–Peucker) |
| Address | `Latest Location` card on vehicle detail | `GET /tracking/reverse-geocode` — `503` ⇒ address omitted |
| Alerts | `Alerts` button → `/vehicles/:id/alerts` (Raised / Rules tabs) | `GET /alerts`, `POST /alerts/{id}/resolve`, `GET/POST/PATCH/DELETE /alert-rules` |
| Geofences | `Geofences` button → `/vehicles/:id/geofences` (Fences / Events tabs) | `GET/POST/PATCH/DELETE /geofences`, `GET /geofences/events` |

Notes:

- The **route map** is a tile-free `CustomPainter`
  (`features/tracking/presentation/widgets/route_map_view.dart`'s
  `RouteMapView` + `GeoUtils.projectToCanvas`) — the app ships no Flutter map
  package, only the native Google-Maps intent channel.
- `reverse-geocode` / `snap-to-road` need an operator-configured provider
  server-side; the app treats a `503` as "feature unavailable" rather than an
  error.
- Alert-rule and geofence create/edit forms build the request body
  (`toCreateJson` / `toUpdateJson`) and hand it to the repository; the list
  notifier invalidates itself on success and the view shows a SnackBar on
  failure.

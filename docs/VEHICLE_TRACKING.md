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
```

Currently used by the app:

- `GET /vehicles?page=0&size=10` to load vehicles in Settings.
- `POST /vehicles` to register a vehicle. The server generates the vehicle id.

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

The app also registers the physical Android device with the vehicle service:

```text
GET  /devices/:deviceId
POST /devices
```

The `GET` call makes registration idempotent. If the server returns `404`, the app creates the device.

Device registration request body:

```json
{
  "id": "android-abc",
  "vehicleId": "car-001",
  "name": "samsung SM-X133",
  "serialNumber": "R8YY91N3TAF",
  "model": "SM-X133",
  "metadata": {
    "model": "SM-X133",
    "manufacturer": "samsung",
    "androidVersion": "16",
    "sdkInt": 36,
    "serial": "R8YY91N3TAF",
    "androidId": "android-abc"
  }
}
```

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
POST /devices/:deviceId/tracking-points
GET  /devices/:deviceId/tracking-points?from&to&page=0&size=50
GET  /devices/:deviceId/tracking-points/latest
```

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
points itself. It only:

- pushes the ready-to-POST tracking-points URL and bearer token to native
  (`updateVehicleTrackingSyncConfig`) whenever the endpoint, vehicle, or token
  changes;
- periodically re-reads `pending_points`/`synced_points` to reflect state in
  the UI (distance, point count, pending count);
- optionally nudges native to sync sooner (`syncVehicleTrackingNow`) — e.g.
  the Settings "Sync now" button.

This single-writer design exists because Flutter and native previously ran
independent capture-and-sync loops against the same SQLite file, which could
double-record the same trip and race each other uploading to the server.

Sync only runs when:

- tracking is enabled;
- a device is assigned to this vehicle (Flutter only pushes a tracking-points
  URL once a device is assigned — see [Assigning Vehicle To Device](#assigning-vehicle-to-device));
- an access token has been pushed from Flutter to native;
- pending points exist.

Each successful local batch is moved from `pending_points` to `synced_points`. Failed batches remain pending for retry.

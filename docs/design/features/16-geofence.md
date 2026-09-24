# 16 — Ranh giới ảo (Geofence)

Updated: 2026-09-24
Status: implemented — tách thành feature riêng (trước đây nằm trong
`features/vehicle`)
Route: `Geofences` button trên vehicle detail → `/vehicles/:id/geofences`
(tab Fences / Events)
Nguồn: `lib/features/geofence/domain/{geofence,geofence_event,geo_point}.dart`,
`lib/features/geofence/data/{geofence_api_client,geofence_repository}.dart`,
`lib/features/geofence/presentation/providers/geofence_providers.dart`,
`lib/features/geofence/presentation/views/geofences_page.dart`,
`lib/features/geofence/presentation/widgets/geofence_form_dialog.dart`

Xem thêm tài liệu nghiệp vụ/API: [`docs/VEHICLE_TRACKING.md`](../../VEHICLE_TRACKING.md)
§"Trips, Route, Geofences and Alerts".

## 1. Mục tiêu & phạm vi

Định nghĩa vùng địa lý (đa giác `GeoPoint` list) cho một xe, xem lịch sử sự
kiện ra/vào (`GeofenceEvent`, `GeofenceTransition`).

## 2. Kiến trúc

```
GeofencesPage (Fences tab / Events tab)
   │ ref.watch
   ▼
geofenceListProvider(vehicleId) / geofenceEventsProvider(vehicleId)
   │
   ▼
geofenceRepositoryProvider ── getIt<GeofenceRepository>(param1: tracking.syncEndpoint)
   │
   ▼
GeofenceRepository ──► GeofenceApiClient (HTTP) ──► vehicle-service client-api
```

## 3. Ánh xạ API

| Thao tác | HTTP |
|---|---|
| Liệt kê / tạo / sửa / xoá | `GET/POST/PATCH/DELETE /geofences` |
| Sự kiện ra/vào | `GET /geofences/events` |

`GeofenceFormDialog` build request body qua `toCreateJson()`/`toUpdateJson()`;
list notifier tự `invalidateSelf()` khi thành công, view hiện SnackBar khi lỗi.

## 4. Kiểm thử

`test/geofence_alert_repository_test.dart`,
`test/vehicle_feature_models_test.dart` (model `Geofence`/`GeofenceEvent`/`GeoPoint`).

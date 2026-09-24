# 15 — Chuyến đi (Trip)

Updated: 2026-09-24
Status: implemented — tách thành feature riêng (trước đây nằm trong
`features/vehicle`)
Route: `Trips` button trên vehicle detail → `/vehicles/:id/trips`; một dòng →
`/trips/:tripId`
Nguồn: `lib/features/trip/domain/trip.dart`,
`lib/features/trip/data/{trip_api_client,trip_repository}.dart`,
`lib/features/trip/presentation/providers/trip_providers.dart`,
`lib/features/trip/presentation/views/{vehicle_trips_page,trip_detail_page}.dart`

Xem thêm tài liệu nghiệp vụ/API: [`docs/VEHICLE_TRACKING.md`](../../VEHICLE_TRACKING.md)
§"Trips, Route, Geofences and Alerts".

## 1. Mục tiêu & phạm vi

Liệt kê các chuyến đi đã đóng của một xe (đoạn hành trình server tự phân đoạn
từ tracking-point) và xem chi tiết một chuyến (route trên bản đồ tối giản +
thống kê quãng đường/thời lượng).

## 2. Kiến trúc

```
VehicleTripsPage / TripDetailPage
   │ ref.watch
   ▼
tripListProvider(vehicleId) / tripDetailProvider(tripId) / tripPointsProvider(tripId)
   │
   ▼
tripRepositoryProvider ── getIt<TripRepository>(param1: tracking.syncEndpoint)
   │
   ▼
TripRepository ──► TripApiClient (HTTP) ──► vehicle-service client-api
```

`tripRepositoryProvider` phụ thuộc `vehicleTrackingProvider` (từ
`features/tracking`) để lấy `syncEndpoint` runtime — cùng pattern với
`vehicleRepositoryProvider`/`trackingRepositoryProvider`.

## 3. Ánh xạ API

| Thao tác | HTTP |
|---|---|
| Liệt kê chuyến của xe | `GET /vehicles/{id}/trips` |
| Chi tiết chuyến | `GET /trips/{tripId}` |
| Điểm tracking của chuyến | `GET /trips/{tripId}/tracking-points` |

## 4. Route trên bản đồ

`TripDetailPage` render route bằng `RouteMapView`
(`features/tracking/presentation/widgets/route_map_view.dart`) — cùng widget
dùng cho `TrackingHistoryPage`, vì cả hai đều chỉ là "vẽ danh sách điểm
(lat,lon) lên canvas tối giản", không phải bản đồ nền thật.

## 5. Kiểm thử

`test/vehicle_trips_page_test.dart`, `test/trip_api_client_test.dart`,
`test/vehicle_feature_models_test.dart` (model `Trip`).

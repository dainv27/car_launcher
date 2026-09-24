# 17 — Cảnh báo (Alert)

Updated: 2026-09-24
Status: implemented — tách thành feature riêng (trước đây nằm trong
`features/vehicle`)
Route: `Alerts` button trên vehicle detail → `/vehicles/:id/alerts` (tab
Raised / Rules)
Nguồn: `lib/features/alert/domain/{alert_rule,vehicle_alert}.dart`,
`lib/features/alert/data/{alert_api_client,alert_repository}.dart`,
`lib/features/alert/presentation/providers/alert_providers.dart`,
`lib/features/alert/presentation/views/alerts_page.dart`,
`lib/features/alert/presentation/widgets/alert_rule_form_dialog.dart`

Xem thêm tài liệu nghiệp vụ/API: [`docs/VEHICLE_TRACKING.md`](../../VEHICLE_TRACKING.md)
§"Trips, Route, Geofences and Alerts".

## 1. Mục tiêu & phạm vi

Quản lý quy tắc cảnh báo (`AlertRule`: tốc độ, idle, ...) cho một xe, xem/giải
quyết cảnh báo đã phát sinh (`VehicleAlert`).

## 2. Kiến trúc

```
AlertsPage (Raised tab / Rules tab)
   │ ref.watch
   ▼
alertListProvider(vehicleId) / alertRuleListProvider(vehicleId)
   │
   ▼
alertRepositoryProvider ── getIt<AlertRepository>(param1: tracking.syncEndpoint)
   │
   ▼
AlertRepository ──► AlertApiClient (HTTP) ──► vehicle-service client-api
```

## 3. Ánh xạ API

| Thao tác | HTTP |
|---|---|
| Liệt kê cảnh báo đã phát sinh | `GET /alerts` |
| Giải quyết cảnh báo | `POST /alerts/{id}/resolve` |
| Quy tắc: liệt kê / tạo / sửa / xoá | `GET/POST/PATCH/DELETE /alert-rules` |

## 4. Kiểm thử

`test/geofence_alert_repository_test.dart`,
`test/vehicle_feature_models_test.dart` (model `AlertRule`/`VehicleAlert`).

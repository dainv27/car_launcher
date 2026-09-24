# 12 — Theo dõi hành trình (Vehicle Tracking)

Updated: 2026-09-24
Status: implemented — nay là feature riêng `features/tracking/` (trước đây
phần ghi nằm lạc trong `shared/data/location_service.dart`, xem §10)
Route: mục Settings "Tracking" (cat 8), `/history/:vehicleId`; badge trên
Dashboard & `TopAppBar`
Nguồn: `lib/features/tracking/presentation/tracking_notifier.dart`
(`VehicleTrackingNotifier`, `VehicleTrackingState`),
`lib/features/tracking/presentation/providers/tracking_providers.dart`
(`vehicleTrackingProvider` + các provider đọc lịch sử/route),
`lib/features/tracking/data/tracking_sync_client.dart` (`TrackingSyncClient` —
chỉ tracking-point, CRUD xe đã tách sang `VehicleApiClient`, xem
[11](11-vehicle-management.md)),
`lib/features/tracking/data/tracking_store_service.dart`,
`lib/features/tracking/domain/vehicle_track_point.dart`,
`lib/features/tracking/data/tracking_repository.dart`,
`lib/features/tracking/presentation/views/tracking_history_page.dart`,
`lib/shared/data/location_service.dart` (`LocationInfo`/`LocationNotifier`/
`currentLocationProvider` — vị trí hiển thị chung, KHÔNG liên quan tracking xe),
`lib/features/dashboard/presentation/widgets/vehicle_tracking_card.dart`,
`android/app/src/main/kotlin/com/carlauncher/car_launcher/VehicleTrackingService.kt`,
`lib/main.dart` (`_setupTrackingAuthChannel`)

Xem thêm tài liệu nghiệp vụ/API: [`docs/VEHICLE_TRACKING.md`](../../VEHICLE_TRACKING.md).

## 1. Mục tiêu & phạm vi

Ghi lại vị trí phương tiện **offline-first** và **tự động đẩy lên server** khi có
mạng. Hiển thị trạng thái (quãng đường, số điểm, số điểm chờ sync, lỗi) và lịch
sử hành trình. Chạy nền bằng foreground service Android kể cả khi UI Flutter
không hoạt động.

## 2. Nguyên tắc thiết kế cốt lõi — Single writer

**Chỉ `VehicleTrackingService` (native) mới thu vị trí và upload.** Flutter
(`VehicleTrackingNotifier`) **không** thu GPS, **không** tự POST. Lý do: trước
đây Flutter và native chạy hai vòng thu-và-sync độc lập trên cùng file SQLite →
ghi trùng chuyến đi và đua nhau upload gây double-record trên server.

Flutter chỉ:

- đẩy cấu hình xuống native (`updateVehicleTrackingSyncConfig`: `trackingPointsUrl`
  + `accessToken`) mỗi khi endpoint / vehicle / token đổi;
- định kỳ (10s) đọc lại SQLite để phản ánh state lên UI;
- "hích" native sync sớm hơn (`syncVehicleTrackingNow`) — ví dụ nút "Sync now".

## 3. Kiến trúc

```
                 ┌──────────────────────────── Flutter ────────────────────────────┐
 UI (badge,      │ vehicleTrackingProvider (StateNotifier<VehicleTrackingState>)   │
 settings card,  │   start()/stop()/clear()/assignVehicle()/loadVehicles()/        │
 history page)   │   saveVehicleProfile()/syncNow()                                │
                 │        │  đọc                     │  MethodChannel               │
                 │        ▼                          ▼                             │
                 │ VehicleTrackingStoreService   NativeBridge:                     │
                 │  (sqflite, cùng file .sqlite) - startVehicleTrackingService     │
                 │        ▲                       - updateVehicleTrackingSyncConfig │
                 └────────┼───────────────────────- syncVehicleTrackingNow─────────┘
                          │ cùng file
              vehicle_tracking.sqlite  (pending_points / synced_points)
                          │ ghi + đọc
                 ┌────────┴──────────── Android native ───────────────────────────┐
                 │ VehicleTrackingService : Service, LocationListener             │
                 │  - foreground service type=location, notification IMPORTANCE_LOW│
                 │  - LocationManager GPS→NETWORK, interval 15s / min 5m           │
                 │  - onLocationChanged → appendPoint() → pending_points → syncNow │
                 │  - scheduleWithFixedDelay 30s: syncPendingPoints()             │
                 │  - POST từng điểm; 401 → requestTokenRefresh() qua              │
                 │    MethodChannel 'com.carlauncher/tracking_auth'/'refreshToken' │
                 │  - thành công: chuyển pending→synced, trim > 10000              │
                 └───────────────────────────────────────────────────────────────┘
```

## 4. Lưu trữ (SQLite `vehicle_tracking.sqlite`)

Hai bảng, schema tạo trùng khớp giữa Dart (`VehicleTrackingStoreService`) và
Kotlin (`VehicleTrackingDatabase`), version 1:

| Bảng | Cột |
|---|---|
| `pending_points` | `id` TEXT PK, `latitude` REAL, `longitude` REAL, `display_name` TEXT, `timestamp` TEXT (ISO‑8601 UTC), `created_at` TEXT |
| `synced_points` | `id` TEXT PK, `latitude`, `longitude`, `display_name`, `timestamp`, `synced_at` TEXT |

Index theo `timestamp`. `id` điểm = `${micros}_${lat.6f}_${lon.6f}` (ổn định,
dùng làm khoá idempotent — insert `CONFLICT_IGNORE`).

Đường dẫn DB: native `getVehicleTrackingDatabasePath` (Dart hỏi native trước, có
fallback `getApplicationDocumentsDirectory()`), để cả hai phía mở cùng file.

Cài đặt + vehicle profile lưu ở `SharedPreferences` (native đọc từ
`FlutterSharedPreferences`, prefix `flutter.`):
`vehicle_tracking_enabled`, `vehicle_tracking_sync_endpoint`, `vehicle_profile`,
`vehicle_tracking_points_url`, `vehicle_tracking_access_token`.

## 5. `VehicleTrackingState` (Flutter)

Trường: `enabled`, `points: List<VehicleTrackPoint>`, `distanceMeters`,
`isLoading`, `syncEndpoint`, `vehicle: Vehicle`, `vehicles: List<Vehicle>`,
`isLoadingVehicles`, `lastVehicleError?`, `isSyncing`, `lastSyncError?`.
`Vehicle` (`features/vehicle/domain/vehicle.dart`) là model xe dùng chung với
CRUD — xem [11](11-vehicle-management.md)§6.
Getter: `lastPoint`, `pointCount`, `pendingSyncCount` (điểm chưa `synced`),
`hasRoute`, `canSync` (`vehicleId` + `deviceId` + có pending), `formattedDistance`.

`VehicleTrackPoint`: `id`, `latitude`, `longitude`, `timestamp`, `displayName`,
`syncedAt?`; `distanceTo` dùng Haversine; `toVehicleServiceJson()` là payload
POST một điểm.

## 6. Vòng đời

- **`start()`**: `enabled=true` → `_saveSettings` → `_syncNativeConfig(token)` →
  `startVehicleTrackingService` → `syncNow()`.
- **`stop()`**: `enabled=false` → lưu → `_syncNativeConfig(clearToken:true)` →
  `stopVehicleTrackingService`.
- **`_load()`** (khởi tạo): đọc snapshot store, dedupe + tính distance; nếu
  `enabled` → bật lại native + đẩy config + `syncNow`.
- **Timer 10s** `_refreshFromStore()`: đọc lại pending/synced → cập nhật state.
- **`assignVehicle` / `saveVehicleProfile` / `loadVehicles`**: gọi
  `VehicleApiClient` (features/vehicle — CRUD xe, không phải
  `TrackingSyncClient`), lưu `Vehicle` vào store, đẩy lại native config (URL
  tracking-points phụ thuộc `deviceId`).
- **`syncNow()`**: gọi `syncVehicleTrackingNow` (no-op nếu service không chạy) →
  chờ 300ms → `_refreshFromStore`.

`_trackingPointsUrl()` = `UrlUtils.vehicleUri(endpoint,
'devices/$deviceId/tracking-points')` — rỗng nếu chưa gán device (native không
sync khi URL rỗng). `UrlUtils` là nguồn luật URL duy nhất; native không cần biết.

## 7. Native `VehicleTrackingService`

- `onStartCommand`: `ACTION_STOP` → dừng; còn lại → `startTracking()`.
- `startTracking()`: kiểm tra quyền `ACCESS_FINE/COARSE_LOCATION` +
  `FOREGROUND_SERVICE_LOCATION`; `startForeground` với notification; chọn
  provider GPS→NETWORK; `requestLocationUpdates(15s, 5m)`; lấy last known;
  `scheduleBackgroundSync()` (delay 5s, chu kỳ 30s); `syncNow()`.
- `appendPoint()`: bỏ qua nếu `flutter.vehicle_tracking_enabled` false; insert
  `pending_points` (`CONFLICT_IGNORE`); `syncNow()`.
- `syncPendingPoints()`: cần `enabled` + có `url` + có `token`; đọc batch 100
  theo `timestamp ASC`; `postBatchWithRefresh` POST từng điểm; `401` →
  `requestTokenRefresh(oldToken)` (block tối đa 30s chờ Flutter) → persist token
  mới → thử lại điểm; thành công → `markBatchSynced` (chuyển pending→synced,
  `trimSyncedHistory` giữ ≤ 10000). Lỗi → điểm ở lại pending cho lần sau.
- `triggerSyncNow()` (static): điểm vào duy nhất để "hích" sync từ Flutter.

Payload POST một điểm:

```json
{
  "latitude": 10.0,
  "longitude": 106.0,
  "eventTime": "2026-06-22T12:00:00.000Z",
  "metadata": { "clientPointId": "<id>", "displayName": "Garage" }
}
```

## 8. State management (providers)

| Provider | Vai trò |
|---|---|
| `vehicleTrackingProvider` | `StateNotifier<VehicleTrackingState>` — nguồn sự thật UI |
| `currentLocationProvider` | `StateNotifier<AsyncValue<LocationInfo?>>` — vị trí hiển thị (tên địa điểm ở `TopAppBar`), poll `getCurrentLocationInfo` mỗi 1 phút; **không** dùng để tracking |
| `trackingRepositoryProvider` | `Provider<TrackingRepository>` — get_it `factoryParam(syncEndpoint)` |
| `latestTrackingPointProvider` / `trackingHistoryProvider` | `FutureProvider.family` — `GET .../tracking-points/latest`, `GET .../tracking-points?from&to&page&size` |

`TrackingRepository` cung cấp path "history feature" (đọc từ server, qua
`TrackingSyncClient`) — chủ yếu native lo sync, repo này phục vụ màn hình lịch
sử.

## 10.1 Đã tách khỏi `shared/` (2026-09-24)

Toàn bộ khối trên từng nằm trong `lib/shared/data/location_service.dart` +
`lib/shared/data/vehicle_tracking_store_service.dart` — bị dán nhãn "shared"
nhưng thực chất là lõi nghiệp vụ Tracking, không phải hạ tầng dùng chung. Đã
chuyển sang `lib/features/tracking/`. Phần thật sự dùng chung (`LocationInfo`,
`LocationNotifier`, `currentLocationProvider` — vị trí hiển thị TopAppBar/thời
tiết) ở lại `shared/data/location_service.dart`.

`VehicleTrackingSyncClient` (từng làm cả CRUD xe lẫn tracking-point) tách làm
2: `VehicleApiClient` (features/vehicle — CRUD xe) và `TrackingSyncClient`
(features/tracking — chỉ tracking-point). `VehicleTrackingNotifier` giờ chỉ
phụ thuộc `VehicleApiClient` (cho `assignVehicle`/`saveVehicleProfile`/
`loadVehicles`) — không hề tham chiếu `TrackingSyncClient`, nên về mặt kiểu
dữ liệu không thể vô tình gọi HTTP tracking-point từ Flutter (bất biến
"single writer" ở §2 giờ được enforce ở compile-time, không chỉ ở quy ước).

## 9. UI

- `TopAppBar._TrackingStatusDot`: chấm pulse theo `_TrackingDotStyle.from(state)`
  — paused (xám tĩnh) / active (xanh lá) / syncing (cyan nhanh) / pending (vàng) /
  error (đỏ).
- `VehicleTrackingBadge` (dashboard) và `VehicleTrackingSettingsCard` (Settings):
  chỉ số + nút Start/Stop, Load/Manage vehicle, Sync now, Clear route, chọn xe
  bằng `ChoiceChip`.
- `TrackingHistoryPage` (`/history/:vehicleId`): danh sách điểm theo khoảng thời
  gian.

## 10. Quyết định thiết kế & đánh đổi

- **Offline-first, single-writer native** — không mất điểm khi mất mạng, không
  double-upload; đổi lại Flutter chỉ "đọc chậm" state (trễ tối đa ~10s giữa các
  lần refresh).
- **Native chỉ giữ access token, refresh nhờ Flutter** qua channel riêng — không
  nhân bản refresh token/secret xuống service nền; đổi lại native phải block
  thread nền tối đa 30s chờ Flutter khi 401.
- **URL tracking-points dựng ở Flutter** (`UrlUtils`) rồi đẩy xuống — một nguồn
  luật URL; native chỉ cần string.
- **POST từng điểm** (không bulk endpoint) — khớp schema vehicle-service; batch
  chỉ là gộp đọc local, mỗi điểm vẫn một request.
- **`id` điểm bằng thời gian+toạ độ** — idempotent tự nhiên, nhưng hai điểm cực
  gần nhau cùng micro giây có thể bị coi là một.
- **Giới hạn 10000 điểm synced** — chặn phình DB; lịch sử cũ hơn bị cắt local
  (server vẫn giữ).

## 11. Edge case

- Chưa gán device → `trackingPointsUrl` rỗng → native không sync (điểm vẫn tích
  luỹ local).
- Mất quyền location khi service chạy → `startTracking` `stopSelf()`.
- Không có provider location bật → service chạy nhưng không có điểm mới.
- `syncNow` khi service chưa chạy → no-op; chu kỳ 30s sẽ chạy khi bật lại.
- Test / non-Android → mọi `NativeBridge.call` liên quan bị nuốt lỗi (chỉ log
  debug); `VehicleTrackingStoreService` fallback documents dir.

## 12. Kiểm thử

`test/vehicle_tracking_contract_test.dart`, `test/vehicle_tracking_notifier_test.dart`,
`test/vehicle_tracking_store_test.dart`, `test/tracking_sync_client_test.dart`
(tracking-point HTTP), `test/vehicle_api_client_test.dart` (CRUD xe),
`test/tracking_repository_test.dart`, `test/tracking_point_test.dart`,
`test/tracking_history_page_test.dart`, `test/location_bridge_contract_test.dart`.

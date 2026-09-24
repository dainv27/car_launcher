# 14 — Đăng ký thiết bị (Device registration)

Updated: 2026-09-24
Status: implemented — nay là feature riêng `features/device/` (gộp cả device
gắn-trên-xe, enrollment/attestation, và thu thập thông tin thiết bị; trước đây
rải ở `core/services`, `shared/data`, và `features/vehicle`)
Nguồn: `lib/features/device/data/device_info_service.dart`,
`lib/features/device/data/device_service.dart`,
`lib/features/device/data/device_enrollment_client.dart`,
`lib/features/device/domain/device.dart`,
`lib/features/device/presentation/providers/device_providers.dart`,
`lib/core/auth/device_identity_service.dart`,
`lib/core/auth/device_assertion_client.dart` (attestation/identity — hạ tầng
auth dùng chung, ở lại `core/auth`),
`lib/main.dart` (`_StartupPermissionGate._ensureDeviceRegistered`)

## 1. Mục tiêu & phạm vi

Đăng ký thiết bị Android vật lý này với vehicle-service (một lần mỗi lần cài
đặt), để các payload tracking gắn được với `deviceId`. Chạy best-effort lúc khởi
động, không chặn app.

## 2. Thu thập thông tin thiết bị — `DeviceInfoService`

Singleton. `fetchDeviceInfo()` dùng `device_info_plus` + `android_id`
(không native bridge, không cần quyền runtime):

| Trường `DeviceInfo` | Nguồn |
|---|---|
| `id` | `android.id` (Build.ID) — dùng làm `deviceId` |
| `androidId` | package `android_id` (device_info_plus v13 đã bỏ) |
| `serial` | `android.fingerprint` (Build.FINGERPRINT — ổn định, không cần quyền) |
| `imei` | luôn rỗng (Android 29+ chặn app thường) |
| `manufacturer`, `model`, `sdkInt`, `androidVersion`, `hardware`, `board`, `bootloader`, `device`, `display`, `host`, `product`, `type`, `isPhysicalDevice` | `device_info_plus` |

`toMap()` → dùng làm `metadata` khi đăng ký.

## 3. Đăng ký — `DeviceService`

`DeviceService({httpClient})` — factory (DI). `ensureDeviceRegistered()`:

1. Lấy `DeviceInfo`; bỏ qua nếu null hoặc `id` rỗng (chỉ log cảnh báo).
2. Dựng `Device(id, name = "<manufacturer> <model>", serialNumber = fingerprint,
   imei, model, firmwareVersion = androidVersion, metadata = deviceInfo.toMap())`.
3. `createDevice(endpoint: '', device)` — idempotent:
   - nếu `device.id` không rỗng → `GET /devices/:id`; 2xx → trả device đã có;
   - `POST /devices` với `toCreateJson()`;
   - `409` → coi như đã tồn tại, `GET` lại;
   - body rỗng → trả `device` truyền vào.

`endpoint: ''` → `UrlUtils.vehicleUri` dùng base mặc định
(`ApiConfig.vehicleServiceClientApiBaseUrl`).

## 4. Kích hoạt

`_StartupPermissionGate._ensureDeviceRegistered()` (main.dart) gọi
`getIt<DeviceService>().ensureDeviceRegistered()` trong `addPostFrameCallback`
lúc khởi động. Lỗi (mạng tạm thời…) chỉ log — thử lại ở lần khởi động sau.

> Ghi chú: `docs/VEHICLE_TRACKING.md` mô tả có cờ persist "đăng ký một lần mỗi
> install". Bản hiện tại dựa vào tính idempotent phía server (GET/POST + 409)
> thay vì cờ local; mỗi lần khởi động vẫn gọi nhưng không tạo trùng.

## 5. Quan hệ với các tính năng khác

- `deviceId` chính là `DeviceInfo.id`, được đưa vào `Vehicle.deviceId` khi
  gán xe (xem [11](11-vehicle-management.md)), từ đó tạo URL
  `devices/:deviceId/tracking-points` cho [12](12-vehicle-tracking.md).
- `LauncherService.getDeviceInfo()` cũng trả `DeviceInfoService.fetchDeviceInfo().toMap()`
  cho các nơi hiển thị thông tin máy.

## 6. Quyết định thiết kế & đánh đổi

- **Thu thập hoàn toàn phía Flutter** (bỏ MethodChannel `getDeviceInfo` cũ) —
  không cần code native, không cần quyền; đổi lại mất `serialNumber` thật và
  `IMEI` (thay bằng `fingerprint`).
- **Idempotent bằng GET-rồi-POST + 409** thay vì cờ local — an toàn khi cài lại,
  đổi lại thêm một round-trip mạng mỗi lần khởi động.
- **Best-effort, không chặn khởi động** — app luôn mở được; nếu đăng ký hỏng thì
  tracking chưa gán được device cho tới lần khởi động thành công.

## 7. Edge case

- `Build.ID` rỗng/không suy ra được → bỏ đăng ký, log cảnh báo.
- Non-Android/test → `fetchDeviceInfo` ném → `getInfo()` trả null → bỏ qua.
- Server offline lúc khởi động → thử lại lần sau.

## 8. Kiểm thử

`test/real_data_contract_test.dart`, `test/device_service_test.dart`
(`ensureDeviceRegistered`/`createDevice`/`listDevices`),
`test/device_enrollment_client_test.dart` (attestation handshake).

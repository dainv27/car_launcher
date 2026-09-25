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

## 3. Đăng ký — `DeviceService.ensureDeviceRegistered()`

`DeviceService({httpClient})` (factory, DI). **`ensureDeviceRegistered()` hiện
chạy handshake attestation `SELF_SIGNED_PKI`, không còn gọi `createDevice`
qua client-api** (xem §3.2):

1. Lấy `DeviceInfo`; `null` → log cảnh báo, bỏ qua (return `null`).
2. `_enrollmentClient.enroll(name, serialNumber=fingerprint, imei, model,
   firmwareVersion=androidVersion, metadata=deviceInfo.toMap())` →
   `DeviceEnrollmentClient` (`features/device/data/device_enrollment_client.dart`):
   - `POST {publicApiBaseUrl}/devices/enroll/challenge` → nhận `nonce` một lần.
   - Lấy identity per-install từ `DeviceIdentityService` (native Keystore, xem
     §3.1) và nạp cặp key bootstrap của app từ asset
     `assets/attestation/app-bootstrap.key` + `.pem`.
   - Ký `proof` (nonce + bootstrap private key) qua
     `DeviceIdentityService.signEnrollmentProof`.
   - `POST {publicApiBaseUrl}/devices/enroll` với `nonce`,
     `attestationCertChain: [bootstrapCertPem]`, `devicePublicKey`, `proof`,
     `name`/`serialNumber`/`imei`/`model`/`firmwareVersion`/`metadata` → server
     tạo device **chưa gán chủ** (`claimed=false`); enroll lại cùng key thì
     idempotent (server làm mới field hardware, giữ nguyên liên kết
     owner/vehicle nếu có).
3. Best-effort: `_enrollmentClient.getSelf()` — `GET {publicApiBaseUrl}/devices/me`
   qua `DeviceAssertionClient` (header `X-Device-Assertion`) để xác nhận key
   vừa đăng ký xác thực được; lỗi ở bước này chỉ log, không huỷ enrollment.

`publicApiBaseUrl` = `ApiConfig.vehicleServicePublicApiBaseUrl` — client dùng
`http.Client()` trần (không qua `AuthInterceptorClient`) vì attestation không
cần phiên Keycloak.

## 3.1 Định danh thiết bị — `DeviceIdentityService` / `DeviceAssertionClient`

- `DeviceIdentityService` (`core/auth/device_identity_service.dart`) bọc
  MethodChannel native `com.carlauncher/device_auth`: native sinh/giữ một key
  Android Keystore EC P-256 mỗi lần cài app; `deviceId` phía server =
  `base64url(SHA-256(SubjectPublicKeyInfo))`. Assertion (`X-Device-Assertion`,
  JWS) được mint native, cache tới gần hết hạn (TTL 4 phút, làm mới trước 60s).
- `DeviceAssertionClient` (`core/auth/device_assertion_client.dart`) — bọc
  `http.Client`, tự chèn header `X-Device-Assertion` cho mỗi request; gặp
  `401` thì bỏ assertion cache để lần gọi lại mint assertion mới (lệch giờ,
  key vừa xoay).

## 3.2 `createDevice`/`getDevice`/`listDevices` (client-api) — vẫn còn nhưng không còn là đường đăng ký

`DeviceService` vẫn có `createDevice()` (GET-rồi-POST-409, dùng
`client-api/v1`, bearer Keycloak) và `getDevice()`/`listDevices()`. Theo mã
nguồn hiện tại, **chỉ `listDevices()` còn được gọi thật** (bởi
`devicesForVehicleProvider`, xem [11](11-vehicle-management.md)§3) để liệt kê
thiết bị đã gán cho một xe. `createDevice()` không còn được `ensureDeviceRegistered()`
hay bất kỳ nơi nào khác trong app gọi — chỉ xuất hiện trong
`test/device_service_test.dart`; có thể là code còn sót lại từ trước khi
chuyển sang attestation, chưa dọn.

## 4. Kích hoạt

`_StartupPermissionGate._ensureDeviceRegistered()` (main.dart) gọi
`getIt<DeviceService>().ensureDeviceRegistered()` trong `addPostFrameCallback`
lúc khởi động. Lỗi (mạng tạm thời, thiếu key bootstrap khi build dev chưa được
cấp `assets/attestation/app-bootstrap.key`…) chỉ log — thử lại ở lần khởi động
sau; enrollment idempotent nên gọi lại mỗi lần khởi động là an toàn.

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
- Thiếu asset `assets/attestation/app-bootstrap.key` (chưa cấp cho build,
  gitignore theo `.gitignore`) → `enroll()` ném lỗi load asset → enrollment
  thất bại, chỉ log.
- **Chưa xác nhận**: từ khi `ensureDeviceRegistered()` chuyển sang attestation,
  không còn nơi nào trong app gọi `POST /devices` (client-api, định danh theo
  `Build.ID`) — kể cả lúc gán xe (`assignVehicle`, xem
  [12](12-vehicle-tracking.md)§6). Nếu bản ghi `/devices/:deviceId` đó phải tồn
  tại trước để native POST `devices/:deviceId/tracking-points` thành công trên
  máy cài mới, đây có thể là một lỗ hổng chức năng cần vehicle-service xác
  nhận (server tự tạo device khi nhận điểm đầu tiên, hay bản ghi bắt buộc phải
  có trước).

## 8. Kiểm thử

`test/real_data_contract_test.dart`, `test/device_service_test.dart`
(`ensureDeviceRegistered`/`createDevice`/`listDevices`),
`test/device_enrollment_client_test.dart` (attestation handshake).

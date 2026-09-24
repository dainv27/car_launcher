# 11 — Quản lý phương tiện (Vehicle)

Updated: 2026-08-29
Status: implemented
Route: `/vehicles`, `/vehicles/:id` (protected); mục Settings "Vehicle" (cat 7)
Nguồn: `lib/features/vehicle/domain/vehicle.dart`,
`lib/features/vehicle/domain/device.dart`,
`lib/features/vehicle/data/vehicle_repository.dart`,
`lib/features/vehicle/presentation/providers/vehicle_providers.dart`,
`lib/features/vehicle/presentation/providers/device_providers.dart`,
`lib/features/vehicle/presentation/views/vehicles_page.dart`,
`lib/features/vehicle/presentation/views/vehicle_detail_page.dart`,
`lib/features/vehicle/presentation/widgets/vehicle_form_dialog.dart`,
`lib/shared/data/location_service.dart` (`VehicleTrackingSyncClient`, `VehicleProfile`)

## 1. Mục tiêu & phạm vi

CRUD phương tiện trên vehicle-service: liệt kê, xem chi tiết (kèm danh sách
thiết bị gắn), tạo, sửa. Chọn một phương tiện để gán cho thiết bị hiện tại phục
vụ tracking. Yêu cầu đăng nhập.

## 2. Mô hình dữ liệu

- `Vehicle` (domain) — `id`, `plateNumber`, `name`, `brand`, `model`, `deviceId`,
  `color`, `vin`, `metadata` (`year` là `metadata['year']`). `fromJson` chấp nhận
  cả `id`/`vehicleId`, `brand`/`make`. `toJson` (POST) / `toPatchJson` (PATCH).
  `toProfile()` / `fromProfile()` chuyển đổi với `VehicleProfile`.
- `Device` (domain) — `id`, `vehicleId`, `name`, `serialNumber`, `imei`,
  `phoneNumber`, `model`, `firmwareVersion`, `metadata`.
- `VehicleProfile` (`location_service.dart`) — model "gọn" mà subsystem tracking
  + native dùng: `vehicleId`, `plateNumber`, `name`, `make`, `model`, `deviceId`,
  `year`. `toRegistrationJson()` (gửi `brand` + `metadata.year`).

## 3. Kiến trúc

```
VehiclesPage / VehicleDetailPage
   │ ref.watch
   ▼
vehicleListProvider (AsyncNotifier<List<Vehicle>>)      vehicleProvider.family (AsyncNotifier<Vehicle, id>)
   │                                                        │
   ▼                                                        ▼
vehicleRepositoryProvider ── getIt<VehicleRepository>(param1: tracking.syncEndpoint)
   │
   ▼
VehicleRepository  ──►  VehicleTrackingSyncClient (HTTP, AuthInterceptorClient)  ──►  vehicle-service
```

`vehicleRepositoryProvider` `ref.watch(vehicleTrackingProvider)` để lấy
`syncEndpoint` runtime → get_it `factoryParam` dựng repo với đúng base URL.

`devicesForVehicleProvider` (`FutureProvider.family<List<Device>, vehicleId>`) gọi
`getIt<DeviceService>().listDevices(endpoint, vehicleId)`.

## 4. Ánh xạ API (`VehicleRepository` + `VehicleTrackingSyncClient`)

| Thao tác | HTTP |
|---|---|
| Liệt kê | `GET /vehicles?page=0&size=10` |
| Chi tiết | `GET /vehicles/:id` |
| Tạo | `POST /vehicles` (body `toRegistrationJson`; server sinh id) |
| Sửa | `PATCH /vehicles/:id` |
| Thiết bị của xe | `GET /devices?vehicleId=:id` |

Base URL chuẩn hoá bởi `UrlUtils.vehicleUri` (thêm `/client-api/v1` nếu thiếu).
Response chấp nhận nhiều hình dạng bọc: `{vehicle}`, `{vehicles}`, `{content}`,
`{data}`, `{items}`, hoặc mảng trần.

## 5. State management

| Provider | Kiểu | Ghi chú |
|---|---|---|
| `vehicleListProvider` | `AsyncNotifierProvider` | `build` nuốt lỗi → `[]`; `refresh()`, `createVehicle()` (→ `invalidateSelf`) |
| `vehicleProvider` | `AsyncNotifierProvider.family<_, Vehicle, String>` | `updateVehicle()` set `AsyncData` + `invalidate(vehicleListProvider)` |
| `devicesForVehicleProvider` | `FutureProvider.family` | rỗng nếu `vehicleId` rỗng |

Gán xe cho thiết bị + đăng ký nhanh từ dashboard/Settings thực ra chạy qua
`VehicleTrackingNotifier` (`assignVehicle`, `saveVehicleProfile`, `loadVehicles`)
— xem [12](12-vehicle-tracking.md).

## 6. Quyết định thiết kế & đánh đổi

- **Hai model song song `Vehicle` và `VehicleProfile`**: `Vehicle` là entity đầy
  đủ cho UI quản lý; `VehicleProfile` là dạng gọn cho tracking + native (chỉ
  trường cần để sync). Chuyển đổi hai chiều — có chi phí bảo trì mapping.
- **`syncEndpoint` runtime qua `factoryParam`**: đổi endpoint (ví dụ từ Settings)
  tự dựng lại repo; đổi lại provider phụ thuộc `vehicleTrackingProvider`.
- **`vehicleListProvider.build` nuốt lỗi về `[]`**: UI không vỡ khi offline,
  nhưng khó phân biệt "không có xe" với "lỗi mạng" (nên bổ sung trạng thái lỗi
  hiển thị).
- **Không có endpoint xoá xe** — chủ ý (client API chỉ cho tạo/sửa).

## 7. Edge case

- Chưa đăng nhập → route redirect `/login`; mục Settings hiện `LoginRequiredWidget`.
- `PATCH` trả body rỗng → coi như thành công, giữ `vehicle` truyền vào.
- `POST /devices` trả `409` → coi như đã tồn tại, `GET` lại (idempotent).

## 8. Kiểm thử

`test/vehicle_model_test.dart`, `test/vehicle_repository_test.dart`,
`test/vehicles_page_test.dart`, `test/vehicle_tracking_sync_client_test.dart`.

# Tài liệu thiết kế theo tính năng

Updated: 2026-08-29

Thư mục này chứa tài liệu thiết kế (design doc) cho từng tính năng của Car
Launcher. Mỗi file mô tả: mục tiêu, luồng người dùng, kiến trúc, luồng dữ liệu,
quản lý trạng thái, tích hợp native/API, persistence, các quyết định thiết kế và
đánh đổi, edge case, và kiểm thử.

Các mockup giao diện tĩnh (HTML) nằm ở thư mục cha [`docs/design/`](../).

## Danh sách tài liệu

| # | Tính năng | File |
|---|---|---|
| 01 | App shell, bootstrap, native bridge, quyền | [01-app-shell-and-bootstrap.md](01-app-shell-and-bootstrap.md) |
| 02 | Điều hướng & routing (GoRouter) | [02-navigation-and-routing.md](02-navigation-and-routing.md) |
| 03 | Dashboard (màn hình chính) | [03-dashboard.md](03-dashboard.md) |
| 04 | App Drawer (danh sách ứng dụng) | [04-app-drawer.md](04-app-drawer.md) |
| 05 | Media Center | [05-media-center.md](05-media-center.md) |
| 06 | Navigation / bản đồ | [06-navigation-maps.md](06-navigation-maps.md) |
| 07 | Multi-window & nhúng ứng dụng Android | [07-multi-window-embedding.md](07-multi-window-embedding.md) |
| 08 | Settings | [08-settings.md](08-settings.md) |
| 09 | Tài khoản & xác thực (Keycloak OIDC) | [09-account-authentication.md](09-account-authentication.md) |
| 10 | Theme & giao diện (sáng/tối tự động) | [10-theme-and-appearance.md](10-theme-and-appearance.md) |
| 11 | Quản lý phương tiện (Vehicle) | [11-vehicle-management.md](11-vehicle-management.md) |
| 12 | Theo dõi hành trình (Vehicle Tracking) | [12-vehicle-tracking.md](12-vehicle-tracking.md) |
| 13 | Thời tiết & đồng hồ | [13-weather-and-clock.md](13-weather-and-clock.md) |
| 14 | Đăng ký thiết bị (Device registration) | [14-device-registration.md](14-device-registration.md) |
| 15 | Chuyến đi (Trip) | [15-trip.md](15-trip.md) |
| 16 | Ranh giới ảo (Geofence) | [16-geofence.md](16-geofence.md) |
| 17 | Cảnh báo (Alert) | [17-alert.md](17-alert.md) |

## Kiến trúc chung (áp dụng cho mọi tính năng)

### Lean Clean Architecture

Theo `ai/rules/architecture_rules.md`, mã nguồn chia 3 lớp, tổ chức theo tính năng:

```
lib/
├── core/          # tiện ích hệ thống: router, DI, native bridge, theme, auth, config, logging
├── shared/        # dùng chung: providers/, widgets/, data/ (service dùng nhiều feature)
└── features/<feature>/
    ├── data/          # data source, model/DTO, service HTTP, mapping
    ├── domain/        # entity nghiệp vụ (một số feature không cần)
    └── presentation/
        ├── providers/ # state của riêng feature (hậu tố *_provider.dart / *_providers.dart)
        ├── views/     # màn hình (một số feature đặt trực tiếp trong presentation/)
        └── widgets/   # widget con của feature
```

### Quản lý trạng thái — Riverpod

- Dùng `flutter_riverpod` (không dùng `provider`/`ChangeNotifier` như ví dụ trong
  rule; rule viết trước khi codebase chọn Riverpod).
- Feature provider: `StateNotifierProvider` / `AsyncNotifierProvider` đặt trong
  `presentation/providers/` của feature đó, không gọi chéo UI feature khác.
- Shared provider (toàn cục): đặt trong `lib/shared/providers/` hoặc `lib/core/`
  (ví dụ `accountSessionProvider`, `effectiveThemeModeProvider`,
  `vehicleTrackingProvider`, `sharedPreferencesProvider`, `httpClientProvider`).
- Một số provider được `overrideWith` trong `main.dart` để tiêm
  `SharedPreferences` (ví dụ `layoutProvider`, `widgetListProvider`,
  `carPlaySettingsProvider`).

### Dependency Injection — get_it

`lib/core/di/injection_container.dart` (`setupServiceLocator()`) đăng ký các
singleton/factory. Riverpod provider chỉ là lớp mỏng đọc lại từ `getIt<T>()`, để
service dễ test và tách khỏi lifecycle của widget tree.

### Lớp mạng

`http.Client` được bọc bởi `AuthInterceptorClient`
(`core/di/injection_container.dart`):

- tự chèn `Authorization: Bearer <token>` cho host thuộc whitelist (API
  gateway);
- khi gặp `401`: gọi `KeycloakAuthRepository.forceRefreshToken()` rồi thử lại
  request một lần với token mới.

Base URL và endpoint xác thực đọc theo thứ tự: `.env` / `.env.local` /
`.env.<env>` → `--dart-define` → hằng số mặc định (xem `core/config/env_loader.dart`,
`core/api/api_config.dart`, `core/auth/keycloak_config.dart`).

### Native bridge

`core/native/native_bridge.dart` bọc `MethodChannel('com.carlauncher/native')`
và `EventChannel('com.carlauncher/events')`. Ngoài ra còn có các channel riêng:
`.../media_events`, `.../nav_events`, `.../navigation`, `car_launcher/google_maps`,
`com.carlauncher/tracking_auth`, `virtual_display_app`, `embedded_app_pane`.

### Logging

`AppLogger` (`core/logging/`) ghi ra file + console, dùng qua `getIt<AppLogger>()`
hoặc `AppLogger.instance`. Xem log trong app tại `/settings/logs`.

### Quy ước kiểm thử

Test đặt ở `test/`, đặt tên `*_contract_test.dart` cho test hợp đồng
(behaviour/API), `*_test.dart` cho unit/widget. Chạy: `flutter test`,
`flutter analyze`.

# 01 — App shell, bootstrap & native bridge

Updated: 2026-08-29
Status: implemented
Nguồn: `lib/main.dart`, `lib/core/di/injection_container.dart`,
`lib/core/native/native_bridge.dart`,
`android/app/src/main/kotlin/com/carlauncher/car_launcher/MainActivity.kt`,
`android/app/src/main/AndroidManifest.xml`

## 1. Mục tiêu & phạm vi

Khởi tạo ứng dụng theo đúng thứ tự phụ thuộc, dựng khung `MaterialApp.router`,
lớp nền (wallpaper) toàn cục, cổng xin quyền lúc khởi động, đăng ký thiết bị, và
kênh làm mới token cho service nền. Tài liệu này mô tả phần "vỏ" chung; các tính
năng cụ thể nằm ở các file khác.

## 2. Trình tự khởi động (`main()`)

1. Gắn `FlutterError.onError` + `PlatformDispatcher.instance.onError` → đẩy vào
   `AppLogger`.
2. `WidgetsFlutterBinding.ensureInitialized()`.
3. `configureKeycloakOidcPlatform()` — chọn implementation OIDC theo nền tảng.
4. `EnvLoader.instance.load(environment: APP_ENV)` — **phải xong trước** DI vì
   `ApiConfig` / `KeycloakConfig` đọc biến môi trường lúc dựng.
5. `AppLogger.instance.init()` — mở file log.
6. `setupServiceLocator()` — đăng ký singleton/factory vào `get_it`.
7. `_setupTrackingAuthChannel()` — mở `MethodChannel('com.carlauncher/tracking_auth')`.
8. `runApp(ProviderScope(overrides: [...], child: CarLauncherApp()))`.

`overrides` tiêm `SharedPreferences` (từ `getIt`) vào `layoutProvider`,
`widgetListProvider`, `carPlaySettingsProvider` — các provider này `throw
UnimplementedError` nếu không được override.

## 3. `CarLauncherApp`

`ConsumerWidget` dựng `MaterialApp.router`:

| Thuộc tính | Nguồn |
|---|---|
| `routerConfig` | `appRouterProvider` (xem [02](02-navigation-and-routing.md)) |
| `theme` | `AppTheme.launcherLightTheme(appearance)` |
| `darkTheme` | `AppTheme.launcherTheme(appearance)` |
| `themeMode` | `effectiveThemeModeProvider` (xem [10](10-theme-and-appearance.md)) |
| `builder` | bọc mọi trang trong `Stack`: `LauncherBackground` + `_StartupPermissionGate` |

`appearance` = `effectiveLauncherAppearanceProvider`.

## 4. `_StartupPermissionGate`

`ConsumerStatefulWidget` bọc toàn bộ cây con. Trong `didChangeDependencies`
(chạy đúng một lần nhờ cờ `_requested`):

- Đăng ký handler cho lời gọi native → Flutter: khi native gửi
  `startupRuntimePermissionsResult` (hộp thoại quyền OS đã đóng) thì gọi lại
  `_ensurePermissions()`.
- `addPostFrameCallback`: gọi `_ensurePermissions()` và `_ensureDeviceRegistered()`.

### `_ensurePermissions()`

Gọi native `ensureStartupPermissions` → nhận `Map` trạng thái. Chính sách:

1. Nếu còn `requestedRuntimePermissions` (hộp thoại quyền OS đang mở) → dừng, chờ
   callback, tránh chồng nhiều prompt.
2. Nếu `accessibilityInputGranted != true` → mở màn hình Accessibility settings.
3. Ngược lại, nếu `notificationListenerGranted != true` → mở Notification access
   settings.

Thứ tự cố ý: Accessibility (fallback nhập liệu cho app nhúng) trước, Notification
access (MediaSession) sau.

### `_ensureDeviceRegistered()`

Gọi `getIt<DeviceService>().ensureDeviceRegistered()` — best-effort, nuốt lỗi
(chỉ log). Chi tiết: [14](14-device-registration.md).

## 5. `_setupTrackingAuthChannel()`

Service nền native chỉ giữ access token, không giữ refresh token. Khi sync gặp
`401`, native gọi `refreshToken` trên channel `com.carlauncher/tracking_auth`.
Handler Flutter:

1. `KeycloakAuthRepository.forceRefreshToken()`; nếu thất bại → ném
   `PlatformException('REFRESH_FAILED')`.
2. Lấy `accessToken()` mới; rỗng → `PlatformException('NO_TOKEN')`.
3. Trả token mới (cảnh báo nếu trùng token cũ).

## 6. DI — `setupServiceLocator()`

Đăng ký (tóm tắt):

| Loại | Kiểu | Lý do |
|---|---|---|
| singleton | `SharedPreferences`, `AppLogger`, `DeviceInfoService`, `LauncherService` | hạ tầng, một instance |
| lazySingleton | `KeycloakAuthRepository` | 1 phiên auth; lazy vì chạm secure storage khi dựng |
| lazySingleton | `http.Client` = `AuthInterceptorClient` | phụ thuộc auth repo |
| lazySingleton | `WeatherService`, `VehicleTrackingStoreService` | stateless / phải là 1 kết nối SQLite |
| factory | `DeviceService`, `VehicleTrackingSyncClient` | nhẹ, không state |
| factoryParam | `VehicleRepository`, `TrackingRepository` (`syncEndpoint`) | endpoint phụ thuộc state runtime |

## 7. Lớp native (Android)

`MainActivity : FlutterActivity` xử lý method channel `com.carlauncher/native`.
Các method chính (`MainActivity.kt`): `getConnectivityStatus`, `getBatteryLevel`,
`hasNotificationListenerAccess`, `openNotificationAccessSettings`,
`openAccessibilitySettings`, `ensureStartupPermissions`, `launchVoiceAssistant`,
`mediaCommand`, `getCurrentLocationInfo`, `requestLocationPermission`,
`startVehicleTrackingService` / `stopVehicleTrackingService`,
`getVehicleTrackingDatabasePath`, `syncVehicleTrackingNow`,
`updateVehicleTrackingSyncConfig`, `launchApp`, `launchSplitScreen`,
`getInstalledApps`, `getAppIcon`, `sendKeyEvent`, `isEmbeddingSupported`,
`getEmbeddingInfo`, `launchMapsWithYoutubeOnTop`, `setScreenBrightness` /
`getScreenBrightness`, `isAutoBrightnessEnabled` / `setAutoBrightness`,
`getSystemReadiness`, và channel điều hướng `com.carlauncher/navigation`
(`stopNavigation`, `switchProvider`).

Thành phần native khác: `BootReceiver` + `StartupCoordinator` + `StartupJobService`
(khởi động lại MainActivity khi máy sẵn sàng, có retry), `AppPackageChangedReceiver`
(bắn event `app_package_changed`), `NotificationListener` (MediaSession),
`VehicleTrackingService` (foreground service, xem [12](12-vehicle-tracking.md)),
`embedding/*` (xem [07](07-multi-window-embedding.md)).

Manifest khai báo `MAIN/LAUNCHER` + intent-filter OAuth callback
(`carlauncher://oauth/callback`), quyền `INTERNET`, `ACCESS_FINE_LOCATION` +
`ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE(_LOCATION)`,
`RECEIVE_BOOT_COMPLETED`, `QUERY_ALL_PACKAGES`, và các quyền đặc quyền cho nhúng
app (`MANAGE_ACTIVITY_TASKS`, `INJECT_EVENTS`, `ADD_TRUSTED_DISPLAY`, …) chỉ hoạt
động khi APK được ký bằng khóa nền tảng.

## 8. Quyết định thiết kế & đánh đổi

- **Env load trước DI**: cấu hình runtime không cần build lại theo môi trường,
  nhưng `main()` phải `await` I/O trước `runApp` (tăng nhẹ thời gian khởi động).
- **get_it + Riverpod**: get_it giữ lifecycle service; Riverpod chỉ lo reactive
  UI. Tránh việc provider tự dựng service (khó test).
- **Permission gate ở lớp `builder`**: mọi route đều đi qua cổng, không cần lặp
  logic ở từng trang; nhược điểm là gate là widget vô hình bọc toàn bộ app.
- **Wallpaper là `Stack` nền toàn cục**: đổi route không nạp lại ảnh nền; các
  `Scaffold` phải để `backgroundColor: Colors.transparent`.

## 9. Edge case

- Native channel không có (test, non-Android): `NativeBridge.call` ném
  `NativeException('NO_PLUGIN')`; các nơi gọi bọc try/catch và bỏ qua.
- Đăng ký thiết bị lỗi mạng tạm thời: chỉ log, thử lại ở lần khởi động sau.
- `SharedPreferences` chưa sẵn sàng trong widget test: nhiều provider bắt lỗi
  `ref.watch(sharedPreferencesProvider)` và dùng giá trị mặc định in-memory.

## 10. Kiểm thử

`test/normal_app_contract_test.dart`, `test/native_lifecycle_contract_test.dart`,
`test/security_config_contract_test.dart`, `test/immersive_fullscreen_test.dart`,
`test/splash_icon_contract_test.dart`, `test/widget_test.dart`.

## 11. Hạn chế / việc còn lại

- Tài liệu cũ (`docs/DOCUMENTATION.md`, `docs/USE_CASES.md`) mô tả app là "normal
  app không auto-start"; thực tế manifest hiện vẫn khai báo `BootReceiver` +
  `BOOT_COMPLETED` + `StartupCoordinator`. Cần thống nhất lại tài liệu tổng.
- IMEI luôn rỗng (Android 29+ chặn app thường).

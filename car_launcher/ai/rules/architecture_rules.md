# Flutter Riverpod & Clean Architecture Coding Standards

Bạn là một chuyên gia lập trình Flutter cấp cao. Dự án này là một **Android Automotive launcher** (car head-unit). Khi phát triển hoặc tối ưu hóa mã nguồn, bạn phải tuân thủ nghiêm ngặt các quy tắc dưới đây về kiến trúc Clean Architecture (Riverpod + go_router + get_it), quản lý phạm vi provider, đặt tên file, và xử lý lỗi.

> ⚠️ **Legacy note:** Các file cũ trong dự n vẫn có thể dùng `ChangeNotifier` + `auto_route` + `flash`. Đó là legacy pattern. **Mọi code MỚI phải dùng Riverpod + go_router.** Khi migrate, giữ pattern cũ trong file cũ; không tạo code mới bằng pattern cũ.

---

## 1. Kiến trúc Clean Architecture (Riverpod)

Cấu trúc hệ thống chia làm 3 lớp cốt lõi, tối ưu cho team nhỏ nhưng giữ khả năng mở rộng:

- **Presentation Layer (Giao diện & Trạng thái):** Widgets/Views (chỉ hiển thị dữ liệu) và **Riverpod Notifier** (`@riverpod` generator) quản lý trạng thái, nhận sự kiện từ UI và gọi Repository.
- **Domain Layer (Nghiệp vụ):** Entity/model thuần (không phụ thuộc Flutter), định nghĩa `Repository` interface (abstract class) chịu trách nhiệm xử lý logic nghiệp vụ.
- **Data Layer (Nguồn dữ liệu):** Data Sources (API Client, Database Helper, Native Bridge) và DTOs/implementations. Implement concrete `Repository` ở tầng này.

### Quy tắc phạm vi Provider (Scope Rule)
- Mỗi provider phải có **phạm vi hoạt động rõ ràng**. Feature provider phục vụ một màn hình/tính năng cụ thể **KHÔNG ĐƯỢC phép gọi chéo** sang UI của tính năng khác.
- **Shared providers** (auth, theme, app-wide state) đặt trong `lib/shared/providers/` hoặc `lib/core/...`.
- **Feature providers** đặt trong `lib/features/<feature>/presentation/providers/`.

### Sơ đồ cấu trúc thư mục chuẩn
```text
lib/
├── core/                        # Tiện ích hệ thống, cấu hình, theme, native bridge, logging
│   ├── api/                     # API config, http client
│   ├── auth/                    # Keycloak OIDC, secure storage
│   ├── logging/                 # AppLogger
│   ├── native/                  # NativeBridge (MethodChannel wrapper)
│   ├── router/                  # go_router config
│   ├── services/                # Device info, etc.
│   ├── theme/                   # AppTheme, LauncherAppearance
│   └── utils/                   # String utils, etc.
├── shared/                      # Các thành phần dùng chung toàn ứng dụng
│   ├── constants/               # AppConstants
│   ├── data/                    # LocationService, WeatherService, VehicleTrackingStore
│   ├── providers/               # Shared providers (auth, theme, http client)
│   └── widgets/                 # CarResponsive, shared UI
└── features/                    # Các module tính năng độc lập
    ├── <feature>/
    │   ├── data/                # Data sources, DTOs, Repository implementations
    │   ├── domain/              # Entities, abstract Repository interfaces
    │   └── presentation/
    │       ├── providers/       # Riverpod Notifiers (chỉ dùng nội bộ feature)
    │       ├── widgets/         # Feature-specific widgets
    │       └── pages/           # Screens
    └── ...
```

---

## 2. Quy ước Đặt tên & Cấu trúc File

- **File provider/notifier:** hậu tố `_provider.dart` (ví dụ: `login_provider.dart`, `theme_provider.dart`).
- **Class notifier:** kết thúc bằng `Notifier` và extends generated `_$...` (ví dụ: `class ThemeNotifier extends _$ThemeNotifier`).
- **Code generation:** luôn thêm dòng `part 'filename.g.dart';` ngay dưới imports khi dùng `@riverpod`, `json_serializable`, v.v.
- **Route file:** `app_router.dart` + `app_router.g.dart` (nếu có code-gen).
- **Tên class:** `PascalCase`. **Tên biến/hàm:** `camelCase`. **Tên file:** `snake_case`.

---

## 3. Riverpod — Cách viết state management đúng

### 3.1. Khai báo provider (dùng code-gen `@riverpod`)
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'theme_provider.dart.g.dart'; // build_runner sẽ sinh

@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  ThemeSettings build() {
    // giá trị khởi tạo
    return ThemeSettings.initial();
  }

  void toggle() {
    state = state.copyWith(isDark: !state.isDark);
  }
}
```

### 3.2. Đọc state từ Widget
- Dùng `ConsumerWidget` / `ConsumerStatefulWidget` (hoặc hook `HookConsumerWidget` nếu cần).
- Trong `build(BuildContext context, WidgetRef ref)`:
  - **Đọc state:** `ref.watch(themeNotifierProvider)` — widget rebuild khi state thay đổi.
  - **Đọc một lần / gọi hàm:** `ref.read(themeNotifierProvider.notifier).toggle()` — trong callback (`onPressed`, `onTap`).
  - **Lắng nghe side-effect:** `ref.listen(themeNotifierProvider, (prev, next) { ... })`.

### 3.3. Quy tắc phạm vi & lifecycle
- **Global/singleton providers** (auth, http client, shared prefs): khai báo ở `shared/providers/`, không override.
- **Feature providers** cần dependency từ constructor: dùng `ProviderScope` overrides tại nơi gần nhất với nơi sử dụng (thường ở `main.dart` hoặc route builder), hoặc dùng `ref.watch` để inject.
- **Tự động dispose:** Riverpod tự dispose khi provider không còn được watch. Không cần gọi `dispose()` thủ công cho notifier (trừ khi bạn giữ tài nguyên đặc biệt như StreamSubscription — hãy override `dispose()`).
- **Không** khai báo feature provider ở cấp toàn cục nếu nó chỉ phục vụ 1 màn hình.

### 3.4. Xử lý lỗi & async state
- Dùng `AsyncValue<T>` cho state bất đồng bộ:
```dart
@riverpod
class VehicleListNotifier extends _$VehicleListNotifier {
  @override
  Future<List<Vehicle>> build() async {
    final repo = ref.read(vehicleRepositoryProvider);
    return repo.fetchVehicles(); // throw sẽ tự thành AsyncError
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(vehicleRepositoryProvider);
      return repo.fetchVehicles();
    });
  }
}
```
- Trong UI: `when(data: ..., loading: ..., error: ...)`. **Không** dùng `!` để unwrap `AsyncValue`.

---

## 4. go_router — Điều hướng

- Cấu hình router trong `lib/core/router/app_router.dart` dưới dạng provider Riverpod (`appRouterProvider`).
- Dùng `MaterialApp.router(routerConfig: router)`.
- **Deep-linking / nested routes:** dùng `ShellRoute` hoặc `GoRoute` lồng nhau.
- **Auth redirect:** dùng tham số `redirect` của `GoRouter`, đọc auth state từ `ref.watch(authProvider)`.
- **Route ngắn hạn** (dialog, bottom sheet): dùng `Navigator.push` thông thường — không cần khai báo trong go_router.
- **Truyền params:** `path: 'details/:id'`, đọc qua `state.pathParameters['id']` (dùng `!` ở đây hợp lệ vì route đã định nghĩa).

---

## 5. Dependency Injection với get_it

- Dùng `get_it` để register singleton/transient objects không phải Riverpod (API clients, database helper, native bridge wrapper).
- **Không** dùng get_it để inject vào Riverpod notifier — Riverpod tự quản lý dependency qua `ref.read`.
- Khởi tạo get_it trong `main.dart` trước `runApp`.

---

## 6. Quy tắc Domain đặc thù cho Car Launcher

### 6.1. Native Bridge (`lib/core/native/native_bridge.dart`)
- **BẮT BUỘC** wrap mọi `MethodChannel` call qua `NativeBridge.call<T>('method')`. Không gọi `MethodChannel` trực tiếp từ provider/repository.
- Xử lý `MissingPluginException` — native side có thể vắng mặt khi chạy test/web. Bắt và trả về giá trị mặc định hoặc throw domain exception rõ ràng.
- Mọi native call là **fallible**: bắt lỗi, log qua `AppLogger`, không crash app.
- Không gọi native bridge trong `build()` widget — chỉ trong callback hoặc `initState`/`build` của notifier.

### 6.2. Vehicle Tracking (realtime)
- Tracking point là **Stream** — không dùng polling.
- Dispose `StreamSubscription` trong notifier `dispose()` (override).
- Xử lý mạng không ổn định (xe di động): retry có backoff, không crash khi mất kết nối. Lỗi mạng tạm thời không được làm crash app.
- Lưu local cache qua `sqflite`/`shared_preferences` để hiển thị khi offline.

### 6.3. Navigation / Maps
- Map controller (Google Maps / embedded) **BẮT BUỘC** dispose trong `dispose()` widget. Không dispose = memory leak nghiêm trọng trên head-unit.
- Xử lý location permission — nếu bị từ chối, hiển thị UI fallback, không crash.
- Cache map tiles/state khi có thể; head-unit thường có mạng chậm.

### 6.4. Launcher (launch app ngoài)
- Launch app ngoài thông qua native bridge (Android intent). Không dùng `url_launcher` cho app ngoài trừ khi là URL scheme.
- Respecting `QUERY_ALL_PACKAGES` permission. Nếu permission bị từ chối, hiển thị danh sách app fallback/trống thay vì crash.
- Không block UI khi launch — fire-and-forget với error được log.

### 6.5. Keycloak OIDC Authentication
- Token lưu trong `flutter_secure_storage` (xem `core/auth/app_secure_storage.dart`). **Không** bao giờ lưu token trong `shared_preferences` (không an toàn).
- Refresh flow: tự động refresh trước khi gọi API khi token hết hạn. Nếu refresh fail → đẩy user về login (không crash).
- Logout: xóa token khỏi secure storage + hủy Riverpod auth state.
- Không block UI trong quá trình auth — dùng `AsyncValue` hoặc loading state.

### 6.6. Layout Engine / Car-responsive
- UI phải responsive cho màn hình xe (nhiều tỷ lệ, thường ngang). Dùng `lib/shared/widgets/car_responsive.dart`.
- Layout engine (`features/layout/`) quản lý split pane, widget placement. State lưu qua `shared_preferences` để khôi phục sau restart.
- Hạn chế text dài, target touch lớn (tay lái/không tập trung vào màn hình).

---

## 7. Xử lý Lỗi & Logging

- **Không dùng `print()`** trong production code. Dùng `AppLogger` (`core/logging/app_logger.dart`) cho structured logging.
- Mọi `try-catch` phải log error + stacktrace qua `AppLogger.instance.e(...)`.
- Lỗi hiển thị cho user phải là **user-friendly message**, không phải raw exception string.
- Lỗi nghiêm trọng (crash): log + report, nhưng app phải recover hoặc graceful shutdown — không để màn hình đen.

```dart
// ✅ ĐÚNG
try {
  await repo.fetchData();
} catch (e, st) {
  AppLogger.instance.e('Failed to fetch data', tag: 'VEHICLE', error: e, stackTrace: st);
  state = AsyncValue.error('Không thể tải dữ liệu. Thử lại?', st);
}
```

---

## 8. Tổng kết quy tắc "KHÔNG ĐƯỢC"

| # | Quy tắc |
|---|---|
| 1 | **Không** dùng `ChangeNotifier` / `auto_route` / `flash` trong code MỚI (legacy thôi). |
| 2 | **Không** gọi `MethodChannel` trực tiếp — phải qua `NativeBridge`. |
| 3 | **Không** dùng `print()` — dùng `AppLogger`. |
| 4 | **Không** dùng `mockito` — dùng `mocktail`. |
| 5 | **Không** dispose quên: StreamSubscription, MapController, AnimationController. |
| 6 | **Không** lưu token trong `shared_preferences` — dùng `flutter_secure_storage`. |
| 7 | **Không** unwrap `AsyncValue` bằng `!` — dùng `when()`. |
| 8 | **Không** gọi native bridge trong widget `build()`. |
| 9 | **Không** crash khi mất mạng — retry + graceful fallback. |
| 10 | **Không** viết test phụ thuộc vào native side — mock `NativeBridge`. |

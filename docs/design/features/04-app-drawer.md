# 04 — App Drawer (danh sách ứng dụng)

Updated: 2026-08-29
Status: implemented
Route: `/apps` (và trang index 2 của Dashboard PageView)
Nguồn: `lib/features/app_drawer/presentation/app_drawer_page.dart`,
`lib/features/app_drawer/presentation/providers/app_drawer_providers.dart`,
`lib/features/app_drawer/presentation/widgets/*.dart`,
`lib/features/launcher/data/launcher_service.dart`

## 1. Mục tiêu & phạm vi

Hiển thị lưới toàn màn hình các ứng dụng Android đã cài (launchable), có tìm
kiếm, đánh dấu yêu thích, và mở app. Danh sách tự cập nhật khi cài/gỡ app.

## 2. Luồng người dùng

1. Người dùng mở `/apps` (hoặc vuốt tới trang Apps).
2. Lưới nạp lần đầu (loading spinner) → hiển thị danh sách đã sắp xếp theo tên.
3. Gõ vào ô tìm kiếm → lọc theo tên hoặc package name.
4. Chạm icon → `launchApp(packageName)` rồi quay lại (`context.pop()` hoặc `/`).
5. Nhấn giữ icon → thêm/bỏ yêu thích (`favoriteAppsProvider`, tối đa 5).

## 3. Kiến trúc

```
AppDrawerPage (ConsumerStatefulWidget)
├── _SearchAppBar → searchQueryProvider
└── _AppGrid  (LayoutBuilder → AppsGridLayout.resolve(width,height,orientation))
    └── GridView.builder → AppIconTile
                           └── appIconProvider(packageName)  # FutureProvider.family, cache bytes icon
```

`AppsGridLayout.resolve` tính số cột, spacing, cỡ icon, cỡ chữ theo kích thước &
hướng màn hình. `resizeToAvoidBottomInset: false`, tự cộng `keyboardInset` vào
padding dưới của lưới.

## 4. State management

| Provider | Kiểu | Vai trò |
|---|---|---|
| `searchQueryProvider` | `StateProvider<String>` | chuỗi tìm kiếm |
| `installedAppsProvider` | `StateNotifier<InstalledAppsState>` | nạp danh sách qua `LauncherService.getInstalledApps()` (timeout 30s), sort theo `appName`, cache sau lần đầu (`hasLoaded`); lắng nghe `NativeBridge.onEvent('app_package_changed')` → `refreshSoon()` (debounce 350ms) |
| `installedAppsListProvider` / `appsLoadingProvider` | `Provider` | truy cập nhanh |
| `appIconProvider` | `FutureProvider.family<Uint8List?, String>` | bytes icon theo package (`getAppIcon` → base64 decode) |
| `filteredAppsProvider` | `Provider` | lọc theo `searchQueryProvider` |
| `recentAppsProvider` | `StateNotifier<List<Map>>` | 10 app gần đây (in-memory) |
| `favoriteAppsProvider` | (dashboard) | app yêu thích |

`InstalledAppsNotifier` chống race bằng `_requestGeneration`; huỷ subscription
`packageChanges` trong `ref.onDispose`.

## 5. Tích hợp native

`LauncherService` (đăng ký singleton trong DI) bọc `NativeBridge`:

- `getInstalledApps()` → `List<Map<String,String>>` (appName, packageName,
  iconBase64…).
- `getAppIconBytes(packageName)` → decode base64.
- `launchApp`, `launchSplitScreen`, `launchMapsWithYoutubeOnTop`.
- `getConnectivityStatus`, `getBatteryLevel`, `getEmbeddingInfo`.
- getter/setter `themeMode` (đọc `SharedPreferences` key `theme_mode`).

Native bắn event `app_package_changed` từ `AppPackageChangedReceiver` khi có
`PACKAGE_ADDED/REMOVED/REPLACED`.

## 6. Quyết định thiết kế & đánh đổi

- **Cache danh sách sau lần đầu + refresh theo event** thay vì poll: nhẹ, nhưng
  phụ thuộc receiver native hoạt động đúng; có nút "Refresh" ở empty state để
  ép nạp lại.
- **Icon lấy lười theo từng tile** (`FutureProvider.family`) thay vì tải hết
  trong danh sách: lưới lớn không bị nghẽn, đổi lại nhiều lời gọi native nhỏ.
- **Model là `Map<String,String>`** (không phải class) — khớp thẳng dữ liệu
  method channel, ít boilerplate, nhưng mất type-safety.
- **`favoriteAppsProvider` / `recentAppsProvider` chỉ in-memory** — mất khi khởi
  động lại (chưa persist).

## 7. Edge case

- `getInstalledApps` timeout 30s → trả danh sách rỗng, `hasLoaded=true` (không
  spinner vô hạn).
- Package thay đổi liên tục → debounce 350ms gộp nhiều refresh.
- Non-Android: danh sách rỗng, empty state.

## 8. Kiểm thử

`test/launcher_service_test.dart`, `test/app_drawer_keyboard_test.dart`,
`test/async_stale_response_protection_test.dart`.

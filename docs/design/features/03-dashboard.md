# 03 — Dashboard (màn hình chính)

Updated: 2026-09-24
Status: implemented
Route: `/`
Nguồn: `lib/features/dashboard/presentation/dashboard_page.dart`,
`lib/features/dashboard/presentation/splash_page.dart`,
`lib/features/dashboard/presentation/providers/*.dart`,
`lib/features/dashboard/presentation/widgets/*.dart`,
`lib/features/dashboard/all_dashboard/*.dart`

## 1. Mục tiêu & phạm vi

Màn hình trung tâm của launcher: khung trên (`TopAppBar`) + vùng nội dung dạng
`PageView` gồm 4 trang + thanh trạng thái dưới (`BottomStatusBar`). Kèm splash
screen và các provider hạ tầng dashboard (đồng hồ, kết nối mạng, wallpaper, chỉ
số trang).

## 2. Bố cục `DashboardPage`

`ConsumerStatefulWidget`. `Column`:

1. `TopAppBar(title: topBarTitles[index])`
2. `Expanded` → `PageView` với `bodies`:
   | index | trang | tiêu đề top bar |
   |---|---|---|
   | 0 | `MediaCenterPage` | "Media Center" |
   | 1 | "Home" — `_homeContentFor(homeViewMode)` | "" (hiển thị tên địa điểm) |
   | 2 | `AppDrawerPage` | "Apps" |
   | 3 | `SettingsPage` | "Settings" |

   Trang "Home" (index 1) **không cố định**: `_homeContentFor` chọn
   `MapPage`/`MapWithMedia`/`MapWithYoutube` theo `carPlaySettingsProvider`
   (`HomeViewMode`, cấu hình ở Settings → Dashboard — xem [08](08-settings.md)).
   Trước 2026-09-24, cả 3 trang map này từng là 3 trang PageView cố định luôn
   hiển thị bất kể setting; `HomeViewMode` khi đó chỉ lưu giá trị, không tác
   động UI.
3. `BottomStatusBar` (cao 40, `dashboardLength = 4`)

- Trang khởi tạo = `dashboardIndexProvider` (mặc định `1`, tức trang Home).
- `PageController` + cờ `_programmaticChanging` để phân biệt vuốt tay và chuyển
  bằng code: `ref.listen(dashboardIndexProvider)` → `_animateToPage`; `onPageChanged`
  do người dùng vuốt → `setIndex`. Cả hai đều `clamp(0, 3)` để tránh index cũ
  (từ bản 6 trang trước đây, lưu ở secure storage) làm vỡ `PageController`.
- `physics: BouncingScrollPhysics(parent: PageScrollPhysics())`.

## 3. Splash

`SplashPage` (`/splash`): hai `AnimationController` (logo scale 1→1.04, fade
out). `_startFlow`: forward logo → chờ 1500ms → fade 500ms → `context.go('/')`.
Ảnh `assets/images/splash.png`, nền gradient tối.

## 4. Providers hạ tầng (`dashboard_providers.dart`)

| Provider | Kiểu | Vai trò |
|---|---|---|
| `clockProvider` | `StateNotifier<String>` | giờ `HH:mm`, `Timer.periodic(1s)` |
| `connectivityStatusProvider` | `StateNotifier<ConnectivityStatus>` | đọc native + lắng nghe `NativeBridge.events`, refresh mỗi 10s; có `ConnectivityStatus` typed thay cho `Map` thô, kèm chống race bằng `_requestGeneration` |
| `currentWallpaperProvider` | `StateNotifier<String>` | đường dẫn wallpaper (in-memory) |
| `favoriteAppsProvider` | `StateNotifier<List<Map>>` | tối đa 5 app yêu thích |
| `dashboardIndexProvider` | `StateNotifier<int>` | chỉ số trang PageView; **lưu vào `AppSecureStorage`** key `dashboardIndex`; mặc định 1 |

`carplay_settings_providers.dart`:

- `HomeViewMode` (dashboard01/02/03 — "Map Focus"/"Grid Layout"/"Split View")
  + `CarPlaySettings` (`dynamicClockNetwork`, `use24HourTime`, `showVpnStatus`,
  `dockPinned`) — lưu `SharedPreferences`, provider `overrideWith` trong
  `main.dart`. `homeViewMode` chọn trang Home của `DashboardPage` (mục 2).
- `overlayVisibleProvider`: ẩn đồng hồ/mạng 5s sau khi người dùng chạm màn hình
  (chỉ khi `dynamicClockNetwork` bật và dock không ghim).

`widget_providers.dart`: `WidgetListNotifier` quản lý danh sách widget dashboard
(`WidgetModel` type clock/media/navigation/appShortcut, lưới 4×3), JSON hoá vào
`SharedPreferences` key `widget_config`; kèm `editModeProvider`,
`selectedWidgetIdProvider`, `draggingWidgetIdProvider` cho chế độ chỉnh sửa.

`weather_providers.dart`: xem [13](13-weather-and-clock.md).

## 5. Widget con đáng chú ý

- `background_layer.dart`, `glass_panel.dart`, `home_indicator.dart` — bề mặt kính,
  chỉ báo home kiểu CarPlay.
- `navigation_map_widget.dart` — bề mặt bản đồ (xem [06](06-navigation-maps.md)).
- `weather_clock_widget.dart`, `bottom_status_bar.dart`, `connectivity_indicator.dart`.
- `youtube_widget.dart`, `map_with_media.dart`, `map_with_youtube.dart` — bố cục
  ghép bản đồ + cửa sổ phụ; `DashboardLayoutMetrics.of(context)` tính padding/gap/
  tỉ lệ YouTube theo bề rộng màn hình (nội suy 1024→2560px).
- `vehicle_tracking_card.dart` — `VehicleTrackingBadge` (badge nhỏ) và
  `VehicleTrackingSettingsCard` (thẻ đầy đủ trong Settings), xem [12](12-vehicle-tracking.md).

## 6. Quyết định thiết kế & đánh đổi

- **`dashboardIndexProvider` lưu ở secure storage** (không phải `SharedPreferences`)
  — vô tình lệch chuẩn với các preference khác; hệ quả: đọc/ghi async, khởi tạo
  bằng giá trị mặc định rồi cập nhật sau khi `_load()`.
- **PageView giữ toàn bộ 4 trang sống** → chuyển trang mượt, không dựng lại state;
  đổi lại tốn RAM và các trang chạy nền (timer, listener) kể cả khi không hiển thị.
  Trang Home tuy đổi nội dung theo `homeViewMode`, nhưng cả 3 lựa chọn đều là
  widget `const` nên Flutter không rebuild lại state khi không cần.
- **Chống race bằng generation counter** (`_requestGeneration`) lặp lại ở nhiều
  notifier — pattern nhất quán nhưng lặp code.

## 7. Edge case

- Native trả `Map<Object?,Object?>` (method channel mất generic) → re-key thủ công
  thay vì cast.
- Sự kiện connectivity từ native và refresh định kỳ có thể tới đan xen →
  generation counter đảm bảo chỉ nhận kết quả mới nhất.

## 8. Kiểm thử

`test/dashboard_space_utilization_test.dart`, `test/design_screens_test.dart`,
`test/responsive_screens_test.dart`, `test/connectivity_surfaces_contract_test.dart`,
`test/real_data_contract_test.dart`.

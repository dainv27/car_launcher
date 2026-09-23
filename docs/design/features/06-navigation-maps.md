# 06 — Navigation / bản đồ

Updated: 2026-08-29
Status: implemented (nhúng bản đồ phụ thuộc firmware)
Route: `/navigation`, `/navigation/youtube`
Nguồn: `lib/features/navigation/data/navigation_service.dart`,
`lib/features/navigation/data/google_maps_channel.dart`,
`lib/features/navigation/presentation/navigation_controller.dart`,
`lib/features/navigation/presentation/providers/navigation_providers.dart`,
`lib/features/navigation/presentation/widgets/navigation_widget.dart`,
`lib/features/dashboard/presentation/widgets/navigation_map_widget.dart`,
`lib/features/dashboard/all_dashboard/map*.dart`,
`android/.../platform_view/GoogleMapsPlatformView*.kt`

## 1. Mục tiêu & phạm vi

Cung cấp "bề mặt bản đồ" trong launcher: nhúng Google Maps qua PlatformView khi
firmware cho phép, hoặc fallback mở app bản đồ toàn màn hình. Theo dõi trạng thái
điều hướng (ETA, khoảng cách, hướng rẽ) do native đẩy lên, và cho phép chuyển
nhà cung cấp bản đồ.

## 2. Thành phần

| Thành phần | Vai trò |
|---|---|
| `MapPage` (route) | wrapper mỏng bọc `NavigationMapWidget` |
| `NavigationMapWidget` | bề mặt bản đồ trong dashboard (PlatformView Google Maps + fallback) |
| `GoogleMapsPlatformView(Factory).kt` | native TaskView/PlatformView cho Google Maps |
| `GoogleMapsChannel` | `MethodChannel('car_launcher/google_maps')` — hiện chỉ có `restartMaps()` |
| `NavigationController` | `StateNotifier<NavigationStateModel>` — nhận `EventChannel('com.carlauncher/nav_events')`, gọi `MethodChannel('com.carlauncher/navigation')` |
| `LauncherService.launchMapsWithYoutubeOnTop(...)` | mở Maps toàn màn hình + YouTube ở cửa sổ freeform (fallback: split-screen) |

## 3. Model — `NavigationStateModel`

Trường: `state (NavState: idle/navigating/rerouting/loading)`, `destination`,
`eta`, `distance`, `nextTurn`, `currentProvider (NavigationProvider)`, `isActive`.
`NavigationProvider` enum: googleMaps, waze, here, tomtom, sygic (kèm
`packageName`, `displayName`). Bất biến, có `fromJson`/`toJson`, `idle` mặc định.

## 4. Luồng dữ liệu

```
Native nav state  ──EventChannel 'nav_events'──►  NavigationController.state
UI ── launchNavigation()/launchProvider() ──► LauncherService.launchApp(packageName)
UI ── switchProvider(p) ──► MethodChannel 'navigation'/'switchProvider' ──► (nếu launched) cập nhật currentProvider
UI ── stopNavigation() ──► MethodChannel 'navigation'/'stopNavigation'
```

Lỗi `PlatformException` khi switch/stop → giữ provider đã xác nhận cuối cùng.

## 5. State management

`navigation_providers.dart` và `navigation_controller.dart` cùng khai báo
`NavigationController` (hai file, một số provider trùng tên như
`isNavigatingProvider`, `navProviderProvider`). Các `Provider` phái sinh:
`navEtaProvider`, `navDistanceProvider`, `navDestinationProvider`,
`navNextTurnProvider`, `navStateProvider`, `availableNavProvidersProvider`.

## 6. Nhúng vs. fallback

`NavigationMapWidget` cố dùng PlatformView Google Maps (native TaskView, cần
firmware/chữ ký nền tảng — xem [07](07-multi-window-embedding.md) cho cơ chế
chung). Nếu không hỗ trợ → fallback: mở app bản đồ như một Activity toàn màn
hình. `launchMapsWithYoutubeOnTop` quyết định kích thước/vị trí cửa sổ YouTube ở
phía Flutter (widthFraction, heightFraction, marginDp, min px, delay) để native
không phải biết luật layout; nếu freeform không có → dùng split-screen kề nhau.

## 7. Quyết định thiết kế & đánh đổi

- **Layout cửa sổ phụ tính ở Flutter**, native chỉ thực thi — giữ một nguồn luật
  layout; đổi lại thêm nhiều tham số truyền qua channel.
- **Trạng thái điều hướng chỉ đọc từ native** (một chiều) — launcher không tự suy
  diễn ETA; chính xác nhưng phụ thuộc app bản đồ/firmware có phát event hay không.
- **Trùng lặp `NavigationController` ở hai file** — nợ kỹ thuật, nên hợp nhất về
  `navigation_providers.dart`.
- **`GoogleMapsChannel` mới có `restart`** — API tối giản, mở rộng khi cần.

## 8. Edge case

- Không có app bản đồ nào cài → `launchApp` trả false, UI giữ trạng thái.
- Firmware không hỗ trợ freeform/embedding → tự động hạ cấp fallback.
- Non-Android/test → mọi lời gọi channel bị nuốt lỗi.

## 9. Kiểm thử

`test/design_screens_test.dart`, `test/responsive_screens_test.dart`
(bao phủ bố cục); phần native embedding xem [07](07-multi-window-embedding.md).

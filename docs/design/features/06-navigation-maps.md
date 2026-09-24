# 06 — Navigation / bản đồ

Updated: 2026-09-24
Status: một phần đã gỡ bỏ (dead code) — xem §7
Route: `/navigation`, `/navigation/youtube`
Nguồn: `lib/features/dashboard/presentation/widgets/navigation_map_widget.dart`,
`lib/features/dashboard/all_dashboard/map*.dart`,
`lib/features/layout/presentation/widgets/embedded_android_app_view.dart`,
`android/.../platform_view/GoogleMapsPlatformView*.kt`

## 1. Mục tiêu & phạm vi

Cung cấp "bề mặt bản đồ" trong launcher: nhúng Google Maps qua PlatformView khi
firmware cho phép, hoặc fallback mở app bản đồ toàn màn hình.

## 2. Thành phần

| Thành phần | Vai trò |
|---|---|
| `MapPage` (route) | wrapper mỏng bọc `NavigationMapWidget` |
| `NavigationMapWidget` | bề mặt bản đồ trong dashboard — nhúng Google Maps qua `EmbeddedAndroidAppView` (cơ chế multi-window chung, xem [07](07-multi-window-embedding.md)), không qua channel riêng |
| `GoogleMapsPlatformView(Factory).kt` | native TaskView/PlatformView cho Google Maps |
| `LauncherService.launchMapsWithYoutubeOnTop(...)` | mở Maps toàn màn hình + YouTube ở cửa sổ freeform (fallback: split-screen) |

## 3. Nhúng vs. fallback

`NavigationMapWidget` dùng PlatformView Google Maps (native TaskView, cần
firmware/chữ ký nền tảng — xem [07](07-multi-window-embedding.md) cho cơ chế
chung). Nếu không hỗ trợ → fallback: mở app bản đồ như một Activity toàn màn
hình. `launchMapsWithYoutubeOnTop` quyết định kích thước/vị trí cửa sổ YouTube ở
phía Flutter (widthFraction, heightFraction, marginDp, min px, delay) để native
không phải biết luật layout; nếu freeform không có → dùng split-screen kề nhau.

## 4. Quyết định thiết kế & đánh đổi

- **Layout cửa sổ phụ tính ở Flutter**, native chỉ thực thi — giữ một nguồn luật
  layout; đổi lại thêm nhiều tham số truyền qua channel.

## 5. Edge case

- Không có app bản đồ nào cài → `launchApp` trả false, UI giữ trạng thái.
- Firmware không hỗ trợ freeform/embedding → tự động hạ cấp fallback.

## 6. Kiểm thử

`test/design_screens_test.dart`, `test/responsive_screens_test.dart`
(bao phủ bố cục); phần native embedding xem [07](07-multi-window-embedding.md).

## 7. Đã gỡ bỏ (2026-09-24)

`lib/features/navigation/` (`NavigationController`, `NavigationStateModel`,
`NavigationProvider` enum, `GoogleMapsChannel`, `NavigationWidget`) đã bị xoá:
không route, không widget nào bên ngoài import các file này — `/navigation`
route thực tế dùng `MapPage`/`NavigationMapWidget` ở trên, và
`GoogleMapsChannel` (`MethodChannel('car_launcher/google_maps')`) không có nơi
gọi. Đây từng là nợ kỹ thuật đã ghi nhận (hai `NavigationController` trùng
lặp ở hai file, không bao giờ cùng được import) nhưng hoá ra toàn bộ cụm này
chưa từng được nối vào UI thật.

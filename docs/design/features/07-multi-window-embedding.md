# 07 — Multi-window & nhúng ứng dụng Android

Updated: 2026-09-24
Status: implemented (yêu cầu chữ ký nền tảng / firmware TBox)
Nguồn: `lib/features/layout/presentation/widgets/embedded_android_app_view.dart`,
`android/app/src/main/kotlin/com/carlauncher/car_launcher/embedding/**`,
`android/app/src/main/AndroidManifest.xml`

## 1. Mục tiêu & phạm vi

Cho phép chạy ứng dụng Android bên thứ ba *bên trong* khung launcher, mỗi app
trên một `VirtualDisplay` riêng. Khi ROM không cho phép nhúng, hạ cấp về mở
app toàn màn hình / split-screen.

`EmbeddedAndroidAppView` (`packageName`, `paneId`, `zOrderOnTop`) là widget
nhúng generic duy nhất còn dùng — `NavigationMapWidget` (Google Maps, pane 1)
và `YoutubeWidget` (YouTube, pane 2) đều render qua nó, tạo nên các layout
"Grid Layout" / "Split View" trong Dashboard settings (xem
[03](03-dashboard.md), [08](08-settings.md)).

## 2. Đã gỡ bỏ: hệ thống "Multi App" / pane tự do (2026-09-24)

Trước đây có một tầng riêng (`lib/features/layout/domain/layout_model.dart`,
`layout_providers.dart`, `EmbeddedAppPane`, `SingleLayout`/`DualLayout`,
`AppPickerDialog`, `PaneLaunchCoordinator`) cho phép người dùng gán **bất kỳ**
app cài trên máy vào pane qua Settings → Dashboard → "Multi App". Đã gỡ bỏ
toàn bộ tầng Dart này vì:

- Nó render qua viewType native `embedded_app_pane`
  (`EmbeddedAppPaneView`/`ActivityViewHelper`) — một cơ chế nhúng **khác**,
  dựa trên `ActivityView` (API cũ hơn), tách biệt hoàn toàn khỏi
  `VirtualDisplayAppView`/`VirtualDisplayEmbeddingCapability` mà
  `EmbeddedAndroidAppView` dùng.
- Trên phần cứng thực tế đã test (Bengal, Android 13, firmware hỗ trợ nhúng),
  `VirtualDisplayEmbeddingCapability` báo `supported: true` và nhúng Maps +
  YouTube thành công — nhưng `ActivityViewHelper.getSupportInfo()` lại báo
  `false`, khiến pane luôn rơi vào thông báo "Embedding unavailable on this
  device" dù máy hoàn toàn nhúng được. Hai class kiểm tra năng lực nhúng song
  song, không đồng bộ.
- Quyết định: chỉ giữ **một** đường nhúng (VirtualDisplay, đã kiểm chứng hoạt
  động thật trên thiết bị) thay vì vá lại đường ActivityView chưa từng chạy
  đúng trong sản phẩm thật.

Code native `embedding/EmbeddedAppPaneView.kt`, `ActivityViewHelper.kt`,
`EmbeddedAppPaneFactory` **vẫn còn trong repo** (không có Dart nào gọi tới
viewType `embedded_app_pane` nữa) — an toàn để giữ lại tạm thời, nhưng có thể
dọn trong một đợt cleanup native riêng nếu không còn dùng đến.

## 3. Nhúng — phía Flutter (còn lại)

- `EmbeddedAndroidAppView` — `PlatformViewLink` viewType `virtual_display_app`,
  `initExpensiveAndroidView`, `EagerGestureRecognizer`. Truyền `packageName`,
  `paneId`, `zOrderOnTop`. Non-Android → hiển thị "Embedded app requires
  Android".
- Không còn khái niệm "pane trống chờ gán app" ở tầng Dart — mỗi widget nhúng
  (`NavigationMapWidget`, `YoutubeWidget`) cố định một `packageName`.

## 4. Nhúng — phía native (`embedding/`)

| Lớp | Vai trò | Còn dùng? |
|---|---|---|
| `VirtualDisplayEmbeddingCapability` | kiểm tra API level, quyền, firmware → `getEmbeddingInfo`/`isEmbeddingSupported` (MethodChannel) | Có |
| `VirtualDisplayAppView(Factory)` | tạo `VirtualDisplay` + `SurfaceView`, khởi chạy Activity đích lên display đó — viewType `virtual_display_app` | Có — nền cho `EmbeddedAndroidAppView` |
| `VirtualDisplayReadinessGate` | hoãn tạo VD tới khi hệ thống sẵn sàng (boot xong, user unlock, display/surface hợp lệ, activity resumed, window focused, layout done) | Có |
| `EmbeddedAppPaneFactory` / `EmbeddedAppPaneView` / `ActivityViewHelper` | biến thể pane ActivityView cho hệ "Multi App" đã gỡ — viewType `embedded_app_pane` | **Không** (orphaned, không có Dart nào tạo view này nữa) |
| `EmbeddedInputAccessibilityService` | fallback bơm sự kiện nhập liệu vào app nhúng (khi `INJECT_EVENTS` không dùng được) — cần bật Accessibility | Có (dùng chung cho `VirtualDisplayAppView`) |
| `VDLogger` | log riêng cho luồng virtual display | Có |

Widget tạo `PlatformViewLink` ngay (để `SurfaceView` được tạo), native mới hoãn
tạo `VirtualDisplay` cho đến khi readiness gate mở.

## 5. Yêu cầu quyền

`ADD_TRUSTED_DISPLAY`, `MANAGE_ACTIVITY_TASKS`, `MANAGE_ACTIVITY_STACKS`,
`INJECT_EVENTS`, `ACTIVITY_EMBEDDING`, `REORDER_TASKS` — đánh dấu
`tools:ignore="ProtectedPermissions"`, **chỉ cấp khi APK ký bằng khóa nền tảng**
(firmware TBox). Trên bản build thường, `getEmbeddingInfo().supported == false`
và app luôn chạy nhánh fallback (`ColoredBox` "Embedded app requires Android"
trên non-Android; trên Android không hỗ trợ thì `VirtualDisplayAppView` tự xử
lý phía native — xem `VirtualDisplayReadinessGate`).

## 6. Quyết định thiết kế & đánh đổi

- **Một `VirtualDisplay` mỗi app** thay vì ActivityView dùng chung: cô lập tốt
  hơn, nhưng tốn tài nguyên và nhạy với trạng thái hệ thống → cần readiness gate.
- **Chỉ một cơ chế nhúng** (bỏ hệ ActivityView song song) — đơn giản hoá, tránh
  lệch trạng thái "hỗ trợ nhúng" giữa hai class kiểm tra năng lực; đổi lại
  không còn UI "gán app tuỳ ý vào pane" — người dùng chỉ chọn giữa các preset
  Dashboard có sẵn (Map Focus/Grid Layout/Split View), không tự phối app.
- **Accessibility service làm fallback nhập liệu**: dùng được khi không có
  `INJECT_EVENTS`, nhưng buộc người dùng tự bật quyền Accessibility (xử lý bởi
  startup permission gate — xem [01](01-app-shell-and-bootstrap.md)).

## 7. Edge case

- ROM thiếu quyền → nhúng không thành công, `VirtualDisplayReadinessGate` xử
  lý phía native; Dart không có fallback UI riêng cho từng pane nữa (không còn
  khái niệm pane trống).
- App đích crash/không mở được trên VD → native log qua `VDLogger`, pane trống.

## 8. Kiểm thử

`test/embedded_android_app_view_test.dart`, `test/virtual_display_surface_test.dart`,
`test/accessibility_input_fallback_contract_test.dart`.

# 07 — Multi-window & nhúng ứng dụng Android

Updated: 2026-08-29
Status: implemented (yêu cầu chữ ký nền tảng / firmware TBox)
Nguồn: `lib/features/layout/**`,
`android/app/src/main/kotlin/com/carlauncher/car_launcher/embedding/**`,
`android/app/src/main/AndroidManifest.xml`

## 1. Mục tiêu & phạm vi

Cho phép chạy một hoặc nhiều ứng dụng Android bên thứ ba *bên trong* khung
launcher (mỗi app trên một `VirtualDisplay` riêng), phục vụ bố cục multi-app.
Khi ROM không cho phép nhúng, hạ cấp về mở app toàn màn hình / split-screen.

## 2. Mô hình dữ liệu (`layout/domain/layout_model.dart`)

- `LayoutType` — hiện chỉ `dashboard_01` ("Single Pane", 1 pane).
- `LayoutRatio` — 50/50, 60/40, 70/30 (`primaryFraction`/`secondaryFraction`).
- `PaneApp` — `packageName`, `appName`, `icon?`; `==` theo `packageName`.
- `LayoutModel` — `type`, `ratio`, `paneApps: List<PaneApp>`; `appForPane(i)`,
  extension `assignedPaneApps`, `hasTwoAssignedApps`. JSON hoá vào
  `SharedPreferences` key `layout_config`.

## 3. State management

| Provider | Vai trò |
|---|---|
| `layoutProvider` | `StateNotifier<LayoutModel>` — `setType/setRatio/assignApp/removeApp/clearAssignments`, persist. `overrideWith` trong `main.dart` |
| `layoutTypeProvider` / `layoutRatioProvider` / `paneAppProvider(i)` | phái sinh |
| `embeddingInfoProvider` | `FutureProvider<EmbeddingInfo>` — gọi `LauncherService.getEmbeddingInfo()` → `{supported, reason, apiLevel}` |

## 4. Nhúng — phía Flutter

- `EmbeddedAndroidAppView` — `PlatformViewLink` viewType `virtual_display_app`,
  `initExpensiveAndroidView`, `EagerGestureRecognizer`. Truyền `packageName`,
  `paneId`, `zOrderOnTop`. Non-Android → hiển thị "Embedded app requires Android".
- `EmbeddedAppPane` — chọn giữa:
  - chưa gán app → `AppPane` (tap để gán, long-press để đổi);
  - non-Android → `_FallbackAppPane`;
  - `embeddingInfoProvider` loading → spinner; error hoặc `!supported` →
    `_FallbackAppPane` (hint kèm `info.reason`, tap → `PaneLaunchCoordinator`);
  - hỗ trợ → `PlatformViewLink` viewType `embedded_app_pane` + overlay nút đổi
    app + nhãn tên app.
- `PaneLaunchCoordinator` — khi không nhúng được: mở app đầu tiên được gán (giữ
  `_lastLaunchedKey`, `_startupLaunched` để không mở lặp), `launchOnStartup` chỉ
  chạy khi `isEmbeddingSupported()` là false.

## 5. Nhúng — phía native (`embedding/`)

| Lớp | Vai trò |
|---|---|
| `VirtualDisplayEmbeddingCapability` | kiểm tra API level, quyền, firmware → `getEmbeddingInfo` |
| `VirtualDisplayAppView(Factory)` | tạo `VirtualDisplay` + `SurfaceView`, khởi chạy Activity đích lên display đó |
| `VirtualDisplayReadinessGate` (mô tả trong doc widget) | hoãn tạo VD tới khi hệ thống sẵn sàng (boot xong, user unlock, display/surface hợp lệ, activity resumed, window focused, layout done) |
| `EmbeddedAppPaneFactory` / `EmbeddedAppPaneView` | biến thể pane cho bố cục launcher |
| `ActivityViewHelper` | tiện ích quản lý task/stack |
| `EmbeddedInputAccessibilityService` | fallback bơm sự kiện nhập liệu vào app nhúng (khi `INJECT_EVENTS` không dùng được) — cần bật Accessibility |
| `VDLogger` | log riêng cho luồng virtual display |

Widget tạo `PlatformViewLink` ngay (để `SurfaceView` được tạo), native mới hoãn
tạo `VirtualDisplay` cho đến khi readiness gate mở.

## 6. Yêu cầu quyền

`ADD_TRUSTED_DISPLAY`, `MANAGE_ACTIVITY_TASKS`, `MANAGE_ACTIVITY_STACKS`,
`INJECT_EVENTS`, `ACTIVITY_EMBEDDING`, `REORDER_TASKS` — đánh dấu
`tools:ignore="ProtectedPermissions"`, **chỉ cấp khi APK ký bằng khóa nền tảng**
(firmware TBox). Trên bản build thường, `getEmbeddingInfo().supported == false`
và app luôn chạy nhánh fallback.

## 7. Quyết định thiết kế & đánh đổi

- **Một `VirtualDisplay` mỗi app** thay vì ActivityView dùng chung: cô lập tốt
  hơn, nhưng tốn tài nguyên và nhạy với trạng thái hệ thống → cần readiness gate.
- **Fallback nhiều tầng** (nhúng → split-screen → mở toàn màn hình): luôn có
  đường dùng được trên mọi ROM; đổi lại nhiều nhánh code và trạng thái static
  (`PaneLaunchCoordinator`) khó test.
- **Accessibility service làm fallback nhập liệu**: dùng được khi không có
  `INJECT_EVENTS`, nhưng buộc người dùng tự bật quyền Accessibility (xử lý bởi
  startup permission gate — xem [01](01-app-shell-and-bootstrap.md)).
- **`LayoutType` hiện chỉ 1 giá trị**: khung mở sẵn cho nhiều bố cục nhưng chưa
  dùng hết.

## 8. Edge case

- ROM thiếu quyền → `reason` mô tả lý do, hiển thị trên fallback pane.
- App đích crash/không mở được trên VD → native log qua `VDLogger`, pane trống.
- Chưa gán app cho pane → tap để chọn qua `app_picker_dialog.dart`.

## 9. Kiểm thử

`test/embedded_android_app_view_test.dart`, `test/virtual_display_surface_test.dart`,
`test/accessibility_input_fallback_contract_test.dart`.

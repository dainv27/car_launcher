# Embedded app và multi-window

## VirtualDisplay kiểu CarCar

`VirtualDisplayAppView` tạo một `SurfaceView` và một `VirtualDisplay` riêng cho
mỗi pane. App đích được launch vào `displayId` bằng
`ActivityOptions.launchDisplayId`. Motion/key event nhận trên SurfaceView được
gán cùng `displayId`, sau đó inject qua Android InputManager.

```text
Flutter PlatformView
  -> SurfaceView
  -> VirtualDisplay
  -> ActivityOptions.launchDisplayId
  -> Google Maps hoặc YouTube
```

Hai bộ flags được thử:

- trusted path: `3337`, cần `ADD_TRUSTED_DISPLAY`;
- compatibility path: `265`, có thể render trên một số ROM nhưng không đảm bảo
  launch/touch đầy đủ.

## ActivityView: chỉ còn native code mồ côi

Hidden `android.app.ActivityView` (qua reflection, xuất hiện từ Android 9,
không phải SDK công khai, thường chỉ hoạt động cho system/privileged app) vẫn
tồn tại trong native code (`ActivityViewHelper`, dùng bởi `EmbeddedAppPaneView`
và `GoogleMapsPlatformView`), nhưng **không còn widget Flutter nào gọi tới
`embedded_app_pane` hay `google_maps_taskview`** — tính năng Multi App/pane bị
gỡ khỏi `lib/features/layout` sau khi thiết bị test (Bengal) cho thấy đường
`embedded_app_pane` báo not-supported ngay cả khi ROM thực sự hỗ trợ embed,
trong khi `virtual_display_app` đã hoạt động tốt trên cùng thiết bị.

`virtual_display_app` (`VirtualDisplayAppView`) — cơ chế embed đang dùng trong
app — **không** fallback sang ActivityView khi VirtualDisplay thất bại; nó chỉ
rơi xuống freeform/adjacent window (xem phần dưới) hoặc báo lỗi.

## Freeform và adjacent fallback

`MultiWindowLauncher.launchMapsWithYoutubeOnTop()`:

1. mở Google Maps;
2. sau khoảng 700 ms, thử mở YouTube ở windowing mode freeform;
3. nếu lỗi, thử `FLAG_ACTIVITY_LAUNCH_ADJACENT`.

Script `tools/tbox/configure_multiwindow.sh` bật:

```text
enable_freeform_support=1
force_resizable_activities=1
```

ROM hoặc app đích vẫn có thể từ chối freeform/split-screen.

## Z-order và touch

- Maps dùng pane nền với `zOrderOnTop=false`.
- YouTube dùng pane trên với `zOrderOnTop=true`.
- Flutter `AndroidViewSurface` dùng eager gesture recognizer.
- Native SurfaceView forward motion, generic motion và key event.

Render đồng thời không đồng nghĩa touch hoạt động. Touch trên display phụ cần:

- gán `InputEvent.displayId`;
- gọi hidden `InputManager.injectInputEvent`;
- quyền `android.permission.INJECT_EVENTS` cho đường input trực tiếp có độ trễ thấp;
- hoặc bật `EmbeddedInputAccessibilityService` làm fallback khi ROM từ chối
  `INJECT_EVENTS`;
- SELinux/hidden API policy của ROM cho phép.

## Capability check

`VirtualDisplayEmbeddingCapability` trả supported khi:

- Android 10+;
- ROM quảng bá feature `android.software.activities_on_secondary_displays`;
- app có `ADD_TRUSTED_DISPLAY`. `INJECT_EVENTS` không còn chặn render; khi thiếu
  quyền này, thao tác được chuyển qua AccessibilityService trên Android 11+.

Accessibility fallback phải được người dùng bật trong Android Accessibility
settings. Nếu chưa bật, launcher giữ nguyên hình ảnh Virtual Display và hiện
thông báo hướng dẫn thay vì đóng pane.

## Lỗi thường gặp

| Thông báo | Nguyên nhân thường gặp |
|---|---|
| `Cannot embed Google Maps on this ROM` | ActivityView/TaskView host không được ROM hỗ trợ |
| `Cannot create VirtualDisplay on this ROM` | ROM chặn display flags hoặc thiếu quyền |
| `Requires ADD_TRUSTED_DISPLAY permission` | APK không có quyền privileged |
| `Permission Denial ... launchDisplayId` | Không được launch activity trên display phụ |
| `injectEvents=false` | Touch/key không thể chuyển sang app đích |

Xem thêm bằng chứng và so sánh phương án trong
[CARCAR_LAUNCHER_ANALYSIS.md](CARCAR_LAUNCHER_ANALYSIS.md).

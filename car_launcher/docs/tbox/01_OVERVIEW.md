# Tổng quan tích hợp TBox

## Mục tiêu

Car Launcher chạy như một ứng dụng thông thường trên TBox, hiển thị dashboard Flutter và
phối hợp với native Android để:

- mở ứng dụng đã cài;
- hiển thị Google Maps và YouTube đồng thời;
- nhúng app vào pane bằng `ActivityView` hoặc `VirtualDisplay`;
- chuyển touch/key vào app nằm trên display phụ;
- giữ settings và media controls bên trong ứng dụng.

## Kiến trúc

```text
Flutter UI
  |
  +-- MethodChannel/EventChannel --> MainActivity
  |
  +-- PlatformView ----------------> ActivityView / VirtualDisplay / Maps host
                                      |
Android services ---------------------+-- NotificationListener
```

## Ba mức khả năng

| Mức | Khả năng | Điều kiện |
|---|---|---|
| APK thường | Dashboard, mở app, settings trong app, fallback adjacent/freeform tùy ROM | Cài APK và cấp notification access nếu dùng media session |
| ROM hỗ trợ hidden API | Có thể tạo `ActivityView` hoặc launch app trên display phụ, phụ thuộc firmware | ROM expose API và không chặn lời gọi |
| Privileged/platform | Trusted `VirtualDisplay`, launch đúng display, inject touch/key | Platform-sign, priv-app allowlist, SELinux phù hợp |

## Luồng Maps + YouTube

Luồng ưu tiên hiện tại:

1. `virtual_display_app`: mỗi app chạy trên một `VirtualDisplay`.
2. Khi VirtualDisplay lỗi, thử `ActivityView`.
3. Khi không thể embed, dùng freeform window.
4. Nếu freeform không được hỗ trợ, dùng adjacent/split-screen.
5. Media Center trong app điều khiển playback khi không thể embed YouTube.

## Package được cho phép embed

Native VirtualDisplay hiện chỉ cho phép:

- `com.google.android.apps.maps`
- `com.google.android.youtube`

Whitelist nằm trong `VirtualDisplayAppView.kt`. Giới hạn này tránh biến native
bridge thành API launch/inject input tùy ý.

## Thành phần chính

| Thành phần | Vai trò |
|---|---|
| `MainActivity` | Đăng ký channel, PlatformView và các native action |
| `VirtualDisplayAppView` | Tạo display, launch app và forward input |
| `ActivityViewHelper` | Wrapper reflection cho hidden `android.app.ActivityView` |
| `MultiWindowLauncher` | Freeform/adjacent fallback |
| Flutter app shell | Nội dung toàn màn hình và settings trong ứng dụng |

## Trạng thái thực nghiệm Bengal

Debug test trên thiết bị Bengal xác nhận compatibility VirtualDisplay flags
`265` có thể render Maps và YouTube đồng thời mà không có system privilege.
Tuy nhiên launch vào display và chuyển touch/multi-touch/scroll/key vẫn bị chặn
khi thiếu `ADD_TRUSTED_DISPLAY`, `INJECT_EVENTS` hoặc policy tương ứng của ROM.

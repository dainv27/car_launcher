# Vận hành và chẩn đoán TBox

## Chuẩn bị

- Bật USB hoặc Wi-Fi ADB trên TBox.
- Chấp nhận authorization prompt.
- Cài Google Maps: `com.google.android.apps.maps`.
- Cài YouTube: `com.google.android.youtube`.
- Cài Car Launcher.

## Chẩn đoán nhanh

```bash
./tools/tbox/diagnose.sh
```

Script in:

- model, Android/API, build và root status;
- feature secondary display/freeform/PiP;
- global multi-window settings;
- permission/package flags của launcher;
- trạng thái cài Maps và YouTube;
- log gần nhất của embedding/multi-window.

## Bật multi-window fallback

```bash
./tools/tbox/configure_multiwindow.sh
adb reboot
```

Script bật freeform/resizable activity và thử cấp một số quyền. Lỗi khi cấp
permission privileged là bình thường trên firmware không root/platform-sign.

Cấp Notification access trong Settings để Media Center đọc MediaSession.

## Lệnh kiểm tra hữu ích

```bash
adb devices -l
adb shell getprop ro.build.version.release
adb shell getprop ro.build.version.sdk
adb shell pm list features
adb shell dumpsys package com.carlauncher.car_launcher
adb shell settings get global enable_freeform_support
adb shell settings get global force_resizable_activities
```

Theo dõi log:

```bash
adb logcat -s VirtualDisplayAppView ActivityViewHelper MultiWindowLauncher \
  GoogleMapsPlatformView
```

## Ma trận chẩn đoán

| Hiện tượng | Kiểm tra | Hướng xử lý |
|---|---|---|
| Settings không mở | App shell / route | Kiểm tra nút Settings và route Flutter |
| Media Center không có bài hát | Notification access, active MediaSession | Cấp access, mở app media và phát nội dung |
| Maps/YouTube chỉ hiện fallback | secondary-display feature, log permission | Tích hợp ROM hoặc dùng freeform/adjacent |
| Hai app render nhưng không touch | log `injectEvents` và `EmbeddedInputA11y` | Cấp `INJECT_EVENTS` hoặc bật Virtual display input fallback trong Accessibility settings |
| Release APK không cài | shared UID/signature | Dùng đúng platform key hoặc debug build |
| YouTube không nổi trên Maps | freeform support, app resize policy | Bật multi-window; kiểm tra ROM/app hỗ trợ |

## File công cụ

| File | Chức năng |
|---|---|
| `tools/tbox/diagnose.sh` | Thu thập trạng thái và log |
| `tools/tbox/configure_multiwindow.sh` | Bật freeform/resizable và thử grant |
| `tools/tbox/privapp-permissions-com.carlauncher.car_launcher.xml` | Allowlist mẫu cho ROM |

## Quy trình lấy bug report

1. Chạy `./tools/tbox/diagnose.sh`.
2. Xóa log cũ bằng `adb logcat -c`.
3. Tái hiện lỗi.
4. Lưu log embedding/sidebar/multi-window.
5. Ghi rõ model TBox, Android/API, build ID, loại APK và quyền đã cấp.

# ROM, platform-sign và quyền hệ thống

## Quyền khai báo

Manifest hiện yêu cầu các quyền liên quan TBox:

| Permission | Mục đích |
|---|---|
| `QUERY_ALL_PACKAGES` | App drawer / launch app |
| `ADD_TRUSTED_DISPLAY` | Trusted VirtualDisplay |
| `MANAGE_ACTIVITY_TASKS` / `MANAGE_ACTIVITY_STACKS` | Quản lý task/display |
| `INJECT_EVENTS` | Chuyển touch/key sang app/display khác |
| `ACTIVITY_EMBEDDING` | Activity embedding |
| `REORDER_TASKS` | Điều phối task |

Chỉ khai báo permission không đồng nghĩa được cấp. Các quyền như
`ADD_TRUSTED_DISPLAY`, `INJECT_EVENTS`, `MANAGE_ACTIVITY_TASKS` và
`ACTIVITY_EMBEDDING` thường là signature/privileged.

## Điều kiện để có quyền privileged

Một tích hợp ROM đầy đủ thường cần:

1. APK được ký bằng TBox platform private key.
2. APK nằm trong đúng `priv-app` partition.
3. Priv-app permission allowlist ở cùng partition.
4. Release manifest/shared UID tương thích với ROM.
5. SELinux policy cho phép display/task/input operation.
6. Hidden API policy hoặc vendor API không chặn lời gọi.

Allowlist mẫu:

```text
tools/tbox/privapp-permissions-com.carlauncher.car_launcher.xml
```

## Platform certificate

Certificate công khai chỉ xác minh chữ ký; nó không thể dùng để tạo chữ ký mới.
Sao chép certificate từ CarCar Launcher không cung cấp private key và không làm
ứng dụng được platform-sign.

Private key đúng phải đến từ vendor/đơn vị build ROM. Không nên nhúng key này
vào repository.

## Kiến trúc production khuyến nghị

Thay vì cấp toàn bộ quyền cho Flutter app, nên đặt display launch và input
injection trong một broker service nhỏ:

```text
Flutter launcher
  -> signature-protected Binder API
  -> platform-signed broker
  -> display/task/input system APIs
```

Broker chỉ cho phép package, display và action đã whitelist. Không expose API
launch package hoặc inject event tùy ý.

## Những việc ADB không giải quyết được

`pm grant` không thể cấp permission signature cho APK không được ký phù hợp.
Copy APK thường vào `/system/priv-app` cũng không tự cấp quyền và có thể làm
thiết bị boot-loop nếu shared UID/signature sai.

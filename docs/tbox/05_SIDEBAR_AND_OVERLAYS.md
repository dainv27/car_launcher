# Điều hướng trong ứng dụng

Car Launcher đăng ký làm HOME launcher (intent categories `MAIN` + `HOME` +
`DEFAULT` + `LAUNCHER`) và có thể thay thế launcher gốc của thiết bị, không
cần root. Người dùng có thể chọn nó làm Home mặc định trong Settings > Apps >
Default apps > Home app, hoặc bấm nút "Set as Default Launcher" trong
Settings > System Info (gọi `RoleManager` trên Android 10+, hoặc mở thẳng màn
hình Settings đó trên bản cũ hơn). Ứng dụng không tạo taskbar hoặc media
controls dạng system overlay.

## App shell

`lib/main.dart` dựng một app shell Flutter dùng toàn bộ cửa sổ:

- không có taskbar hoặc sidebar cố định;
- Settings mở từ nút trong `TopAppBar`;
- các route nội bộ điều hướng bằng `GoRouter`;
- Back sử dụng hành vi chuẩn của Android/router.

Settings nằm hoàn toàn trong route `/settings`. Các tùy chọn taskbar native cũ
đã được loại bỏ.

## Hành vi ngoài ứng dụng

Khi mở một ứng dụng ngoài ở chế độ toàn màn hình, Car Launcher không hiển thị
điều khiển phía trên ứng dụng đó. Đây là hành vi chủ ý của một ứng dụng Android
thông thường.

Pane nhúng bằng `VirtualDisplay` (`virtual_display_app`, dùng cho Maps/YouTube
trên Dashboard) vẫn có thể hiển thị ứng dụng khác bên trong Car Launcher nếu
firmware cấp đủ quyền tương ứng. Đường `ActivityView` (`embedded_app_pane`)
còn tồn tại ở phía native nhưng không còn widget Flutter nào gọi tới — xem
[04_EMBEDDED_APPS.md](04_EMBEDDED_APPS.md).

## Media

Media Center trong app đọc active MediaSession thông qua Notification Listener.
Người dùng có thể cần mở Android Settings để cấp Notification access; ứng dụng
không yêu cầu quyền `SYSTEM_ALERT_WINDOW`.

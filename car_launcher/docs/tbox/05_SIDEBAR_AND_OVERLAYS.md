# Điều hướng trong ứng dụng

Car Launcher không còn tạo taskbar hoặc media controls dạng system overlay.
Ứng dụng cũng không đăng ký làm HOME launcher và không tự khởi động service sau
boot.

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

Các pane nhúng bằng `ActivityView` hoặc `VirtualDisplay` vẫn có thể hiển thị
ứng dụng khác bên trong Car Launcher nếu firmware cấp đủ quyền tương ứng.

## Media

Media Center trong app đọc active MediaSession thông qua Notification Listener.
Người dùng có thể cần mở Android Settings để cấp Notification access; ứng dụng
không yêu cầu quyền `SYSTEM_ALERT_WINDOW`.

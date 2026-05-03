# Kế hoạch dự án — Car Launcher

## 1. Mục tiêu

- Ứng dụng **launcher** (màn hình Home) cho thiết bị Android trên xe / Android box.
- UI phù hợp **ngang màn hình**, nút bấm **lớn**, thao tác nhanh khi lái (tuân thủ luật địa phương).

## 2. Phạm vi phiên bản đầu (MVP)

- [ ] Activity làm **HOME** mặc định (đã khai báo trong manifest).
- [ ] Hiển thị **lưới ứng dụng** đã cài (resolve `MAIN` / `LAUNCHER`).
- [ ] Mở ứng dụng khi chạm; nút hoặc cử chỉ **quay về Home**.
- [ ] Chạ ổn định **landscape**, không crash khi đổi cấu hình cơ bản.

## 3. Hướng phát triển tiếp

- Chủ đề **sáng/tối**, wallpaper.
- Nhóm app (Bản đồ, Nhạc, Tiện ích).
- Shortcut tới app hay dùng; tùy chọn ẩn app hệ thống.

## 4. Rủi ro / ràng buộc

- **Android 11+**: truy vấn danh sách app cần `<queries>` hoặc quyền phù hợp; phân phối Play Store có quy tắc riêng với `QUERY_ALL_PACKAGES`.
- **ROM OEM**: một số box hạn chế đặt launcher mặc định hoặc tự khởi động lại app khác.
- **An toàn lái xe**: giảm nhập liệu phức tạp; cân nhắc disclaimer cho người dùng.

## 5. Kiểm thử

- Thiết bị / emulator **API 26+** (theo `minSdk` hiện tại).
- Kiểm tra đặt làm **launcher mặc định** và nút Home phần cứng (nếu có).

## 6. Ghi chú phiên bản

| Ngày | Nội dung |
|------|----------|
| 2026-05-03 | Khởi tạo project Android (Kotlin, Compose), intent HOME, Gradle Wrapper, thư mục `doc/` |

*(Cập nhật bảng khi có milestone.)*

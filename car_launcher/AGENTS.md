# AGENT DIRECTIVE: PROJECT-LEVEL RULES INJECTION

Bạn là một AI Agent điều phối mã nguồn cấp dự án. Trước khi thực hiện bất kỳ hành động nào (đọc, viết, sửa đổi mã nguồn hoặc trả lời câu hỏi), bạn BẮT BUỘC phải thực hiện quy trình nạp cấu hình dưới đây:

## 1. Yêu cầu Nạp Quy tắc (Rules Ingestion)
- Quét và đọc toàn bộ nội dung các tệp tin cấu hình quy tắc nằm trong thư mục `ai/rules/`:
  - `architecture_rules.md` — kiến trúc Riverpod + Clean Architecture, quy ước đặt tên, quy tắc domain đặc thù (native bridge, vehicle tracking, launcher, OIDC, layout).
  - `common_rules.md` — hướng dẫn chung cho Flutter/Dart (style, theming, layout, testing, a11y).
  - `testing_rules.md` — quy trình test: `flutter test`, `mocktail`, coverage, cấu trúc thư mục test.
- Phân tích sâu bộ quy tắc để hiểu: Kiến trúc thư mục, Quy ước đặt tên file/lớp, Quy trình xử lý logic/lỗi đặc thù của dự án.

## 2. Nguyên tắc Áp dụng ở Cấp độ Dự án (Project-Level Execution)
- **Tính tối thượng:** Bộ quy tắc được nạp từ `ai/rules/` là "Luật tối cao" của dự án này. Nội dung trong đó có giá trị cao hơn kiến thức mặc định hoặc thói quen viết code thông thường của bạn. Nếu `common_rules.md` mâu thuẫn với `architecture_rules.md`, **architecture_rules.md thắng** (nó project-specific).
- **Tính nhất quán:** Mọi tệp tin bạn tạo mới hoặc chỉnh sửa phải tuân thủ 100% cấu trúc và tiêu chuẩn đã nạp. Không được tự ý thay đổi kiến trúc (ví dụ: không được đổi từ Riverpod sang ChangeNotifier, không đổi hậu tố đặt tên).
- **Kiểm tra chéo (Self-Verification):** Trước khi xuất phản hồi hoặc mã nguồn cuối cùng, hãy tự đối chiếu lại với bộ quy tắc đã nạp xem có vi phạm điểm nào không (Ví dụ: Đã dispose stream/controller chưa? Đã wrap MethodChannel qua NativeBridge chưa? Đã đặt đúng thư mục `presentation/providers/` chưa?).

## 3. Phản hồi Xác nhận (Acknowledge)
Hãy phản hồi lại cho tôi bằng cách liệt kê:
1. Danh sách các tệp tin quy tắc bạn đã tìm thấy và nạp thành công từ thư mục chỉ định.
2. Tóm tắt ngắn gọn 3 điểm cốt lõi nhất trong bộ quy tắc đó mà bạn sẽ áp dụng cho các yêu cầu tiếp theo của tôi.

## 4. Tài liệu thiết kế kiến trúc & tích hợp hệ thống
- Quét và đọc toàn bộ tài liệu kiến trúc nằm trong thư mục `docs/design/` và `docs/code_guide/`.
- Đọc `docs/FEATURES.md`, `docs/USE_CASES.md`, `docs/VEHICLE_TRACKING.md` để hiểu nghiệp vụ.

> ⚠️ **Lưu ý:** Nếu cần tham chiếu tài liệu nghiệp vụ / API spec bên ngoài repo, người dùng sẽ cung cấp đường dẫn cụ thể cho máy đó. **Không** hardcode đường dẫn máy cá nhân vào rules.

## 5. Tài liệu API specs
- Tham chiếu `docs/` và mã nguồn `lib/core/api/`, `lib/features/*/data/` để hiểu API contract hiện tại.
- Nếu có tài liệu OpenAPI/Swagger riêng, người dùng sẽ chỉ định.

## 6. Môi trường & bảo mật
- **Không** bao giờ commit file `.env` chứa secret thật. Chỉ commit `.env.development` / `.env.production` (đã được whitelist trong `.gitignore`).
- Token/sensitive data chỉ lưu trong `flutter_secure_storage`, không trong `shared_preferences`.

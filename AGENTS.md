# AGENT DIRECTIVE: PROJECT-LEVEL RULES INJECTION

Bạn là một AI Agent điều phối mã nguồn cấp dự án. Trước khi thực hiện bất kỳ hành động nào (đọc, viết, sửa đổi mã nguồn hoặc trả lời câu hỏi), bạn BẮT BUỘC phải thực hiện quy trình nạp cấu hình dưới đây:

## 1. Yêu cầu Nạp Quy tắc (Rules Ingestion)
- Hãy quét và đọc toàn bộ nội dung các tệp tin cấu hình quy tắc nằm trong thư mục: `ai/rules` (Ví dụ: `.github/linters/`, `config/ai_rules/`, `*_rules.md`, hoặc `.cursorrules`).
- Hãy phân tích sâu bộ quy tắc này để hiểu về: Kiến trúc thư mục, Quy ước đặt tên file/lớp, và Quy trình xử lý logic/lỗi đặc thù của dự án này.

## 2. Nguyên tắc Áp dụng ở Cấp độ Dự án (Project-Level Execution)
- **Tính tối thượng**: Bộ quy tắc được nạp từ thư mục trên là "Luật tối cao" của dự án này. Nội dung trong đó có giá trị cao hơn tất cả các kiến thức mặc định hoặc thói quen viết code thông thường của bạn.
- **Tính nhất quán**: Mọi tệp tin bạn tạo mới hoặc chỉnh sửa phải tuân thủ 100% cấu trúc và tiêu chuẩn đã nạp. Không được tự ý thay đổi kiến trúc (ví dụ: không được đổi từ Clean Architecture sang MVC, không thay đổi hậu tố đặt tên).
- **Kiểm tra chéo (Self-Verification)**: Trước khi xuất phản hồi hoặc mã nguồn cuối cùng, hãy tự đối chiếu lại với bộ quy tắc đã nạp xem có vi phạm điểm nào không (Ví dụ: Đã xử lý lỗi đồng bộ chưa? Đã đặt đúng thư mục `shared/` hay `features/` chưa?).

## 3. Phản hồi Xác nhận (Acknowledge)
Hãy phản hồi lại cho tôi bằng cách liệt kê:
1. Danh sách các tệp tin quy tắc bạn đã tìm thấy và nạp thành công từ thư mục chỉ định.
2. Tóm tắt ngắn gọn 3 điểm cốt lõi nhất trong bộ quy tắc đó mà bạn sẽ áp dụng cho các yêu cầu tiếp theo của tôi.

## 4. Tài liệu thiết kế kiến trục và tích hợp hệ thống
- Quét và đọc toàn bộ tài liệu kiến trúc nằm trong thư muck: `/Volumes/Data/Git/tzt/vehicle_service/docs/archi`

## 5. Tài liều nghiệp vụ
- Quét và đọc toàn bộ tài liệu nghiệp vụ nằm trong thư muck: `/Volumes/Data/Git/tzt/vehicle_service/docs/biz`

## 6. Tài liệu API specs
- Quét và đọc toàn bộ tài liệu thiết kế API nằm trong thư muck: `/Volumes/Data/Git/tzt/vehicle_service/api-spec`

## 7. Test user
- username: dainv
- password: 1

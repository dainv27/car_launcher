# Flutter Provider & Clean Architecture Coding Standards

Bạn là một chuyên gia lập trình Flutter cấp cao. Khi phát triển hoặc tối ưu hóa mã nguồn, bạn phải tuân thủ nghiêm ngặt các quy tắc dưới đây về kiến trúc Clean Architecture tinh gọn, quản lý phạm vi cập nhật của `provider`, đặt tên file và xử lý lỗi đồng bộ bằng gói `flash`.

## 1. Kiến trúc Clean Architecture Tinh gọn (Lean Clean Architecture)
Để tối ưu cho team nhỏ nhưng giữ khả năng mở rộng (scale) tốt, cấu trúc hệ thống được chia làm 3 lớp cốt lõi, loại bỏ các file boilerplate không cần thiết (như UseCases đơn giản trừ khi thực sự phức tạp):
- **Presentation Layer (Giao diện & Trạng thái)**: Gồm Widgets/Views (chỉ hiển thị dữ liệu) và `_provider.dart` (quản lý trạng thái, nhận sự kiện từ UI và gọi lớp Repository).
- **Domain/Repository Layer (Nghiệp vụ)**: Định nghĩa các lớp `Repository` chịu trách nhiệm xử lý logic nghiệp vụ, điều phối dữ liệu từ Local/Remote.
- **Data Layer (Nguồn dữ liệu)**: Gồm các Data Sources (API Client, Database Helper) và Models (DTOs) để chuyển đổi dữ liệu thô.

## 2. Quản lý Phạm vi Provider & Cấu trúc Thư mục (Scope & Folder Structure)
- **Quy tắc Phạm vi (Scope Rule)**: Mỗi Provider phải có phạm vi hoạt động (Scope) rõ ràng. Các Feature Provider phục vụ cho một màn hình/tính năng cụ thể **KHÔNG ĐƯỢC phép sử dụng chồng chéo** hoặc gọi chéo sang UI của tính năng khác.
- **Provider Dùng chung (Shared Providers)**: Các trạng thái toàn cục hoặc dùng chung cho nhiều module (như `AuthProvider`, `ThemeProvider`, `CartProvider`) bắt buộc phải đặt trong thư mục `shared/providers/` độc lập.

### Sơ đồ cấu trúc thư mục chuẩn:
```text
lib/
├── core/                        # Tiện ích hệ thống, cấu hình network, theme, lỗi chung
├── shared/                      # Các thành phần dùng chung toàn ứng dụng
│   ├── providers/               # 📂 Nơi chứa các Shared Provider (Ví dụ: auth_provider.dart)
│   └── widgets/                 # Các widget giao diện dùng chung (Button, Text field...)
└── features/                    # Các module tính năng độc lập (Dễ scale bằng cách thêm feature mới)
    ├── auth/                    # Tính năng xác thực
    │   ├── data/                # Data sources, Models
    │   ├── repositories/        # AuthRepository
    │   └── presentation/        # UI & Feature Providers
    │       ├── providers/       # 📂 Chỉ dùng nội bộ trong module auth (Ví dụ: login_provider.dart)
    │       └── views/           # Các màn hình (LoginScreen, RegisterScreen)
    └── products/                # Tính năng sản phẩm (Cấu trúc tương tự)
```

## 3. Quy ước Đặt tên & Cấu trúc File (Naming Conventions)
- **Tên file**: File chứa lớp quản lý trạng thái bằng Provider bắt buộc phải dùng hậu tố `_provider.dart` (Ví dụ: `login_provider.dart`, `auth_provider.dart`).
- **Tên lớp**: Lớp quản lý trạng thái phải kết thúc bằng chữ `Provider` (Ví dụ: `class LoginProvider extends ChangeNotifier`).
- **Phát sinh code (Code Generation)**: Nếu dự án dùng `freezed`, `json_serializable`, luôn tự động thêm dòng `part 'filename.g.dart';` hoặc `part 'filename.freezed.dart';` ngay dưới danh sách import.

## 4. Quản lý Lỗi Đồng bộ & Hiển thị Giao diện với Flash
Tuyệt đối KHÔNG import thư viện giao diện, không gọi trực tiếp cấu trúc hộp thoại (`showFlash`, `context.showFlashBar`) bên trong lớp Provider để giữ tính độc lập khi viết Unit Test.

### Thiết kế State trong Provider:
- Cung cấp thuộc tính `errorMessage` kiểu dữ liệu chuỗi có thể null (`String?`).
- Cung cấp hàm `clearError()` để xóa trạng thái lỗi sau khi giao diện đã tiếp nhận và hiển thị xong.

### Xử lý Đồng bộ tại lớp UI (View/Widget):
- Sử dụng phương thức `context.select<T, R>` hoặc widget `Selector` để chỉ định nghe duy nhất thuộc tính lỗi từ Provider.
- Sử dụng phương thức `WidgetsBinding.instance.addPostFrameCallback` để bọc hàm hiển thị của gói `flash`, tránh xung đột trong quá trình render cây widget (xung đột build phase).
- Ngay sau khi lệnh hiển thị `flash` được kích hoạt, phải gọi lệnh xóa lỗi `context.read<T>().clearError()` để reset trạng thái.

```dart
// ✅ ĐÚNG: Feature Provider sạch, nằm trong phạm vi một màn hình, không chứa logic UI
class LoginProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  LoginProvider(this._authRepository);

  Future<void> login(String email, String password) async {
    _errorMessage = null;
    notifyListeners();
    try {
      await _authRepository.login(email, password);
    } catch (e) {
      _errorMessage = e.toString(); // Gán thông điệp lỗi đồng bộ
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

// ✅ ĐÚNG: UI lắng nghe thuộc tính lỗi và kích hoạt gói 'flash' an toàn
class LoginButton extends StatelessWidget {
  const LoginButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Chỉ lắng nghe duy nhất thuộc tính errorMessage
    final error = context.select<LoginProvider, String?>((p) => p.errorMessage);

    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showFlash(
          context: context,
          duration: const Duration(seconds: 3),
          builder: (context, controller) {
            return FlashBar(
              controller: controller,
              behavior: FlashBehavior.floating,
              content: Text(error),
            );
          },
        );
        // Reset trạng thái lỗi ngay lập tức để tránh lặp lại hành động
        context.read<LoginProvider>().clearError();
      });
    }

    return ElevatedButton(
      onPressed: () => context.read<LoginProvider>().login('email', 'pass'),
      child: const Text('Đăng nhập'),
    );
  }
}
```

## 5. Vòng đời, Khởi tạo & Kiểm soát Rebuild (Context Lookups)
- **Khởi tạo đúng phạm vi**: Tiêm (Inject) Feature Provider bằng `ChangeNotifierProvider` ngay tại vị trí cao nhất của màn hình đó trong thư mục `views/` để đảm bảo khi tắt màn hình, Provider tự động được giải phóng (dispose). Không khai báo Feature Provider bừa bãi ở cấp toàn cục (Global).
- **Khởi tạo mới**: Dùng hàm khởi tạo mặc định của hệ thống với tham số `create`. Không dùng `.value`.
    * *Hợp lệ*: `ChangeNotifierProvider(create: (_) => LoginProvider(context.read<AuthRepository>()))`
- **Tái sử dụng**: Dùng `.value` khi muốn truyền một instance đã tồn tại sẵn từ trước xuống cây widget bên dưới.
    * *Hợp lệ*: `ChangeNotifierProvider.value(value: existingProvider)`
- **Trong hàm build (Dữ liệu cụ thể)**: Luôn ưu tiên dùng `context.select<T, R>((t) => t.property)` để tối ưu hóa hiệu năng, giảm số lần rebuild không đáng có.
- **Trong Sự kiện (Callbacks)**: Chỉ dùng `context.read<T>()` bên trong các hàm xử lý sự kiện (như `onPressed`, `onTap`). Nghiêm cấm dùng `context.read` trực tiếp ngoài luồng build của widget.

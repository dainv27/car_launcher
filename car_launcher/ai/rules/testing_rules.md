# Testing Rules — Flutter / Riverpod / Car Launcher

Bạn là một chuyên gia testing Flutter. Mọi thay đổi mã nguồn trong dự án này BẮT BUỘC phải tuân thủ quy trình test dưới đây. TDD là bắt buộc.

## 1. Nguyên tắc chung

- **TDD:** Viết test trước → chạy và thấy FAIL → viết implementation → test PASS.
- **Test command:** `flutter test`
- **Coverage command:** `flutter test --coverage`
- **Coverage report (HTML):** `genhtml coverage/lcov.info -o coverage/html && open coverage/html/index.html`
- **Coverage threshold:** được định nghĩa trong `.coverage-thresholds.json` (nếu file tồn tại). Đây là **blocking gate** trước khi tạo PR.
- **Mocking:** dùng **`mocktail`** (null-safe). **Không** dùng `mockito`.
- **Fakes > Mocks:** Ưu tiên fake/stub object thay mock khi có thể — test sẽ ít brittle hơn.

## 2. Cấu trúc thư mục test

`test/` phải **mirror** `lib/`:

```
lib/features/vehicle/data/vehicle_repository.dart
test/features/vehicle/data/vehicle_repository_test.dart

lib/features/dashboard/presentation/providers/theme_provider.dart
test/features/dashboard/presentation/providers/theme_provider_test.dart
```

- **Widget test:** cùng thư mục với widget, hậu tố `_test.dart`.
- **Contract test:** test xác nhận contract (API response shape, model serialization) — đặt cùng với file đang test.
- **Integration test:** đặt trong `integration_test/` (không phải `test/`).
- **Test helper / fake:** đặt trong `test/test_helpers/` hoặc `test/fakes/`.

## 3. Các loại test bắt buộc

### 3.1. Unit test (logic thuần)
- Domain logic, data transformation, extension methods.
- Không cần `testWidgets`, dùng `test()`.

```dart
test('parseTrackingPoint returns null for malformed JSON', () {
  final result = parseTrackingPoint({'lat': 'not-a-number'});
  expect(result, isNull);
});
```

### 3.2. Riverpod notifier test
- Dùng `ProviderContainer` để tạo container, đọc provider, assert state.
- Override dependency (repository, service) bằng mock/fake.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test('VehicleListNotifier loads vehicles', () async {
    final container = ProviderContainer(overrides: [
      vehicleRepositoryProvider.overrideWithValue(FakeVehicleRepository()),
    ]);
    addTearDown(container.dispose);

    final notifier = container.read(vehicleListNotifierProvider.notifier);
    await notifier.refresh();

    final state = container.read(vehicleListNotifierProvider);
    expect(state.hasValue, isTrue);
    expect(state.value, hasLength(2));
  });
}
```

### 3.3. Widget test
- Dùng `testWidgets`.
- Bọc widget trong `ProviderScope` (và `MaterialApp` nếu cần navigation/theme).
- Override các provider phụ thuộc bằng mock/fake — **không** gọi network/native thật.

```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      vehicleListNotifierProvider.overrideWith(() => FakeVehicleListNotifier()),
    ],
    child: const MaterialApp(home: VehicleListPage()),
  ),
);
```

### 3.4. Contract test
- Xác nhận DTO serialize/deserialize đúng (json_serializable).
- Xác nhận API response shape khớp với model.
- Đặt cùng file hoặc `*_contract_test.dart`.

### 3.5. Integration test
- Dùng package `integration_test` (đã có trong `integration_test/`).
- Chạy trên thiết bị thật/emulator: `flutter test integration_test/`.
- Kiểm tra end-to-end flow (login → load dashboard → launch app).

## 4. Quy tắc mock & dependency

- **Mock `NativeBridge`** — test KHÔNG được phụ thuộc vào native side. Fake `NativeBridge.call` trả về giá trị giả.
- **Mock repository** — widget/provider test override repository bằng fake.
- **Không** mock Flutter framework widgets (MaterialApp, Scaffold) — dùng thật.
- **Không** dùng `fakeAsync` cho Riverpod async state trừ khi thực sự cần kiểm soát timer.

## 5. Assertions

- Dùng matcher của `package:tests` (built-in flutter_test) hoặc `package:checks` nếu có.
- Ưu tiên matcher có ý nghĩa: `isA<Type>()`, `hasLength(n)`, `predicate(...)`, thay vì `equals` cho object phức tạp.
- Test cả happy path VÀ error path.

## 6. Coverage

- Chạy `flutter test --coverage` trước khi commit nếu thay đổi logic.
- Xem `coverage/lcov.info` hoặc mở HTML report.
- Nếu coverage giảm, viết thêm test trước khi thêm code mới.
- File `.coverage-thresholds.json` là source of truth — không được bypass.

## 7. Quy tắc "KHÔNG ĐƯỢC" trong test

| # | Quy tắc |
|---|---|
| 1 | **Không** gọi network thật trong unit/widget test — mock repository. |
| 2 | **Không** gọi `MethodChannel` / native thật — mock `NativeBridge`. |
| 3 | **Không** dùng `mockito` — dùng `mocktail`. |
| 4 | **Không** skip test bằng `@Skip` vĩnh viễn — fix hoặc xóa. |
| 5 | **Không** assert bằng `expect(true, isTrue)` vô nghĩa — assert behavior thật. |
| 6 | **Không** viết test sau khi viết implementation mà không thấy FAIL trước. |
| 7 | **Không** commit nếu coverage dưới threshold trong `.coverage-thresholds.json`. |

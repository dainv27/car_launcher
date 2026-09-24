# 13 — Thời tiết & đồng hồ

Updated: 2026-08-29
Status: implemented
Nguồn: `lib/shared/data/weather_service.dart`,
`lib/features/dashboard/presentation/providers/weather_providers.dart`,
`lib/features/dashboard/presentation/providers/dashboard_providers.dart` (`clockProvider`),
`lib/features/dashboard/presentation/widgets/weather_clock_widget.dart`,
`lib/features/settings/presentation/widgets/weather_settings_dialog.dart`

## 1. Mục tiêu & phạm vi

Widget dashboard hiển thị giờ hiện tại và thời tiết theo thành phố (OpenWeatherMap).

## 2. Đồng hồ

`clockProvider` — `StateNotifier<String>`, `Timer.periodic(1s)`, format `HH:mm`.
`ClockNetworkSettingsPage` có toggle `use24HourTime` (`carPlaySettingsProvider`),
và `dynamicClockNetwork` (ẩn đồng hồ/mạng 5s sau khi chạm màn hình — xem
`overlayVisibleProvider` trong [03](03-dashboard.md)).

## 3. Thời tiết

```
WeatherNotifier (StateNotifier<AsyncValue<WeatherData?>>)
   │
   ▼
WeatherService  ── http.Client (AuthInterceptorClient) ──►  api.openweathermap.org/data/2.5/weather
```

- `WeatherService(_prefs, _client)` — lazySingleton (DI).
  - `fetchWeatherByCity(city)` — cần `weather_api_key` trong `SharedPreferences`;
    timeout 10s; parse `WeatherData.fromJson` (Kelvin→°C).
  - `fetchWeatherByCoords(lat, lon)` — biến thể theo toạ độ.
- `WeatherData`: `cityName`, `temperature` (°C), `description`, `iconCode`,
  `humidity`, `windSpeed`.
- `WeatherNotifier`:
  - `_loadWeather()` đọc `weather_city`; rỗng → `AsyncData(null)`.
  - `setCity()` / `setApiKey()` lưu prefs rồi nạp lại.
  - `refreshForCoords()` cho vị trí hiện tại.
  - Chống race bằng `_requestGeneration`.

Cấu hình qua `weather_settings_dialog.dart` (mục Settings). Keys `SharedPreferences`:
`weather_api_key`, `weather_city`.

## 4. Quyết định thiết kế & đánh đổi

- **API key OpenWeatherMap do người dùng nhập** (không nhúng sẵn) — tránh lộ key
  dùng chung; đổi lại người dùng phải tự cấu hình mới có thời tiết.
- **Fetch theo tên thành phố là mặc định**, theo toạ độ là tuỳ chọn — đơn giản,
  không phụ thuộc quyền vị trí; kém chính xác khi di chuyển.
- **`iconAsset` trả rỗng** — hiện map icon theo điều kiện trong widget, chưa có
  asset icon thời tiết.
- Dùng chung `http.Client` có `AuthInterceptorClient`, nhưng host OpenWeatherMap
  không thuộc whitelist nên không bị chèn Bearer.

## 5. Edge case

- Thiếu API key hoặc city → trả `null`, widget hiển thị trạng thái trống, log
  cảnh báo.
- HTTP ≠ 200 hoặc timeout → `null` (không ném lên UI).

## 6. Kiểm thử

Bao phủ gián tiếp qua `test/design_screens_test.dart`,
`test/real_data_contract_test.dart` (chưa có unit test riêng cho `WeatherService`).

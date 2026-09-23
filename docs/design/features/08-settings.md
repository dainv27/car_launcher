# 08 — Settings

Updated: 2026-08-29
Status: implemented
Route: `/settings` (+ `/settings/account`, `/settings/clock-network`,
`/settings/logs`, `/settings/vehicle`, `/settings/tracking`)
Nguồn: `lib/features/settings/presentation/settings_page.dart`,
`lib/features/settings/presentation/clock_network_settings_page.dart`,
`lib/features/settings/presentation/log_viewer_page.dart`,
`lib/features/settings/presentation/providers/brightness_provider.dart`,
`lib/features/settings/presentation/widgets/weather_settings_dialog.dart`

## 1. Mục tiêu & phạm vi

Trang cấu hình hai cột (sidebar danh mục + vùng chi tiết). Tất cả tuỳ chọn của
launcher nằm trong `/settings`; deep-link vào từng mục qua `initialCategory`.

## 2. Danh mục (`_CategorySidebar._categories`, index cố định)

| idx | Danh mục | Section widget | Ghi chú |
|---|---|---|---|
| 0 | Appearance | `_AppearanceSection` | theme style, sáng/tối, wallpaper, brightness, transparency, fluid animations |
| 1 | Dashboard | `_DashboardSection` | `HomeViewMode`, tuỳ chọn dashboard |
| 2 | Navigation | `_NavigationSection` | app điều hướng mặc định |
| 3 | Media & Sound | `_MediaSection` | app media mặc định |
| 4 | Connectivity | `_ConnectivitySection` | trạng thái Wi‑Fi/BT/VPN (chỉ đọc) |
| 5 | Account | `_AccountSection` | Keycloak — xem [09](09-account-authentication.md) |
| 6 | System Info | `_SystemInfoSection` | version/build, hidden apps, link logs |
| 7 | Vehicle | `_VehicleSection` | cần đăng nhập → `/vehicles` — xem [11](11-vehicle-management.md) |
| 8 | Tracking | `_TrackingSection` | cần đăng nhập → `VehicleTrackingSettingsCard` — xem [12](12-vehicle-tracking.md) |

`SettingsPage(initialCategory: N)` được clamp `0..8`. Route `/settings/account`
map `initialCategory: 5`, `/settings/vehicle` → 7, `/settings/tracking` → 8.

## 3. Responsive

`CarResponsive.isCompact` (width < 1200), `ultraCompact` (width < 1100),
`isShort` (height < 650). `useCompactCategories = ultraCompact || short` → đổi
sidebar dọc thành `_CompactCategoryBar` (thanh ngang cuộn). Sidebar rộng
240/350px tuỳ compact.

## 4. State management

Trang giữ `_selectedCategory` là local state. `ref.listen(loginSuccessFlagProvider)`
→ tự nhảy sang mục Account (5) sau khi đăng nhập thành công.

Provider dùng trong các section:

| Provider | Nguồn | Persist |
|---|---|---|
| `launcherAppearanceProvider` / `themeModeProvider` | [10](10-theme-and-appearance.md) | `SharedPreferences` |
| `brightnessProvider` (`BrightnessSettings{brightness, autoBrightness}`) | native + prefs | `SharedPreferences` keys `screen_brightness`, `auto_brightness`; đẩy xuống native (`setScreenBrightness`, `setAutoBrightness`) |
| `carPlaySettingsProvider` | dashboard | `SharedPreferences` |
| `accountSessionProvider` | [09](09-account-authentication.md) | secure storage (OIDC) |
| `hiddenAppsProvider` | local `StateNotifier` (in-memory) | — chưa persist |
| `defaultNavProvider` / `defaultMediaProvider` | `StateProvider<String>` | — chưa persist |

Một số tuỳ chọn Appearance (`_transparency`, `_dynamicAccents`, `_fluidAnimations`)
hiện là `setState` local, **chưa persist / chưa tác động thực**.

## 5. Trang phụ

- `ClockNetworkSettingsPage` (`/settings/clock-network`) — 4 toggle
  (`dynamicClockNetwork`, `use24HourTime`, `showVpnStatus`, `dockPinned`) map vào
  `carPlaySettingsProvider`, style `CupertinoSwitch`.
- `LogViewerPage` (`/settings/logs`) — xem file log của `AppLogger`.
- `weather_settings_dialog.dart` — nhập API key + thành phố cho thời tiết
  (xem [13](13-weather-and-clock.md)).
- Wallpaper: `_pickWallpaper` dùng `image_picker` → copy file vào
  `getApplicationSupportDirectory()/wallpapers/` → `setCustomWallpaperPath`.

## 6. Quyết định thiết kế & đánh đổi

- **Danh mục đánh số cố định 0–8**: deep-link đơn giản (`initialCategory`), nhưng
  chèn/xoá mục giữa danh sách sẽ lệch số ở nhiều nơi (route, `loginSuccessFlag`).
- **Section là widget private trong một file lớn** (`settings_page.dart` ~1.8k
  dòng) — mọi thứ ở một chỗ, nhưng file to, khó điều hướng.
- **Vài toggle Appearance mới là mock UI** — trực quan hoá sớm, chưa nối logic.
- **Brightness đồng bộ hai chiều với native** (`syncFromNative`) — nguồn sự thật
  là hệ thống; đổi lại phải xử lý trường hợp native không có (test) bằng
  in-memory default.

## 7. Edge case

- Chưa đăng nhập mà mở mục Vehicle/Tracking → `LoginRequiredWidget`.
- Auto‑brightness bật → ẩn slider brightness, chỉ hiện nhãn "Auto".
- `SharedPreferences` null trong test → `BrightnessNotifier` dùng default 0.85 /
  autoBrightness true.

## 8. Kiểm thử

`test/settings_design_test.dart`, `test/design_screens_test.dart`,
`test/responsive_screens_test.dart`, `test/launcher_appearance_contract_test.dart`.

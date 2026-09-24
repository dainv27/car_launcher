# 10 — Theme & giao diện (sáng/tối tự động)

Updated: 2026-08-29
Status: implemented
Nguồn: `lib/core/theme/app_theme.dart`, `lib/core/theme/launcher_appearance.dart`,
`lib/core/theme/carplay_theme.dart`,
`lib/features/theme/presentation/providers/theme_providers.dart`,
`lib/features/theme/presentation/providers/launcher_appearance_provider.dart`,
`lib/features/theme/presentation/widgets/launcher_background.dart`,
`lib/main.dart`

## 1. Mục tiêu & phạm vi

Hỗ trợ giao diện sáng/tối cho ứng dụng và cho phép ứng dụng **tự đổi theme theo
điều kiện hoạt động** (giờ trong ngày / cài đặt dark-mode của hệ thống). Kèm
"theme style" (màu nhấn) và "background style" cho launcher, và ảnh nền tuỳ chọn.

## 2. Khái niệm

| Khái niệm | Kiểu | Giá trị |
|---|---|---|
| `AppThemeMode` | enum | `day`, `night`, `auto` — lựa chọn thô người dùng lưu, key `theme_mode` |
| `LauncherThemeStyle` | enum | `dark`(#00E5FF), `electric`(#9B7BFF), `glass`(#A8F7E8) — màu nhấn |
| `LauncherBackgroundStyle` | enum | `obsidian`, `electric`, `aurora` |
| `LauncherAppearance` | class bất biến | `themeStyle`, `backgroundStyle`, `customWallpaperPath?` |

## 3. `AppTheme`

- `dayTheme` — Material 3, `Brightness.light`, seed xanh `#1976D2`.
- `nightTheme` — Material 3, `Brightness.dark`, màu CarPlay neon.
- `launcherLightTheme(appearance)` / `launcherTheme(appearance)` — copy day/night
  và ghi đè `primary/secondary/surfaceTint` bằng `appearance.themeStyle.accent`;
  `scaffoldBackgroundColor: transparent` (vì có `LauncherBackground` toàn cục).

`MaterialApp.router` (main.dart): `theme = launcherLightTheme(appearance)`,
`darkTheme = launcherTheme(appearance)`, `themeMode = effectiveThemeModeProvider`.

## 4. Lịch tự đổi giao diện

`LauncherAppearanceSchedule.resolve(now)` theo giờ:

| Giờ | themeStyle | backgroundStyle | Ý nghĩa |
|---|---|---|---|
| 06:00–16:59 | `glass` | `aurora` | ban ngày → coi là "light" |
| 17:00–21:59 | `electric` | `electric` | chạng vạng |
| 22:00–05:59 | `dark` | `obsidian` | ban đêm → "dark" |

## 5. Providers

| Provider | Kiểu | Vai trò |
|---|---|---|
| `themeModeProvider` | `StateNotifier<AppThemeMode>` | lựa chọn thô người dùng; `setMode` ghi `SharedPreferences` qua `LauncherService` |
| `launcherAppearanceProvider` | `StateNotifier<LauncherAppearance>` | style/background/wallpaper người dùng chọn thủ công; persist keys `launcher_theme_style`, `launcher_background_style`, `wallpaper_path` |
| `_appearanceClockProvider` | `StreamProvider<DateTime>` | phát mỗi 1 phút (kèm giá trị đầu) |
| `_systemBrightnessProvider` | `StreamProvider<Brightness>` | `PlatformDispatcher.platformBrightness`, cập nhật khi OS đổi dark-mode; **chain** callback cũ thay vì ghi đè |
| `effectiveLauncherAppearanceProvider` | `Provider<LauncherAppearance>` | nếu mode ≠ `auto` → dùng appearance thủ công; nếu `auto` → `schedule.resolve(now)` nhưng giữ `customWallpaperPath` của người dùng |
| `effectiveThemeModeProvider` | `Provider<ThemeMode>` | phân giải cuối cùng cho Flutter |

### Logic `effectiveThemeModeProvider`

1. `day` → `ThemeMode.light`; `night` → `ThemeMode.dark`.
2. `auto`:
   - nếu `_systemBrightnessProvider == dark` → `ThemeMode.dark` (OS opt-in là
     tín hiệu chủ động, tin cậy);
   - ngược lại theo lịch: `schedule.resolve(now).themeStyle == glass` → `light`,
     còn lại `dark`.

Lý do: hầu hết head unit không có UI để bật dark-mode OS nên setting đó thường
kẹt ở "light" và **không mang tín hiệu** — chỉ tin "dark" từ hệ thống, còn lại
rơi về cùng lịch day/night đang điều khiển màu nhấn & nền.

## 6. `LauncherBackground`

`ConsumerWidget` đặt trong `builder` của `MaterialApp` (nền toàn cục, đổi route
không nạp lại). `AnimatedContainer` nền `deepObsidian` + `_WallpaperImage`:
`customWallpaperPath` → `Image.file` (lỗi → ảnh mặc định
`assets/images/logo_1.png`).

## 7. Quyết định thiết kế & đánh đổi

- **Tách "lựa chọn thô" (`themeModeProvider`) và "kết quả áp dụng"
  (`effectiveThemeModeProvider` / `effectiveLauncherAppearance`)** — UI Settings
  hiển thị đúng ý người dùng, còn Flutter nhận giá trị đã phân giải.
- **`auto` ưu tiên OS-dark rồi tới lịch giờ** — bù cho việc head unit thường
  thiếu setting dark-mode; đổi lại hành vi "auto" khó đoán hơn nếu OS thực sự có
  setting.
- **Đồng hồ 1 phút cho lịch** — đủ mịn để chuyển khung giờ, không tốn tài nguyên.
- **Chain `onPlatformBrightnessChanged`** thay vì ghi đè — không phá callback của
  bên khác (`PlatformDispatcher` chỉ giữ 1); khôi phục trong `ref.onDispose`.
- **`themeStyle`/`backgroundStyle` bị lịch ghi đè khi ở `auto`** nhưng
  `customWallpaperPath` thì không — ảnh nền người dùng luôn thắng.

## 8. Edge case

- `SharedPreferences` không có (test) → `_read` dùng default `dark`/`obsidian`.
- Ảnh nền tuỳ chọn bị xoá khỏi đĩa → `errorBuilder` về ảnh mặc định.
- Đổi mode day/night thủ công → bỏ qua lịch hoàn toàn.

## 9. Kiểm thử

`test/launcher_appearance_contract_test.dart`, `test/settings_design_test.dart`,
`test/design_screens_test.dart`.

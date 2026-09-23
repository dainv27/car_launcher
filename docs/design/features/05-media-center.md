# 05 — Media Center

Updated: 2026-08-29
Status: implemented (một số nút phụ còn TODO)
Route: `/media` (và trang index 0 của Dashboard PageView)
Nguồn: `lib/features/media/presentation/media_center_page.dart`,
`lib/features/media/data/media_controller.dart`,
`lib/features/media/domain/media_session_model.dart`,
`lib/features/media/presentation/providers/media_providers.dart`

## 1. Mục tiêu & phạm vi

Hiển thị và điều khiển phiên phát nhạc (MediaSession) đang hoạt động trên
Android: ảnh bìa, tên bài / nghệ sĩ / album, thanh tiến trình có seek, các nút
play/pause/next/prev, shuffle/repeat (local UI state), volume.

## 2. Kiến trúc & luồng dữ liệu

```
Android MediaSession (NotificationListener)
        │  EventChannel 'com.carlauncher/media_events'  (Map JSON)
        ▼
MediaController (StateNotifier<MediaSessionModel>)  ── state ──► MediaCenterPage
        │  MethodChannel 'com.carlauncher/native' → 'mediaCommand'
        ▼
Android transport controls (play/pause/stop/next/previous/seekTo)
```

- `MediaController._init()` lắng nghe event channel, parse `MediaSessionModel.fromJson`,
  cập nhật `state`. Event lỗi/không đúng dạng → **giữ nguyên state cuối** (không
  bịa trạng thái local).
- Lệnh điều khiển: `_sendCommand(action, extras)` gọi `mediaCommand`; bắt
  `PlatformException` / `MissingPluginException` và im lặng.
- `playPause()` dựa trên `state.isPlaying`.

## 3. Model — `MediaSessionModel`

Bất biến, `==`/`hashCode` đầy đủ. Trường: `title, artist, album, albumArtUrl,
durationMs, positionMs, state (PlaybackState: playing/paused/stopped/none),
packageName`. Getter tiện ích: `isPlaying`, `hasMedia`, `positionFormatted`,
`durationFormatted`, `progress` (0..1). `empty` là mặc định.

## 4. State management

| Provider | Vai trò |
|---|---|
| `mediaControllerProvider` | `StateNotifierProvider<MediaController, MediaSessionModel>` |
| `mediaAccessProvider` | `StreamProvider<bool>` — poll `hasNotificationListenerAccess` mỗi 3s |
| `media_providers.dart` | các `Provider` phái sinh: `isPlayingProvider`, `trackTitleProvider`, `playbackProgressProvider`, … |

`TopAppBar` dùng `mediaAccessProvider` để hiện nút "Enable media access" →
`openNotificationAccessSettings`.

## 5. UI (`MediaCenterPage`)

`ConsumerStatefulWidget`. Local ephemeral state: `_shuffleEnabled`,
`_repeatEnabled`, `_volume` (chỉ UI, chưa nối native). Bố cục `Row`: bên trái
(flex 7) `_ControlsSection` (label, tiêu đề, nghệ sĩ•album, `_ProgressBarSection`
seek bằng `GestureDetector` tính theo `constraints.maxWidth`, hàng nút
`_PlaybackControlRow`, `_VolumeAndActionsRow`), bên phải (flex 5)
`_AlbumArtSection` (ảnh network + placeholder + overlay "Dolby Atmos" khi playing,
equalizer `_AnimatedBars`). Responsive qua `CarResponsive.isCompact/isShort`.

## 6. Quyết định thiết kế & đánh đổi

- **Native là nguồn sự thật duy nhất**: lỗi event → giữ state cuối; lệnh lỗi →
  không đổi state local. Tránh UI "nói dối" về trạng thái phát.
- **shuffle/repeat/volume là state UI cục bộ**: chưa map sang MediaSession →
  hiển thị được nhưng chưa tác động thực; nút "Save"/"Add to Queue" còn `TODO`.
- **`MediaController` tự tạo `EventChannel` riêng** (`com.carlauncher/media_events`)
  thay vì dùng `NativeBridge.events` chung — tách luồng media khỏi event hệ thống.
- Seek/volume tự vẽ bằng `GestureDetector` + `LayoutBuilder` thay vì `Slider`
  chuẩn để khớp theme neon.

## 7. Edge case

- Chưa cấp Notification access → không có phiên nào, `MediaSessionModel.empty`,
  `TopAppBar` gợi ý bật quyền.
- `durationMs <= 0` → `progress` = 0, seek bị bỏ qua.
- Non-Android → `MissingPluginException` nuốt, UI hiển thị "No Track".

## 8. Kiểm thử

`test/tmp_media_center_layout_test.dart`, `test/design_screens_test.dart`,
`test/responsive_screens_test.dart`.

## 9. Việc còn lại

- Nối shuffle/repeat/volume vào MediaSession.
- Hiện thực nút Save / Add to Queue.

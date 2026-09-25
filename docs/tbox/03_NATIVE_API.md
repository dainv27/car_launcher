# Native API cho TBox

## Flutter bridge

Flutter gọi native qua `NativeBridge` tại `lib/core/native/native_bridge.dart`.
Channel chính:

```text
MethodChannel: com.carlauncher/native
EventChannel:  com.carlauncher/events
```

### MethodChannel `com.carlauncher/native`

| Method | Arguments | Kết quả / tác dụng |
|---|---|---|
| `getConnectivityStatus` | Không | Map trạng thái kết nối |
| `getBatteryLevel` | Không | Phần trăm pin |
| `getDeviceInfo` | Không | Thông tin Android/device |
| `getInstalledApps` | Không | Danh sách launcher apps |
| `getAppIcon` | `packageName` | Icon Base64 |
| `launchApp` | `packageName` | Mở app |
| `launchSplitScreen` | `pkg1`, `pkg2` | Yêu cầu adjacent split-screen |
| `sendKeyEvent` | `keyCode` | Gửi key event, có thể cần quyền hệ thống |
| `isEmbeddingSupported` | Không | `bool` theo capability check |
| `getEmbeddingInfo` | Không | `supported`, `reason`, `apiLevel` |
| `launchMapsWithYoutubeOnTop` | Không | Maps + YouTube freeform/adjacent |
| `sendKeyEvent` | `keyCode` | Gửi key event; native có xử lý (`MainActivity.sendKeyEvent`) nhưng **hiện không có nơi nào trong Dart gọi method này** — mồ côi phía client |
| `setScreenBrightness` | `level` (0.0–1.0) | Chỉ có tác dụng khi tắt auto-brightness |
| `getScreenBrightness` | Không | `double`, mặc định `0.85` nếu native trả `null` |
| `isAutoBrightnessEnabled` | Không | `bool` trạng thái adaptive brightness |
| `setAutoBrightness` | `enabled` | Bật/tắt adaptive brightness |
| `pickNotificationSound` | `currentUri` | Mở `RingtoneManager` hệ thống, trả `uri`/`title` đã chọn |
| `isDefaultLauncher` | Không | `bool` app có đang là Home mặc định |
| `requestDefaultLauncher` | Không | Mở prompt/Settings để đặt làm Home mặc định |

Ngoài các method trên, `NativeBridge.setIncomingCallHandler` còn nhận lệnh
native gọi *vào* Flutter trên cùng `MethodChannel('com.carlauncher/native')`:
hiện chỉ dùng cho `startupRuntimePermissionsResult` (native báo kết quả dialog
runtime-permission của OS).

## Navigation và media channels

| Channel | Loại | API |
|---|---|---|
| `com.carlauncher/navigation` | MethodChannel | `stopNavigation` (native trả cứng `false`), `switchProvider` — đăng ký và xử lý trong `MainActivity.kt` nhưng **không có `MethodChannel('com.carlauncher/navigation')` nào phía Dart** kể từ khi tính năng navigation trong app bị gỡ (xem [06-navigation-maps.md](../design/features/06-navigation-maps.md)); native code mồ côi |
| `com.carlauncher/nav_events` | EventChannel | Trạng thái navigation — cùng tình trạng mồ côi như trên, không có `EventChannel` tương ứng phía Dart |
| `com.carlauncher/media_events` | EventChannel | Metadata và playback state — **kênh còn sống thật**, `MediaController` (`lib/features/media/data/media_controller.dart`) lắng nghe |

Media events cần Notification Listener access để đọc active MediaSession.

## PlatformView

| `viewType` | Creation params | Native implementation |
|---|---|---|
| `embedded_app_pane` | `paneId`, `packageName` | `EmbeddedAppPaneView` dùng `ActivityView`. Đăng ký trong `MainActivity` nhưng **không còn widget Flutter nào tạo view này** — tính năng Multi App/pane (`lib/features/layout`) đã bị gỡ bỏ, đây là native code mồ côi |
| `virtual_display_app` | `paneId`, `packageName`, `zOrderOnTop` | `VirtualDisplayAppView` — cơ chế embed duy nhất còn dùng trong app |
| `google_maps_taskview` | Không | `GoogleMapsPlatformView` dùng `ActivityView`. Cũng đăng ký native nhưng không có widget Flutter nào tham chiếu `google_maps_taskview` |

Flutter widget dùng `virtual_display_app` là `EmbeddedAndroidAppView`, được
`NavigationMapWidget` và `YoutubeWidget` gọi. `zOrderOnTop=true` đặt
SurfaceView ở media-overlay Z order, dùng cho YouTube hiển thị trên Maps.
`VirtualDisplayAppView` không có fallback sang `ActivityView` khi
VirtualDisplay thất bại (trường `fallbackHost` chỉ được giải phóng, không bao
giờ được khởi tạo trong code hiện tại).

## Native component API

| Class | API quan trọng |
|---|---|
| `ActivityViewHelper` | `getSupportInfo`, `createHost`, `startApp`, `release` — chỉ còn được gọi bởi hai PlatformView mồ côi ở trên (`embedded_app_pane`, `google_maps_taskview`), không nằm trên đường chạy thực tế của UI |
| `VirtualDisplayEmbeddingCapability` | `getSupportInfo` |
| `MultiWindowLauncher` | `launchMapsWithYoutubeOnTop` |

Các API reflection như `ActivityView`, `InputEvent.setDisplayId`,
`InputManager.injectInputEvent` và `syncInputTransactions` là private/hidden
API; chữ ký có thể thay đổi giữa ROM.

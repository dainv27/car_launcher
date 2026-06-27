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

## Navigation và media channels

| Channel | Loại | API |
|---|---|---|
| `com.carlauncher/navigation` | MethodChannel | `stopNavigation`, `switchProvider` |
| `com.carlauncher/nav_events` | EventChannel | Trạng thái navigation |
| `com.carlauncher/media_events` | EventChannel | Metadata và playback state |

Media events cần Notification Listener access để đọc active MediaSession.

## PlatformView

| `viewType` | Creation params | Native implementation |
|---|---|---|
| `embedded_app_pane` | `paneId`, `packageName` | `EmbeddedAppPaneView` dùng `ActivityView` |
| `virtual_display_app` | `paneId`, `packageName`, `zOrderOnTop` | `VirtualDisplayAppView` |
| `google_maps_taskview` | Không | `GoogleMapsPlatformView` |

Flutter widget dùng `virtual_display_app` là `EmbeddedAndroidAppView`.
`zOrderOnTop=true` đặt SurfaceView ở media-overlay Z order, dùng cho YouTube
hiển thị trên Maps.

## Native component API

| Class | API quan trọng |
|---|---|
| `ActivityViewHelper` | `getSupportInfo`, `createHost`, `startApp`, `release` |
| `VirtualDisplayEmbeddingCapability` | `getSupportInfo` |
| `MultiWindowLauncher` | `launchMapsWithYoutubeOnTop` |

Các API reflection như `ActivityView`, `InputEvent.setDisplayId`,
`InputManager.injectInputEvent` và `syncInputTransactions` là private/hidden
API; chữ ký có thể thay đổi giữa ROM.

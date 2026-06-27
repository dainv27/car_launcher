# Phân tích cơ chế chạy nhiều ứng dụng của CarCar Launcher

## 1. Mục tiêu

Tài liệu này tổng hợp kết quả phân tích mã decompile của CarCar Launcher tại:

```text
/Users/dainv/Desktop/carcar_launcher
```

Mục tiêu là xác định cách CarCar Launcher hiển thị đồng thời nhiều ứng dụng Android, ví dụ Google Maps ở phía dưới và YouTube ở lớp phía trên, đồng thời đánh giá khả năng áp dụng trên TBox Android 13.

> Lưu ý: mã nguồn đã qua decompile và obfuscate nên tên package/class như `z7.g`, `z7.m`, `o1.c` không phản ánh tên gốc. Tuy nhiên, các API Android và chuỗi gọi chính vẫn thể hiện rõ cơ chế hoạt động.

## 2. Kết luận chính

CarCar Launcher không chủ yếu dựa vào Android split-screen, freeform window, `TaskView` hoặc `ActivityView` thông thường.

Nó sử dụng kiến trúc:

1. Tạo một `VirtualDisplay` riêng cho mỗi vùng hiển thị ứng dụng.
2. Launch activity của ứng dụng đích vào đúng `displayId` bằng `ActivityOptions.setLaunchDisplayId()`.
3. Render hoặc mirror nội dung của VirtualDisplay vào một `SurfaceView` nằm trong giao diện Launcher.
4. Đặt các `SurfaceView` theo vị trí, kích thước và thứ tự layer mong muốn.
5. Chuyển touch/key event từ Launcher sang đúng VirtualDisplay bằng cách gán `displayId` rồi inject input event.
6. Theo dõi task stack để quản lý focus, trạng thái và ứng dụng đang chạy trên từng display.

Vì mỗi ứng dụng chạy fullscreen bên trong VirtualDisplay riêng, Google Maps và YouTube có thể hoạt động đồng thời mà không cần chia đôi màn hình theo cơ chế split-screen tiêu chuẩn.

## 3. Sơ đồ kiến trúc

```text
Flutter Launcher UI
    |
    | create(viewId, width, height, scale, ...)
    v
VirtualDisplayViewsChannel
    |
    v
Native AppView Controller
    |
    +--> AppView Maps
    |      +--> SurfaceView
    |      +--> VirtualDisplay A
    |      +--> Google Maps activity launched on display A
    |
    +--> AppView YouTube
           +--> SurfaceView
           +--> VirtualDisplay B
           +--> YouTube activity launched on display B

Touch/key trên AppView
    |
    +--> Gán displayId tương ứng
    +--> Inject vào Android InputManager/IWindowManager
```

Để YouTube hiển thị phía trên Google Maps, Launcher chỉ cần đặt AppView YouTube sau hoặc có thứ tự hiển thị cao hơn AppView Maps trong cây view.

## 4. Bằng chứng từ mã decompile

### 4.1. CarCar Launcher chạy với quyền system

Manifest khai báo:

```xml
android:sharedUserId="android.uid.system"
```

Nguồn:

```text
app/src/main/AndroidManifest.xml:3
```

Các quyền đặc biệt liên quan trực tiếp đến cơ chế embedded app:

```xml
android.permission.INJECT_EVENTS
android.permission.MANAGE_ACTIVITY_STACKS
android.permission.MANAGE_ACTIVITY_TASKS
android.permission.FORCE_STOP_PACKAGES
android.permission.REORDER_TASKS
android.permission.ACTIVITY_EMBEDDING
android.permission.MANAGE_USERS
android.permission.ADD_TRUSTED_DISPLAY
```

Nguồn:

```text
app/src/main/AndroidManifest.xml:14-37
```

Các quyền này phần lớn thuộc nhóm signature, privileged hoặc chỉ dành cho system app. Chỉ khai báo chúng trong manifest của APK thông thường sẽ không đủ.

### 4.2. Flutter yêu cầu tạo AppView

Custom Flutter method channel nhận lệnh `create` với các tham số:

- `id`
- `viewType`
- `width`
- `height`
- `direction`
- `scale`
- `newEngine`

Sau đó channel tạo request `o1.d` và gọi controller:

```java
cVar.a(dVar, callback);
```

Nguồn:

```text
app/src/main/java/h2/h.java:762-789
```

Controller tạo AppView native tương ứng với phiên bản Android rồi thêm trực tiếp AppView đó vào `FlutterView`:

```java
nVar.addView((View) hVar);
```

Nguồn:

```text
app/src/main/java/o1/c.java:141-200
```

Điều này cho phép Launcher kiểm soát vị trí và layer của từng vùng ứng dụng ngay trong giao diện Flutter.

### 4.3. Có implementation riêng cho từng phiên bản Android

CarCar chọn implementation dựa trên `Build.VERSION.SDK_INT`:

```text
Android 10 / SDK 29
Android 11 / SDK 30
Android 12 / SDK 31
Android 12L / SDK 32
Android 13 / SDK 33
Android 14 / SDK 34
Android 15 / SDK 35
```

Nếu nằm ngoài các phiên bản này, ứng dụng báo:

```text
Unsupported android version
```

Nguồn:

```text
app/src/main/java/o1/c.java:71-123
```

Trên Android 13, controller chọn:

- Task/app manager: `z7.m`
- AppView mặc định: `z7.g`
- Một nhánh AppView khác sử dụng `y7.g` để mirror display

Điều này cho thấy CarCar phải xử lý khác nhau theo từng phiên bản do sử dụng hidden/private Android API.

### 4.4. Tạo VirtualDisplay cho AppView trên Android 13

Nhánh AppView Android 13 tạo VirtualDisplay bằng:

```java
DisplayManager.createVirtualDisplay(
    "AppViewVirtualDisplay@...",
    width,
    height,
    density,
    surface,
    3337
);
```

Nguồn:

```text
app/src/main/java/z7/g.java:102-115
```

`surface` được lấy từ `SurfaceHolder` của `SurfaceView`:

```java
Surface surface = surfaceHolder.getSurface();
g.k(gVar, surface);
```

Nguồn:

```text
app/src/main/java/z7/f.java:28-45
```

Như vậy, ứng dụng chạy trên VirtualDisplay sẽ render trực tiếp vào vùng `SurfaceView` của Launcher.

### 4.5. Nhánh mirror VirtualDisplay bằng SurfaceControl

Một implementation khác tạo VirtualDisplay không gắn surface ngay từ đầu:

```java
DisplayManager.createVirtualDisplay(..., null, 3337);
```

Sau đó sử dụng API hệ thống:

```java
iWindowManager.mirrorDisplay(getDisplayId(), surfaceControl);
transaction.reparent(surfaceControl, getSurfaceControl()).show(surfaceControl).apply();
```

Nguồn:

```text
app/src/main/java/y7/g.java:133-143
app/src/main/java/y7/g.java:284-301
```

Implementation này mirror toàn bộ nội dung VirtualDisplay vào SurfaceControl của AppView. Đây là kỹ thuật mạnh hơn và phụ thuộc nhiều vào private API của hệ thống.

### 4.6. Launch ứng dụng vào đúng VirtualDisplay

Flutter gọi method `launchAppInView` với `viewId` và `packageName`:

```java
cVar13.f8947i.h(viewId, packageName);
```

Nguồn:

```text
app/src/main/java/com/example/car_launcher/MainActivity.java:1127-1147
```

Task manager tìm launcher activity của package, tạo intent, rồi launch bằng:

```java
ActivityOptions activityOptions = ActivityOptions.makeBasic();
activityOptions.setLaunchDisplayId(displayId);
activityOptions.setLaunchWindowingMode(1);

pendingIntent.send(..., activityOptions.toBundle());
```

Nguồn:

```text
app/src/main/java/z7/m.java:193-244
```

`setLaunchWindowingMode(1)` yêu cầu activity chạy fullscreen, nhưng fullscreen trong VirtualDisplay thay vì fullscreen trên màn hình vật lý.

### 4.7. Quản lý task và focus

CarCar gọi trực tiếp các service hệ thống:

```java
ActivityManager.getService();
ActivityTaskManager.getService();
```

Nó sử dụng các API như:

```java
getAllRootTaskInfos();
setFocusedRootTask(taskId);
registerTaskStackListener(...);
```

Nguồn:

```text
app/src/main/java/z7/m.java:44-55
app/src/main/java/z7/m.java:57-72
app/src/main/java/z7/m.java:105-121
app/src/main/java/z7/m.java:174-190
```

Nhờ vậy Launcher biết ứng dụng nào đang chạy trên display nào và có thể chuyển focus mà không đóng ứng dụng còn lại.

### 4.8. Inject touch và key event vào ứng dụng

Touch event được gán lại `displayId` trước khi inject:

```java
motionEvent.setDisplayId(virtualDisplay.getDisplay().getDisplayId());
inputManager.injectInputEvent(motionEvent, 0);
```

Nguồn:

```text
app/src/main/java/z7/g.java:129-146
```

Key event cũng được tạo với display ID tương ứng rồi inject:

```java
inputManager.injectInputEvent(keyEvent, 0);
```

Nguồn:

```text
app/src/main/java/z7/g.java:261-272
```

Nhánh mirror display sử dụng:

```java
iWindowManager.injectInputAfterTransactionsApplied(...);
```

Nguồn:

```text
app/src/main/java/y7/g.java:123-131
```

Đây là lý do người dùng vẫn có thể thao tác trực tiếp với Google Maps hoặc YouTube trong từng vùng embedded.

## 5. Vì sao đây không phải split-screen

Split-screen tiêu chuẩn đặt hai task trên cùng display vật lý và để WindowManager chia màn hình.

CarCar tạo nhiều display logic:

```text
Physical display
    +--> Launcher
          +--> SurfaceView hiển thị VirtualDisplay A
          +--> SurfaceView hiển thị VirtualDisplay B
```

Mỗi ứng dụng vẫn cho rằng nó đang chạy fullscreen trên display riêng. Vì vậy:

- Launcher tự quyết định kích thước và vị trí hiển thị.
- Có thể đặt YouTube đè lên Google Maps.
- Không phụ thuộc vào việc Google Maps hoặc YouTube có hỗ trợ split-screen hay không.
- Có thể giữ cả hai activity sống đồng thời.
- Cần quyền hệ thống để quản lý task, display và input.

## 6. Điều kiện cần trên TBox Android 13

Để triển khai gần giống CarCar Launcher, Launcher cần trở thành privileged system app.

Các điều kiện tối thiểu:

1. APK được ký bằng platform certificate của ROM TBox.
2. APK được cài vào `/system/priv-app` hoặc `/system_ext/priv-app`.
3. Package được cấp privileged-permission allowlist phù hợp.
4. ROM cho phép gọi hidden/private Android APIs được sử dụng.
5. SELinux policy cho phép Launcher truy cập các service và thao tác display/input cần thiết.
6. ROM không chặn launch activity bên thứ ba trên VirtualDisplay.
7. Google Maps và YouTube được kiểm thử thực tế trên VirtualDisplay của ROM.

Việc chỉ thêm:

```xml
android:sharedUserId="android.uid.system"
```

vào manifest sẽ không có tác dụng nếu APK không được ký bằng đúng platform key.

## 7. Khả năng hỗ trợ theo phiên bản Android

Android public API có VirtualDisplay từ lâu, nhưng khả năng embedded hoàn chỉnh một ứng dụng bên thứ ba phụ thuộc vào API hệ thống và chính sách ROM.

Từ mã CarCar có thể xác nhận:

| Android | SDK | CarCar có implementation riêng |
|---|---:|---|
| Android 10 | 29 | Có |
| Android 11 | 30 | Có |
| Android 12 | 31 | Có |
| Android 12L | 32 | Có |
| Android 13 | 33 | Có |
| Android 14 | 34 | Có |
| Android 15 | 35 | Có |

CarCar không dùng một implementation chung cho mọi phiên bản. Do đó, việc chạy được trên Android 13 không đảm bảo cùng mã đó sẽ chạy nguyên trạng trên Android 14 hoặc Android 15.

## 8. Kiến trúc đề xuất cho Car Launcher hiện tại

### 8.1. Native Android layer

Xây dựng các thành phần:

```text
EmbeddedAppView
    - Sở hữu SurfaceView
    - Tạo và giải phóng VirtualDisplay
    - Quản lý kích thước, vị trí và visibility
    - Forward touch/key event

EmbeddedAppManager
    - Map viewId -> EmbeddedAppView/displayId
    - Launch package vào displayId
    - Theo dõi task stack
    - Quản lý focus và lifecycle

Flutter MethodChannel
    - createAppView
    - resizeAppView
    - launchAppInView
    - focusAppView
    - freezeAppView
    - disposeAppView
```

### 8.2. Flutter layer

Flutter quản lý bố cục:

```text
GoogleMaps AppView: full dashboard background
YouTube AppView: floating layer phía trên
```

Flutter gửi vị trí/kích thước của từng vùng sang native. Native đặt `SurfaceView` tương ứng vào `FlutterView`.

### 8.3. Luồng khởi chạy

```text
1. Flutter tạo AppView Google Maps.
2. Native tạo VirtualDisplay A.
3. Flutter gọi launchAppInView(A, com.google.android.apps.maps).
4. Native launch Google Maps lên display A.
5. Flutter tạo AppView YouTube.
6. Native tạo VirtualDisplay B.
7. Flutter gọi launchAppInView(B, com.google.android.youtube).
8. Native launch YouTube lên display B.
9. Flutter đặt AppView YouTube phía trên AppView Maps.
10. Native inject input theo displayId của vùng được chạm.
```

## 9. Rủi ro kỹ thuật

### 9.1. Quyền hệ thống

Đây là rào cản lớn nhất. APK thông thường từ Play Store hoặc cài qua ADB không thể sử dụng đầy đủ cơ chế này.

### 9.2. Hidden API thay đổi theo Android

Các API như `IWindowManager`, `IActivityTaskManager`, `mirrorDisplay()` và `updateDisplayContentLocation()` có thể thay đổi chữ ký hoặc hành vi giữa các bản Android.

### 9.3. Ứng dụng đích từ chối VirtualDisplay

Một số ứng dụng có thể:

- Không cho launch trên secondary display.
- Chỉ render màn hình đen.
- Sử dụng secure surface.
- Tạm dừng video khi mất focus.
- Chặn input hoặc DRM content.

YouTube cần được kiểm thử riêng, đặc biệt với video DRM và trạng thái focus.

### 9.4. SurfaceView và thứ tự layer

`SurfaceView` không hoạt động giống widget Flutter thông thường. Cần kiểm soát cẩn thận:

- Z-order.
- Clipping.
- Visibility.
- Resize.
- Rotation.
- Surface lifecycle.

### 9.5. Hiệu năng

Chạy đồng thời Google Maps và YouTube làm tăng:

- GPU composition.
- RAM.
- CPU.
- Nhiệt độ.
- Băng thông mạng.

TBox cần được kiểm thử trong thời gian dài và trong điều kiện nhiệt độ thực tế trên xe.

## 10. So sánh các phương án

| Phương án | Giống CarCar | Chạy Maps + YouTube đồng thời | YouTube đè trên Maps | Yêu cầu system app |
|---|---|---|---|---|
| VirtualDisplay + launch display ID | Cao | Có | Có | Có |
| ActivityView/TaskView public hoặc hạn chế | Trung bình | Tùy ROM | Tùy implementation | Thường có |
| Android split-screen | Thấp | Có nếu app hỗ trợ | Không đúng kiểu overlay | Không nhất thiết |
| Freeform window | Thấp | Tùy ROM | Có giới hạn | Tùy ROM |
| Overlay Launcher | Thấp | Có giới hạn | Có | Không, nhưng không embed thực sự |
| WebView/YouTube embed | Không phải app YouTube thật | Có | Có | Không |

## 11. Khuyến nghị triển khai

Để đạt hành vi gần đúng CarCar Launcher trên TBox Android 13:

1. Xác nhận có platform key và khả năng chỉnh ROM/system image.
2. Cài Launcher thành privileged system app.
3. Làm proof of concept native Android trước:
   - Tạo một VirtualDisplay.
   - Launch một ứng dụng đơn giản vào display đó.
   - Render vào SurfaceView.
   - Inject touch.
4. Kiểm thử Google Maps.
5. Kiểm thử YouTube và video playback.
6. Sau khi native proof of concept ổn định, tích hợp vào Flutter.
7. Bổ sung quản lý hai AppView, focus, lifecycle và layer.
8. Tạo implementation riêng cho từng phiên bản Android cần hỗ trợ.

Overlay Launcher và split-screen nên được giữ làm fallback khi thiết bị không cấp quyền hệ thống. Chúng không thể tái tạo đầy đủ hành vi của CarCar.

## 12. Kết luận cuối

CarCar Launcher đạt khả năng chạy nhiều ứng dụng song song bằng cách biến mỗi vùng ứng dụng thành một display Android độc lập:

```text
Một AppView = một SurfaceView + một VirtualDisplay + một activity chạy trên display đó
```

Sau đó Launcher compositing các AppView trên màn hình và chuyển input vào đúng display.

Trên TBox Android 13, cơ chế này có thể triển khai nếu có toàn quyền với ROM, platform signing key, privileged permissions và SELinux policy. Nếu Launcher chỉ là APK thông thường, không thể đạt mức hoạt động tương đương CarCar chỉ bằng Flutter, overlay hoặc manifest permissions.

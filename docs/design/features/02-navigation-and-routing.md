# 02 — Điều hướng & routing

Updated: 2026-08-29
Status: implemented
Nguồn: `lib/core/router/app_router.dart`, `lib/core/router/app_route_transition.dart`,
`lib/features/dashboard/presentation/widgets/top_app_bar.dart`

## 1. Mục tiêu & phạm vi

Định nghĩa toàn bộ route của app bằng `go_router`, cơ chế bảo vệ route cần đăng
nhập, hiệu ứng chuyển trang thống nhất, và thanh điều hướng trên cùng
(`TopAppBar`).

## 2. Bảng route

| Path | Trang | Ghi chú |
|---|---|---|
| `/splash` | `SplashPage` | `initialLocation`; tự `context.go('/')` sau ~2s |
| `/` | `DashboardPage` | màn hình chính (PageView 6 trang) |
| `/apps` | `AppDrawerPage` | |
| `/media` | `MediaCenterPage` | |
| `/navigation` | `MapPage(showYoutube: false)` | con: `/navigation/youtube` |
| `/vehicles` | `VehiclesPage` | **protected** |
| `/vehicles/:id` | `VehicleDetailPage` | gate ở cấp trang |
| `/history/:vehicleId` | `TrackingHistoryPage` | **protected** (prefix `/history`) |
| `/login` | `AccountLoginPage` | |
| `/callback` | rỗng, redirect | nhận `carlauncher://oauth/callback` → `/` |
| `/settings` | `SettingsPage` | con: `account` (cat 5), `clock-network`, `logs`, `vehicle` (cat 7), `tracking` (cat 8) |

`SettingsPage(initialCategory: N)` dùng để deep-link vào đúng mục Settings.

## 3. Cơ chế bảo vệ route

`_protectedRoutes = {'/vehicles', '/history'}`. Hàm `redirect` toàn cục:

- chỉ xét route top-level (khớp chính xác hoặc prefix `<r>/`);
- đọc `accountSessionProvider`; nếu `valueOrNull == null` → redirect `/login`;
- route con (ví dụ `/vehicles/:id`) **không** bị redirect ở đây mà tự gate trong
  trang, để tránh double-redirect.

Các mục Settings cần đăng nhập (`Vehicle`, `Tracking`) tự kiểm tra
`accountSessionProvider` và hiển thị `LoginRequiredWidget` thay vì redirect.

## 4. Hiệu ứng chuyển trang

`_transitionPage()` bọc mọi trang trong `CarTransitionPage`
(`app_route_transition.dart`) — hiệu ứng thống nhất, dùng `state.pageKey` làm key.

## 5. `TopAppBar` (thanh trên cùng)

`ConsumerWidget`, cao 50px, dùng trong `DashboardPage` (và một số trang). Bố cục
`Row`: khối trái (logo K3 + tên địa điểm hiện tại hoặc tiêu đề trang) và khối
phải.

- Điểm gãy responsive: `constraints.maxWidth < 1200` → chế độ `compact`.
- Chế độ đủ rộng: đồng hồ, `_NavigationMenu` (Media / Navigation / Apps /
  Settings — dùng `GoRouter.push`), nút bật Notification access, nút voice
  assistant, chấm trạng thái tracking.
- Chế độ compact: chỉ đồng hồ + chấm trạng thái tracking.
- `_TrackingStatusDot`: chấm pulse đổi màu/nhịp theo `vehicleTrackingProvider`
  (paused / active / syncing / pending / error) — xem [12](12-vehicle-tracking.md).

## 6. Quyết định thiết kế & đánh đổi

- **`go_router` khai báo tập trung** trong `core/router/` — dễ thấy toàn bộ sơ đồ
  điều hướng; nhược điểm: thêm route phải sửa file trung tâm.
- **Redirect chỉ ở top-level + gate trang cho route con**: tránh nhấp nháy
  double-redirect khi session đang load, đổi lại logic gate nằm rải ở vài nơi.
- **Dashboard vừa là route `/` vừa là `PageView` 6 trang**: một số màn hình
  (Media, Apps, Settings) tồn tại cả dưới dạng route độc lập lẫn trang trong
  PageView của Dashboard.

## 7. Edge case

- `/callback` chỉ redirect về `/` khi URI đúng scheme/host/path
  `carlauncher://oauth/callback`; việc phân phối token cho request OAuth đang chờ
  do `MainActivity` lo.
- `context.canPop()` false (vào thẳng route) → các trang fallback `context.go('/')`.

## 8. Kiểm thử

`test/app_route_transition_test.dart`, `test/top_app_bar_navigation_test.dart`,
`test/login_gate_test.dart`, `test/design_screens_test.dart`,
`test/responsive_screens_test.dart`.

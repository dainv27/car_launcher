# 09 — Tài khoản & xác thực (Keycloak OIDC)

Updated: 2026-08-29
Status: implemented
Route: `/login`, `/callback`, `/settings/account`
Nguồn: `lib/features/account/**`, `lib/core/auth/**`,
`lib/features/account/repositories/keycloak_auth_repository.dart`,
`lib/core/di/injection_container.dart` (`AuthInterceptorClient`)

## 1. Mục tiêu & phạm vi

Đăng nhập bằng OIDC Authorization Code + PKCE tới Keycloak realm
`car_management`, khôi phục phiên khi mở lại app, tự refresh token, cung cấp
access token cho lớp HTTP và cho service tracking native.

## 2. Cấu hình (`core/auth/keycloak_config.dart`)

Giá trị đọc theo thứ tự `.env*` → `--dart-define` → mặc định:

| Khoá | Mặc định |
|---|---|
| realm | `car_management` |
| issuer | `https://dev-idp.202corp.com/realms/car_management` |
| `AUTH_DISCOVERY_URL` | `<issuer>/.well-known/openid-configuration` |
| `AUTH_CLIENT_ID` | `car_launcher` |
| `AUTH_CLIENT_SECRET` | (có default trong repo — nên chuyển sang env cho production) |
| `AUTH_REDIRECT_URL` (mobile) | `carlauncher://oauth/callback` |
| `AUTH_LOOPBACK_REDIRECT_URL` (Win/Linux) | `http://localhost:47321/oauth/callback` |
| scopes | `openid profile email` |

`redirectUrl` chọn theo nền tảng: Windows/Linux → loopback, còn lại → custom
scheme.

## 3. Kiến trúc

```
AccountLoginPage ──► accountSessionProvider (AsyncNotifier<AccountUser?>)
                         │  loginWithOidc(context)
                         ▼
              KeycloakAuthRepository  (get_it lazySingleton)
                 │  OpenIdConnectClient (package openidconnect, autoRefresh)
                 │  FlutterSecureStorage (AppSecureStorage) — identity + encryption key
                 ▼
             Keycloak (idp.202corp.com)
```

- `_ensureClient()` tạo `OpenIdConnectClient` một lần, dùng
  `_getOrCreateStorageEncryptionKey()` (UUID lưu secure storage) để mã hoá kho
  identity.
- `restoreSession()` / `currentUser()` / `accessToken()`: nếu
  `isTokenAboutToExpire` → `refresh(raiseEvents: false)`; refresh fail →
  `clearIdentity()` (đăng xuất ngầm).
- `forceRefreshToken()`: refresh bất kể trạng thái hết hạn — gọi khi server trả
  `401`.
- `logout()`: `revokeTokens()` (bỏ qua lỗi) → `clearIdentity()` → xoá provider key.
- `_userFromIdentity()`: dựng `AccountUser{id=sub, email, displayName, preferredLocale,
  authProvider}`; có thể override displayName/locale từ profile lưu ở
  `SharedPreferences` key `kc_profile_<sub>`.

## 4. State management

- `accountSessionProvider` — `AsyncNotifierProvider<AccountNotifier, AccountUser?>`.
  `build()` khôi phục phiên; `loginWithOidc` → set `AsyncData(user)` rồi
  `invalidateSelf()`; `logout()` → `AsyncLoading` → `null`.
  Debug: `setMockUser()` + `setDebugMockToken()` bỏ qua OAuth.
- `keycloakAuthRepositoryProvider` — accessor `getIt`.
- `loginSuccessFlagProvider` — `StateProvider<bool>`, login page bật để Settings
  nhảy sang mục Account.
- `login_required.dart` — `LoginRequiredWidget` cho các mục cần đăng nhập.

## 5. Luồng đăng nhập

1. `AccountLoginPage` (nút "Sign in") → `_run(loginWithOidc(context))`.
2. `client.loginInteractive(prompts: ['login'])` mở trình duyệt hệ thống.
3. Keycloak redirect `carlauncher://oauth/callback` → `MainActivity` bắt qua
   intent-filter, chuyển vào request OAuth đang chờ; route `/callback` chỉ điều
   khiển màn hình hiển thị (→ `/`).
4. Thành công → `context.go('/')`. Hủy → thông báo "Đăng nhập đã hủy." (không
   snackbar). Lỗi khác → `_mapAuthError` cho thông điệp cụ thể (redirect mismatch,
   invalid_client, không tới được Keycloak, cổng loopback bận…).
5. `_AccountLoginPageState` theo dõi lifecycle: khi `resumed` mà vẫn `_busy` →
   đặt timer 5s rồi `cancelPendingInteractiveLogin()` (S60 có thể trả callback
   chậm).

## 6. Access token cho HTTP & native

- `AuthInterceptorClient` (bọc `http.Client`): chèn `Bearer` cho host gateway;
  gặp `401` → `forceRefreshProvider()` rồi gửi lại request đã copy một lần.
- Service tracking native: Flutter đẩy access token qua
  `updateVehicleTrackingSyncConfig`; khi native gặp `401` nó gọi
  `com.carlauncher/tracking_auth`/`refreshToken` → handler ở `main.dart` gọi
  `forceRefreshToken()` và trả token mới (xem [01](01-app-shell-and-bootstrap.md),
  [12](12-vehicle-tracking.md)).

## 7. Quyết định thiết kế & đánh đổi

- **Browser-based OIDC, không form trong app** — an toàn hơn, dùng lại SSO; đổi
  lại phụ thuộc trình duyệt hệ thống và cách head unit trả deep link.
- **`AccountAuthProvider` hiện chỉ `email`** — enum mở sẵn cho IdP hint khác.
- **Kho identity mã hoá bằng key sinh ngẫu nhiên lưu chính trong secure storage**
  — đơn giản; bảo mật phụ thuộc secure storage của thiết bị.
- **Client secret có default trong mã nguồn** — tiện dev, là rủi ro cho
  production; nên bắt buộc qua `.env`.
- **Refresh fail = đăng xuất ngầm** (`clearIdentity`) — tránh vòng lặp 401, đổi
  lại người dùng bị đá ra mà không luôn có thông báo.

## 8. Edge case

- Token sắp hết hạn tại mọi điểm đọc (`currentUser`, `accessToken`) → refresh
  chủ động.
- Hủy đăng nhập giữa chừng → `_clearPartialLogin()` dọn identity dở.
- Non-mobile (Windows/Linux) cần cấu hình redirect loopback đúng cổng, nếu sai →
  thông điệp lỗi hướng dẫn.

## 9. Kiểm thử

`test/keycloak_auth_repository_test.dart`, `test/account_login_page_test.dart`,
`test/login_gate_test.dart`, `test/security_config_contract_test.dart`.

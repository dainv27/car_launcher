import 'package:flutter/foundation.dart';

import 'package:car_launcher/core/config/env_loader.dart';

/// Keycloak OIDC config — realm `card_management` on idp.202corp.com.
///
/// Values resolve in this order:
///   1. `.env` / `.env.local` / `.env.<env>` (via flutter_dotenv)
///   2. `--dart-define` (compile-time)
///   3. Hardcoded default
abstract final class KeycloakConfig {
  static const realm = 'card_management';
  static const issuer = 'https://dev-idp.202corp.com/realms/$realm';

  static String get discoveryUrl =>
      _env('AUTH_DISCOVERY_URL') ??
      const String.fromEnvironment(
        'AUTH_DISCOVERY_URL',
        defaultValue: '$issuer/.well-known/openid-configuration',
      );

  static String get tokenUrl =>
      _env('AUTH_TOKEN_URL') ??
      const String.fromEnvironment(
        'AUTH_TOKEN_URL',
        defaultValue:
            'https://dev-idp.202corp.com/realms/$realm/protocol/openid-connect/token',
      );

  static String get authorizationEndpoint =>
      _env('AUTHORIZATION_ENDPOINT') ??
      const String.fromEnvironment(
        'AUTHORIZATION_ENDPOINT',
        defaultValue:
            'https://dev-idp.202corp.com/realms/$realm/protocol/openid-connect/auth',
      );

  static String get logoutEndpoint =>
      _env('LOGOUT_ENDPOINT') ??
      const String.fromEnvironment(
        'LOGOUT_ENDPOINT',
        defaultValue:
            'https://dev-idp.202corp.com/realms/$realm/protocol/openid-connect/logout',
      );

  static String get clientId =>
      _env('AUTH_CLIENT_ID') ??
      const String.fromEnvironment(
        'AUTH_CLIENT_ID',
        defaultValue: 'car_launcher',
      );

  static String get clientSecret =>
      _env('AUTH_CLIENT_SECRET') ??
      const String.fromEnvironment(
        'AUTH_CLIENT_SECRET',
        defaultValue: 'dMx5nYG5LGQy1ovx4VHgMbTfkmjS13bT',
      );

  /// Android / iOS custom scheme.
  static String get mobileRedirectUrl =>
      _env('AUTH_REDIRECT_URL') ??
      const String.fromEnvironment(
        'AUTH_REDIRECT_URL',
        defaultValue: 'carlauncher://oauth/callback',
      );

  /// Windows / Linux loopback — openidconnect requires `localhost`.
  static String get loopbackRedirectUrl =>
      _env('AUTH_LOOPBACK_REDIRECT_URL') ??
      const String.fromEnvironment(
        'AUTH_LOOPBACK_REDIRECT_URL',
        defaultValue: 'http://localhost:47321/oauth/callback',
      );

  static const scopes = ['openid', 'profile', 'email'];

  static const storageTenantId = 'car_launcher';

  static String get redirectUrl {
    if (kIsWeb) return mobileRedirectUrl;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows || TargetPlatform.linux => loopbackRedirectUrl,
      _ => mobileRedirectUrl,
    };
  }

  static List<String> get allRedirectUris => [
        mobileRedirectUrl,
        loopbackRedirectUrl,
        '${Uri.parse(loopbackRedirectUrl).origin}/*',
      ];

  /// Read from env-loaded config, falling back to --dart-define.
  static String? _env(String key) => EnvLoader.instance.getValue(key);
}

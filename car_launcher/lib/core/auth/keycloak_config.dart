import 'package:flutter/foundation.dart';

/// Keycloak OIDC config — realm `card_management` on idp.202corp.com.
///
/// Override any value via `--dart-define` at build time:
///   flutter build apk --dart-define=AUTH_CLIENT_ID=xxx
abstract final class KeycloakConfig {
  static const realm = 'card_management';
  static const issuer = 'https://dev-idp.202corp.com/realms/$realm';

  static const discoveryUrl = String.fromEnvironment(
    'AUTH_DISCOVERY_URL',
    defaultValue: '$issuer/.well-known/openid-configuration',
  );

  static const tokenUrl = String.fromEnvironment(
    'AUTH_TOKEN_URL',
    defaultValue:
        'https://dev-idp.202corp.com/realms/$realm/protocol/openid-connect/token',
  );

  static const authorizationEndpoint = String.fromEnvironment(
    'AUTHORIZATION_ENDPOINT',
    defaultValue:
        'https://dev-idp.202corp.com/realms/$realm/protocol/openid-connect/auth',
  );

  static const logoutEndpoint = String.fromEnvironment(
    'LOGOUT_ENDPOINT',
    defaultValue:
        'https://dev-idp.202corp.com/realms/$realm/protocol/openid-connect/logout',
  );

  static const clientId = String.fromEnvironment(
    'AUTH_CLIENT_ID',
    defaultValue: 'car_launcher',
  );

  static const clientSecret = String.fromEnvironment(
    'AUTH_CLIENT_SECRET',
    defaultValue: 'dMx5nYG5LGQy1ovx4VHgMbTfkmjS13bT',
  );

  /// Android / iOS custom scheme.
  static const mobileRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'carlauncher://oauth/callback',
  );

  /// Windows / Linux loopback — openidconnect requires `localhost`.
  static const loopbackRedirectUrl = String.fromEnvironment(
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
}

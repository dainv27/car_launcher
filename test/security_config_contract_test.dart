import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Keycloak is configured as a public client without static secrets', () {
    final config = File('lib/core/auth/keycloak_config.dart').readAsStringSync();
    final repository =
        File('lib/features/account/repositories/keycloak_auth_repository.dart').readAsStringSync();

    expect(config, isNot(contains('AUTH_CLIENT_SECRET')));
    expect(config, isNot(contains('clientSecret')));
    expect(config, isNot(contains('storageEncryptionKey')));
    expect(repository, isNot(contains('clientSecret:')));
    expect(repository, contains('encryptionKey: storageEncryptionKey'));
    expect(repository, contains('_getOrCreateStorageEncryptionKey'));
    expect(repository, isNot(contains('_ensureClientSecret')));
    expect(repository, isNot(contains('client_id, secret')));
  });

  test('Android OAuth callback is not logged and uses secure storage', () {
    final platform =
        File('lib/core/auth/keycloak_oidc_platform.dart').readAsStringSync();

    expect(platform, isNot(contains('handleOAuthRedirect: \$redirectUri')));
    expect(platform, contains('AppSecureStorage.instance.write'));
    expect(platform, contains('AppSecureStorage.instance.read'));
    expect(platform, contains('AppSecureStorage.instance.delete'));
    expect(platform, contains('_startupOAuthRedirect'));
    expect(platform, contains('OAuth login is already in progress'));
  });

  test('release signing fails closed without platform credentials', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('GradleException'));
    expect(gradle, contains('TBOX_PLATFORM_KEYSTORE'));
    expect(gradle, contains('TBOX_PLATFORM_KEY_ALIAS'));
    expect(gradle, contains('TBOX_PLATFORM_STORE_PASSWORD'));
    expect(gradle, contains('TBOX_PLATFORM_KEY_PASSWORD'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
  });

  test('manifests enforce release identity and application security policy', () {
    final main = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final release =
        File('android/app/src/release/AndroidManifest.xml').readAsStringSync();

    expect(main, contains('android:allowBackup="false"'));
    expect(main, contains('android:usesCleartextTraffic="false"'));
    expect(main, isNot(contains('android:sharedUserId=')));
    expect(main, isNot(contains('QUICKBOOT_POWERON')));
    expect(main, contains('android:name=".embedding.EmbeddedInputAccessibilityService"'));
    expect(main, contains('android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE"'));
    expect(main, contains('android:exported="true"'));
    expect(
      release,
      contains(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:sharedUserId="android.uid.system">',
      ),
    );
  });

  test('Maps WebView allows only approved HTTPS origins and hardens settings', () {
    final source = File(
      'android/app/src/main/kotlin/com/carlauncher/car_launcher/platform_view/'
      'GoogleMapsPlatformView.kt',
    ).readAsStringSync();

    expect(source, contains('"https://www.google.com"'));
    expect(source, contains('"https://maps.google.com"'));
    expect(source, contains('isApprovedMapsOrigin'));
    expect(source, contains('callback?.invoke(origin, approved, false)'));
    expect(source, contains('allowFileAccess = false'));
    expect(source, contains('allowContentAccess = false'));
    expect(source, contains('MIXED_CONTENT_NEVER_ALLOW'));
    expect(source, contains('ACCESS_FINE_LOCATION'));
    expect(source, isNot(contains('callback?.invoke(origin, true, false)')));
    expect(source, isNot(contains('Intent(Intent.ACTION_VIEW, uri)')));
  });

  test('Maps fullscreen fallback ownership is per platform view instance', () {
    final source = File(
      'android/app/src/main/kotlin/com/carlauncher/car_launcher/platform_view/'
      'GoogleMapsPlatformView.kt',
    ).readAsStringSync();
    final companionObject = RegExp(
      r'private companion object \{[\s\S]*?\n    \}',
    ).firstMatch(source)?.group(0);

    expect(source, contains('private var fullscreenFallbackStarted = false'));
    expect(companionObject, isNot(contains('fullscreenFallbackStarted')));
    expect(source, isNot(contains('MediaOverlayService')));
    expect(source, isNot(contains('Settings.canDrawOverlays')));
  });
}

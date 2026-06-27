import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:openidconnect/openidconnect.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:car_launcher/core/auth/app_secure_storage.dart';
import 'package:car_launcher/core/auth/keycloak_config.dart';
import 'package:car_launcher/core/auth/keycloak_oidc_platform.dart';
import 'package:car_launcher/core/di/injection_container.dart';
import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/core/logging/logging.dart';
import 'package:car_launcher/features/account/domain/account_user.dart';

sealed class AccountAuthException implements Exception {
  const AccountAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

final class KeycloakAuthException extends AccountAuthException {
  const KeycloakAuthException(super.message);
}

String accountErrorMessage(Object error) {
  if (error is AccountAuthException) return error.message;
  final text = error.toString();
  if (text.contains('User cancelled') || text.contains('CANCELED') || text.contains('cancelled')) {
    return 'Đăng nhập đã hủy.';
  }
  return text;
}

/// Keycloak OIDC — authorization code + PKCE.
class KeycloakAuthRepository {
  KeycloakAuthRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? AppSecureStorage.instance;

  final FlutterSecureStorage _storage;
  OpenIdConnectClient? _client;

  static const _providerKey = 'kc_auth_provider';
  static const _profileKeyPrefix = 'kc_profile_';
  static const _storageEncryptionKeyName = 'kc_storage_encryption_key';

  Future<OpenIdConnectClient> _ensureClient() async {
    if (_client != null) return _client!;
    final storageEncryptionKey = await _getOrCreateStorageEncryptionKey();
    _client = await OpenIdConnectClient.create(
      discoveryDocumentUrl: KeycloakConfig.discoveryUrl,
      clientId: KeycloakConfig.clientId,
      clientSecret: KeycloakConfig.clientSecret,
      redirectUrl: KeycloakConfig.redirectUrl,
      tenantId: KeycloakConfig.storageTenantId,
      encryptionKey: storageEncryptionKey,
      scopes: KeycloakConfig.scopes,
      autoRefresh: true,
    );
    return _client!;
  }

  Future<String> _getOrCreateStorageEncryptionKey() async {
    final existing = await _storage.read(key: _storageEncryptionKeyName);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = const Uuid().v4();
    await _storage.write(key: _storageEncryptionKeyName, value: generated);
    return generated;
  }

  Future<void> restoreSession() async {
    final client = await _ensureClient();
    AppLogger.instance.d('[KC] restoreSession — identity=${client.identity != null}', tag: 'KC');
    if (client.identity == null) return;
    if (client.isTokenAboutToExpire) {
      AppLogger.instance.d('[KC] token expiring — refreshing', tag: 'KC');
      final ok = await client.refresh(raiseEvents: false);
      if (!ok) {
        AppLogger.instance.w('[KC] refresh failed — clearing identity', tag: 'KC');
        await client.clearIdentity();
      }
    }
  }

  Future<AccountUser?> currentUser() async {
    final client = await _ensureClient();
    final identity = client.identity;
    AppLogger.instance.d('[KC] currentUser — identity=${identity != null}', tag: 'KC');
    if (identity == null) return null;
    if (client.isTokenAboutToExpire) {
      final ok = await client.refresh(raiseEvents: false);
      if (!ok) {
        await client.clearIdentity();
        return null;
      }
    }
    if (client.hasTokenExpired) {
      await client.clearIdentity();
      return null;
    }
    final refreshed = client.identity;
    if (refreshed == null) return null;
    final provider = await _readStoredProvider() ?? AccountAuthProvider.email;
    return _userFromIdentity(refreshed, fallbackProvider: provider);
  }

  Future<String?> accessToken() async {
    // Debug mode: return a mock token if a mock user was set
    if (kDebugMode && _mockAccessToken != null) {
      return _mockAccessToken;
    }
    final client = await _ensureClient();
    final identity = client.identity;
    if (identity == null) return null;
    if (client.isTokenAboutToExpire) {
      final ok = await client.refresh(raiseEvents: false);
      if (!ok) {
        await client.clearIdentity();
        return null;
      }
    }
    if (client.hasTokenExpired) {
      await client.clearIdentity();
      return null;
    }
    return client.identity?.accessToken;
  }

  /// Force-refresh the access token regardless of expiry state.
  ///
  /// Call this when a server returns 401 to obtain a fresh token. Returns
  /// true if a new token is available, false if refresh failed or no
  /// session exists.
  Future<bool> forceRefreshToken() async {
    if (kDebugMode && _mockAccessToken != null) return true;
    final client = await _ensureClient();
    if (client.identity == null) return false;
    final ok = await client.refresh(raiseEvents: false);
    if (!ok) {
      await client.clearIdentity();
      return false;
    }
    return client.identity != null;
  }

  /// Debug-only: set a mock access token for testing.
  static String? _mockAccessToken;
  static void setDebugMockToken(String? token) {
    _mockAccessToken = token;
  }

  Future<AccountUser> loginWithOidc(BuildContext context) => _authorize(context);

  static void cancelPendingInteractiveLogin() {
    cancelKeycloakInteractiveLogin();
  }

  Future<void> logout() async {
    final client = await _ensureClient();
    try {
      await client.revokeTokens();
    } catch (_) {}
    await client.clearIdentity();
    await _storage.delete(key: _providerKey);
  }

  Future<AccountUser> _authorize(BuildContext context, {String? idpHint}) async {
    AppLogger.instance.d('[KC] _authorize — idpHint=$idpHint', tag: 'KC');
    final client = await _ensureClient();
    const provider = AccountAuthProvider.email;
    try {
      if (!context.mounted) throw const KeycloakAuthException('Login cancelled.');
      AppLogger.instance.d('[KC] calling loginInteractive…', tag: 'KC');
      await client.loginInteractive(
        context: context,
        title: 'Car Launcher Login',
        additionalParameters: idpHint != null ? {'kc_idp_hint': idpHint} : null,
        prompts: const ['login'],
      );
      AppLogger.instance.d('[KC] loginInteractive done — writing provider', tag: 'KC');
      await _writeStoredProvider(provider);
      final identity = client.identity;
      AppLogger.instance.d('[KC] identity after login: ${identity != null}', tag: 'KC');
      if (identity == null) {
        throw const KeycloakAuthException('Keycloak did not return a session.');
      }
      return _userFromIdentity(identity, fallbackProvider: provider);
    } catch (e, st) {
      await _clearPartialLogin();
      throw _mapAuthError(e, st, phase: 'login');
    }
  }

  Future<void> _clearPartialLogin() async {
    cancelKeycloakInteractiveLogin();
    try {
      final client = _client;
      if (client != null) await client.clearIdentity();
    } catch (_) {}
  }

  KeycloakAuthException _mapAuthError(Object error, StackTrace? stackTrace, {required String phase}) {
    if (kDebugMode) {
      AppLogger.instance.e('Keycloak auth [$phase]: $error', tag: 'KC', error: error, stackTrace: stackTrace);
    }
    if (error is KeycloakAuthException) return error;

    final text = error.toString().toLowerCase();
    if (_isUserCancelled(text, error)) {
      return const KeycloakAuthException('Login cancelled.');
    }
    if (text.contains('only supports http://localhost') || text.contains('127.0.0.1')) {
      return const KeycloakAuthException('OAuth redirect config error — desktop needs http://localhost:<port>/oauth/callback.');
    }
    if (text.contains('failed to bind') || text.contains('socketexception') || text.contains('address already in use')) {
      return const KeycloakAuthException('Cannot open OAuth loopback port. Try closing other apps.');
    }
    if (text.contains('discovery document') || text.contains('could not be found')) {
      return const KeycloakAuthException('Cannot reach Keycloak. Check network or AUTH_DISCOVERY_URL.');
    }
    if (text.contains('invalid_client') || text.contains('unauthorized_client') || text.contains('invalid_grant')) {
      return const KeycloakAuthException('Keycloak rejected client. Check client_id and Valid redirect URIs.');
    }
    if (text.contains('redirect_uri') || text.contains('invalid redirect')) {
      return KeycloakAuthException('Redirect URI mismatch (${KeycloakConfig.redirectUrl}). Add it to Valid redirect URIs.');
    }
    return const KeycloakAuthException('Login failed.');
  }

  bool _isUserCancelled(String text, Object error) {
    if (text.contains('user closed') || text.contains('user_closed') || text.contains('user_cancelled') || text.contains('cancel')) {
      return true;
    }
    return error is StateError && text.contains('closed');
  }

  Future<AccountAuthProvider?> _readStoredProvider() async {
    final raw = await _storage.read(key: _providerKey);
    if (raw == null) return null;
    for (final p in AccountAuthProvider.values) {
      if (p.name == raw) return p;
    }
    return null;
  }

  Future<void> _writeStoredProvider(AccountAuthProvider provider) =>
      _storage.write(key: _providerKey, value: provider.name);

  Future<AccountUser> _userFromIdentity(
    OpenIdIdentity identity, {
    AccountAuthProvider fallbackProvider = AccountAuthProvider.email,
  }) async {
    final id = identity.sub;
    final email = identity.email ??
        identity.userName ??
        identity.claims['preferred_username']?.toString() ??
        '';
    var displayName = identity.fullName ?? identity.givenName ?? email.split('@').first;
    var locale = identity.claims['locale']?.toString() ?? 'vi';

    final prefs = getIt<SharedPreferences>();
    final profileRaw = prefs.getString('$_profileKeyPrefix$id');
    if (profileRaw != null) {
      final profile = jsonDecode(profileRaw) as Map<String, dynamic>;
      displayName = profile['displayName'] as String? ?? displayName;
      locale = profile['preferredLocale'] as String? ?? locale;
    }

    final authProvider = await _readStoredProvider() ?? fallbackProvider;
    return AccountUser(
      id: id,
      email: email,
      displayName: displayName,
      preferredLocale: locale,
      authProvider: authProvider,
    );
  }
}

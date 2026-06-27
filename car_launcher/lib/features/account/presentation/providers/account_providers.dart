import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:car_launcher/features/account/domain/account_user.dart';
import 'package:car_launcher/features/account/repositories/keycloak_auth_repository.dart';

export 'package:car_launcher/features/account/domain/account_user.dart';
export 'package:car_launcher/features/account/repositories/keycloak_auth_repository.dart';

final keycloakAuthRepositoryProvider = Provider<KeycloakAuthRepository>(
  (ref) => KeycloakAuthRepository(),
);

/// Set to `true` by the login page after a successful sign-in.
/// Consumed by the settings page to auto-select the Account section.
final loginSuccessFlagProvider = StateProvider<bool>((ref) => false);

final accountSessionProvider =
    AsyncNotifierProvider<AccountNotifier, AccountUser?>(AccountNotifier.new);

class AccountNotifier extends AsyncNotifier<AccountUser?> {
  AccountUser? _mockUser;

  @override
  Future<AccountUser?> build() async {
    // Debug mode: return mock user if set
    if (kDebugMode && _mockUser != null) {
      debugPrint('[AccountNotifier] build() — using mock user: ${_mockUser!.email}');
      return _mockUser;
    }
    final repo = ref.read(keycloakAuthRepositoryProvider);
    debugPrint('[AccountNotifier] build() — restoring session');
    await repo.restoreSession();
    final user = await repo.currentUser();
    debugPrint('[AccountNotifier] build() — user=${user?.email ?? "null"}');
    return user;
  }

  KeycloakAuthRepository get _repo => ref.read(keycloakAuthRepositoryProvider);

  Future<AccountUser> _login(Future<AccountUser> Function() action) async {
    final previous = state.valueOrNull;
    try {
      debugPrint('[AccountNotifier] _login() — starting');
      final user = await action();
      debugPrint('[AccountNotifier] _login() — success: ${user.email}');
      state = AsyncData(user);
      // Invalidate so next listener re-runs build() and picks up the stored token
      ref.invalidateSelf();
      return user;
    } catch (e, st) {
      debugPrint('[AccountNotifier] _login() — error: $e');
      state = AsyncData(previous);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<AccountUser> loginWithOidc(BuildContext context) =>
      _login(() => _repo.loginWithOidc(context));

  /// Debug-only: set a mock user session without going through OAuth.
  Future<AccountUser> setMockUser(AccountUser user) async {
    // Set a mock access token so API calls work in debug mode
    KeycloakAuthRepository.setDebugMockToken('debug-mock-token');
    _mockUser = user;
    state = AsyncData(user);
    ref.invalidateSelf();
    return user;
  }

  Future<void> logout() async {
    final previous = state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.logout();
      if (kDebugMode) {
        KeycloakAuthRepository.setDebugMockToken(null);
        _mockUser = null;
      }
      return null;
    });
    if (state.hasError) {
      final error = state.error!;
      state = AsyncData(previous);
      Error.throwWithStackTrace(error, StackTrace.current);
    }
  }
}

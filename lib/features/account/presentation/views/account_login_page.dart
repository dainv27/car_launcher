import 'dart:async';

import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/core/logging/logging.dart';
import 'package:car_launcher/features/account/presentation/providers/account_providers.dart';
import 'package:flutter/material.dart' hide Notification; // hide to avoid clash with go_router's Notification
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Keycloak OIDC login page — dark theme matching car_launcher.
/// Uses browser-based OAuth 2.0 / OIDC — no in-app form.
class AccountLoginPage extends ConsumerStatefulWidget {
  const AccountLoginPage({super.key});

  @override
  ConsumerState<AccountLoginPage> createState() => _AccountLoginPageState();
}

class _AccountLoginPageState extends ConsumerState<AccountLoginPage> with WidgetsBindingObserver {
  bool _busy = false;
  Timer? _resumeCancelTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _resumeCancelTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_busy) KeycloakAuthRepository.cancelPendingInteractiveLogin();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_busy) return;
    if (state == AppLifecycleState.resumed) {
      _resumeCancelTimer?.cancel();
      // S60 can take a few seconds to deliver the browser callback through
      // MainActivity and the Flutter MethodChannel after resuming.
      _resumeCancelTimer = Timer(const Duration(seconds: 5), () {
        if (_busy && mounted) KeycloakAuthRepository.cancelPendingInteractiveLogin();
      });
    }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _resumeCancelTimer?.cancel();
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      AppLogger.instance.d('[LoginPage] _run — starting action', tag: 'LOGIN');
      await action();
      AppLogger.instance.d('[LoginPage] _run — action done, navigating to Settings → Account', tag: 'LOGIN');

      // Wait for the widget tree to be fully mounted before navigating,
      // otherwise GoRouter may throw if the context is unmounted.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      // Open the account details immediately after the OAuth callback.
      context.go('/');
    } catch (e, st) {
      AppLogger.instance.e('[LoginPage] _run — error: $e', tag: 'LOGIN', error: e, stackTrace: st);
      if (!mounted) return;
      final message = accountErrorMessage(e);
      if (message != 'Đăng nhập đã hủy.') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      _resumeCancelTimer?.cancel();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [Color(0xFF0A0A0A), Color(0xFF1A1A2E), Color(0xFF0D1B2A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  SizedBox(
                    width: 200,
                    child: Image.asset(
                      'assets/images/dainv.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Sign in to Car Launcher',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(230)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use your account to sign in',
                    style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(128)),
                  ),
                  const SizedBox(height: 40),

                  // Keycloak OIDC login — opens browser
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(() => ref.read(accountSessionProvider.notifier).loginWithOidc(context)),
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.login_rounded, size: 20),
                      label: Text(_busy ? 'Signing in…' : 'Sign in'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

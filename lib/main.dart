import 'dart:ui';

import 'package:car_launcher/core/auth/keycloak_oidc_platform.dart';
import 'package:car_launcher/core/config/env_loader.dart';
import 'package:car_launcher/core/di/injection_container.dart';
import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/core/logging/logging.dart';
import 'package:car_launcher/core/native/native_bridge.dart';
import 'package:car_launcher/core/router/app_router.dart';
import 'package:car_launcher/core/theme/app_theme.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/carplay_settings_providers.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/widget_providers.dart';
import 'package:car_launcher/features/layout/presentation/providers/layout_providers.dart';
import 'package:car_launcher/features/theme/presentation/providers/launcher_appearance_provider.dart';
import 'package:car_launcher/features/theme/presentation/widgets/launcher_background.dart';
import 'package:car_launcher/shared/constants/app_constants.dart';
import 'package:car_launcher/shared/data/device_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';


void main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.instance.e('Flutter error: ${details.exception}', tag: 'MAIN', error: details.exception, stackTrace: details.stack);
  };

  WidgetsFlutterBinding.ensureInitialized();
  configureKeycloakOidcPlatform();

  // Load environment variables from .env files before anything else.
  // This must complete before setupServiceLocator() because services
  // (ApiConfig, KeycloakConfig) read env values at construction time.
  await EnvLoader.instance.load(environment: const String.fromEnvironment('APP_ENV', defaultValue: 'development'));
  AppLogger.instance.i('Environment loaded', tag: 'MAIN');

  // Initialise file logger before anything else
  // Honour LOG_LEVEL (prod: warn) — debug lines for every native call cost
  // I/O on the UI thread in builds that do not need them.
  await AppLogger.instance.init(
    minLevel: LogLevel.parse(EnvLoader.instance.getValue('LOG_LEVEL')),
  );
  AppLogger.instance.i('App starting', tag: 'MAIN');

  // Catch uncaught async errors
  FlutterError.onError = (details) {
    AppLogger.instance.e(
      'Flutter error: ${details.summary}',
      tag: 'ERROR',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.instance.e('Uncaught platform error', tag: 'ERROR', error: error, stackTrace: stack);
    return false;
  };

  // Initialise the service locator. This must happen before runApp so that
  // singletons (SharedPreferences, LauncherService, etc.) are registered
  // before any provider tries to read them.
  await setupServiceLocator();
  AppLogger.instance.d('Service locator initialised', tag: 'MAIN');

  runApp(
    ProviderScope(
      overrides: [
        // sharedPreferencesProvider and launcherServiceProvider are now
        // registered in injection_container.dart — no override needed.
        layoutProvider.overrideWith((ref) => LayoutNotifier(getIt<SharedPreferences>())),
        widgetListProvider.overrideWith((ref) => WidgetListNotifier(getIt<SharedPreferences>())),
        carPlaySettingsProvider.overrideWith((ref) => CarPlaySettingsNotifier(getIt<SharedPreferences>())),
      ],
      child: const CarLauncherApp(),
    ),
  );
}

class CarLauncherApp extends ConsumerWidget {
  const CarLauncherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(effectiveThemeModeProvider);
    final appearance = ref.watch(effectiveLauncherAppearanceProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.launcherLightTheme(appearance),
      darkTheme: AppTheme.launcherTheme(appearance),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            const LauncherBackground(),
            _StartupPermissionGate(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
    );
  }
}

class _StartupPermissionGate extends ConsumerStatefulWidget {
  const _StartupPermissionGate({required this.child});

  final Widget child;

  @override
  ConsumerState<_StartupPermissionGate> createState() => _StartupPermissionGateState();
}

class _StartupPermissionGateState extends ConsumerState<_StartupPermissionGate> {
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;

    // Native reports when the OS runtime-permission dialog resolves; Flutter
    // owns the decision of what (if anything) to open next.
    NativeBridge.setIncomingCallHandler((method) async {
      if (method == 'startupRuntimePermissionsResult') {
        await _ensurePermissions();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Permission
      _ensurePermissions();

      // Register device information
      _ensureDeviceRegistered();
    });
  }

  /// Checks startup permission status and, when policy calls for it, opens
  /// the next relevant settings screen — accessibility input before
  /// notification access, and never while an OS runtime-permission dialog
  /// is still pending (avoids stacking prompts on top of it).
  Future<void> _ensurePermissions() async {
    try {
      final status = await NativeBridge.call<Map<dynamic, dynamic>>('ensureStartupPermissions');
      AppLogger.instance.i('Startup permission check: $status', tag: 'PERMISSION');
      if (status == null) return;

      final requestedRuntimePermissions = status['requestedRuntimePermissions'];
      final hasPendingRuntimeRequest =
          requestedRuntimePermissions is List && requestedRuntimePermissions.isNotEmpty;
      if (hasPendingRuntimeRequest) return;

      if (status['accessibilityInputGranted'] != true) {
        await NativeBridge.call<bool>('openAccessibilitySettings');
      } else if (status['notificationListenerGranted'] != true) {
        await NativeBridge.call<bool>('openNotificationAccessSettings');
      }
    } catch (error, stackTrace) {
      AppLogger.instance.e('Startup permission check failed', tag: 'PERMISSION', error: error, stackTrace: stackTrace);
    }
  }

  /// Registers this device with the backend ONCE per install lifetime.
  ///
  /// We persist a flag keyed by the derived deviceId so the operation
  /// survives app upgrades and restarts. If the user factory-resets the
  /// app they will hit this path again on first launch — which is the
  /// correct behaviour (new install = new registration).
  Future<void> _ensureDeviceRegistered() async {
    try {
      final deviceSyncClient = getIt<DeviceService>();
      await deviceSyncClient.ensureDeviceRegistered();
    } catch (error, stackTrace) {
      // Surface but do not crash the app — registration is best-effort at
      // startup and can be retried on the next launch by clearing the flag
      // if the backend was unreachable transiently.
      AppLogger.instance.e(
        'Install-time device registration failed',
        tag: 'DEVICE',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

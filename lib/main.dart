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
import 'package:car_launcher/features/theme/presentation/providers/theme_providers.dart';
import 'package:car_launcher/features/theme/presentation/widgets/launcher_background.dart';
import 'package:car_launcher/shared/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared/data/location_service.dart';

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
  await AppLogger.instance.init();
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
    final themeMode = ref.watch(themeModeProvider);
    final appearance = ref.watch(effectiveLauncherAppearanceProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.launcherTheme(appearance),
      darkTheme: AppTheme.launcherTheme(appearance),
      themeMode: themeMode == AppThemeMode.auto
          ? ThemeMode.system
          : themeMode == AppThemeMode.night
          ? ThemeMode.dark
          : ThemeMode.light,
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Permission
      _ensurePermissions();

      // Register device information
      _ensureDeviceRegistered();
    });
  }

  Future<void> _ensurePermissions() async {
    try {
      final status = await NativeBridge.call<Map<dynamic, dynamic>>('ensureStartupPermissions');
      AppLogger.instance.i('Startup permission check: $status', tag: 'PERMISSION');
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
      final syncClient = getIt<VehicleTrackingSyncClient>();
      await syncClient.ensureDeviceRegistered();
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

import 'dart:convert';
import 'dart:typed_data';
import 'package:car_launcher/core/services/device_info_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_launcher/core/di/injection_container.dart';
import 'package:car_launcher/core/logging/logging.dart';
import 'package:car_launcher/core/native/native_bridge.dart';
import 'package:car_launcher/core/theme/app_theme.dart';
import 'package:car_launcher/shared/constants/app_constants.dart';

/// Service for launcher core operations
class LauncherService {
  LauncherService(this._prefs);
  final SharedPreferences _prefs;

  /// Get connectivity status from native.
  ///
  /// The native bridge returns `Map<Object?, Object?>` (method-channel
  /// serialisation does not preserve generic type arguments), so we
  /// re-key the map explicitly instead of casting.
  Future<Map<String, dynamic>> getConnectivityStatus() async {
    final raw = await NativeBridge.call<Map<Object?, Object?>>(
      'getConnectivityStatus',
    );
    if (raw == null || raw.isEmpty) return {};
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  /// Get battery level from the same native status source used by the bars.
  Future<int> getBatteryLevel() async {
    return await NativeBridge.call<int>('getBatteryLevel') ?? -1;
  }

  /// Get device info.
  ///
  /// Sourced from `device_info_plus` on the Flutter side (see
  /// `DeviceInfoAdapter`), not the native bridge.
  Future<Map<String, dynamic>> getDeviceInfo() async {
    final info = await DeviceInfoService.instance.fetchDeviceInfo();
    return info.toMap();
  }

  /// Whether native ActivityView embedding is available on this device.
  Future<bool> isEmbeddingSupported() async {
    return await NativeBridge.call<bool>('isEmbeddingSupported') ?? false;
  }

  /// Detailed embedding capability from the native layer.
  Future<Map<String, dynamic>> getEmbeddingInfo() async {
    final raw = await NativeBridge.call<Map<Object?, Object?>>('getEmbeddingInfo');
    if (raw == null || raw.isEmpty) {
      return {
        'supported': false,
        'reason': 'Native bridge unavailable',
        'apiLevel': 0,
      };
    }
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  /// Launch an app by package name
  Future<bool> launchApp(String packageName) async {
    AppLogger.instance.i('Launching app: $packageName', tag: 'LAUNCHER');
    final result = await NativeBridge.call<bool>('launchApp', {
          'packageName': packageName,
        }) ??
        false;
    if (!result) {
      AppLogger.instance.w('Failed to launch app: $packageName', tag: 'LAUNCHER');
    }
    return result;
  }

  /// Launch two apps in split-screen mode (Android 7.0+)
  Future<bool> launchSplitScreen(String pkg1, String pkg2) async {
    return await NativeBridge.call<bool>('launchSplitScreen', {
          'pkg1': pkg1,
          'pkg2': pkg2,
        }) ??
        false;
  }

  /// Launch Google Maps fullscreen and request YouTube in a freeform window.
  /// Falls back to Android adjacent split-screen when freeform is unavailable.
  Future<bool> launchMapsWithYoutubeOnTop() async {
    return await NativeBridge.call<bool>('launchMapsWithYoutubeOnTop') ?? false;
  }

  /// Get launcher icon bytes for [packageName], or null if unavailable.
  Future<Uint8List?> getAppIconBytes(String packageName) async {
    final base64 = await NativeBridge.call<String>('getAppIcon', {
      'packageName': packageName,
    });
    if (base64 == null || base64.isEmpty) return null;
    try {
      return base64Decode(base64);
    } catch (_) {
      return null;
    }
  }

  /// Get installed apps list
  Future<List<Map<String, String>>> getInstalledApps() async {
    final apps = await NativeBridge.call<List>('getInstalledApps') ?? [];
    return apps.map<Map<String, String>>((e) {
      final map = e is Map ? e : <String, String>{};
      return map.map<String, String>(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }).toList();
  }

  /// Get theme mode
  AppThemeMode get themeMode {
    final value = _prefs.getString(AppConstants.keyTheme) ?? 'auto';
    return AppThemeMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppThemeMode.auto,
    );
  }

  /// Set theme mode
  Future<void> setThemeMode(AppThemeMode mode) async {
    await _prefs.setString(AppConstants.keyTheme, mode.name);
  }
}

/// Bridges the get_it-registered [LauncherService] into Riverpod.
///
/// The singleton is registered in injection_container.dart with the
/// SharedPreferences dependency resolved automatically.
final launcherServiceProvider = Provider<LauncherService>(
  (ref) => getIt<LauncherService>(),
);

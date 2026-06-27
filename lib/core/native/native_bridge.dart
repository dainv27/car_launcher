/// Native bridge for Android platform communication
library;

import 'package:car_launcher/core/logging/logging.dart';
import 'package:flutter/services.dart';

/// MethodChannel for communicating with Android native code
class NativeBridge {
  static const _channel = MethodChannel('com.carlauncher/native');
  static const _eventChannel = EventChannel('com.carlauncher/events');

  /// Call a native method
  static Future<T?> call<T>(String method, [dynamic arguments]) async {
    AppLogger.instance.d('Native call → $method', tag: 'NATIVE');
    try {
      final result = await _channel.invokeMethod<T>(method, arguments);
      AppLogger.instance.d('Native call ← $method OK', tag: 'NATIVE');
      return result;
    } on PlatformException catch (e) {
      AppLogger.instance.e(
        'Native call ← $method failed: ${e.code}',
        tag: 'NATIVE',
        error: e,
      );
      throw NativeException(e.code, e.message ?? 'Unknown error');
    } on MissingPluginException {
      AppLogger.instance.e(
        'Native call ← $method: plugin not available',
        tag: 'NATIVE',
      );
      throw NativeException('NO_PLUGIN', 'Native plugin not available');
    }
  }

  /// Listen to native events
  static Stream<dynamic> get events => _eventChannel.receiveBroadcastStream();

  /// Listen to a specific event type
  static Stream<T> onEvent<T>(String eventType) {
    return events.where((e) => e is Map && e['type'] == eventType).cast<T>();
  }

  /// Set the screen brightness (0.0 - 1.0).
  /// Only takes effect when auto-brightness is disabled.
  static Future<bool> setScreenBrightness(double level) async {
    return await call<bool>('setScreenBrightness', {'level': level}) ?? false;
  }

  /// Get the current screen brightness (0.0 - 1.0).
  static Future<double> getScreenBrightness() async {
    final value = await call<double>('getScreenBrightness');
    return value ?? 0.85;
  }

  /// Check whether Android auto-brightness (adaptive brightness) is enabled.
  static Future<bool> isAutoBrightnessEnabled() async {
    return await call<bool>('isAutoBrightnessEnabled') ?? true;
  }

  /// Enable or disable Android auto-brightness.
  static Future<bool> setAutoBrightness(bool enabled) async {
    return await call<bool>('setAutoBrightness', {'enabled': enabled}) ?? false;
  }
}

/// Exception from native bridge
class NativeException implements Exception {
  const NativeException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'NativeException($code): $message';
}

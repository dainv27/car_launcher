import 'package:flutter/services.dart';

/// Channel helper for controlling the native Google Maps PlatformView.
///
/// Communicates with the native-side Google Maps TaskView via a
/// [MethodChannel].  The native implementation is responsible for
/// creating / disposing the TaskView and for handling the commands
/// defined here.
class GoogleMapsChannel {
  GoogleMapsChannel._();

  static const _channel = MethodChannel('car_launcher/google_maps');

  /// Requests the native side to restart / re-route navigation.
  static Future<void> restartMaps() async {
    try {
      await _channel.invokeMethod('restart');
    } on PlatformException {
      // Native side not available — silently ignore.
    } on MissingPluginException {
      // No native implementation registered yet — silently ignore.
    }
  }
}

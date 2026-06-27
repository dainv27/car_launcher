import 'package:car_launcher/core/native/native_bridge.dart';
import 'package:car_launcher/shared/constants/app_constants.dart';
import 'package:car_launcher/shared/providers/shared_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screen brightness settings model.
class BrightnessSettings {
  const BrightnessSettings({
    this.brightness = 0.85,
    this.autoBrightness = true,
  });

  /// Brightness level from 0.0 (darkest) to 1.0 (brightest).
  final double brightness;

  /// Whether Android adaptive brightness is enabled.
  final bool autoBrightness;

  BrightnessSettings copyWith({
    double? brightness,
    bool? autoBrightness,
  }) {
    return BrightnessSettings(
      brightness: brightness ?? this.brightness,
      autoBrightness: autoBrightness ?? this.autoBrightness,
    );
  }
}

/// Riverpod provider for brightness settings.
final brightnessProvider =
    StateNotifierProvider<BrightnessNotifier, BrightnessSettings>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    // Widget tests and previews can use the in-memory defaults.
  }
  return BrightnessNotifier(prefs);
});

class BrightnessNotifier extends StateNotifier<BrightnessSettings> {
  BrightnessNotifier(this._prefs) : super(_read(_prefs));

  final SharedPreferences? _prefs;

  static BrightnessSettings _read(SharedPreferences? prefs) {
    final brightness = prefs?.getDouble(AppConstants.keyScreenBrightness) ?? 0.85;
    final autoBrightness = prefs?.getBool(AppConstants.keyAutoBrightness) ?? true;
    return BrightnessSettings(
      brightness: brightness,
      autoBrightness: autoBrightness,
    );
  }

  /// Set screen brightness (0.0 - 1.0) and push to Android native.
  Future<void> setBrightness(double level) async {
    final clamped = level.clamp(0.0, 1.0);
    state = state.copyWith(brightness: clamped);
    await _prefs?.setDouble(AppConstants.keyScreenBrightness, clamped);
    try {
      await NativeBridge.setScreenBrightness(clamped);
    } on NativeException {
      // Native bridge may not be available on non-Android targets.
    }
  }

  /// Toggle auto-brightness and push to Android native.
  Future<void> setAutoBrightness(bool enabled) async {
    state = state.copyWith(autoBrightness: enabled);
    await _prefs?.setBool(AppConstants.keyAutoBrightness, enabled);
    try {
      await NativeBridge.setAutoBrightness(enabled);
    } on NativeException {
      // Native bridge may not be available on non-Android targets.
    }
  }

  /// Read current brightness from Android native (e.g. on startup).
  Future<void> syncFromNative() async {
    try {
      final nativeBrightness = await NativeBridge.getScreenBrightness();
      final nativeAuto = await NativeBridge.isAutoBrightnessEnabled();
      state = BrightnessSettings(
        brightness: nativeBrightness,
        autoBrightness: nativeAuto,
      );
      await _prefs?.setDouble(
        AppConstants.keyScreenBrightness,
        nativeBrightness,
      );
      await _prefs?.setBool(AppConstants.keyAutoBrightness, nativeAuto);
    } on NativeException {
      // Keep current state if native is unavailable.
    }
  }
}

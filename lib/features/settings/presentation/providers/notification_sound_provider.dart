import 'package:car_launcher/core/native/native_bridge.dart';
import 'package:car_launcher/shared/constants/app_constants.dart';
import 'package:car_launcher/shared/providers/shared_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Selected notification sound (Android system default when both fields
/// are empty).
class NotificationSoundSettings {
  const NotificationSoundSettings({this.uri = '', this.title = ''});

  final String uri;
  final String title;

  String get displayTitle => title.isNotEmpty ? title : 'Default';
}

final notificationSoundProvider = StateNotifierProvider<
    NotificationSoundNotifier, NotificationSoundSettings>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    // Widget tests and previews can use the in-memory defaults.
  }
  return NotificationSoundNotifier(prefs);
});

class NotificationSoundNotifier extends StateNotifier<NotificationSoundSettings> {
  NotificationSoundNotifier(this._prefs) : super(_read(_prefs));

  final SharedPreferences? _prefs;

  static NotificationSoundSettings _read(SharedPreferences? prefs) {
    return NotificationSoundSettings(
      uri: prefs?.getString(AppConstants.keyNotificationSoundUri) ?? '',
      title: prefs?.getString(AppConstants.keyNotificationSoundTitle) ?? '',
    );
  }

  /// Opens the native sound picker and persists the selection. Returns false
  /// if the user cancelled or the native bridge is unavailable.
  Future<bool> pick() async {
    try {
      final picked = await NativeBridge.pickNotificationSound(
        currentUri: state.uri.isNotEmpty ? state.uri : null,
      );
      if (picked == null) return false;
      final uri = picked['uri'] ?? '';
      final title = picked['title'] ?? '';
      state = NotificationSoundSettings(uri: uri, title: title);
      await _prefs?.setString(AppConstants.keyNotificationSoundUri, uri);
      await _prefs?.setString(AppConstants.keyNotificationSoundTitle, title);
      return true;
    } on NativeException {
      return false;
    }
  }
}

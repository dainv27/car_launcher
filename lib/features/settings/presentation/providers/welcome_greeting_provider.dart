import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/features/settings/domain/welcome_greeting.dart';
import 'package:car_launcher/shared/constants/app_constants.dart';
import 'package:car_launcher/shared/providers/shared_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the spoken welcome greeting plays on launcher startup.
final welcomeGreetingEnabledProvider =
    StateNotifierProvider<WelcomeGreetingNotifier, bool>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    // Widget tests and previews can use the in-memory default.
  }
  return WelcomeGreetingNotifier(prefs);
});

class WelcomeGreetingNotifier extends StateNotifier<bool> {
  WelcomeGreetingNotifier(this._prefs)
      : super(_prefs?.getBool(AppConstants.keyWelcomeGreetingEnabled) ?? true);

  final SharedPreferences? _prefs;

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _prefs?.setBool(AppConstants.keyWelcomeGreetingEnabled, enabled);
  }
}

/// Speaks the time-of-day welcome greeting via on-device text-to-speech.
///
/// TTS (rather than a bundled audio file) is what lets the greeting change
/// with the time of day without shipping a recording per phrase.
class WelcomeGreetingService {
  WelcomeGreetingService([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _spokenThisSession = false;

  /// Speaks the greeting once per app session, unless [force] is set (used
  /// by the settings preview button to replay it on demand).
  Future<void> speak({bool force = false}) async {
    if (_spokenThisSession && !force) return;
    _spokenThisSession = true;

    try {
      final languages = await _tts.getLanguages;
      final hasVietnamese =
          languages is List && languages.any((l) => l.toString().toLowerCase().startsWith('vi'));
      await _tts.setLanguage(hasVietnamese ? 'vi-VN' : 'en-US');
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.speak(welcomeGreetingForHour(DateTime.now().hour));
    } catch (error, stackTrace) {
      AppLogger.instance.e(
        'Welcome greeting TTS failed',
        tag: 'WELCOME_GREETING',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

final welcomeGreetingServiceProvider = Provider<WelcomeGreetingService>((ref) {
  return WelcomeGreetingService();
});

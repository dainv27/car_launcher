import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/core/theme/app_theme.dart';

/// Theme mode provider
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
      final launcher = ref.watch(launcherServiceProvider);
      return ThemeModeNotifier(launcher);
    });

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier(this._launcher) : super(_launcher.themeMode) {
    _startAutoThemeTimer();
  }

  final LauncherService _launcher;
  Timer? _autoThemeTimer;

  /// Start a timer that checks every minute whether to switch day/night theme
  /// when auto mode is active. Day: 6:00-18:00, Night: 18:00-6:00.
  void _startAutoThemeTimer() {
    _autoThemeTimer?.cancel();
    _autoThemeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (state == AppThemeMode.auto) {
        // We don't change the state here because auto mode is handled
        // by MaterialApp.themeMode = ThemeMode.system.
        // This timer is for future use if we want custom time-based logic.
      }
    });
  }

  Future<void> setMode(AppThemeMode mode) async {
    await _launcher.setThemeMode(mode);
    state = mode;
  }

  @override
  void dispose() {
    _autoThemeTimer?.cancel();
    super.dispose();
  }
}

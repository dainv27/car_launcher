import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/core/theme/app_theme.dart';

/// The user's raw theme mode preference (day/night/auto), as persisted.
///
/// This is not what Flutter applies directly — [AppThemeMode.auto] needs
/// further resolution against system brightness and the day/night schedule.
/// See `effectiveThemeModeProvider` in launcher_appearance_provider.dart.
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
      final launcher = ref.watch(launcherServiceProvider);
      return ThemeModeNotifier(launcher);
    });

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier(this._launcher) : super(_launcher.themeMode);

  final LauncherService _launcher;

  Future<void> setMode(AppThemeMode mode) async {
    await _launcher.setThemeMode(mode);
    state = mode;
  }
}

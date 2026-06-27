import 'dart:async';

import 'package:car_launcher/core/theme/app_theme.dart';
import 'package:car_launcher/core/theme/launcher_appearance.dart';
import 'package:car_launcher/features/theme/presentation/providers/theme_providers.dart';
import 'package:car_launcher/shared/constants/app_constants.dart';
import 'package:car_launcher/shared/providers/shared_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final launcherAppearanceProvider =
    StateNotifierProvider<LauncherAppearanceNotifier, LauncherAppearance>((
      ref,
    ) {
      SharedPreferences? prefs;
      try {
        prefs = ref.watch(sharedPreferencesProvider);
      } catch (_) {
        // Widget tests and previews can use the in-memory defaults.
      }
      return LauncherAppearanceNotifier(prefs);
    });

class LauncherAppearanceNotifier extends StateNotifier<LauncherAppearance> {
  LauncherAppearanceNotifier(this._prefs) : super(_read(_prefs));

  final SharedPreferences? _prefs;

  static LauncherAppearance _read(SharedPreferences? prefs) {
    return LauncherAppearance(
      themeStyle: LauncherThemeStyle.values.firstWhere(
        (style) =>
            style.name == prefs?.getString(AppConstants.keyLauncherThemeStyle),
        orElse: () => LauncherThemeStyle.dark,
      ),
      backgroundStyle: LauncherBackgroundStyle.values.firstWhere(
        (style) =>
            style.name ==
            prefs?.getString(AppConstants.keyLauncherBackgroundStyle),
        orElse: () => LauncherBackgroundStyle.obsidian,
      ),
      customWallpaperPath: prefs?.getString(AppConstants.keyWallpaper),
    );
  }

  Future<void> setThemeStyle(LauncherThemeStyle style) async {
    state = state.copyWith(themeStyle: style);
    await _prefs?.setString(AppConstants.keyLauncherThemeStyle, style.name);
  }

  Future<void> setBackgroundStyle(LauncherBackgroundStyle style) async {
    state = state.copyWith(backgroundStyle: style);
    await _prefs?.setString(
      AppConstants.keyLauncherBackgroundStyle,
      style.name,
    );
  }

  Future<void> setCustomWallpaperPath(String path) async {
    state = state.copyWith(customWallpaperPath: path);
    await _prefs?.setString(AppConstants.keyWallpaper, path);
  }

  Future<void> clearCustomWallpaper() async {
    state = state.copyWith(clearCustomWallpaper: true);
    await _prefs?.remove(AppConstants.keyWallpaper);
  }
}

final _appearanceClockProvider = StreamProvider<DateTime>((ref) {
  return Stream<DateTime>.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now(),
  ).startWith(DateTime.now());
});

final effectiveLauncherAppearanceProvider = Provider<LauncherAppearance>((ref) {
  final manualAppearance = ref.watch(launcherAppearanceProvider);
  final themeMode = ref.watch(themeModeProvider);
  final now = ref.watch(_appearanceClockProvider).valueOrNull ?? DateTime.now();
  if (themeMode != AppThemeMode.auto) return manualAppearance;

  final scheduled = LauncherAppearanceSchedule.resolve(now);
  return scheduled.copyWith(
    customWallpaperPath: manualAppearance.customWallpaperPath,
  );
});

extension _StartWith<T> on Stream<T> {
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}

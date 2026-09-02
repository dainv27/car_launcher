import 'dart:async';
import 'dart:ui' show Brightness, PlatformDispatcher;

import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/core/logging/logging.dart';
import 'package:car_launcher/core/theme/app_theme.dart';
import 'package:car_launcher/core/theme/launcher_appearance.dart';
import 'package:car_launcher/features/theme/presentation/providers/theme_providers.dart';
import 'package:car_launcher/shared/constants/app_constants.dart';
import 'package:car_launcher/shared/providers/shared_providers.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final launcherAppearanceProvider =
    StateNotifierProvider<LauncherAppearanceNotifier, LauncherAppearance>((
      ref,
    ) {
      SharedPreferences? prefs;
      try {
        prefs = ref.watch(sharedPreferencesProvider);
      } catch (e) {
        // Widget tests and previews can use the in-memory defaults.
        AppLogger.instance.d('SharedPreferences unavailable for appearance', tag: 'THEME', error: e);
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

/// Live platform (OS) brightness, updated whenever Android reports a change
/// (e.g. system dark-mode toggled). Chains any pre-existing callback rather
/// than overwriting it, since [PlatformDispatcher] only holds one.
final _systemBrightnessProvider = StreamProvider<Brightness>((ref) {
  final dispatcher = PlatformDispatcher.instance;
  final controller = StreamController<Brightness>();
  void emit() => controller.add(dispatcher.platformBrightness);

  final previousCallback = dispatcher.onPlatformBrightnessChanged;
  dispatcher.onPlatformBrightnessChanged = () {
    previousCallback?.call();
    emit();
  };
  ref.onDispose(() {
    dispatcher.onPlatformBrightnessChanged = previousCallback;
    controller.close();
  });

  emit();
  return controller.stream;
});

/// Resolves [themeModeProvider] to a concrete [ThemeMode] Flutter can apply.
///
/// Day/Night map directly. Auto prioritizes a real OS dark-mode opt-in (a
/// deliberate signal) over the day/night schedule — but most car head units
/// have no user-facing UI for that OS setting, so it is usually stuck at its
/// light default, which carries no real signal. Only "dark" is trusted from
/// the system; anything else falls back to the same day/night schedule that
/// already drives accent and background (see [LauncherAppearanceSchedule]).
final effectiveThemeModeProvider = Provider<ThemeMode>((ref) {
  final mode = ref.watch(themeModeProvider);
  if (mode == AppThemeMode.day) return ThemeMode.light;
  if (mode == AppThemeMode.night) return ThemeMode.dark;

  final systemBrightness = ref.watch(_systemBrightnessProvider).valueOrNull;
  if (systemBrightness == Brightness.dark) return ThemeMode.dark;

  final now = ref.watch(_appearanceClockProvider).valueOrNull ?? DateTime.now();
  final isDaySchedule =
      LauncherAppearanceSchedule.resolve(now).themeStyle == LauncherThemeStyle.glass;
  return isDaySchedule ? ThemeMode.light : ThemeMode.dark;
});

import 'package:flutter/material.dart';
import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/core/theme/launcher_appearance.dart';

/// Theme configuration for Car Launcher
class AppTheme {
  static ThemeData launcherTheme(LauncherAppearance appearance) {
    final accent = appearance.themeStyle.accent;
    return nightTheme.copyWith(
      colorScheme: nightTheme.colorScheme.copyWith(
        primary: accent,
        secondary: accent,
        surfaceTint: accent,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      splashColor: accent.withValues(alpha: 0.12),
      highlightColor: accent.withValues(alpha: 0.08),
    );
  }

  /// Light counterpart of [launcherTheme] — same accent tinting, applied to
  /// [dayTheme] instead of [nightTheme]. Used as `MaterialApp.theme` so light
  /// mode actually renders light instead of falling back to the dark base.
  static ThemeData launcherLightTheme(LauncherAppearance appearance) {
    final accent = appearance.themeStyle.accent;
    return dayTheme.copyWith(
      colorScheme: dayTheme.colorScheme.copyWith(
        primary: accent,
        secondary: accent,
        surfaceTint: accent,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      splashColor: accent.withValues(alpha: 0.12),
      highlightColor: accent.withValues(alpha: 0.08),
    );
  }

  /// Day theme (light)
  static ThemeData get dayTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: const Color(0xFF1976D2),
      secondary: const Color(0xFF03A9F4),
      surface: const Color(0xFFF5F5F5),
      error: const Color(0xFFB00020),
    ),
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
  );

  /// Night theme (dark)
  static ThemeData get nightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: CarPlayTheme.neonCyan,
      secondary: CarPlayTheme.neonMagenta,
      surface: CarPlayTheme.surface,
      error: const Color(0xFFCF6679),
    ),
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
  );
}

/// Theme mode enum
enum AppThemeMode {
  day,
  night,
  auto;

  String get label => switch (this) {
    AppThemeMode.day => 'Day',
    AppThemeMode.night => 'Night',
    AppThemeMode.auto => 'Auto',
  };
}

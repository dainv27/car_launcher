import 'package:flutter/material.dart';

enum LauncherThemeStyle {
  dark('Dark', Color(0xFF00E5FF)),
  electric('Electric', Color(0xFF9B7BFF)),
  glass('Glass', Color(0xFFA8F7E8));

  const LauncherThemeStyle(this.label, this.accent);

  final String label;
  final Color accent;
}

enum LauncherBackgroundStyle { obsidian, electric, aurora }

@immutable
class LauncherAppearance {
  const LauncherAppearance({
    this.themeStyle = LauncherThemeStyle.dark,
    this.backgroundStyle = LauncherBackgroundStyle.obsidian,
    this.customWallpaperPath,
  });

  final LauncherThemeStyle themeStyle;
  final LauncherBackgroundStyle backgroundStyle;
  final String? customWallpaperPath;

  LauncherAppearance copyWith({
    LauncherThemeStyle? themeStyle,
    LauncherBackgroundStyle? backgroundStyle,
    String? customWallpaperPath,
    bool clearCustomWallpaper = false,
  }) {
    return LauncherAppearance(
      themeStyle: themeStyle ?? this.themeStyle,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      customWallpaperPath: clearCustomWallpaper
          ? null
          : customWallpaperPath ?? this.customWallpaperPath,
    );
  }
}

class LauncherAppearanceSchedule {
  const LauncherAppearanceSchedule._();

  static LauncherAppearance resolve(DateTime now) {
    final hour = now.hour;
    if (hour >= 6 && hour < 17) {
      return const LauncherAppearance(
        themeStyle: LauncherThemeStyle.glass,
        backgroundStyle: LauncherBackgroundStyle.aurora,
      );
    }
    if (hour >= 17 && hour < 22) {
      return const LauncherAppearance(
        themeStyle: LauncherThemeStyle.electric,
        backgroundStyle: LauncherBackgroundStyle.electric,
      );
    }
    return const LauncherAppearance(
      themeStyle: LauncherThemeStyle.dark,
      backgroundStyle: LauncherBackgroundStyle.obsidian,
    );
  }
}

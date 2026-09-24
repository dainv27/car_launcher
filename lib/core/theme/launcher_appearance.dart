import 'package:flutter/material.dart';

/// Accent presets. Enum names are persisted, so only labels and colours may
/// change; each preset carries a night and a day variant tuned for contrast
/// against the matching [LauncherPalette] surfaces.
enum LauncherThemeStyle {
  dark('Arctic', night: Color(0xFF5AC8FA), day: Color(0xFF0068B8)),
  electric('Violet', night: Color(0xFFA78BFA), day: Color(0xFF6D4AE0)),
  glass('Mint', night: Color(0xFF5EE0C4), day: Color(0xFF00806C)),
  ember('Ember', night: Color(0xFFFFA94D), day: Color(0xFFB45309));

  const LauncherThemeStyle(
    this.label, {
    required this.night,
    required this.day,
  });

  final String label;
  final Color night;
  final Color day;

  Color accentFor(Brightness brightness) =>
      brightness == Brightness.dark ? night : day;
}

enum LauncherBackgroundStyle {
  obsidian(
    label: 'Obsidian',
    night: [Color(0xFF0B0D10), Color(0xFF1F242B)],
    day: [Color(0xFFF4F5F7), Color(0xFFDDE1E7)],
  ),
  electric(
    label: 'Dusk',
    night: [Color(0xFF0E0B1A), Color(0xFF2A2150)],
    day: [Color(0xFFF3F1FA), Color(0xFFDCD6F0)],
  ),
  aurora(
    label: 'Horizon',
    night: [Color(0xFF081014), Color(0xFF123A44)],
    day: [Color(0xFFEEF5F6), Color(0xFFD3E6E8)],
  );

  const LauncherBackgroundStyle({
    required this.label,
    required this.night,
    required this.day,
  });

  final String label;

  /// Built-in gradient wallpaper for this preset, used whenever no custom
  /// wallpaper image is selected.
  final List<Color> night;
  final List<Color> day;

  List<Color> gradientFor(Brightness brightness) =>
      brightness == Brightness.dark ? night : day;
}

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

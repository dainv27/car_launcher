import 'package:flutter/material.dart';

/// Semantic colour tokens for the launcher's minimal automotive look.
///
/// Widgets read colours from here (via [LauncherPaletteContext.palette])
/// instead of hard-coding them, so Day/Night mode and the accent preset
/// picked in Settings apply everywhere. Neutral tokens are tuned for WCAG
/// contrast against [surface]: [textPrimary] and [textSecondary] clear 4.5:1,
/// [textTertiary] is reserved for large text, hints and disabled states.
@immutable
class LauncherPalette extends ThemeExtension<LauncherPalette> {
  const LauncherPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.glass,
    required this.border,
    required this.foreground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.favorite,
    required this.toggleTrackOff,
    required this.shadow,
    required this.scrim,
  });

  /// Night palette: graphite neutrals, low glare for night driving.
  factory LauncherPalette.dark(Color accent) => LauncherPalette(
    brightness: Brightness.dark,
    background: const Color(0xFF0B0D10),
    surface: const Color(0xFF15181D),
    surfaceRaised: const Color(0xFF1E2228),
    surfaceSunken: const Color(0xFF0F1115),
    glass: const Color(0xB814171C),
    border: const Color(0x1FFFFFFF),
    foreground: const Color(0xFFFFFFFF),
    textPrimary: const Color(0xFFF2F4F7),
    textSecondary: const Color(0xFFA3AAB5),
    textTertiary: const Color(0xFF6B7280),
    accent: accent,
    onAccent: const Color(0xFF0B0D10),
    success: const Color(0xFF34C759),
    warning: const Color(0xFFFFB020),
    danger: const Color(0xFFFF453A),
    favorite: const Color(0xFFFFD60A),
    toggleTrackOff: const Color(0xFF3A3F47),
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
  );

  /// Day palette: bright neutrals that stay legible in direct sunlight.
  factory LauncherPalette.light(Color accent) => LauncherPalette(
    brightness: Brightness.light,
    background: const Color(0xFFEEF0F3),
    surface: const Color(0xFFFFFFFF),
    surfaceRaised: const Color(0xFFF3F4F6),
    surfaceSunken: const Color(0xFFE6E8EC),
    glass: const Color(0xD1FFFFFF),
    border: const Color(0x1F0F1115),
    foreground: const Color(0xFF0F1115),
    textPrimary: const Color(0xFF0F1115),
    textSecondary: const Color(0xFF4B5563),
    textTertiary: const Color(0xFF6B7280),
    accent: accent,
    onAccent: const Color(0xFFFFFFFF),
    success: const Color(0xFF1F9D4C),
    warning: const Color(0xFFB26A00),
    danger: const Color(0xFFD92D20),
    favorite: const Color(0xFFC99700),
    toggleTrackOff: const Color(0xFFCBD0D6),
    shadow: const Color(0xFF1B2230),
    scrim: const Color(0xFF0F1115),
  );

  final Brightness brightness;

  /// Opaque base colour behind the wallpaper and full-screen pages.
  final Color background;

  /// Opaque card, dialog and sheet colour.
  final Color surface;

  /// Tiles, inputs and selected rows placed on top of [surface].
  final Color surfaceRaised;

  /// Recessed wells such as segmented-control tracks and search fields.
  final Color surfaceSunken;

  /// Translucent panel fill drawn over the wallpaper.
  final Color glass;

  /// Hairline border / divider colour.
  final Color border;

  /// Maximum-contrast ink (white at night, near-black by day). Use it with
  /// an alpha for subtle overlays that must flip with the theme.
  final Color foreground;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// The single accent colour chosen in Settings.
  final Color accent;

  /// Ink placed on top of [accent].
  final Color onAccent;

  final Color success;
  final Color warning;
  final Color danger;
  final Color favorite;
  final Color toggleTrackOff;
  final Color shadow;

  /// Dimming colour for modal barriers and wallpaper legibility layers.
  final Color scrim;

  bool get isDark => brightness == Brightness.dark;

  /// Accent at low opacity, for selected backgrounds and chips.
  Color get accentSoft => accent.withValues(alpha: isDark ? 0.16 : 0.12);

  /// Soft, layered drop shadow that makes cards look lifted.
  List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: shadow.withValues(alpha: isDark ? 0.40 : 0.08),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: shadow.withValues(alpha: isDark ? 0.24 : 0.06),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  /// Restrained accent glow for active interactive elements.
  List<BoxShadow> get accentGlow => [
    BoxShadow(
      color: accent.withValues(alpha: isDark ? 0.35 : 0.25),
      blurRadius: 16,
      spreadRadius: -4,
    ),
  ];

  @override
  LauncherPalette copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? glass,
    Color? border,
    Color? foreground,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? favorite,
    Color? toggleTrackOff,
    Color? shadow,
    Color? scrim,
  }) {
    return LauncherPalette(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      glass: glass ?? this.glass,
      border: border ?? this.border,
      foreground: foreground ?? this.foreground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      favorite: favorite ?? this.favorite,
      toggleTrackOff: toggleTrackOff ?? this.toggleTrackOff,
      shadow: shadow ?? this.shadow,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  LauncherPalette lerp(LauncherPalette? other, double t) {
    if (other is! LauncherPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return LauncherPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      surfaceSunken: mix(surfaceSunken, other.surfaceSunken),
      glass: mix(glass, other.glass),
      border: mix(border, other.border),
      foreground: mix(foreground, other.foreground),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      favorite: mix(favorite, other.favorite),
      toggleTrackOff: mix(toggleTrackOff, other.toggleTrackOff),
      shadow: mix(shadow, other.shadow),
      scrim: mix(scrim, other.scrim),
    );
  }
}

/// Shorthand for reading the [LauncherPalette] from the ambient theme.
extension LauncherPaletteContext on BuildContext {
  /// Falls back to the night palette so widgets rendered outside the app
  /// theme (tests, previews) still get sensible colours.
  LauncherPalette get palette =>
      Theme.of(this).extension<LauncherPalette>() ??
      LauncherPalette.dark(Theme.of(this).colorScheme.primary);
}

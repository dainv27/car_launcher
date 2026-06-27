import 'package:flutter/material.dart';

/// CarPlay-inspired visual tokens.
abstract final class CarPlayTheme {
  static Color accent(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  // ── Legacy CarPlay colors (preserved) ──
  static const background = Color(0xFF000000);
  static const dockBackground = Color(0xFF000000);
  static const toggleOn = Color(0xFF34C759);
  static const toggleOff = Color(0xFF3A3A3C);
  static const settingsBackground = Color(0xFF000000);
  static const secondaryText = Color(0xFF8E8E93);
  static const vpnBadge = Color(0xFF2C2C2E);
  static const secondHand = Color(0xFFFF6B4A);
  static const homeIndicator = Color(0xFFFFFFFF);
  static const searchBarBackground = Color(0xFF1C1C1E);
  static const tileBackground = Color(0xFF2C2C2E);
  static const tertiaryText = Color(0xFF636366);
  static const favoriteAccent = Color(0xFFFFD60A);

  static const dockWidth = 88.0;
  static const appIconSize = 80.0;
  static const appIconRadius = 16.0;
  static const carMinTouchTarget = 88.0;

  // ── Nova Drive automotive design system ──
  // Surfaces
  static const deepObsidian = Color(0xFF030712);
  static const backgroundNova = Color(0xFF06111F);
  static const surface = Color(0xFF071522);
  static const surfaceContainerLowest = Color(0xFF020814);
  static const surfaceContainerLow = Color(0xFF091827);
  static const surfaceContainer = Color(0xFF0D2233);
  static const surfaceContainerHigh = Color(0xFF12324A);
  static const surfaceContainerHighest = Color(0xFF183D59);
  static const surfaceBright = Color(0xFF24516D);
  static const surfaceDim = Color(0xFF06111F);
  static const surfaceVariant = Color(0xFF153046);
  static const glassSurface = Color(0x1A0BE7FF);

  // On-surface colors
  static const onSurface = Color(0xFFE8FBFF);
  static const onSurfaceVariant = Color(0xFFA4C8D4);
  static const inverseSurface = Color(0xFFE4E2E3);
  static const inverseOnSurface = Color(0xFF303031);

  // Primary / accent
  static const primary = Color(0xFF8AF7FF);
  static const primaryContainer = Color(0xFF00E5FF);
  static const primaryFixedDim = Color(0xFF00B8FF);
  static const primaryFixed = Color(0xFFB8FBFF);
  static const onPrimary = Color(0xFF00363D);
  static const onPrimaryContainer = Color(0xFF00626E);
  static const onPrimaryFixed = Color(0xFF001F24);
  static const onPrimaryFixedVariant = Color(0xFF004F58);
  static const surfaceTint = Color(0xFF00DAF3);

  // Secondary
  static const secondary = Color(0xFFC6C6C9);
  static const secondaryFixed = Color(0xFFE2E2E5);
  static const secondaryFixedDim = Color(0xFFC6C6C9);
  static const secondaryContainer = Color(0xFF454749);
  static const onSecondary = Color(0xFF2F3133);
  static const onSecondaryContainer = Color(0xFFB4B5B7);
  static const onSecondaryFixed = Color(0xFF1A1C1E);
  static const onSecondaryFixedVariant = Color(0xFF454749);

  // Tertiary
  static const tertiary = Color(0xFFEAEDF2);
  static const tertiaryFixed = Color(0xFFE0E3E8);
  static const tertiaryFixedDim = Color(0xFFC3C7CC);
  static const tertiaryContainer = Color(0xFFCED1D6);
  static const onTertiary = Color(0xFF2D3135);
  static const onTertiaryContainer = Color(0xFF56595E);
  static const onTertiaryFixed = Color(0xFF181C20);
  static const onTertiaryFixedVariant = Color(0xFF43474B);

  // Outline
  static const outline = Color(0xFF39D8F2);
  static const outlineVariant = Color(0xFF1B4D63);

  // Status
  static const hazardRed = Color(0xFFFF3B30);
  static const error = Color(0xFFFFB4AB);
  static const errorContainer = Color(0xFF93000A);
  static const onError = Color(0xFF690005);
  static const onErrorContainer = Color(0xFFFFDAD6);

  // Named accents
  static const neonCyan = Color(0xFF00E5FF);
  static const neonMagenta = Color(0xFFFF2BD6);
  static const neonViolet = Color(0xFF8B5CFF);
  static const cityAmber = Color(0xFFFFB020);
  static const safetyWhite = Color(0xFFFFFFFF);

  // ── Layout constants ──
  static const gutter = 24.0;
  static const margin = 32.0;
  static const widgetGap = 16.0;
  static const touchTargetMin = 64.0;
}

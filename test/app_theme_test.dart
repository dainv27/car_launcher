import 'package:car_launcher/core/theme/app_theme.dart';
import 'package:car_launcher/core/theme/launcher_appearance.dart';
import 'package:car_launcher/core/theme/launcher_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.1 contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final themes = <String, ThemeData Function(LauncherAppearance)>{
    'night': AppTheme.launcherTheme,
    'day': AppTheme.launcherLightTheme,
  };

  for (final MapEntry(key: mode, value: build) in themes.entries) {
    for (final style in LauncherThemeStyle.values) {
      group('$mode / ${style.label}', () {
        final theme = build(LauncherAppearance(themeStyle: style));
        final palette = theme.extension<LauncherPalette>()!;

        test('registers the palette and applies the preset accent', () {
          expect(palette.accent, style.accentFor(theme.brightness));
          expect(theme.colorScheme.primary, palette.accent);
          expect(theme.colorScheme.onPrimary, palette.onAccent);
        });

        test('body text meets WCAG AA on every surface', () {
          for (final surface in [
            palette.surface,
            palette.surfaceRaised,
            palette.background,
          ]) {
            expect(contrast(palette.textPrimary, surface), greaterThan(4.5));
            expect(contrast(palette.textSecondary, surface), greaterThan(4.5));
          }
        });

        test('accent is legible as text and carries its own ink', () {
          expect(contrast(palette.accent, palette.surface), greaterThan(4.5));
          expect(contrast(palette.onAccent, palette.accent), greaterThan(4.5));
        });
      });
    }
  }

  test('palette lerps for animated theme switches', () {
    final night = LauncherPalette.dark(const Color(0xFF5AC8FA));
    final day = LauncherPalette.light(const Color(0xFF0068B8));
    final mid = night.lerp(day, 0.5);

    expect(mid.surface, Color.lerp(night.surface, day.surface, 0.5));
    expect(night.lerp(day, 0).brightness, Brightness.dark);
    expect(night.lerp(day, 1).brightness, Brightness.light);
  });

  testWidgets('context.palette falls back outside the app theme', (
    tester,
  ) async {
    late LauncherPalette palette;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          palette = context.palette;
          return const SizedBox.shrink();
        },
      ),
    );
    expect(palette.brightness, Brightness.dark);
  });

  test('background presets provide day and night gradients', () {
    for (final style in LauncherBackgroundStyle.values) {
      expect(style.gradientFor(Brightness.dark), isNotEmpty);
      expect(style.gradientFor(Brightness.light), isNotEmpty);
    }
  });
}

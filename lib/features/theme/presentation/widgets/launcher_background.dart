import 'dart:io';

import 'package:car_launcher/core/theme/launcher_appearance.dart';
import 'package:car_launcher/features/theme/presentation/providers/launcher_appearance_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/core/theme/launcher_palette.dart';

class LauncherBackground extends ConsumerWidget {
  const LauncherBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(effectiveLauncherAppearanceProvider);
    final palette = context.palette;

    // Static layer under every page: isolate it so page transitions and
    // widget updates never repaint (or re-rasterize) the wallpaper.
    return Positioned.fill(
      child: RepaintBoundary(
        child: AnimatedContainer(
          key: const Key('launcher-global-background'),
          duration: const Duration(milliseconds: 350),
          color: palette.background,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _WallpaperImage(
                path: appearance.customWallpaperPath,
                backgroundStyle: appearance.backgroundStyle,
                brightness: palette.brightness,
              ),
              _LegibilityScrim(palette: palette),
            ],
          ),
        ),
      ),
    );
  }
}

/// Decode width for full-screen wallpapers: the display's physical width.
///
/// Decoding a camera photo at native size costs ~48 MB of RAM for 12 MP; the
/// head unit runs with a few tens of MB free, so decode at screen size.
int _screenCacheWidth(BuildContext context) {
  final media = MediaQuery.of(context);
  final longest = media.size.longestSide * media.devicePixelRatio;
  return longest.ceil().clamp(1, 4096);
}

class _WallpaperImage extends StatelessWidget {
  const _WallpaperImage({
    required this.backgroundStyle,
    required this.brightness,
    this.path,
  });

  final String? path;
  final LauncherBackgroundStyle backgroundStyle;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final wallpaperPath = path;
    final fallback = _DefaultWallpaperImage(
      style: backgroundStyle,
      brightness: brightness,
    );
    if (wallpaperPath != null && wallpaperPath.isNotEmpty) {
      return Image.file(
        File(wallpaperPath),
        key: const Key('launcher-custom-wallpaper'),
        cacheWidth: _screenCacheWidth(context),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return fallback;
  }
}

/// Default (no custom wallpaper) background. At night the `obsidian` preset
/// keeps the original launcher artwork; every other case renders the
/// preset's calm gradient for the current brightness, so the Settings
/// picker and Day/Night mode both change what is on screen.
class _DefaultWallpaperImage extends StatelessWidget {
  const _DefaultWallpaperImage({required this.style, required this.brightness});

  final LauncherBackgroundStyle style;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final useArtwork =
        style == LauncherBackgroundStyle.obsidian &&
        brightness == Brightness.dark;
    if (!useArtwork) {
      return DecoratedBox(
        key: Key('launcher-default-wallpaper-${style.name}'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: style.gradientFor(brightness),
          ),
        ),
      );
    }
    return Image.asset(
      'assets/images/logo_1.webp',
      key: const Key('launcher-default-wallpaper'),
      cacheWidth: _screenCacheWidth(context),
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );
  }
}

/// Soft top-and-bottom dimming so status bars and cards stay readable on
/// any wallpaper, including bright user photos.
class _LegibilityScrim extends StatelessWidget {
  const _LegibilityScrim({required this.palette});

  final LauncherPalette palette;

  @override
  Widget build(BuildContext context) {
    final tint = palette.isDark ? palette.scrim : palette.background;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              tint.withValues(alpha: 0.55),
              tint.withValues(alpha: 0.25),
              tint.withValues(alpha: 0.55),
            ],
          ),
        ),
      ),
    );
  }
}

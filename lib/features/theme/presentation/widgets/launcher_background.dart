import 'dart:io';

import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/core/theme/launcher_appearance.dart';
import 'package:car_launcher/features/theme/presentation/providers/launcher_appearance_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LauncherBackground extends ConsumerWidget {
  const LauncherBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(effectiveLauncherAppearanceProvider);

    return Positioned.fill(
      child: AnimatedContainer(
        key: const Key('launcher-global-background'),
        duration: const Duration(milliseconds: 350),
        decoration: BoxDecoration(color: CarPlayTheme.deepObsidian),
        child: _WallpaperImage(
          path: appearance.customWallpaperPath,
          backgroundStyle: appearance.backgroundStyle,
        ),
      ),
    );
  }
}

class _WallpaperImage extends StatelessWidget {
  const _WallpaperImage({required this.backgroundStyle, this.path});

  final String? path;
  final LauncherBackgroundStyle backgroundStyle;

  @override
  Widget build(BuildContext context) {
    final wallpaperPath = path;
    if (wallpaperPath != null && wallpaperPath.isNotEmpty) {
      return Image.file(
        File(wallpaperPath),
        key: const Key('launcher-custom-wallpaper'),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _DefaultWallpaperImage(style: backgroundStyle),
      );
    }
    return _DefaultWallpaperImage(style: backgroundStyle);
  }
}

/// Default (no custom wallpaper) background. The `obsidian` preset keeps the
/// original launcher artwork; `electric` and `aurora` render their built-in
/// gradient instead, so the preset picker in Settings actually changes what
/// is on screen.
class _DefaultWallpaperImage extends StatelessWidget {
  const _DefaultWallpaperImage({required this.style});

  final LauncherBackgroundStyle style;

  @override
  Widget build(BuildContext context) {
    if (style != LauncherBackgroundStyle.obsidian) {
      return DecoratedBox(
        key: Key('launcher-default-wallpaper-${style.name}'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: style.gradient,
          ),
        ),
      );
    }
    return Image.asset(
      'assets/images/logo_1.png',
      key: const Key('launcher-default-wallpaper'),
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );
  }
}

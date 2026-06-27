import 'dart:io';

import 'package:car_launcher/core/theme/carplay_theme.dart';
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
        child: _WallpaperImage(path: appearance.customWallpaperPath),
      ),
    );
  }
}

class _WallpaperImage extends StatelessWidget {
  const _WallpaperImage({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final wallpaperPath = path;
    if (wallpaperPath != null && wallpaperPath.isNotEmpty) {
      return Image.file(
        File(wallpaperPath),
        key: const Key('launcher-custom-wallpaper'),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _DefaultWallpaperImage(),
      );
    }
    return const _DefaultWallpaperImage();
  }
}

class _DefaultWallpaperImage extends StatelessWidget {
  const _DefaultWallpaperImage();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_1.png',
      key: const Key('launcher-default-wallpaper'),
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:car_launcher/features/theme/presentation/widgets/launcher_background.dart';

/// Background layer — displays the dashboard wallpaper.
/// Supports static default wallpaper and custom user-selected wallpaper.
class BackgroundLayer extends StatelessWidget {
  const BackgroundLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return const LauncherBackground();
  }
}

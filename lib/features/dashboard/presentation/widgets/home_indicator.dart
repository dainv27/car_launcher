import 'package:flutter/material.dart';
import 'package:car_launcher/core/theme/launcher_palette.dart';

/// iOS-style home indicator bar at the bottom of the screen.
class HomeIndicator extends StatelessWidget {
  const HomeIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          width: 120,
          height: 4,
          decoration: BoxDecoration(
            color: context.palette.textPrimary.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

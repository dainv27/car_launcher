import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:car_launcher/core/theme/launcher_palette.dart';

/// Reusable frosted panel used for dashboard cards.
///
/// Translucent [LauncherPalette.glass] fill over a 24px backdrop blur, a
/// hairline border and a soft layered shadow. [cyanGlow] (kept for API
/// compatibility) adds a restrained accent glow; [glowBorderLeft] draws an
/// accent rail on the leading edge.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.cyanGlow = false,
    this.glowBorderLeft = false,
    this.padding,
  });

  final Widget child;
  final double borderRadius;
  final bool cyanGlow;
  final bool glowBorderLeft;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(borderRadius);
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            ...palette.cardShadow,
            if (cyanGlow) ...palette.accentGlow,
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.glass,
                borderRadius: radius,
                border: Border.all(
                  color: cyanGlow
                      ? palette.accent.withValues(alpha: 0.4)
                      : palette.border,
                ),
              ),
              child: glowBorderLeft
                  ? Row(
                      children: [
                        Container(
                          width: 4,
                          constraints: const BoxConstraints(minHeight: 48),
                          decoration: BoxDecoration(
                            color: palette.accent,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(4),
                            ),
                          ),
                        ),
                        Expanded(child: content),
                      ],
                    )
                  : content,
            ),
          ),
        ),
      ),
    );
  }
}

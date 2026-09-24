import 'package:flutter/material.dart';
import 'package:car_launcher/core/theme/launcher_palette.dart';

/// Reusable frosted panel used for dashboard cards.
///
/// Translucent [LauncherPalette.glass] fill, a hairline border and a soft
/// layered shadow.
///
/// No backdrop blur: the fill is already 72–82% opaque, so a blur behind it
/// was barely visible — invisible over the default gradients — yet it made
/// the GPU re-sample and blur the backdrop on every repaint of each panel,
/// a major cost during page transitions on the head unit's Adreno 610. [cyanGlow] (kept for API
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
    this.shadow = true,
  });

  final Widget child;
  final double borderRadius;
  final bool cyanGlow;
  final bool glowBorderLeft;
  final EdgeInsetsGeometry? padding;

  /// Soft drop shadow. Turn it off for panels that sit next to (or host) an
  /// embedded Maps/YouTube pane: under hybrid composition any Flutter pixel
  /// painted over a platform view — such as a neighbour's 24px shadow —
  /// forces an extra overlay surface, which on the head unit raised the
  /// frame's raster cost from ~7 ms to ~30 ms.
  final bool shadow;

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
            if (shadow) ...palette.cardShadow,
            if (cyanGlow) ...palette.accentGlow,
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
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
    );
  }
}

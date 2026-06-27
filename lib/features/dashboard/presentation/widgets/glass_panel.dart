import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:car_launcher/core/theme/carplay_theme.dart';

/// Reusable glassmorphism panel — matches the `.glass-panel` CSS class from
/// Dashboard_Home.html:
///   background: rgba(255,255,255,0.04)
///   backdrop-filter: blur(24px)
///   border: 1px solid rgba(255,255,255,0.1)
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 12.0,
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
    final accent = CarPlayTheme.accent(context);
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: CarPlayTheme.glassSurface,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.085),
                  CarPlayTheme.neonCyan.withValues(alpha: 0.035),
                  CarPlayTheme.neonMagenta.withValues(alpha: 0.025),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: accent.withValues(alpha: cyanGlow || glowBorderLeft ? 0.26 : 0.12),
                  blurRadius: cyanGlow || glowBorderLeft ? 28 : 18,
                  spreadRadius: -8,
                ),
              ],
            ),
            child: glowBorderLeft
                ? Row(
                    children: [
                      Container(
                        width: 4,
                        constraints: const BoxConstraints(minHeight: 48),
                        decoration: BoxDecoration(
                          color: CarPlayTheme.neonCyan,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CarPlayTheme.neonCyan.withValues(alpha: 0.5),
                              blurRadius: 15,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: padding ?? const EdgeInsets.all(16),
                          child: child,
                        ),
                      ),
                    ],
                  )
                : Padding(
                    padding: padding ?? const EdgeInsets.all(16),
                    child: child,
                  ),
          ),
        ),
      ),
    );
  }
}

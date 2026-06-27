import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A short, compositing-friendly transition tuned for automotive displays.
class CarTransitionPage<T> extends CustomTransitionPage<T> {
  const CarTransitionPage({required super.key, required super.child})
    : super(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 160),
        transitionsBuilder: _buildTransition,
      );

  static Widget _buildTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return child;
    }

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      key: const ValueKey('car-route-fade'),
      opacity: curvedAnimation,
      child: SlideTransition(
        key: const ValueKey('car-route-slide'),
        position: Tween<Offset>(
          begin: const Offset(0.018, 0),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}

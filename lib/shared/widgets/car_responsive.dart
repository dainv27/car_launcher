import 'dart:math' as math;

import 'package:flutter/widgets.dart';

abstract final class CarResponsive {
  static const compactWidth = 1200.0;
  static const expandedWidth = 2000.0;
  static const shortHeight = 650.0;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactWidth;

  static bool isShort(BuildContext context) =>
      MediaQuery.sizeOf(context).height < shortHeight;

  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width < compactWidth
        ? 16
        : width >= expandedWidth
        ? 40
        : 32;
  }

  static double gap(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactWidth ? 12 : 24;

  static double scale(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return math.min(size.width / 1920, size.height / 720).clamp(0.78, 1.25);
  }
}

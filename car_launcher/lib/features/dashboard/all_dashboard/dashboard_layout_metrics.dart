import 'package:flutter/widgets.dart';

@immutable
class DashboardLayoutMetrics {
  const DashboardLayoutMetrics({
    required this.outerPadding,
    required this.gap,
    required this.youtubeWidthFactor,
    required this.mapControlsClearance,
  });

  final double outerPadding;
  final double gap;
  final double youtubeWidthFactor;
  final double mapControlsClearance;

  factory DashboardLayoutMetrics.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final widthProgress = ((size.width - 1024) / (2560 - 1024)).clamp(0.0, 1.0);
    return DashboardLayoutMetrics(
      outerPadding: (size.width * 0.00625).clamp(5.0, 10.0),
      gap: (size.width * 0.00625).clamp(1.0, 2.0),
      youtubeWidthFactor: 0.43 - (0.04 * widthProgress),
      mapControlsClearance: (size.height * 0.12).clamp(72.0, 96.0),
    );
  }
}

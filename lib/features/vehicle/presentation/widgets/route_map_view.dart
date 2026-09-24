import 'package:car_launcher/core/api/geo_utils.dart';
import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:flutter/material.dart';

/// Lightweight, tile-free route preview: fits an ordered list of
/// `(lat, lon)` points to the canvas and draws them as a polyline with
/// start / end markers.
///
/// The app ships no Flutter map package (only a native Google-Maps intent
/// channel), so this is a [CustomPainter] over [GeoUtils.projectToCanvas]
/// rather than a real basemap — enough for a "what did the trip look like"
/// glance in-vehicle.
class RouteMapView extends StatelessWidget {
  const RouteMapView({
    super.key,
    required this.points,
    this.height = 260,
    this.distanceKm,
  });

  /// Ordered path points, oldest first.
  final List<({double lat, double lon})> points;
  final double height;

  /// Optional distance readout drawn as an overlay chip.
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: height,
        width: double.infinity,
        color: CarPlayTheme.surfaceContainerLowest,
        child: points.length < 2
            ? Center(
                child: Text(
                  points.isEmpty
                      ? 'No route for this range'
                      : 'Not enough points to draw a route',
                  style: TextStyle(
                    fontSize: 13,
                    color: CarPlayTheme.onSurfaceVariant,
                  ),
                ),
              )
            : Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RoutePainter(points),
                    ),
                  ),
                  if (distanceKm != null)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: CarPlayTheme.deepObsidian.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${distanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: CarPlayTheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.points);

  final List<({double lat, double lon})> points;

  @override
  void paint(Canvas canvas, Size size) {
    final projected = GeoUtils.projectToCanvas(points, size, padding: 22);
    if (projected.length < 2) return;

    final path = Path()..moveTo(projected.first.dx, projected.first.dy);
    for (var i = 1; i < projected.length; i++) {
      path.lineTo(projected[i].dx, projected[i].dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = CarPlayTheme.neonCyan,
    );

    // Start (green) and end (magenta) markers.
    canvas.drawCircle(
      projected.first,
      6,
      Paint()..color = CarPlayTheme.toggleOn,
    );
    canvas.drawCircle(
      projected.last,
      6,
      Paint()..color = CarPlayTheme.neonMagenta,
    );
    canvas.drawCircle(
      projected.last,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = CarPlayTheme.safetyWhite,
    );
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) =>
      !identical(oldDelegate.points, points);
}

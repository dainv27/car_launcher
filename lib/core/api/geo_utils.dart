import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

/// Small geospatial helpers shared by the tracking / route features.
///
/// Kept dependency-free (no map package) so the same maths backs both the
/// `CustomPainter` route view and any distance readouts.
class GeoUtils {
  const GeoUtils._();

  static const double earthRadiusMeters = 6371000.0;

  static double _degToRad(double deg) => deg * math.pi / 180.0;

  /// Great-circle distance between two `(lat, lon)` pairs, in meters.
  static double haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Total path length in meters over an ordered list of `(lat, lon)` points.
  static double pathLengthMeters(List<({double lat, double lon})> points) {
    if (points.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += haversineMeters(
        points[i - 1].lat,
        points[i - 1].lon,
        points[i].lat,
        points[i].lon,
      );
    }
    return total;
  }

  /// Projects `(lat, lon)` points into canvas [Offset]s that fit inside [size]
  /// (minus [padding] on every edge), preserving aspect ratio with an
  /// equirectangular projection centred on the mean latitude.
  ///
  /// Good enough for a city-scale route preview; not a survey-grade projection.
  static List<Offset> projectToCanvas(
    List<({double lat, double lon})> points,
    Size size, {
    double padding = 16.0,
  }) {
    if (points.isEmpty) return const [];

    final meanLatRad = _degToRad(
      points.map((p) => p.lat).reduce((a, b) => a + b) / points.length,
    );
    final cosMeanLat = math.cos(meanLatRad);

    // World-space coordinates: x scales with longitude * cos(meanLat) so the
    // horizontal and vertical meter-per-degree are comparable.
    double worldX(double lon) => lon * cosMeanLat;
    double worldY(double lat) => -lat; // north is up

    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final p in points) {
      final x = worldX(p.lon);
      final y = worldY(p.lat);
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }

    final available = Rect.fromLTWH(
      padding,
      padding,
      math.max(1.0, size.width - padding * 2),
      math.max(1.0, size.height - padding * 2),
    );
    final spanX = math.max(maxX - minX, 1e-9);
    final spanY = math.max(maxY - minY, 1e-9);
    final scale = math.min(available.width / spanX, available.height / spanY);

    // Centre the projected bbox inside the available rect.
    final drawnW = spanX * scale;
    final drawnH = spanY * scale;
    final originX = available.left + (available.width - drawnW) / 2;
    final originY = available.top + (available.height - drawnH) / 2;

    return [
      for (final p in points)
        Offset(
          originX + (worldX(p.lon) - minX) * scale,
          originY + (worldY(p.lat) - minY) * scale,
        ),
    ];
  }
}

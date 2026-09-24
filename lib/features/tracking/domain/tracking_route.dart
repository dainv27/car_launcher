/// A simplified route polyline for a vehicle over a time range.
///
/// Mirrors `TrackingRouteResponse` in the vehicle-service client API. The
/// server runs Ramer–Douglas–Peucker so the app can draw the path without
/// downloading every raw point.
class TrackingRoute {
  const TrackingRoute({
    this.vehicleId = '',
    this.from,
    this.to,
    this.rawCount = 0,
    this.simplifiedCount = 0,
    this.toleranceMeters,
    this.distanceMeters = 0,
    this.points = const [],
  });

  final String vehicleId;
  final DateTime? from;
  final DateTime? to;
  final int rawCount;
  final int simplifiedCount;
  final double? toleranceMeters;
  final double distanceMeters;
  final List<RoutePoint> points;

  bool get isEmpty => points.isEmpty;

  bool get hasPath => points.length >= 2;

  double get distanceKm => distanceMeters / 1000.0;

  factory TrackingRoute.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    return TrackingRoute(
      vehicleId: json['vehicleId'] as String? ?? '',
      from: _parseTime(json['from']),
      to: _parseTime(json['to']),
      rawCount: (json['rawCount'] as num?)?.toInt() ?? 0,
      simplifiedCount: (json['simplifiedCount'] as num?)?.toInt() ?? 0,
      toleranceMeters: (json['toleranceMeters'] as num?)?.toDouble(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      points: rawPoints is List
          ? rawPoints
              .whereType<Map<String, dynamic>>()
              .map(RoutePoint.fromJson)
              .toList(growable: false)
          : const [],
    );
  }

  static DateTime? _parseTime(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

class RoutePoint {
  const RoutePoint({
    required this.latitude,
    required this.longitude,
    this.speedKph,
    this.eventTime,
  });

  final double latitude;
  final double longitude;
  final double? speedKph;
  final DateTime? eventTime;

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      speedKph: (json['speedKph'] as num?)?.toDouble(),
      eventTime: switch (json['eventTime']) {
        final String s when s.isNotEmpty => DateTime.tryParse(s),
        _ => null,
      },
    );
  }
}

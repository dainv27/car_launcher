import 'dart:math' as math;

import 'package:car_launcher/shared/data/location_service.dart';

/// A GPS point captured locally (offline-first queue), pending or already
/// pushed to the server. Distinct from [TrackingPoint], which is the shape
/// read back *from* the server for the history views.
class VehicleTrackPoint {
  const VehicleTrackPoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.displayName = '',
    this.syncedAt,
  });

  final String id;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String displayName;
  final DateTime? syncedAt;

  bool get synced => syncedAt != null;

  factory VehicleTrackPoint.fromLocation(
    LocationInfo location, {
    DateTime? timestamp,
  }) {
    final capturedAt = timestamp ?? DateTime.now();
    return VehicleTrackPoint(
      id: _buildId(capturedAt, location.latitude, location.longitude),
      latitude: location.latitude,
      longitude: location.longitude,
      displayName: location.displayName,
      timestamp: capturedAt,
    );
  }

  factory VehicleTrackPoint.fromJson(Map<String, dynamic> json) {
    final timestamp =
        DateTime.tryParse(json['timestamp'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final latitude = (json['latitude'] as num).toDouble();
    final longitude = (json['longitude'] as num).toDouble();
    return VehicleTrackPoint(
      id: json['id'] as String? ?? _buildId(timestamp, latitude, longitude),
      latitude: latitude,
      longitude: longitude,
      displayName: json['displayName'] as String? ?? '',
      timestamp: timestamp,
      syncedAt: DateTime.tryParse(json['syncedAt'] as String? ?? ''),
    );
  }

  VehicleTrackPoint markSynced(DateTime value) => VehicleTrackPoint(
    id: id,
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp,
    displayName: displayName,
    syncedAt: value,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'displayName': displayName,
    'timestamp': timestamp.toIso8601String(),
    if (syncedAt != null) 'syncedAt': syncedAt!.toIso8601String(),
  };

  Map<String, dynamic> toSyncJson() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'displayName': displayName,
    'timestamp': timestamp.toIso8601String(),
  };

  Map<String, dynamic> toVehicleServiceJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'eventTime': timestamp.toUtc().toIso8601String(),
    'metadata': {
      'clientPointId': id,
      if (displayName.isNotEmpty) 'displayName': displayName,
    },
  };

  double distanceTo(VehicleTrackPoint other) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = _degToRad(latitude);
    final lat2 = _degToRad(other.latitude);
    final dLat = _degToRad(other.latitude - latitude);
    final dLon = _degToRad(other.longitude - longitude);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static String _buildId(
    DateTime timestamp,
    double latitude,
    double longitude,
  ) {
    return '${timestamp.toUtc().microsecondsSinceEpoch}_${latitude.toStringAsFixed(6)}_${longitude.toStringAsFixed(6)}';
  }

  static double _degToRad(double deg) => deg * math.pi / 180;
}

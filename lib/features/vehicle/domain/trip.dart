/// A segmented trip derived server-side from a vehicle's tracking points.
///
/// Mirrors `TripResponse` in the vehicle-service client API.
class Trip {
  const Trip({
    required this.id,
    this.vehicleId = '',
    this.status = TripStatus.closed,
    this.startTime,
    this.startLat,
    this.startLon,
    this.endTime,
    this.endLat,
    this.endLon,
    this.distanceMeters,
    this.durationSeconds,
    this.maxSpeedKph,
    this.avgSpeedKph,
    this.pointCount = 0,
    this.closeReason,
  });

  final String id;
  final String vehicleId;
  final TripStatus status;
  final DateTime? startTime;
  final double? startLat;
  final double? startLon;
  final DateTime? endTime;
  final double? endLat;
  final double? endLon;
  final double? distanceMeters;
  final int? durationSeconds;
  final double? maxSpeedKph;
  final double? avgSpeedKph;
  final int pointCount;
  final TripCloseReason? closeReason;

  bool get isOpen => status == TripStatus.open;

  double get distanceKm => (distanceMeters ?? 0) / 1000.0;

  Duration? get duration =>
      durationSeconds == null ? null : Duration(seconds: durationSeconds!);

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String? ?? '',
      vehicleId: json['vehicleId'] as String? ?? '',
      status: TripStatus.fromValue(json['status'] as String?),
      startTime: _parseTime(json['startTime']),
      startLat: (json['startLat'] as num?)?.toDouble(),
      startLon: (json['startLon'] as num?)?.toDouble(),
      endTime: _parseTime(json['endTime']),
      endLat: (json['endLat'] as num?)?.toDouble(),
      endLon: (json['endLon'] as num?)?.toDouble(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      maxSpeedKph: (json['maxSpeedKph'] as num?)?.toDouble(),
      avgSpeedKph: (json['avgSpeedKph'] as num?)?.toDouble(),
      pointCount: (json['pointCount'] as num?)?.toInt() ?? 0,
      closeReason: TripCloseReason.fromValue(json['closeReason'] as String?),
    );
  }

  static DateTime? _parseTime(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Trip && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Trip(id: $id, status: ${status.value}, '
      'distance: ${distanceKm.toStringAsFixed(1)}km)';
}

enum TripStatus {
  open('OPEN'),
  closed('CLOSED');

  const TripStatus(this.value);

  final String value;

  static TripStatus fromValue(String? value) {
    for (final s in TripStatus.values) {
      if (s.value == value) return s;
    }
    return TripStatus.closed;
  }
}

enum TripCloseReason {
  ignitionOff('IGNITION_OFF'),
  stopGap('STOP_GAP'),
  staleTimeout('STALE_TIMEOUT');

  const TripCloseReason(this.value);

  final String value;

  static TripCloseReason? fromValue(String? value) {
    if (value == null) return null;
    for (final r in TripCloseReason.values) {
      if (r.value == value) return r;
    }
    return null;
  }

  String get label => switch (this) {
        TripCloseReason.ignitionOff => 'Ignition off',
        TripCloseReason.stopGap => 'Stopped',
        TripCloseReason.staleTimeout => 'Signal lost',
      };
}

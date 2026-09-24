/// A single vehicle tracking point as reported by the tracking subsystem
/// and synced to the vehicle-service API.
///
/// This is the domain-layer representation; the SQLite layer uses
/// [VehicleTrackPoint] and the JSON wire format uses the API shape in
/// [toJson]/[fromJson].
class TrackingPoint {
  const TrackingPoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.eventTime,
    this.vehicleId = '',
    this.speedKph,
    this.heading,
    this.accuracyMeters,
    this.altitudeMeters,
    this.ignitionOn,
    this.metadata = const {},
    this.deviceId = '',
  });

  /// Server-assigned or client-generated point ID.
  final String id;

  /// Vehicle that produced this point.
  final String vehicleId;

  /// Latitude in decimal degrees.
  final double latitude;

  /// Longitude in decimal degrees.
  final double longitude;

  /// Ground speed in km/h (nullable if not available).
  final double? speedKph;

  /// Heading/bearing in degrees 0-360 (nullable).
  final double? heading;

  /// Horizontal accuracy in meters (nullable).
  final double? accuracyMeters;

  /// Altitude in meters (nullable).
  final double? altitudeMeters;

  /// Whether the ignition was on at the time of the reading.
  final bool? ignitionOn;

  /// Server-reported event time.
  final DateTime eventTime;

  /// Arbitrary metadata (e.g. clientPointId, displayName).
  final Map<String, dynamic> metadata;

  /// Device that captured the point.
  final String deviceId;

  factory TrackingPoint.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    final metadata = rawMetadata is Map<String, dynamic>
        ? rawMetadata
        : const <String, dynamic>{};
    return TrackingPoint(
      id: json['id'] as String? ?? '',
      vehicleId: json['vehicleId'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      speedKph: (json['speedKph'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
      altitudeMeters: (json['altitudeMeters'] as num?)?.toDouble(),
      ignitionOn: json['ignitionOn'] as bool?,
      eventTime: DateTime.tryParse(json['eventTime'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      metadata: metadata,
      deviceId: json['deviceId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (vehicleId.isNotEmpty) 'vehicleId': vehicleId,
        'latitude': latitude,
        'longitude': longitude,
        if (speedKph != null) 'speedKph': speedKph,
        if (heading != null) 'heading': heading,
        if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
        if (altitudeMeters != null) 'altitudeMeters': altitudeMeters,
        if (ignitionOn != null) 'ignitionOn': ignitionOn,
        'eventTime': eventTime.toUtc().toIso8601String(),
        if (metadata.isNotEmpty) 'metadata': metadata,
        if (deviceId.isNotEmpty) 'deviceId': deviceId,
      };

  /// Convert to the sync payload expected by POST /tracking-points.
  Map<String, double> toLocationJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  @override
  String toString() =>
      'TrackingPoint(id: $id, lat: $latitude, lon: $longitude, eventTime: $eventTime)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackingPoint &&
          id == other.id &&
          vehicleId == other.vehicleId &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          eventTime == other.eventTime;

  @override
  int get hashCode => Object.hash(id, vehicleId, latitude, longitude, eventTime);
}

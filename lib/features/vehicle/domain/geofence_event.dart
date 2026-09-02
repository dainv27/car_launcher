/// A geofence ENTER / EXIT transition recorded for a vehicle.
///
/// Mirrors `GeofenceEventResponse` in the vehicle-service client API.
class GeofenceEvent {
  const GeofenceEvent({
    required this.id,
    this.geofenceId = '',
    this.geofenceName = '',
    this.vehicleId = '',
    this.transition = GeofenceTransition.enter,
    this.latitude,
    this.longitude,
    this.eventTime,
  });

  final String id;
  final String geofenceId;
  final String geofenceName;
  final String vehicleId;
  final GeofenceTransition transition;
  final double? latitude;
  final double? longitude;
  final DateTime? eventTime;

  factory GeofenceEvent.fromJson(Map<String, dynamic> json) {
    return GeofenceEvent(
      id: json['id'] as String? ?? '',
      geofenceId: json['geofenceId'] as String? ?? '',
      geofenceName: json['geofenceName'] as String? ?? '',
      vehicleId: json['vehicleId'] as String? ?? '',
      transition: GeofenceTransition.fromValue(json['transition'] as String?),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      eventTime: switch (json['eventTime']) {
        final String s when s.isNotEmpty => DateTime.tryParse(s),
        _ => null,
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GeofenceEvent && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

enum GeofenceTransition {
  enter('ENTER'),
  exit('EXIT');

  const GeofenceTransition(this.value);

  final String value;

  static GeofenceTransition fromValue(String? value) {
    for (final t in GeofenceTransition.values) {
      if (t.value == value) return t;
    }
    return GeofenceTransition.enter;
  }
}

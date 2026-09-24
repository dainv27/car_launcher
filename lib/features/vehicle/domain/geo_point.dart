/// A plain `(latitude, longitude)` pair used by geofence polygons and any
/// other place the client API exchanges a `LatLng` object.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        (json['latitude'] as num?)?.toDouble() ?? 0,
        (json['longitude'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint &&
          other.latitude == latitude &&
          other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

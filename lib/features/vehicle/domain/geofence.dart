import 'package:car_launcher/features/vehicle/domain/geo_point.dart';

/// A geofence owned by the current user, optionally bound to one vehicle.
///
/// Mirrors `GeofenceResponse` / `CreateGeofenceRequest` in the vehicle-service
/// client API. A geofence is either a [GeofenceShape.circle] (centre + radius)
/// or a [GeofenceShape.polygon] (ordered ring of vertices).
class Geofence {
  const Geofence({
    this.id = '',
    this.vehicleId,
    this.name = '',
    this.shape = GeofenceShape.circle,
    this.centerLat,
    this.centerLon,
    this.radiusMeters,
    this.polygon = const [],
    this.active = true,
    this.notifyOnEnter = true,
    this.notifyOnExit = true,
  });

  final String id;

  /// `null` means the geofence applies to every vehicle the owner has.
  final String? vehicleId;
  final String name;
  final GeofenceShape shape;
  final double? centerLat;
  final double? centerLon;
  final double? radiusMeters;
  final List<GeoPoint> polygon;
  final bool active;
  final bool notifyOnEnter;
  final bool notifyOnExit;

  bool get isCircle => shape == GeofenceShape.circle;

  Geofence copyWith({
    String? id,
    Object? vehicleId = _sentinel,
    String? name,
    GeofenceShape? shape,
    double? centerLat,
    double? centerLon,
    double? radiusMeters,
    List<GeoPoint>? polygon,
    bool? active,
    bool? notifyOnEnter,
    bool? notifyOnExit,
  }) {
    return Geofence(
      id: id ?? this.id,
      vehicleId:
          identical(vehicleId, _sentinel) ? this.vehicleId : vehicleId as String?,
      name: name ?? this.name,
      shape: shape ?? this.shape,
      centerLat: centerLat ?? this.centerLat,
      centerLon: centerLon ?? this.centerLon,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      polygon: polygon ?? this.polygon,
      active: active ?? this.active,
      notifyOnEnter: notifyOnEnter ?? this.notifyOnEnter,
      notifyOnExit: notifyOnExit ?? this.notifyOnExit,
    );
  }

  factory Geofence.fromJson(Map<String, dynamic> json) {
    final rawPolygon = json['polygon'];
    return Geofence(
      id: json['id'] as String? ?? '',
      vehicleId: json['vehicleId'] as String?,
      name: json['name'] as String? ?? '',
      shape: GeofenceShape.fromValue(json['shapeType'] as String?),
      centerLat: (json['centerLat'] as num?)?.toDouble(),
      centerLon: (json['centerLon'] as num?)?.toDouble(),
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble(),
      polygon: rawPolygon is List
          ? rawPolygon
              .whereType<Map<String, dynamic>>()
              .map(GeoPoint.fromJson)
              .toList(growable: false)
          : const [],
      active: json['active'] as bool? ?? true,
      notifyOnEnter: json['notifyOnEnter'] as bool? ?? true,
      notifyOnExit: json['notifyOnExit'] as bool? ?? true,
    );
  }

  /// Body for `POST /client-api/v1/geofences`.
  Map<String, dynamic> toCreateJson() => {
        if (vehicleId != null && vehicleId!.isNotEmpty) 'vehicleId': vehicleId,
        'name': name,
        'shapeType': shape.value,
        if (isCircle) ...{
          'centerLat': centerLat,
          'centerLon': centerLon,
          'radiusMeters': radiusMeters,
        } else
          'polygon': polygon.map((p) => p.toJson()).toList(growable: false),
        'active': active,
        'notifyOnEnter': notifyOnEnter,
        'notifyOnExit': notifyOnExit,
      };

  /// Body for `PATCH /client-api/v1/geofences/{id}` — all fields optional.
  Map<String, dynamic> toUpdateJson() => {
        'name': name,
        if (isCircle) ...{
          'centerLat': centerLat,
          'centerLon': centerLon,
          'radiusMeters': radiusMeters,
        } else
          'polygon': polygon.map((p) => p.toJson()).toList(growable: false),
        'active': active,
        'notifyOnEnter': notifyOnEnter,
        'notifyOnExit': notifyOnExit,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Geofence && other.id == id;

  @override
  int get hashCode => id.hashCode;

  static const Object _sentinel = Object();
}

enum GeofenceShape {
  circle('CIRCLE'),
  polygon('POLYGON');

  const GeofenceShape(this.value);

  final String value;

  static GeofenceShape fromValue(String? value) {
    for (final s in GeofenceShape.values) {
      if (s.value == value) return s;
    }
    return GeofenceShape.circle;
  }
}

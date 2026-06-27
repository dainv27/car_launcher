import 'package:car_launcher/shared/data/location_service.dart';

/// Primary vehicle entity for the vehicle management feature.
///
/// This wraps the API contract fields and provides conversion to/from
/// the existing [VehicleProfile] model used by the tracking subsystem.
class Vehicle {
  const Vehicle({
    this.id = '',
    this.plateNumber = '',
    this.name = '',
    this.brand = '',
    this.model = '',
    this.metadata = const {},
  });

  /// Server-assigned vehicle ID (e.g. "car-001").
  final String id;

  /// License plate number (e.g. "51A-12345").
  final String plateNumber;

  /// Human-readable vehicle name (e.g. "Family car").
  final String name;

  /// Vehicle brand/manufacturer (e.g. "Toyota").
  final String brand;

  /// Vehicle model (e.g. "Vios").
  final String model;

  /// Arbitrary key-value metadata (e.g. {"year": "2026"}).
  final Map<String, dynamic> metadata;

  /// Convenience accessor for the "year" metadata field.
  String get year => metadata['year']?.toString() ?? '';

  bool get hasData =>
      id.isNotEmpty ||
      plateNumber.isNotEmpty ||
      name.isNotEmpty ||
      brand.isNotEmpty ||
      model.isNotEmpty;

  String get displayName {
    if (plateNumber.isNotEmpty) return plateNumber;
    if (name.isNotEmpty) return name;
    if (id.isNotEmpty) return id;
    return 'Unknown vehicle';
  }

  Vehicle copyWith({
    String? id,
    String? plateNumber,
    String? name,
    String? brand,
    String? model,
    Map<String, dynamic>? metadata,
  }) {
    return Vehicle(
      id: id ?? this.id,
      plateNumber: plateNumber ?? this.plateNumber,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Create from the API JSON response shape.
  factory Vehicle.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    final metadata = rawMetadata is Map<String, dynamic>
        ? rawMetadata
        : const <String, dynamic>{};
    return Vehicle(
      id: json['id'] as String? ?? json['vehicleId'] as String? ?? '',
      plateNumber: json['plateNumber'] as String? ?? '',
      name: json['name'] as String? ?? '',
      brand: json['brand'] as String? ?? json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      metadata: metadata,
    );
  }

  /// Serialize to API JSON for POST /vehicles.
  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        if (id.isNotEmpty) 'vehicleId': id,
        'plateNumber': plateNumber,
        'name': name,
        'brand': brand,
        'model': model,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  /// Serialize to the PATCH request shape (all fields optional).
  Map<String, dynamic> toPatchJson() => {
        'plateNumber': plateNumber,
        'name': name,
        'brand': brand,
        'model': model,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  /// Convert to [VehicleProfile] for use by the tracking subsystem.
  VehicleProfile toProfile() => VehicleProfile(
        vehicleId: id,
        plateNumber: plateNumber,
        name: name,
        make: brand,
        model: model,
        year: year,
      );

  /// Create from an existing [VehicleProfile].
  factory Vehicle.fromProfile(VehicleProfile profile) => Vehicle(
        id: profile.vehicleId,
        plateNumber: profile.plateNumber,
        name: profile.name,
        brand: profile.make,
        model: profile.model,
        metadata: profile.year.isNotEmpty ? {'year': profile.year} : const {},
      );

  @override
  String toString() => 'Vehicle(id: $id, plateNumber: $plateNumber, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vehicle &&
          id == other.id &&
          plateNumber == other.plateNumber &&
          name == other.name &&
          brand == other.brand &&
          model == other.model;

  @override
  int get hashCode => Object.hash(id, plateNumber, name, brand, model);
}

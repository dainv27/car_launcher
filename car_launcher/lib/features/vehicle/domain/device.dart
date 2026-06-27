/// Device entity representing a piece of hardware attached to a vehicle.
///
/// Mirrors the API contract shape for `/devices` endpoints.
class Device {
  const Device({
    this.id = '',
    this.vehicleId = '',
    this.name = '',
    this.serialNumber = '',
    this.imei = '',
    this.phoneNumber = '',
    this.model = '',
    this.firmwareVersion = '',
    this.metadata = const {},
  });

  /// Server-assigned device ID (e.g. "dev-001").
  final String id;

  /// Vehicle ID this device is attached to.
  final String vehicleId;

  /// Human-readable device name.
  final String name;

  /// Hardware serial number.
  final String serialNumber;

  /// Device IMEI (if cellular-capable).
  final String imei;

  /// Phone number associated with the SIM in the device.
  final String phoneNumber;

  /// Device model identifier.
  final String model;

  /// Currently installed firmware version.
  final String firmwareVersion;

  /// Arbitrary key-value metadata.
  final Map<String, dynamic> metadata;

  bool get hasData =>
      id.isNotEmpty ||
      vehicleId.isNotEmpty ||
      name.isNotEmpty ||
      serialNumber.isNotEmpty;

  String get displayName {
    if (name.isNotEmpty) return name;
    if (serialNumber.isNotEmpty) return serialNumber;
    if (id.isNotEmpty) return id;
    return 'Unknown device';
  }

  Device copyWith({
    String? id,
    String? vehicleId,
    String? name,
    String? serialNumber,
    String? imei,
    String? phoneNumber,
    String? model,
    String? firmwareVersion,
    Map<String, dynamic>? metadata,
  }) {
    return Device(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      name: name ?? this.name,
      serialNumber: serialNumber ?? this.serialNumber,
      imei: imei ?? this.imei,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      model: model ?? this.model,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Create from the API JSON response shape.
  factory Device.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    final metadata = rawMetadata is Map<String, dynamic>
        ? rawMetadata
        : const <String, dynamic>{};
    return Device(
      id: json['id'] as String? ?? '',
      vehicleId: json['vehicleId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      serialNumber: json['serialNumber'] as String? ?? '',
      imei: json['imei'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      model: json['model'] as String? ?? '',
      firmwareVersion: json['firmwareVersion'] as String? ?? '',
      metadata: metadata,
    );
  }

  /// Serialize to API JSON for POST /devices.
  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        if (vehicleId.isNotEmpty) 'vehicleId': vehicleId,
        if (name.isNotEmpty) 'name': name,
        if (serialNumber.isNotEmpty) 'serialNumber': serialNumber,
        if (imei.isNotEmpty) 'imei': imei,
        if (phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
        if (model.isNotEmpty) 'model': model,
        if (firmwareVersion.isNotEmpty) 'firmwareVersion': firmwareVersion,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  /// Serialize for POST /devices (same as [toJson]).
  Map<String, dynamic> toCreateJson() => toJson();

  @override
  String toString() =>
      'Device(id: $id, vehicleId: $vehicleId, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device &&
          id == other.id &&
          vehicleId == other.vehicleId &&
          name == other.name &&
          serialNumber == other.serialNumber;

  @override
  int get hashCode => Object.hash(id, vehicleId, name, serialNumber);
}

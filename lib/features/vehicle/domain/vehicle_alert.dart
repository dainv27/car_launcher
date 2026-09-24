import 'package:car_launcher/features/vehicle/domain/alert_rule.dart';

/// A raised speeding / idle alert.
///
/// Mirrors `AlertResponse` in the vehicle-service client API.
class VehicleAlert {
  const VehicleAlert({
    required this.id,
    this.ruleId = '',
    this.vehicleId = '',
    this.type = AlertType.overspeed,
    this.status = AlertStatus.open,
    this.message = '',
    this.peakValue,
    this.latitude,
    this.longitude,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String ruleId;
  final String vehicleId;
  final AlertType type;
  final AlertStatus status;
  final String message;

  /// Peak speed (OVERSPEED) or idle minutes (IDLE) observed for this alert.
  final double? peakValue;
  final double? latitude;
  final double? longitude;
  final DateTime? startedAt;
  final DateTime? endedAt;

  bool get isOpen => status == AlertStatus.open;

  factory VehicleAlert.fromJson(Map<String, dynamic> json) {
    return VehicleAlert(
      id: json['id'] as String? ?? '',
      ruleId: json['ruleId'] as String? ?? '',
      vehicleId: json['vehicleId'] as String? ?? '',
      type: AlertType.fromValue(json['type'] as String?),
      status: AlertStatus.fromValue(json['status'] as String?),
      message: json['message'] as String? ?? '',
      peakValue: (json['peakValue'] as num?)?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      startedAt: _parseTime(json['startedAt']),
      endedAt: _parseTime(json['endedAt']),
    );
  }

  static DateTime? _parseTime(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is VehicleAlert && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

enum AlertStatus {
  open('OPEN'),
  resolved('RESOLVED');

  const AlertStatus(this.value);

  final String value;

  static AlertStatus fromValue(String? value) {
    for (final s in AlertStatus.values) {
      if (s.value == value) return s;
    }
    return AlertStatus.open;
  }
}

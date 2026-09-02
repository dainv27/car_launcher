/// A speeding / idle alert rule owned by the current user.
///
/// Mirrors `AlertRuleResponse` / `CreateAlertRuleRequest` in the
/// vehicle-service client API.
class AlertRule {
  const AlertRule({
    this.id = '',
    this.vehicleId,
    this.type = AlertType.overspeed,
    this.speedLimitKph,
    this.idleMinutes,
    this.minDurationSeconds,
    this.active = true,
  });

  final String id;

  /// `null` means the rule applies to every vehicle the owner has.
  final String? vehicleId;
  final AlertType type;

  /// OVERSPEED only.
  final double? speedLimitKph;

  /// IDLE only.
  final int? idleMinutes;

  /// OVERSPEED only — sustain the breach this long before raising.
  final int? minDurationSeconds;
  final bool active;

  bool get isOverspeed => type == AlertType.overspeed;

  AlertRule copyWith({
    String? id,
    Object? vehicleId = _sentinel,
    AlertType? type,
    double? speedLimitKph,
    int? idleMinutes,
    int? minDurationSeconds,
    bool? active,
  }) {
    return AlertRule(
      id: id ?? this.id,
      vehicleId:
          identical(vehicleId, _sentinel) ? this.vehicleId : vehicleId as String?,
      type: type ?? this.type,
      speedLimitKph: speedLimitKph ?? this.speedLimitKph,
      idleMinutes: idleMinutes ?? this.idleMinutes,
      minDurationSeconds: minDurationSeconds ?? this.minDurationSeconds,
      active: active ?? this.active,
    );
  }

  factory AlertRule.fromJson(Map<String, dynamic> json) {
    return AlertRule(
      id: json['id'] as String? ?? '',
      vehicleId: json['vehicleId'] as String?,
      type: AlertType.fromValue(json['type'] as String?),
      speedLimitKph: (json['speedLimitKph'] as num?)?.toDouble(),
      idleMinutes: (json['idleMinutes'] as num?)?.toInt(),
      minDurationSeconds: (json['minDurationSeconds'] as num?)?.toInt(),
      active: json['active'] as bool? ?? true,
    );
  }

  /// Body for `POST /client-api/v1/alert-rules`.
  Map<String, dynamic> toCreateJson() => {
        if (vehicleId != null && vehicleId!.isNotEmpty) 'vehicleId': vehicleId,
        'type': type.value,
        if (isOverspeed) ...{
          'speedLimitKph': speedLimitKph,
          if (minDurationSeconds != null)
            'minDurationSeconds': minDurationSeconds,
        } else
          'idleMinutes': idleMinutes,
        'active': active,
      };

  /// Body for `PATCH /client-api/v1/alert-rules/{ruleId}` — all fields optional.
  Map<String, dynamic> toUpdateJson() => {
        if (isOverspeed) ...{
          if (speedLimitKph != null) 'speedLimitKph': speedLimitKph,
          if (minDurationSeconds != null)
            'minDurationSeconds': minDurationSeconds,
        } else if (idleMinutes != null)
          'idleMinutes': idleMinutes,
        'active': active,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AlertRule && other.id == id;

  @override
  int get hashCode => id.hashCode;

  static const Object _sentinel = Object();
}

enum AlertType {
  overspeed('OVERSPEED'),
  idle('IDLE');

  const AlertType(this.value);

  final String value;

  static AlertType fromValue(String? value) {
    for (final t in AlertType.values) {
      if (t.value == value) return t;
    }
    return AlertType.overspeed;
  }

  String get label => switch (this) {
        AlertType.overspeed => 'Speeding',
        AlertType.idle => 'Idle',
      };
}

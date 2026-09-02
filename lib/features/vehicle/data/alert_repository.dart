import 'package:car_launcher/features/vehicle/data/alert_api_client.dart';
import 'package:car_launcher/features/vehicle/domain/alert_rule.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle_alert.dart';

/// Maps the raw `alert-client` JSON into domain [AlertRule] / [VehicleAlert]
/// and back.
class AlertRepository {
  AlertRepository({
    required this._apiClient,
    required this.syncEndpoint,
  });

  final AlertApiClient _apiClient;

  /// Vehicle-service base URL override (from the runtime tracking state).
  final String syncEndpoint;

  // ---- Rules ------------------------------------------------------------

  Future<List<AlertRule>> listRules({
    String? vehicleId,
    int page = 0,
    int size = 50,
  }) async {
    final raw = await _apiClient.listRules(
      endpoint: syncEndpoint,
      vehicleId: vehicleId,
      page: page,
      size: size,
    );
    return raw.map(AlertRule.fromJson).toList(growable: false);
  }

  Future<AlertRule> createRule(AlertRule rule) async {
    final json = await _apiClient.createRule(
      endpoint: syncEndpoint,
      body: rule.toCreateJson(),
    );
    return AlertRule.fromJson(json);
  }

  Future<AlertRule> updateRule(AlertRule rule) async {
    final json = await _apiClient.updateRule(
      endpoint: syncEndpoint,
      ruleId: rule.id,
      body: rule.toUpdateJson(),
    );
    return AlertRule.fromJson(json);
  }

  Future<void> deleteRule(String ruleId) {
    return _apiClient.deleteRule(endpoint: syncEndpoint, ruleId: ruleId);
  }

  // ---- Raised alerts --------------------------------------------------

  Future<List<VehicleAlert>> listAlerts({
    String? vehicleId,
    AlertType? type,
    AlertStatus? status,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 50,
  }) async {
    final raw = await _apiClient.listAlerts(
      endpoint: syncEndpoint,
      vehicleId: vehicleId,
      type: type?.value,
      status: status?.value,
      from: from,
      to: to,
      page: page,
      size: size,
    );
    return raw.map(VehicleAlert.fromJson).toList(growable: false);
  }

  Future<VehicleAlert> resolveAlert(String alertId) async {
    final json = await _apiClient.resolveAlert(
      endpoint: syncEndpoint,
      alertId: alertId,
    );
    return VehicleAlert.fromJson(json);
  }
}

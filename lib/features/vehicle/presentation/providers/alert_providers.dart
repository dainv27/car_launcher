import 'package:car_launcher/core/di/injection_container.dart';
import 'package:car_launcher/features/vehicle/data/alert_repository.dart';
import 'package:car_launcher/features/vehicle/domain/alert_rule.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle_alert.dart';
import 'package:car_launcher/shared/data/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resolves the [AlertRepository] for the current runtime sync endpoint.
final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  final tracking = ref.watch(vehicleTrackingProvider);
  return getIt<AlertRepository>(param1: tracking.syncEndpoint);
});

/// Filter for [alertListProvider].
typedef AlertQuery = ({
  String vehicleId,
  AlertType? type,
  AlertStatus? status,
});

/// Raised alerts for a vehicle, with a `resolve` action.
final alertListProvider =
    AsyncNotifierProvider.family<AlertListNotifier, List<VehicleAlert>, AlertQuery>(
  AlertListNotifier.new,
);

class AlertListNotifier
    extends FamilyAsyncNotifier<List<VehicleAlert>, AlertQuery> {
  @override
  Future<List<VehicleAlert>> build(AlertQuery query) async {
    final repo = ref.watch(alertRepositoryProvider);
    return repo.listAlerts(
      vehicleId: query.vehicleId.isEmpty ? null : query.vehicleId,
      type: query.type,
      status: query.status,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(alertRepositoryProvider).listAlerts(
            vehicleId: arg.vehicleId.isEmpty ? null : arg.vehicleId,
            type: arg.type,
            status: arg.status,
          ),
    );
  }

  Future<void> resolve(String alertId) async {
    await ref.read(alertRepositoryProvider).resolveAlert(alertId);
    ref.invalidateSelf();
  }
}

/// Alert rules visible for a vehicle (its own + owner-wide), with create /
/// update / delete. Mutations throw on failure; the caller shows the message.
final alertRuleListProvider =
    AsyncNotifierProvider.family<AlertRuleListNotifier, List<AlertRule>, String>(
  AlertRuleListNotifier.new,
);

class AlertRuleListNotifier
    extends FamilyAsyncNotifier<List<AlertRule>, String> {
  @override
  Future<List<AlertRule>> build(String vehicleId) async {
    final repo = ref.watch(alertRepositoryProvider);
    return repo.listRules(vehicleId: vehicleId.isEmpty ? null : vehicleId);
  }

  AlertRepository get _repo => ref.read(alertRepositoryProvider);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.listRules(vehicleId: arg.isEmpty ? null : arg),
    );
  }

  Future<AlertRule> createRule(AlertRule rule) async {
    final created = await _repo.createRule(rule);
    ref.invalidateSelf();
    return created;
  }

  Future<AlertRule> updateRule(AlertRule rule) async {
    final updated = await _repo.updateRule(rule);
    ref.invalidateSelf();
    return updated;
  }

  Future<void> deleteRule(String ruleId) async {
    await _repo.deleteRule(ruleId);
    ref.invalidateSelf();
  }
}

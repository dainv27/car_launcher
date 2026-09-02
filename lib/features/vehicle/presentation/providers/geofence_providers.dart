import 'package:car_launcher/core/di/injection_container.dart';
import 'package:car_launcher/features/vehicle/data/geofence_repository.dart';
import 'package:car_launcher/features/vehicle/domain/geofence.dart';
import 'package:car_launcher/features/vehicle/domain/geofence_event.dart';
import 'package:car_launcher/shared/data/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resolves the [GeofenceRepository] for the current runtime sync endpoint.
final geofenceRepositoryProvider = Provider<GeofenceRepository>((ref) {
  final tracking = ref.watch(vehicleTrackingProvider);
  return getIt<GeofenceRepository>(param1: tracking.syncEndpoint);
});

/// Geofences visible for a vehicle (its own + owner-wide), with create /
/// update / delete. Mutations throw on failure; the caller shows the message.
final geofenceListProvider =
    AsyncNotifierProvider.family<GeofenceListNotifier, List<Geofence>, String>(
  GeofenceListNotifier.new,
);

class GeofenceListNotifier
    extends FamilyAsyncNotifier<List<Geofence>, String> {
  @override
  Future<List<Geofence>> build(String vehicleId) async {
    final repo = ref.watch(geofenceRepositoryProvider);
    return repo.listGeofences(
      vehicleId: vehicleId.isEmpty ? null : vehicleId,
    );
  }

  GeofenceRepository get _repo => ref.read(geofenceRepositoryProvider);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.listGeofences(vehicleId: arg.isEmpty ? null : arg),
    );
  }

  Future<Geofence> createGeofence(Geofence geofence) async {
    final created = await _repo.createGeofence(geofence);
    ref.invalidateSelf();
    return created;
  }

  Future<Geofence> updateGeofence(Geofence geofence) async {
    final updated = await _repo.updateGeofence(geofence);
    ref.invalidateSelf();
    return updated;
  }

  Future<void> deleteGeofence(String geofenceId) async {
    await _repo.deleteGeofence(geofenceId);
    ref.invalidateSelf();
  }
}

/// Recent geofence ENTER / EXIT events for a vehicle.
final geofenceEventsProvider =
    FutureProvider.family<List<GeofenceEvent>, String>((ref, vehicleId) async {
  final repo = ref.watch(geofenceRepositoryProvider);
  return repo.listEvents(vehicleId: vehicleId.isEmpty ? null : vehicleId);
});

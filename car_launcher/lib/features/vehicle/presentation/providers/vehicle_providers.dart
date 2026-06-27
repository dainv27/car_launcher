import 'package:car_launcher/shared/data/location_service.dart';
import 'package:car_launcher/features/vehicle/data/vehicle_repository.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle.dart';
import 'package:car_launcher/shared/providers/shared_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the vehicle repository — depends on auth and sync endpoint.
final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  final httpClient = ref.watch(httpClientProvider);
  // Read the current sync endpoint from the tracking provider.
  final tracking = ref.watch(vehicleTrackingProvider);
  return VehicleRepository(
    syncClient: VehicleTrackingSyncClient(
      httpClient: httpClient
    ),
    syncEndpoint: tracking.syncEndpoint,
  );
});

/// Async list of all vehicles.
final vehicleListProvider =
    AsyncNotifierProvider<VehicleListNotifier, List<Vehicle>>(
  VehicleListNotifier.new,
);

class VehicleListNotifier extends AsyncNotifier<List<Vehicle>> {
  @override
  Future<List<Vehicle>> build() async {
    final repo = ref.watch(vehicleRepositoryProvider);
    try {
      return await repo.listVehicles();
    } catch (_) {
      return const [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(vehicleRepositoryProvider);
      return repo.listVehicles();
    });
  }

  Future<Vehicle> createVehicle(Vehicle vehicle) async {
    final repo = ref.read(vehicleRepositoryProvider);
    final created = await repo.createVehicle(vehicle);
    // Refresh the list to include the new vehicle.
    ref.invalidateSelf();
    return created;
  }
}

/// Single vehicle by ID (family provider).
final vehicleProvider =
    AsyncNotifierProvider.family<VehicleNotifier, Vehicle, String>(
  VehicleNotifier.new,
);

class VehicleNotifier extends FamilyAsyncNotifier<Vehicle, String> {
  @override
  Future<Vehicle> build(String arg) async {
    final repo = ref.watch(vehicleRepositoryProvider);
    return repo.getVehicle(arg);
  }

  Future<Vehicle> updateVehicle(Vehicle vehicle) async {
    final repo = ref.read(vehicleRepositoryProvider);
    final updated = await repo.updateVehicle(arg, vehicle);
    state = AsyncData(updated);
    // Invalidate list so it picks up the change.
    ref.invalidate(vehicleListProvider);
    return updated;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(vehicleRepositoryProvider);
      return repo.getVehicle(arg);
    });
  }
}

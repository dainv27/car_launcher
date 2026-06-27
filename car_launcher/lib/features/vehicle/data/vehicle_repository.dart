import 'package:car_launcher/features/vehicle/domain/vehicle.dart';
import 'package:car_launcher/shared/data/location_service.dart';

/// Repository that wraps [VehicleTrackingSyncClient] for the vehicle
/// management feature. All HTTP logic lives in the sync client; this
/// layer maps between [Vehicle] domain objects and [VehicleProfile].
class VehicleRepository {
  VehicleRepository({required this._syncClient, required this.syncEndpoint});

  final VehicleTrackingSyncClient _syncClient;

  /// Endpoint override for the vehicle service base URL.
  final String syncEndpoint;

  /// List all vehicles (first page, up to 10).
  Future<List<Vehicle>> listVehicles() async {
    final profiles = await _syncClient.fetchVehicles(endpoint: syncEndpoint);
    return profiles.map(Vehicle.fromProfile).toList(growable: false);
  }

  /// Get a single vehicle by ID.
  Future<Vehicle> getVehicle(String id) async {
    final profile = await _syncClient.getVehicle(endpoint: syncEndpoint, id: id);
    return Vehicle.fromProfile(profile);
  }

  /// Create a new vehicle via POST /vehicles.
  Future<Vehicle> createVehicle(Vehicle vehicle) async {
    final profile = await _syncClient.saveVehicle(endpoint: syncEndpoint, vehicle: vehicle.toProfile());
    return Vehicle.fromProfile(profile);
  }

  /// Update an existing vehicle via PATCH /vehicles/:id.
  Future<Vehicle> updateVehicle(String id, Vehicle vehicle) async {
    final profile = await _syncClient.updateVehicle(endpoint: syncEndpoint, id: id, vehicle: vehicle.toProfile());
    return Vehicle.fromProfile(profile);
  }
}
